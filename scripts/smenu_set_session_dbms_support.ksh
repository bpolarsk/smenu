#!/usr/bin/ksh
#set -xv
#
if [ "x-$1" = "x-" ];then
   echo " "
   echo " "
   echo "  I need a SID !"
   echo " "
   echo "  Usage : $0 SID  [TRUE|FALSE] "
   echo 
   echo "  set the SQL DBMS_SUPPORT trace on|off in the session Oracle SID is given "
   echo "  Use this script when you want to know why a session is taking "
   echo "  so much CPU"
   echo 
   echo 
   exit
fi
SID=$1
BOOL=$2
S_USER=SYS
SBINS=${SBIN}/scripts
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# check pkg dbms_supp is installed
cpt=`sqlplus  -s "$CONNECT_STRING" <<EOF
        set pages 0 feed off echo on head off verify off pause off
        select nvl(count(1),0) from dba_procedures where object_name = 'DBMS_SUPPORT'
/
EOF`
if [ $cpt -gt 0 ];then
  :
else
  `sqlplus  -s "$CONNECT_STRING" >/dev/null <<EOF
   @$ORACLE_HOME/rdbms/admin/dbmssupp.sql
/
EOF`
fi


SERIAL=`sqlplus  -s "$CONNECT_STRING" <<EOF  
set pages 0 feed off echo on head off verify off pause off
select s.serial# from v\\$session s where s.sid = '$SID'
/
EOF`

if [ "x-$SERIAL" = "x-" ];then
     echo "Error : could not retrieve serial for SID=$SID"
     echo "Press any key to continue..."
     read ff
     exit 1
fi

if [ $BOOL = TRUE ];then        
      sqlplus  "$CONNECT_STRING" <<EOF2
set feed on verify on pause off
prompt "doing : execute sys.dbms_support.start_trace_in_session($SID,$SERIAL,TRUE,TRUE)
execute sys.dbms_support.start_trace_in_session($SID,$SERIAL,TRUE,TRUE)
/
exit
EOF2

else

      sqlplus  "$CONNECT_STRING" <<EOF2
set feed on verify on pause off
prompt "doing : execute sys.dbms_support.stop_trace_in_session($SID,$SERIAL)
execute sys.dbms_support.stop_trace_in_session($SID,$SERIAL)
/
exit
EOF2

fi
