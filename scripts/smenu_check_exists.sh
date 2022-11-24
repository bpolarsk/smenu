#!/bin/ksh
#set -xv
# Check object existence
if [ "x-$1" = "x-" ];then
      # no variable
      exit 2
fi
PAR1=$1
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
sqlplus -s "$CONNECT_STRING" >/dev/null <<!EOF
whenever OSERROR  exit 10
whenever sqlerror exit 11
select count(1) from $PAR1 ;
/
!EOF
Result=$?
#echo $Result
return $Result
#case $Result in
#   0)  echo "SQL ok" ;;
#   1)  echo "SqlPlus Error : Check password"  ;;
#   10) echo "Operating System error occurs" ;;
#   11) echo "SqlPlus Error " ;;
#   *)  echo "Non trapped problem" ;;
#esac
