#!/bin/sh
#set -xv
#echo Check the connection on the DB
S_USER=$1
S_PASSWD=$2
SID=$3
# try to find oraenv :
if [ -f /usr/local/bin/oraenv ];then
   ORAENV=/usr/local/bin/oraenv
elif [ -f $ORACLE_HOME/bin/oraenv ];then
    ORAENV=$ORACLE_HOME/bin/oraenv
elif [ -f /var/opt/bin/oraenv ];then
    ORAENV=/var/opt/bin/oraenv
elif [ -f /etc/oraenv ];then
    ORAENV=/etc/oraenv
elif [ -f /usr/bin/oraenv ];then
    ORAENV=/usr/bin/oraenv
else 
    echo " I did not find oraenv : Please input the full path : \c"
    read ORAENV
fi
ORAENV_ASK=NO
ORACLE_SID=$SID
export ORACLE_SID ORAENV_ASK

. ${ORAENV}

sqlplus -s <<!EOF
${S_USER}/$S_PASSWD
whenever OSERROR  exit 10
whenever sqlerror exit 11
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
