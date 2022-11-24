#!/bin/ksh
#set -xv
if [ "x-$1" = "x-" ];then
   echo " "
   echo " "
   echo "    Usage : ks SID <Program name length> "
   echo " "
   echo "      Use 'sl' or 'wss' to get the SID to kill "
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
TO_KILL=$1
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
       'Kill user session - Session SID to kill : $TO_KILL ' nline
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
where s.sid = $TO_KILL and
s.paddr = p.addr
order by 2
/
EOF
) 

var=`sqlplus -s "$CONNECT_STRING" <<EOF
set pagesize 0 feed off termout off head off
select s.serial#,p.spid from v\\$session s,v\\$process p 
where s.sid = $TO_KILL and s.paddr =  p.addr ;
EOF
`
serial=`echo $var | awk '{print $1}'`
ppid=`echo $var | awk '{print $2}'`
if $SBINS/yesno.sh "to kill Session $TO_KILL, serial $serial" DO N
  then
sqlplus -s "$CONNECT_STRING" <<EOF
alter system kill session '$TO_KILL,$serial' immediate ;
EOF
  if [ ! "x-$ppid" = "x-" ];then
     if ps -ef | grep $ppid | grep -v grep 
       then
        if $SBINS/yesno.sh "I try to get rid of $ppid also" DO Y
           then
             kill -9 $ppid
             num=`ps -ef | grep $ppid | grep -v grep |wc -l`
             if [ $num -gt 0 ];then
                  echo " Could not get rid of $ppid using kill -9 as \"`who am i`\""
             else
                  echo " $ppid is gone ! "
             fi
        fi
     fi
  fi
fi
