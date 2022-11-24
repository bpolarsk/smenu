#!/usr/bin/ksh
#set -xv
SBINS=$SBIN/scripts
WK_SBIN=${SBIN}/module2/s5
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

cd $WK_SBIN
TMP=$SBIN/tmp
FOUT=$TMP/Db_Coalescable_extents.txt
> $FOUT
cd $TMP

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

sqlplus -s  "$CONNECT_STRING" <<EOF 
@$WK_SBIN/smenu_db_coalescable_extents.sql $HOST $ORACLE_SID $FOUT
EOF
