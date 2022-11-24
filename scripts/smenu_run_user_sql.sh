#!/bin/sh
#set -xv
#--------------- declare some parameters -------------
SQL_TO_RUN=$1
USER=$2
MODULE=$3
FOUT=$4
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

eval cd ${SBIN}/module"$MODULE"



MODULE_DIR=$SBIN/module$MODULE

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID

if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
sqlplus -s "$CONNECT_STRING" @$MODULE_DIR/$SQL_TO_RUN $HOST $ORACLE_SID $FOUT
echo "\n\n"
if [ ! "x-FOUT" = "x-" ];then
   echo "  Result in $FOUT "
fi

