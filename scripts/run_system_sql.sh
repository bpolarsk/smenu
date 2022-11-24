#!/bin/sh
#set -xv
if [ "x-$ORACLE_SID" = "x-" ];then
   echo " No Oracle SID"
   exit
fi
MODULE_FROM=$1
SQL_TO_RUN=$2
if [ ! "x-$3" = "x-" ];then
   shift
   shift
   PAR=Y
else
   PAR=N
fi
SBINS=$SBIN/scripts
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

eval cd ${SBIN}/module${MODULE_FROM}
if [ ! "x-$PASSWD" = "x-" ];then
   if [ "x-$PAR" = "x-N" ];then
        sqlplus -s $S_USER/$PASSWD @$SQL_TO_RUN
   else
        sqlplus -s $S_USER/$PASSWD @$SQL_TO_RUN $*
   fi
fi
