#!/bin/sh
#-------------------------------------------------------------------------------
#-- Script 	smenu_statpack.sh
#-- Purpose 	Execute statpack, sleep x time, run utlestat and show report.txt
#-- For:		All versions
#-- Author 	Bpolarsk
#-- Date        23-Jan-2001      : Creation
#-- Description: This script rely on the statspack found in ./rdbms/admin
#__ adapted to smenu by B. Polarski
#-------------------------------------------------------------------------------
#set -x
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
SBINS=$SBIN/scripts
PURGE=N

#set -x
if [ -z "$ORACLE_SID" ];then
   echo "Oracle SID is not defined .. aborting "
   exit 0
fi
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
show_help() {
cat <<EOF


	This scripts launch statspack sleep x seconds, run reportstat and let you review the report.txt file. 
        A copy of the execution is put in '$SBIN/tmp'
  
        Usage : Take snap

                sstp -n 10 -s 500 -b 31 -e 35
                sstp -x

         Snap report :

                sstp -b 15
                sstp -p              # Purge stats id from x to y  <you will be asked the value>
                sstp -r              #

         Snap list:

                sstp -l -rn <nn>     # Display available measurements

        Notes : 

                -x : Take one snap now
                -n : Level of details. by default it is 10, possible is 5
                -s : Seconds to sleep between the 2 measurement
                     s=0 will take only one measurment and report using a previous first measurment
      -b <snap_id> : report using start snap_id
      -e <snap_id> : report using stop snap_id (default is last snap_id)

               -rn : show <nn> lines

EOF
}
#-------------------------------------------------------------------------------
check_if_stat_exists()
{
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [ "x-$CONNECT_STRING" = "x-" ];then
     echo "could no get a the password of $S_USER"
     exit 0
fi

$SBINS/smenu_check_exists.sh perfstat.STATS\$PARAMETER
echo "$?"
}
#-------------------------------------------------------------------------------
if [ -z "$1"  ];then
   show_help
   exit 0
fi
if [ "$1" = "-h" ];then
       show_help
       exit
fi
  SEE_REPORT=N
  SLEEP=60
  LEVEL=10
  ROWNUM=30
  while [ -n "$1" ] 
    do
       case "$1" in
          -n ) LEVEL=$2; shift ;;
          -x ) RUNNOW=TRUE ;;
          -s ) SLEEP=$i; shift ;;
          -p ) PURGE=Y
               PURGE1=$2
               PURGE2=$3 ; shift ;shift ;;
         -rn ) ROWNUM=$2; shift ;;
          -r ) LAST_REPORT=TRUE
               SEE_REPORT=Y ;;
          -b ) SNP_ID0=$2; shift
               SEE_REPORT=Y ;;
          -e ) SNP_ID1=$2; shift
               SEE_REPORT=Y ;;
          -l ) LIST_STAT=TRUE ;;
       esac
       shift
  done

if [ $? -eq 0 ];then
   . $SBIN/scripts/passwd.env
   . ${GET_PASSWD} $S_USER $ORACLE_SID
fi
  
if [ "$LIST_STAT" = "TRUE" ];then
sqlplus -s "$CONNECT_STRING" <<EOF

set feed off head off termout off verify off  termout on feed on head on linesize 124 pagesize 66

column snap_id       format 9999990 heading 'Snap Id'
column snap_date     format a21   heading 'Snapshot Started'
column host_name     format a15   heading 'Host'
column parallel      format a3    heading 'OPS' trunc
column level         format 99    heading 'Snap|Level'
column versn         format a7    heading 'Release'
column ucomment          heading 'Comment' format a25;

prompt
prompt
prompt Snapshots for this database instance
prompt ====================================

select * from (
select s.snap_id
     , s.snap_level                                      "level"
     , to_char(s.snap_time,' dd Mon YYYY HH24:mi:ss')    snap_date
     , di.host_name                                      host_name
     , s.ucomment
  from stats\$snapshot s
     , stats\$database_instance di
     ( select dbid , instance_number  from v\$database, v\$instance  ) v
 where s.dbid              = v.dbid
   and di.dbid             = v.dbid
   and s.instance_number   = v.instance_number
   and di.instance_number  = v.instance_number
   and di.startup_time     = s.startup_time
 order by db_name, instance_name, snap_id
) where rownum < $ROWNUM
/

EOF
   exit 
fi
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
#res=`check_if_stat_exists`
res=0
if [ ! $res -eq 0 ];then
   echo "I need to create Statspack"
   if [ ! -f $ORACLE_HOME/rdbms/admin/spcreate.sql ];then
      echo "\$ORACLE_HOME/rdbms/admin/spcreate.sql does not exists ! " 
      exit 2
   fi
   echo " "
   echo " run now : \$ORACLE_HOME/rdbms/admin/spcreate.sql" 
   echo " "
   echo "            if you have problems during statscre with existing objects"
   echo "            run spdrop.sql first"
   echo " "
else
   echo "Found statspack"
fi
var=$ORACLE_SID:perfstat
grep $var $SBIN/scripts/.passwd > /dev/null
if [ $? -eq 0 ];then
   S_USER=perfstat 
   . $SBIN/scripts/passwd.env
   . ${GET_PASSWD} $S_USER $ORACLE_SID
else
   CONNECT_STRING="perfstat/perfstat"
fi

if [ "$PURGE" = "Y" ]
then
   sqlplus -s  "$CONNECT_STRING" <<EOF
@$ORACLE_HOME/rdbms/admin/sppurge.sql 
$PURGE1 
$PURGE2
/
EOF
   exit
fi


if [ "$SEE_REPORT" = "N" ];then
   if [ -n "$RUNNOW" ];then
      sqlplus "$CONNECT_STRING" <<EOF
              execute statspack.snap(i_snap_level=>$LEVEL)
EOF
   exit
   else
     if $SBINS/yesno.sh "Measurment time to last $SLEEP seconds " DO Y
        then
         :
     else
          echo "    Measurement duration (seconds) ==> \c"
         read SLEEP
     fi

START=`date +%H:%M:%S`
cd $SBIN/tmp
echo
echo "    Running statstpack first measurement "
echo
sqlplus "$CONNECT_STRING" <<EOF
 execute statspack.snap(i_snap_level=>$LEVEL)
EOF

echo
echo "    [`date +%H:%M:%S`] : Sleeping $SLEEP Seconds"
echo
sleep $SLEEP
echo
echo "    Running second statspack measurement"
echo
sqlplus  "$CONNECT_STRING" <<EOF
 execute statspack.snap(i_snap_level=>$LEVEL)
EOF
STOP=`date +%H:%M:%S`

  fi
fi   # SEE_REPORT=N

if [ "$LAST_REPORT" = "TRUE" ];then
        VAR=`sqlplus -s  "$CONNECT_STRING" <<EOF
set head off feed off termout off pause off
select prev||':'|| snap_id from (
select snap_id, prev from ( select snap_id , lag(snap_id,1,0) over( order by snap_time )  prev
    from STATS\\\$SNAPSHOT  order by snap_id )order by  1 desc
) where rownum = 1
/
EOF`
SNP_ID0=`echo $VAR | cut -f1 -d':'`
SNP_ID1=`echo $VAR | cut -f2 -d':'`

elif [ -n "$SNP_ID0" ];then
   if [ -z "$SNP_ID1" ];then
        SNP_ID1=`sqlplus -s  "$CONNECT_STRING" <<EOF
set head off feed off termout off pause off
select max(snap_id) from stats\\\$snapshot ;
EOF`
   SNP_ID1=`echo $SNP_ID1 | awk '{print $1}' `
   fi 
fi

FOUT=$SBIN/tmp/report_${ORACLE_SID}_`date +%m%d%H%M`.txt
FOUT0=$SBIN/tmp/report.txt


   sqlplus "$CONNECT_STRING" <<EOF
@${ORACLE_HOME}/rdbms/admin/spreport
$SNP_ID0
$SNP_ID1
$FOUT0
EOF


if [ -f $FOUT0 ];then
    cat > $FOUT <<%

   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID   
   
   *************************************************************
   *                                                           *
   *                 Report of statspack                       *
   *                                                           *
   *************************************************************

   Start time :  $START
   Stop  time :  $STOP
   Duration   :  $SLEEP secs
   -------------------------------------------------------------

%
    cat $FOUT0 >> $FOUT
    rm  $FOUT0
    if $SBINS/yesno.sh "to review the report now " DO Y
        then
          vi $FOUT
    fi

else
   echo " Error, report not found"
fi
