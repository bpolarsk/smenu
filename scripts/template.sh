#!/bin/sh
#set -xv
SQL=smenu_large_object_in_mem
SBINS=$SBIN/scripts
WK_SBIN=${SBIN}/module
#------------------------
if [ "x-$1" = "x-" ];then
   minvalue=10000
else
   minvalue=$1
fi
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

cd $WK_SBIN
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$PASSWD" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
echo " Progran in progress ...."
sqlplus -s $S_USER/$PASSWD @$WK_SBIN/$SQL $HOST $ORACLE_SID $minvalue
