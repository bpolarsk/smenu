#set -xv
#echo Check the connection on the DB
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

sqlplus -s "$CONNECT_STRING" <<!EOF
whenever OSERROR  exit 10
whenever sqlerror exit 11
select sysdate from dual
/
!EOF
Result=$?
case $Result in
   0)  echo "Connection done on the DB" ;;
   1)  echo "SqlPlus Error : Check password"  ;;
   10) echo "Operating System error occurs" ;;
   11) echo "SqlPlus Error " ;;
   *)  echo "Non trapped problem" ;;
esac
