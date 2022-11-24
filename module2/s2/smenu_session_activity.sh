#!/bin/ksh
# set -x
HOSTNAME=`uname -n`
SID=$1
if [ "x-$SID" = "x-" ];then
   echo " I need a Session ID. "
   exit
fi
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
RET=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off feed off pause off
select version from v\\$instance;
EOF
`
VERSION=`echo $RET | awk '{print $1}'| cut -f1 -d'.'`
if [ "$VERSION" = "8" ];then
      CPU_TIME=",0"
else
      CPU_TIME=",cpu_time/1000000 cpu_time"
fi
FOUT=$SBIN/tmp/sa_${ORACLE_SID}_$SID.log
echo "MACHINE $HOSTNAME - ORACLE_SID : $ORACLE_SID                   Page: 1"
	sqlplus -s "$CONNECT_STRING" <<!EOF
set long 2000

column nline newline
set pagesize 66
set linesize 80
set heading off pause off
set embedded off
set verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Session           -  Session Activity Overview  ' nline
	      from sys.dual
/
set embedded on
set linesize 152
set head on
column Sid format A6 head 'Sid'
column osuser format A12 head 'Osuser'
column username format A18 head 'User'
column program format A30 head 'Program'
col machine for a25 head 'Machine'
col LAC head 'Last|call(s)' justify c
col PPID format a8 head 'OS|Pid' justify c

select '$SID' Sid, serial#, process PPID, username ,osuser, program , machine, to_char(logon_time,'dd-mon hh24:mi') logon_time, LAST_CALL_ET LAC
 from v\$session where sid=$SID
/
set pause off feed off embedded on
prompt
prompt Sql in work area:
prompt
column buffer_gets format 999999990 head "Buffer Gets" justify c
column executions format 9999990 head "Executions" justify c
column exec format 999999990 head "Gets/Exec" justify c
column sql_text format a80 head "Sql"
column disk_reads format 99999990 head "Disk|Reads" justify c
column rows_processed format 9999999990 head "Rows|Processed" justify c
column hp format 999999 head "Total|Session|Hard Parse" justify c
column sid format 99999999 head "Sid" justify c

break on buffer_gets on executions on exec on disk_reads on rows_processed
   SELECT 'Curr' SQL , s.sql_id , sql_text
     FROM v\$sqlarea q, v\$session s
     WHERE s.sql_id = q.sql_id  and s.sid='$SID'
union all
   SELECT 'Prev' SQL, prev_sql_id , sql_text
   FROM v\$sqlarea q, v\$session s
    WHERE s.prev_sql_id = q.sql_id  and s.sid='$SID'
/
prompt 
   SELECT 'Curr' SQL, buffer_gets, executions, buffer_gets/decode(nvl(executions,1),0,1,executions) exec, 
           disk_reads,rows_processed,
     sorts , parse_calls,  t.value hp $CPU_TIME
    FROM v\$sqlarea q, v\$session s, v\$sesstat t, v\$statname n
     WHERE s.sql_id = q.sql_id   and s.sid='$SID'
     and s.sid = t.sid (+) 
     and t.statistic# = n.statistic#
     and n.name = 'parse count (hard)'
union all
   SELECT  'Prev' SQL,buffer_gets, executions, buffer_gets/decode(nvl(executions,1),0,1,executions) exec, 
         disk_reads,rows_processed,
     sorts , parse_calls, t.value hp  $CPU_TIME
   FROM v\$sqlarea q, v\$session s, v\$sesstat t, v\$statname n
    WHERE s.prev_sql_id = q.sql_id   and s.sid='$SID'
    and s.sid = t.sid (+) 
    and t.statistic# = n.statistic#
    and n.name = 'parse count (hard)'
/
prompt
prompt Event and his latch wait:
prompt
set linesize 124
column name        format a25 heading "Latch type"
column event       format a24 heading "Event name"
column waits_holding_latch   format 99999999 heading "Wait     | holding latch"
column sleeps  format 99999999 heading "Number|Sleeps"
column sw      format 999999 heading "Seconds| Waiting"
column sid     format 999999 heading "Sid"

SELECT s.sid, s.event, n.name, SUM(s.p3) Sleeps, SUM(s.seconds_in_wait) sw
 FROM V\$SESSION_WAIT s, V\$LATCHNAME n
WHERE  s.sid = '$SID'
  and s.p2 = n.latch# and latch# not in (1) 
GROUP BY s.sid, n.name, s.event
/
column name        format a60 heading "Name"
column STATISTIC#  heading "Stat id"
column class       heading "Class"
column value       heading "Value"

select sid, p1,p2,p3
from v\$session_wait
where event = 'buffer busy waits'
/

 -- select b.sid, b.STATISTIC#,a.NAME,a.CLASS,b.VALUE${MEGS}
 -- from v\$sysstat a  ,  v\$sesstat b where b.sid = $SID and a.STATISTIC# = b.STATISTIC# and b.value > 0 ;

exit
!EOF
# echo "result in $FOUT"
