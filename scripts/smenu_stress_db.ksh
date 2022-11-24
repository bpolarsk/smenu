#!/usr/bin/ksh
#set -xv
#  let'ss t stress a bit theDB
case $1 in
  1 ) SQL="select * from dba_source" ;;
  2 ) SQL="select * from dba_views" ;;
  * ) echo "I need a stress number" 
      exit ;;
esac
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
while true 
do
sqlplus -s "$CONNECT_STRING" <<!EOF
whenever OSERROR  exit 10
whenever sqlerror exit 11
$SQL
/
!EOF
done
