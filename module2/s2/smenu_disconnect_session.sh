#!/bin/ksh
# disconnect session
#set -xv
if [ "x-$1" = "x-" ];then
   echo " "
   echo " "
   echo "    Usage : ksd SID <Program name length> "
   echo " "
   echo "      Use 'sl' or 'wss' to get the SID to Disconnect "
   echo " "
   echo " "
   exit
fi
if [ "x-$2" = "x-" ];then
   column_name_long=30
else
   column_name_long=$1
fi
if [ "$2" = "-u" ];then
   S_USER="$3"
fi
HOSTNAME=`hostname`
TO_DISCONNECT=$1
SBINS=$SBIN/scripts
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} 
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
(
sqlplus -s "$CONNECT_STRING" <<EOF  
ttitle skip 2 'MACHINE $HOSTNAME - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 80
set heading off
set embedded off pause off
set termout on
set verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Disconnect user session - Session SID to Disconnect : $TO_DISCONNECT ' nline
from sys.dual
/
rem set pages 0 feed off echo off
set embedded on
rem prompt *----------------------------------------------------*
set lines 200
set heading on pause off
column "USERNAME" format a12
column "terminal" format a6
column "OSUSER" format a12
column "sess" format 9,999 heading "Sess|ID" justify c
column "serial#" format 99,999 heading "Serial" justify c
column "PID" format 99,999 heading "PID#" justify c
column program format a${column_name_long}
select nvl(s.username,p.program) "USERNAME",s.sid sess ,s.OSUSER,
       s.serial#,p.spid "PID", s.process "OS-PPID", s.program
from v\$session s, v\$process p
where s.sid = $TO_DISCONNECT and
s.paddr = p.addr
order by 2
/
EOF
) 

var=`sqlplus -s "$CONNECT_STRING" <<EOF
set pagesize 0 feed off termout off head off
select s.serial# from v\\$session s where s.sid = $TO_DISCONNECT  ;
EOF
`
serial=`echo $var | awk '{print $1}'`
if $SBINS/yesno.sh "to disconnect Session $TO_DISCONNECT, serial $serial" DO N
  then
sqlplus -s "$CONNECT_STRING" <<EOF
prompt 
prompt 
prompt alter system disconnect session '$TO_DISCONNECT,$serial' immediate;
prompt 
alter system disconnect session '$TO_DISCONNECT,$serial' immediate;
EOF
fi
