#!/bin/sh
#set -xv
if [  -z "$1"  ];then
   echo " "
   echo " "
   echo "    Usage : dps SID "
   echo "   "
   echo " "
   echo "      Use 'sl' or  to get sid PGA to dump "
   echo " "
   echo " "
   exit
fi

TO_DUMP=$1
HOSTNAME=`hostname`
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
       'Suspend session - Session SID whose PGA to dump : $TO_DUMP ' nline
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
column program format a30
select nvl(s.username,p.program) "USERNAME",s.sid sess ,s.OSUSER,
       s.serial#,p.spid "PID", s.process "OS-PPID", s.program
from v\$session s, v\$process p
where s.sid = $TO_DUMP and
s.paddr = p.addr
and s.username != 'NULL'
order by 2
/
EOF
) 

ret=`sqlplus -s "$CONNECT_STRING" <<EOF
set pagesize 0 feed off termout off head off
select p.spid from v\\$session s, v\\$process p where s.sid = $TO_DUMP  and s.paddr = p.addr ;
EOF
`

set -x
if $SBINS/yesno.sh "to dump PGA for Session $TO_DUMP" DO N
  then
sqlplus -s "$CONNECT_STRING" <<EOF
oradebug setospid $ret ;
oradebug dump processstate 10 ;
oradebug tracefile_name;
EOF
fi
