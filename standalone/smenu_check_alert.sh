#!/bin/sh
# smenu_check_alert.sh
# Author : Bernard Polarski
# 20-Jan-2000
trap 'rm $SBIN/tmp/chk_alert_$$*
      exit' 0 2 3 15

#set -xv
#----------------------------------------------------------------------------------------
MESG(){
cat    <<EOF

      Usage : smenu_check_alert.sh -h  -a <alert log path & name> -u <mail list> 
                                   -f <today|full|inc> -d -n <path_name> -p
              Where : 

                -a    Give full path and name of alert log if not given, then 
                      smenu will try to fetch this information from the DB

                -f    Type of report  : full ) all messages in the alert log
                                        today) all messages for today
                                        inc  ) send all msg not yet sent
                      if '-f inc' is issued then smenu create a file 
                      smenu_alert_today.log write today date at first 
                      line and then search the alert log for the
                      day messages that he eventually don't have yet. 

 		-h    This help

                -n    Path and name of the file to already sent daily findings. 
                      it may be used only if '-f inc' is used. Use this option 
                      if you do not have write permission in background_dump_dest.
 
                -p    purge the alert log. This option keeps the archive logs
                      7 days. may be used only with '-f inc' 

                -o    Path and of outpout file. Not mandatory if you went to
                      send results to E-mail.

                -u    Mail list : user1@company.com,user2@company.com
                      if this field is present then results will be mailed.

EOF
}
#----------------------------------------------------------------------------------------
. $SBIN/smenu.env
SBINS=$SBIN/scripts
if [ $# -eq 0 ];then
   MESG
   exit
fi

#-------------- Processing call options ---------------------------------
while getopts a:f:o:p:u:hx ARG
do
  case $ARG in
   a) ALERT_LOG=$OPTARG;;
   f) TYPE=$OPTARG;;
   h) MESG
      exit ;;
   n) TODAY_FILE=$OPTARG;;
   o) F_RES=$OPTARG;;
   p) PURGE=Y;;
   u) MAIL_LIST=$OPTARG;;
   x) set -xv ;;
esac
done

#-------------- Determing the compress method --------------------------
if [ "x-$COMPRESS_PRG" = "x-" ];then
   COMPRESS_PRG=compress
elif [ "x-$COMPRESS_PRG" = "x-gzip" ];then
   VAR=`which gzip | awk '{print $1}'`
   if [ "x-$VAR" = "x-no" ];then
      COMPRESS_PRG=compress
      Z_EXT=.Z
   else
      Z_EXT=.gz
   fi
else
   Z_EXT=.Z
fi
#---------------- Determining the alert log file location --------------
if [ "x-$ALERT_LOG" = "x-" ];then
   ALERT_LOG=`$SBIN/module2/s1/smenu_list_init_param.sh -p background_dump_dest`
   ALERT_LOG=${ALERT_LOG}/alert_${ORACLE_SID}.log
   if [ ! -f $ALERT_LOG ];then
      echo " I can't find the alert log. "
      exit
   fi
elif  [ ! -f $ALERT_LOG ];then
   ALERT_LOG=$ORACLE_HOME/../../admin/$ORACLE_SID/bdump/alert_${ORACLE_SID}.log
   if [ ! -f $ALERT_LOG ];then
      echo " I can't find the alert log. "
      exit
   fi
fi
if [ "x-$TYPE" = "x-inc" ];then
   if [ "x-$TODAY_FILE" = "x-" ];then
      VAR=`dirname $ALERT_LOG`
      TODAY_FILE=$VAR/today_alert.log
   fi
   if [ ! -f $TODAY_FILE ];then
      touch $TODAY_FILE
      if [ ! $? -eq 0 ];then
         echo "Error in  creating $TODAY_FILE with '-f inc' option"
         echo "Check if you have read and write permission on : "
         echo " ==> `dirname $ALERT_LOG` "
         exit
      fi
      echo "`date +%Y%m%d`" > $TODAY_FILE
   else
      HEAD_A=`head -1 $TODAY_FILE`
      HEAD_B=`date +%Y%m%d`
      if [ ! "x-$HEAD_A" = "x-$HEAD_B" ];then
         echo "`date +%Y%m%d`" > $TODAY_FILE
      fi
      if [ ! $? -eq 0 ];then
         echo "Error in  creating $TODAY_FILE with '-f inc' option"
         echo "Check if you have read and write permission on : "
         echo " ==> `dirname $ALERT_LOG` "
         exit
      fi
   fi
fi
#------------ Variable section ---------------
C_DATE=`date +"%a %b %e "`
C_HOUR=`date +"%H"`
C_TIME=`date +"%p"`
FOUT=$SBIN/tmp/chk_alert_$$.fout
FTMP=$SBIN/tmp/chk_alert_$$.txt1
FTMP1=$SBIN/tmp/chk_alert_$$.txt2
#----------- Retrieveing messages to send ------------------------------
if [ "x-$TYPE" = "x-inc" ];then
    sed -n "/^$C_DATE/,$ p" $ALERT_LOG > $FTMP
    echo "`date +%Y%m%d`" > $FTMP1
    sed -n '/^ORA-/ p' $FTMP >> $FTMP1
    diff $TODAY_FILE $FTMP1 > $FTMP
    echo "    Last messages in alert_log for $ORACLE_SID: `date +%d-%b-%Y`"  > $FOUT
    echo "--------------------------------------------------------------\n" >> $FOUT
    cat $FTMP | grep "^> "| sed 's/^> //' >> $FOUT
    cat $FTMP | grep "^> "| sed 's/^> //' >> $TODAY_FILE
elif [ "x-$TYPE" = "x-today" ];then
    sed -n "/^$C_DATE/,$ p" $ALERT_LOG > $FTMP
    echo "    Alert log for $ORACLE_SID: `date +%d-%b-%Y`"  > $FOUT
    echo "--------------------------------------------------------------\n" >> $FOUT
    grep '^ORA-' $FTMP  >> $FOUT
elif [ "x-$TYPE" = "x-full" ];then
    echo "    Alert log  for ${ORACLE_SID} "  > $FOUT
    echo "--------------------------------------------------------------\n" >> $FOUT
    grep '^ORA-' $ALERT_LOG  >> $FOUT
fi
#----------- Mailing results (if applicable) ---------------------------
CPT=`cat $FOUT |wc -l `
if [ $CPT -ge 1 ]; then
    if [ ! "x-$MAIL_LIST" = "x-" ];then
       mailx -s 'Please Check the ALERT_LOG File for Errors' $MAIL_LIST < $FOUT
    fi
fi
#----------- if we start a new day then we save old alert_log ----------
if [ "x-$TYPE" = "x-inc" -a "x-$PURGE" = "x-Y" ];then
   HEAD_DATE_A=`head -1 $ALERT_LOG`
   HEAD_DATE_B=`date +%Y%m%d`
   if [ ! "x-$HEAD_DATE_A" = "x-$HEAD_DATE_B" ];then
      cat $ALERT_LOG > ${ALERT_LOG}.`date %a`
      if [ -f  ${ALERT_LOG}.`date %a`.$Z_EXT ];then
         rm -f  ${ALERT_LOG}.`date %a`.$Z_EXT
      fi
      $COMPRESS_PRG  ${ALERT_LOG}.`date %a`
      echo "`date +%Y%m%d`" > $ALERT_LOG
   fi
fi
if [ ! "x-$F_RES" = "x-" ];then
   cp $FOUT $F_RES
fi
