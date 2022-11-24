#!/bin/sh
# program : watch_arc.sh
# purpose : check your archive directory and if actual percentage is > MAX_PERC
#           then undertake the action coded by -a param
# Author : Bernard Polarski
# Date   :  01-08-2000
#           12-09-2005      : added option -s MAX_SIZE
#           20-11-2005      : added option -f to check if an archive is applied on data guard site before deleting it
#           20-12-2005      : added option -z to check if an archive is still needed by logminer in a streams operation
#           27-04-2014      : Rens Roeland : changed list option to redirect into verbose mode
#                           : Rens Roeland : changed AIX to correct total-free 
# set -xv

#--------------------------- default values if not defined --------------
# put here default values if you don't want to code then at run time
MAX_PERC=85
ARC_DIR=
ACTION=
LOG=/tmp/watch_arch.log
EXT_ARC=
PART=2
#------------------------- Function section -----------------------------
get_perc_occup()
{

  cd $ARC_DIR
  if [ $MAX_SIZE -gt 0 ];then
       # size is given in mb, we calculate all in K
       TOTAL_DISK=`expr $MAX_SIZE \* 1024`
       USED=`du -ks . | tail -1| awk '{print $1}'`    # in Kb!
  else
    USED=`df -k . | tail -1| awk '{print $3}'`    # in Kb!
    if [ `uname -a | awk '{print $1}'` = HP-UX ] ;then
           TOTAL_DISK=`df -b . | cut -f2 -d: | awk '{print $1}'`
    elif [ `uname -s` = AIX ] ;then
           TOTAL_DISK=`df -k . | tail -1| awk '{print $2}'`
           FREE=`df -k . | tail -1| awk '{print $3}'`
           USED=`expr $TOTAL_DISK - $FREE`
    elif [ `uname -s` = ReliantUNIX-N ] ;then
           TOTAL_DISK=`df -k . | tail -1| awk '{print $2}'`
    else
             # works on Sun
             TOTAL_DISK=`df -b . | sed  '/avail/d' | awk '{print $2}'`
    fi
  fi
  USED100=`expr $USED \* 100`
  USG_PERC=`expr $USED100 / $TOTAL_DISK`
  echo $USG_PERC
}
#------------------------ Main process ------------------------------------------
usage()
{
    cat <<EOF


              Usage : watch_arc.sh -h
                      watch_arc.sh  -p <MAX_PERC> -e <EXTENTION> -l -d -m <TARGET_DIR> -r <PART>
                                    -t <ARCHIVE_DIR> -c <gzip|compress> -v <LOGFILE> 
                                    -s <MAX_SIZE (meg)> -i <SID> -g -f


              Note :

                       -c compress file after move using either compress or gzip (if available)
                          if -c is given without -m then file will be compressed in ARCHIVE DIR
                       -d Delete selected files
                       -e Extention of files to be processed
                       -f Check if log has been applied, required -i <sid> and -g if v8
                       -g Version 8 (use svrmgrl instead of sqlplus /
                       -i Oracle SID
                       -l List file that will be processing using -d or -m
                       -h help
                       -m move file to TARGET_DIR
                       -p Max percentage above wich action is triggered.
                          Actions are of type -l, -d  or -m
                       -t ARCHIVE_DIR
                       -s Perform action if size of target dir is bigger than MAX_SIZE (meg)
                       -v report action performed in LOGFILE
                       -r Part of files that will be affected by action :
                           2=half, 3=a third, 4=a quater .... [ default=2 ]
                       -z Check if log is still needed by logminer (used in streams), 
                                it requires -i <sid> and also -g for Oracle 8i

              This program list, delete or move half of all file whose extention is given [ or default 'arc']
              It check the size of the archive directory and if the percentage occupancy is above the given limit
              then it performs the action on the half older files.

        How to use this prg :

                run this file from the crontab, say, each hour.
     example

 
     1) Delete archive that is sharing common arch disk, when you are at 85% of 2500 mega perform delete half of the files
     whose extention is 'arc' using default affected file (default is -r 2)

     0,30 * * * * /usr/local/bin/watch_arc.sh -e arc -t /arc/POLDEV -s 2500 -p 85 -d -v /var/tmp/watch_arc.POLDEV.log

     2) Delete archive that is sharing common disk with oother DB in /archive, act when 90% of 140G, affect by deleting
     a quater of all files (-r 4) whose extention is 'dbf' but connect before as sysdba in POLDEV db (-i) if they are 
     applied (-f is a dataguard option) 

     watch_arc.sh -e dbf -t /archive/standby/CITSPRD -s 140000 -p 90 -d -f -i POLDEV -r 4 -v /tmp/watch_arc.POLDEV.log

     3) Delete archive of DB POLDEV when it reaches 75% affect 1/3 third of files, but connect in DB to check if
     logminer do not need this archive (-z). this is usefull in 9iR2 when using Rman as rman do not support delete input
     in connection to Logminer.

     watch_arc.sh -e arc -t /archive/standby/CITSPRD  -p 75 -d -z -i POLDEV -r 3 -v /tmp/watch_arc.POLDEV.log
     

EOF
}
#------------------------- Function section -----------------------------
if [ "x-$1" = "x-" ];then
      usage
      exit
fi

MAX_SIZE=-1  # disable this feature if it is not specificaly selected
while getopts  c:e:p:m:r:s:i:t:v:dhlfgz ARG
  do
    case $ARG in
       e ) EXT_ARC=$OPTARG ;;
       f ) CHECK_APPLIED=YES ;;
       g ) VERSION8=TRUE;;
       i ) ORACLE_SID=$OPTARG;;
       h ) usage
           exit ;;
       c ) COMPRESS_PRG=$OPTARG ;;
       p ) MAX_PERC=$OPTARG ;;
       d ) ACTION=delete ;;
       l ) ACTION=list ;;
       m ) ACTION=move
           TARGET_DIR=$OPTARG
           if [ ! -d $TARGET_DIR ] ;then
               echo "Dir $TARGET_DIR does not exits"
               exit
           fi;;
       r)  PART=$OPTARG ;;
       s)  MAX_SIZE=$OPTARG ;;
       t)  ARC_DIR=$OPTARG ;;
       v)  VERBOSE=TRUE
           LOG=$OPTARG
           if [ ! -f $LOG ];then
               > $LOG
           fi ;;
       z)  LOGMINER=TRUE;;
    esac
done


if [ "x-$ARC_DIR" = "x-" ];then
     echo "NO ARC_DIR : aborting"
     exit
fi
if [ "x-$EXT_ARC" = "x-" ];then
     echo "NO EXT_ARC : aborting"
     exit
fi
if [ "x-$ACTION" = "x-" ];then
     echo "NO ACTION : aborting"
     exit
fi

if [ ! "x-$COMPRESS_PRG" = "x-" ];then
   if [ ! "x-$ACTION" =  "x-move" ];then
         ACTION=compress
   fi
fi

if [ "$CHECK_APPLIED" = "YES" ];then
   if [ -n "$ORACLE_SID" ];then
         export PATH=$PATH:/usr/local/bin
         export ORAENV_ASK=NO
         export ORACLE_SID=$ORACLE_SID
         . /usr/local/bin/oraenv
   fi
   if [ "$VERSION8" = "TRUE" ];then
      ret=`svrmgrl <<EOF
connect internal
select max(sequence#) from v\\$log_history ;
EOF`
LAST_APPLIED=`echo $ret | sed 's/.*------ \([^ ][^ ]* \).*/\1/' | awk '{print $1}'`
   else

    ret=`sqlplus -s '/ as sysdba' <<EOF
set pagesize 0 head off pause off
select max(SEQUENCE#) FROM V\\$ARCHIVED_LOG where applied = 'YES';
EOF`
   LAST_APPLIED=`echo $ret | awk '{print $1}'`
   fi

elif [ "$LOGMINER" = "TRUE" ];then
   if [ -n "$ORACLE_SID" ];then
         export PATH=$PATH:/usr/local/bin
         export ORAENV_ASK=NO
         export ORACLE_SID=$ORACLE_SID
         . /usr/local/bin/oraenv
   fi
    var=`sqlplus -s '/ as sysdba' <<EOF
set pagesize 0 head off pause off serveroutput on 
DECLARE
 hScn number := 0;
 lScn number := 0;
 sScn number;
 ascn number;
 alog varchar2(1000);
begin
  select min(start_scn), min(applied_scn) into sScn, ascn from dba_capture ;
  DBMS_OUTPUT.ENABLE(2000);
  for cr in (select distinct(a.ckpt_scn)
             from system.logmnr_restart_ckpt\\$ a
             where a.ckpt_scn <= ascn and a.valid = 1
               and exists (select * from system.logmnr_log\\$ l
                   where a.ckpt_scn between l.first_change# and l.next_change#)
              order by a.ckpt_scn desc)
  loop
    if (hScn = 0) then
       hScn := cr.ckpt_scn;
    else
       lScn := cr.ckpt_scn;
       exit;
    end if;
  end loop;

  if lScn = 0 then
    lScn := sScn;
  end if;
   select min(sequence#) into alog from v\\$archived_log where lScn between first_change# and next_change#;
  dbms_output.put_line(alog);
end;
/
EOF`
 
  # if there are no mandatory keep archive, instead of a number we just get the "PLS/SQL successfull" 
  ret=`echo $var | awk '{print $1}'`
  if [ ! "$ret" = "PL/SQL" ];then
     LAST_APPLIED=$ret
  else
     unset LOGMINER

  fi
fi

PERC_NOW=`get_perc_occup`
if [ $PERC_NOW -gt $MAX_PERC ];then
     cd $ARC_DIR
     cpt=`ls -tr *.$EXT_ARC | wc -w`
     if [ ! "x-$cpt" = "x-" ];then
          MID=`expr $cpt / $PART`
          cpt=0
          ls -tr *.$EXT_ARC |while read ARC
              do
                 cpt=`expr $cpt + 1`
                 if [ $cpt -gt $MID ];then
                      break
                 fi
                 if [ "$CHECK_APPLIED" = "YES" -o "$LOGMINER" = "TRUE" ];then
                    VAR=`echo $ARC | sed 's/.*_\([0-9][0-9]*\)\..*/\1/' | sed 's/[^0-9][^0-9].*//'`
                    if [ $VAR -gt $LAST_APPLIED ];then
                         continue
                    fi
                 fi
                 case $ACTION in
                      'compress' ) $COMPRESS_PRG $ARC_DIR/$ARC
                                 if [ "x-$VERBOSE" = "x-TRUE" ];then
                                       echo " `date +%d-%m-%Y' '%H:%M` : $ARC compressed using $COMPRESS_PRG" >> $LOG
                                 fi ;;
                      'delete' ) rm $ARC_DIR/$ARC
                                 if [ "x-$VERBOSE" = "x-TRUE" ];then
                                       echo " `date +%d-%m-%Y' '%H:%M` : $ARC deleted" >> $LOG
                                 fi ;;
                      'list'   ) if [ "x-$VERBOSE" = "x-TRUE" ];then
                                       echo " `date +%d-%m-%Y' '%H:%M` : list `ls -l $ARC_DIR/$ARC`  " >> $LOG
                                 else
                                       ls -l $ARC_DIR/$ARC 
                                 fi ;;
                      'move'   ) mv  $ARC_DIR/$ARC $TARGET_DIR
                                 if [ ! "x-$COMPRESS_PRG" = "x-" ];then
                                       $COMPRESS_PRG $TARGET_DIR/$ARC
                                       if [ "x-$VERBOSE" = "x-TRUE" ];then
                                             echo " `date +%d-%m-%Y' '%H:%M` : $ARC moved to $TARGET_DIR and compressed" >> $LOG
                                       fi
                                 else
                                       if [ "x-$VERBOSE" = "x-TRUE" ];then
                                             echo " `date +%d-%m-%Y' '%H:%M` : $ARC moved to $TARGET_DIR" >> $LOG
                                       fi
                                 fi ;;
                  esac

          done
      else
          echo "Warning : The filesystem is not full due to archive logs !"
          exit
      fi
elif [ "x-$VERBOSE" = "x-TRUE" ];then
     echo "Nothing to do at `date +%d-%m-%Y' '%H:%M` USAGE $PERC_NOW << $MAX_PERC (keep 1/$PART) or $MAX_SIZE" >> $LOG
fi
