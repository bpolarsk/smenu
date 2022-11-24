#!/usr/bin/ksh
#set -xv
# For a more detailed trace, which show waits and the value of bind variables, you can use: 
#  dbms_system.set_ev( sid,serial#,10046,12,'') 
#
if [ "x-$1" = "x-" ];then
   echo " "
   echo " "
   echo "  I need a PID !"
   echo " "
   echo "  Usage : $0 Unix_PID [TRUE|FALSE] "
   echo 
   echo "  set the SQL TRACE on|off in the session whose Unix_PID is given "
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
      if [ ! $? -eq 0 ];then
           echo "wrong PID !"
           exit
      fi
   fi
fi
PID=$1
OPT=$2
S_USER=SYS
SBINS=${SBIN}/scripts
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

if [ "x-$SERIAL" = "x-TRUE" ];then
RES=`sqlplus  -s "$CONNECT_STRING" <<-EOF  
	set pages 0 feed off echo off head off verify off pause off
        select s.serial# from v\\$session s
               where s.sid = '$PID'
	/
	EOF`
        if [ ! "x-$RES" = "x-" ];then
           RES="$PID $RES"
        else
            echo "Error : could not retrieve serial for SID=$SID"
            echo "Press any key to continue..."
            read ff
            exit 1
        fi
        
else

echo " Get Oracle SID and Serial"
echo " ========================="
RES=`sqlplus  -s "$CONNECT_STRING" <<-EOF  
	set pages 0 feed off echo off head off verify off pause off
        select s.sid , s.serial# from v\\$session s, v\\$process p
        where s.paddr = p.addr
              and s.username != 'NULL'
              and p.spid = '$PID'
	/
	EOF`

fi


if [ ! "x-$RES" = "x-" ];then
   SID=`echo $RES | awk '{print $1}'`
   SERIAL=`echo $RES | awk '{print $2}'`
   if [ "x-$OPT" = "x-TRUE" -o "x-$OPT" = "x-FALSE" ];then
      sqlplus  "$CONNECT_STRING" <<-EOF2
      set feed on verify on pause off
      prompt "doing : execute sys.dbms_system.set_sql_trace_in_session($SID,$SERIAL,$OPT)"
      execute sys.dbms_system.set_sql_trace_in_session($SID,$SERIAL,$OPT)
      /
      exit
	EOF2
   else
      echo "Invalid Parameter"
      echo "execute sys.dbms_system.set_sql_trace_in_session($SID,$SERIAL,TRUE)"
   fi
else
     echo "Error in getting sid and serial#"
fi

