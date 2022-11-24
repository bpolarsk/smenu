#!/bin/sh

cat > clean_logtrc.ini <<EOF
#  each section must be put at begining of line, start with the SID (or dummy SID)
#  have an ADMIN_DIR where the log file and trace file dir are supposed to be
#  extention monitored by default are 'trc log gz'
#  execution is performed on break of each "DIR="

EOF

 ps -ef | grep -v sed | sed -n '/tnslsnr/s@.*tnslsnr \([^ ][^ ]*\) .*@\1@p' | while read LISTENER
do
  echo "[SQLNET_$LISTENER]" >> clean_logtrc.ini
  VAR=`lsnrctl status $LISTENER | grep "Listener Log File" | awk '{print $4'}`
  SQLNET_LOG=`basename $VAR`
  VAR1=`dirname $VAR`
  DIR=`basename $VAR1`
  ADMIN_DIR=`dirname $VAR1`
  echo "ADMIN_DIR=$ADMIN_DIR"   >> clean_logtrc.ini
  echo "DIR=$DIR"               >> clean_logtrc.ini
  echo "FILE_CHECK=$SQLNET_LOG" >> clean_logtrc.ini
  echo "FILE_AGE=7"            >> clean_logtrc.ini
  echo "" >> clean_logtrc.ini
  echo "DIR=$DIR"               >> clean_logtrc.ini
  echo "EXT='log'" >> clean_logtrc.ini
  echo "FILE_DAYS=7"            >> clean_logtrc.ini
  echo "" >> clean_logtrc.ini
done


ps -ef | grep -v grep | grep -v sed | sed -n '/ora_smon/s@.*ora_smon_\([^ ][^ ]*\).*@\1@p' | while read TDIR
do
  # check if this DB is up, otherwise skip
  echo "Adding $TDIR to ini file"
  ORACLE_SID=$TDIR
  ORAENV_ASK=NO
  export ORAENV_ASK ORACLE_SID
  . oraenv
  RET=`$SBIN/module2/s1/smenu_list_init_param.sh -p background_dump_dest`
  RDIR=`dirname $RET`

cat >> clean_logtrc.ini <<!EOF
[$TDIR] 
ADMIN_DIR=$RDIR
FILE_DAYS=7
CORE_DAYS=5

DIR=bdump
FILE_CHECK=alert_$TDIR.log
FILE_AGE=7

DIR=bdump
EXT='trc gz log'
FILE_DAYS=7

DIR=cdump
EXT=\\\*
DIR=udump

!EOF
done

echo "Checking ....."

echo checking
nbr_entry=`grep "^\["  clean_logtrc.ini | grep -v SQLNET_| wc -l`
nbr_smon=`ps -ef | grep "_smon" | grep -v grep | wc -l`
if [ $nbr_entry -eq $nbr_smon ];then
   echo "all db in log"
else
   if [ $nbr_entry -gt $nbr_smon ];then
      echo "More entry than DB up : entry=$nbr_entry  up=$nbr_smon" 
   else
      echo "Less entry than DB up : entry=$nbr_entry  up=$nbr_smon" 
   fi
   grep "^\["  clean_logtrc.ini | sed 's/\[//' | grep -v ^SQLNET_ | sed 's/\]//' | sort > file_entry
   ps -ef |  grep _smon | grep -v grep | cut -f3 -d_ | sort > file_smon
   echo "Entry                                                              Db running"
   echo "=================================================================================="
   sdiff file_entry file_smon
   rm file_entry file_smon
fi
