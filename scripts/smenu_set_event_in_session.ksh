#!/bin/ksh
#set -xv
# For a more detailed trace, which show waits and the value of bind variables, you can use: 
#  dbms_system.set_ev( sid,serial#,10046,12,'') 
#
if [ "x-$1" = "x-" ];then
   echo " "
   echo " "
   echo "  I need a SID !"
   echo " "
   echo "  Usage : $0 SID [TRUE|FALSE] "
   echo 
   echo "  set the SQL TRACE on|off in the session Oracle SID is given "
   echo "  Use this script when you want to know why a session is taking "
   echo "  so much CPU"
   echo 
   echo 
   exit
else
   if [ "x-$3" = "x-SERIAL" ];then
         SERIAL=TRUE 
   else
      SERIAL=FALSE
      ps -ef | awk '{print $2}' | grep $1  >> /dev/null
      if [ -z "$2" ];then
           echo " Missing \$2"
           echo " I don't know if you want to set or unset the session in trace level !"
           exit
      fi
   fi
fi
SID=$1
EVENT=${2:-10046}
LEVEL=${3:-0}
SBINS=${SBIN}/scripts
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

VAR=`sqlplus  -s "$CONNECT_STRING" <<-EOF  
	set pages 0 feed off echo on head off verify off pause off
        select s.serial# from v\\$session s where s.sid = '$SID'
	/
	EOF`
SERIAL=`echo $VAR |awk '{ print $1'}`
if [ "x-$SERIAL" = "x-" ];then
     echo "Error : could not retrieve serial for SID=$SID"
     echo "Press any key to continue..."
     read ff
     exit 1
fi
        
      sqlplus -s  "$CONNECT_STRING" <<EOF2
      set feed on verify on pause off head off
      set lines 190
      prompt doing : execute sys.dbms_system.set_ev($SID,$SERIAL,$EVENT,$LEVEL,'')
      prompt
      execute sys.dbms_system.set_ev($SID,$SERIAL,$EVENT,$LEVEL,'')
      /
      prompt tracefile:
      SELECT TRACEFILE FROM V\$SESSION JOIN V\$PROCESS ON (ADDR=PADDR) and sid=$SID ;
EOF2

