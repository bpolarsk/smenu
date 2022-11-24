#!/bin/sh
#
# Author   : Polarski bernard
# date     : 01-Sep-2005
# Program  : check_dr_db.ksh         This script connect to the primary DB, takes some measurement
#                                    and compare to the DR to see if the archive logs where shipped
#                                    and applied.
#                                    The db, primary and dr are refenrenced by their tnsnames entry
#                                    this script assume that the DR tnsentry is identical to  dr ORACLE_SID
# example of ini file :
# <-- Start of example -->
#[ORACLE_SID]
#PRIMARY=<TNS_ORACLE_SID>
#P_USER=SYSTEM
#P_PASS=my_password
#DO_IT=N              # if DO_IT=N then skip this section
#THRESHOLD_GAP=3      # Number of archive non applied before warningA
#DELAY=Y              # retrieve the delay information from primary
#/                    # End of section
# <-- End of example -->
#
#set -x
trap ' if [ -f $TMPFIL ];then
   rm -f $TMPFIL
fi '0 1 2 3 4 5 6 7 8 9  13 15

TMPFIL=/tmp/tmpfile$$

# --------------------- Functions ------------------------------
do_check()
{
  > $TMPFIL

  echo "$ORACLE_SID             (primary=$PRIMARY) Gap=$THRESHOLD_GAP" >> $TMPFIL
  echo "-----------------------------------------------" >> $TMPFIL
  ORACLE_SID=$ORACLE_SID
  export  ORACLE_SID
  ORAENV_ASK=NO
  export ORAENV 
  . /usr/local/bin/oraenv

#set -x
# if there is a delay
if [ "$DELAY" = TRUE ];then
  # ............................................
  # delay
  # ............................................
  var=`sqlplus  -s "$P_USER/$P_PASS@$PRIMARY" <<EOF
set heading off embedded off pause off verify off
select value FROM V\\$PARAMETER where name = 'log_archive_dest_$DEST_DELAY'
/
exit
EOF`
 var0=`echo $var | tr -d '\n'`
 delay=`echo $var0 |  sed 's/.* DELAY=\([^ ][^ ]*\)$/\1/'`
 
  # get the max applied  
  var=`sqlplus  -s '/ as sysdba' <<EOF
set heading off embedded off pause off verify off
select min(SEQUENCE#) FROM V\\$ARCHIVED_LOG where next_time > (sysdate - (${delay}/1440))
/
exit
EOF`
#bpa
#var=7984
  DELAYED_LOG=`echo $var | tr -d '\n'`
  MAX_DELAYED_LOG=`expr $DELAYED_LOG - $THRESHOLD_GAP`      #this is the first non applied log with gap
  # now if the  diff between current time and nex_time dernier log applique is supperior to 0
  # then the gap is beyond the apply delay et we output red msg.
  var0=`sqlplus  -s '/ as sysdba' <<EOF
set heading off embedded off pause off verify off
select to_char(next_time ,'YYYY-MM-DD HH24:MI:SS') FROM V\\$ARCHIVED_LOG where sequence# = $MAX_DELAYED_LOG
/
exit
EOF`
       var=`echo $var0  | tr -d '\n'`
  var0=`sqlplus  -s '/ as sysdba' <<EOF
set heading off embedded off pause off verify off
select applied FROM V\\$ARCHIVED_LOG where sequence# = $MAX_DELAYED_LOG
/
exit
EOF`
  res=`echo $var0  | tr -d '\n'`
  if [ ! "$res" =  'YES' ];then
       DIAG="&red"
       echo "Current time is  : `date +%Y-%m-%d' '%H:%M:%S`" >> $TMPFIL
       echo "Max allowed was  : $var  (time with gap allowance ($THRESHOLD_GAP) and delay of $delay min" >> $TMPFIL
       echo "archive $MAX_DELAYED_LOG should have already been applied"  >> $TMPFIL
  else
       DIAG="&green"
       echo "Current time is  : `date +%Y-%m-%d' '%H:%M:%S`" >> $TMPFIL
       echo "Max allowed was  : $var  (delay of $delay min + $THRESHOLD_GAP logs)" >> $TMPFIL
       echo "archive $MAX_DELAYED_LOG which is in the boundaries is applied"  >> $TMPFIL
  fi

  # get the first time of max_applied + gap
else
  # ............................................
  # No delay
  # ............................................

  # last in Primary
  var=`sqlplus  -s "$P_USER/$P_PASS@$PRIMARY" <<EOF
set heading off embedded off pause off verify off
select max(sequence#) FROM V\\$ARCHIVED_LOG
/
exit
EOF`
  #var=898
  LAST_PRODUCED=`echo $var | awk '{print $1}'`
  # last in DR
  var=`sqlplus -s '/ as sysdba' <<EOF
set heading off embedded off pause off verify off
   select sequence#
          FROM V\\$ARCHIVED_LOG where applied = 'YES' and sequence# = (
   select max(SEQUENCE#) FROM V\\$ARCHIVED_LOG where applied = 'YES' )
/
exit
EOF`
  LAST_APPLIED=`echo $var | awk '{print $1}'`
  echo "Last produced on `echo $PRIMARY | awk '{printf("%-8.8s",$1)}'`  = $LAST_PRODUCED" >> $TMPFIL
  echo "Last applied  on `echo $ORACLE_SID | awk '{printf("%-8.8s",$1)}'`  = $LAST_APPLIED" >> $TMPFIL
  LAST_PRODUCED=${LAST_PRODUCED:--1}
  LAST_APPLIED=${LAST_APPLIED:--1}
  if [ $LAST_PRODUCED = $LAST_APPLIED ];then
       DIAG="&green"
  elif [ $LAST_PRODUCED -lt $LAST_APPLIED ];then
        DIAG="&red"
        echo "Dataguard is inconsistent : more archives applied than ever exits on $PRIMARY" >> $TMPFIL
        echo "Check for a possible resetlogs on primary" >> $TMPFIL
  else
       #test GS
       #echo "Test, LAST_APPLIED=$LAST_APPLIED , THRESHOLD_GAP=$THRESHOLD_GAP"
       var=`expr $LAST_APPLIED + $THRESHOLD_GAP`
       if [ $var -ge $LAST_PRODUCED ];then
             DIAG="&yellow"
       else 
            DIAG="&red"
            echo "Max allowed gap ($THRESHOLD_GAP) in applied logs has been exceeded" >> $TMPFIL
       fi
   fi
fi
echo >> $TMPFIL
echo "$DIAG"
cat $TMPFIL
}
# --------------------------------------------------------------
help()
{

        cat <<EOF 

            check_dr_db -p <PRIMARY> -d <DR_SID> -u <PRIMARY_USER> -a <PRIMARY_PASSWD> -g <nbr_threshold>
                        -y <DEST_DELAY>
         or
            check_dr_db -f <FILE> [ <PRIMARY> ]


            Notes : if -f is provide, all other params are discarted

                    The file contains a section and the needed parameters

                     [SECTION_NAME]
                     PRIMARY=AKTIVDB
                     DR=DRDB
                     P_PASS=THIS_IS_SYS_PASSWORD_OF_AKTIVDB
                     P_USER=I_AM_A_USER_WITH_GRANT_SELECT_ON_V\$ARCHIVE_LOG
                     THRESHOLD_GAP=3
                     DELAY=TRUE

            If you use only the file, you can still restrict to one DB by given it as argument 3,
            otherwise all file is processed.
       
            ie)    check_dr_db -f chk_dr_db.ini CITSDR

           if you use a delay, then the script will connect to the primary and get he delay value from
           v$parameter, by default it will look at second dest. You can point to another dest using
           DEST_DELAY=[2..9]
                 
           when a delay apply is used, the rule becomes
            
             if [ current_time - first_time_column_of_redolog ((max(applied) + GAP)) > DELAY ];then
                red
             else
                green
             fi

EOF
      exit
}
# --------------------------------------------------------------
# default values
DEST_DELAY=2
# end of default values

while getopts f:p:d:a:u:hg: ARG
do
   case $ARG in
      a ) P_PASS=$OPTARG ;;
      u ) P_USER=$OPTARG;;
      g ) THRESHOLD_GAP=$OPTARG;;
      p ) PRIMARY=$OPTARG;;
      d ) ORACLE_SID=$OPTARG 
          DR=$OPTARG;;
      f ) INI_FILE=$OPTARG 
          ONLY_DR=$3;;
      y ) DELAY=TRUE ; DEST_DELAY=$2 ; shift ;;
      h ) help ;;
      * ) echo "unknown parameters" 
          exit;;
   esac
done
# default value
THRESHOLD_GAP=${THRESHOLD_GAP:-3}
# if an ini file was provided we will work only with its content
if [ -n "$INI_FILE" ];then
   unset PRIMARY
   unset DR
   unset P_PASS
elif [ -z "$PRIMARY" ];then
      echo "no Primary given"
      help
elif [ -z "$DR" ];then
      echo "no DR ORACLE_SID given "
      help
elif [ -z "$P_PASS" ];then
      echo "Missing remote password given to connect"
      help
elif [ -z "$P_USER" ];then
      echo "Missing remote user given to connect"
      help
else
    do_check $PRIMARY $P_USER $P_PASS
    exit
fi

# if no ini file then we will work with PRIMARYn DR, P_PASS
if [ -f "$INI_FILE" ];then
    cat $INI_FILE | while read line NOIMPORTANT
    do
      section=`echo $line |  grep "^\[" `
      if [ $? -eq 0 ];then
         ORACLE_SID=`echo $section | sed -e 's/\[//' -e 's/\]//'`
         if [ -n "$ONLY_DR" ];then
            if [ ! "$ORACLE_SID" = "$ONLY_DR" ];then
               continue
            fi
         fi
         # unset variables so we are not affected by previous execution 
         # (pas a un vieux singe qu'on apprend a faire la grimace)
         unset PRIMARY
         unset P_PASS
         unset P_USER
         unset DO_IT
         unset THRESHOLD_GAP
         unset DELAY

         while true 
         do
            read line NOIMPORTANT
            end_section=`echo $line |  grep "^/" `
            if [ $? -eq 0 ];then
                if [ "$DO_IT-x" = "Y-x" ];then
                    do_check $ORACLE_SID $PRIMARY P_PASS
                fi
                break
            fi
            par=`echo $line | cut -f1 -d=`
            value=`echo $line | cut -f2 -d=`
            case $par in
                PRIMARY ) PRIMARY=$value ;;
                P_USER  ) P_USER=$value ;;
                P_PASS  ) P_PASS=$value ;;
                DO_IT   ) DO_IT=$value ;;
                DELAY   ) DELAY=TRUE;;
                THRESHOLD_GAP   ) THRESHOLD_GAP=$value ;;
            esac
         done
      fi
    done
fi
