#!/bin/bash
#set -x
# author  : B. Polarski
# program : smenu_session_wait.sh
# 
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SBINS=$SBIN/scripts

# -----------------------------------------------------------------
function help
{
    cat <<EOF

     Show session wait state : this shortcut is used to gather info from v\$session_wait
   
      wss               
      wss -k           # variation of Jeffrey M. Hunter
      wss -p           # variation of Tanel Poder
      wss -r           # Wait sessions in Rac 
      wss -t           # Sample v\$session_wait 10 times in a row
      wss -s <sid>

Notes: 
 
         -v    : Verbose
      

        SEQ# : The internal sequence number of the wait for this session.  
        ------ Use this column to determine the number of waits (counts), the session has experienced

        P[1-3] These parameters are foreign keys to other views and are wait event dependent
        ------ for latch waits, P2 is the latch number, which is a foreign key to v\$latch
               for 'db file sequential read' or 'db file scattered read' P1 is the file number 
              (foreign key to v\$filestat or dba_data_files) and P2 is the actual block number 
              (related to dba_extents, sys.uet\$)

        STATE : WAITING = Session is currently waiting for event. See 'SECONDS_IN_WAIT' for value in secds.
                WAITED UNKNOWN TIME= Timed statistics = false!
                WAITED SHORT TIME : Session did not wait even one clock tick, no wait recorded
                WAITING KNOW TIME : Wait time was recorded. See 'WAIT_TIME' for value in secds.
 
        WAIT_TIME:  The values of WAIT_TIME are :
                            Negative : the wait time was unknown.
                            Zero     : the session is still waiting.
                            Positive : the session's last wait time. A zero value means the session is currently waiting.

EOF
exit
}
# -----------------------------------------------------------------
ACTION=DEFAULT
while [ -n "$1" ]
do
  case "$1" in
         -r ) FRAC=TRUE;;
       -rac ) G=g;;
         -k ) J_DISP=TRUE;;
         -p ) TANEL=TRUE;;
         -t ) WST=TRUE ;;
         -h ) help 
              exit;;
         -v ) set -xv ;;
          * ) AND_SID=" and s.sid = '$1' " 
  esac
  shift
done

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
      echo "could no get a the password of $S_USER"
      exit 0
fi


if [ "$WST" = "TRUE" ];then
   echo
   echo $NN "MACHINE $HOST - ORACLE_SID : $ORACLE_SID $NC"
   sqlplus -s "$CONNECT_STRING" <<EOF

column nline newline
set pagesize 66 linesize 124 termout on embedded on verify off 
set heading off pause off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER  ,15) || 'Show session waits events : Short grouped version' nline
from sys.dual
/
set head on pause off feed off
set linesize 110


column event format a29
column t0 format 999
column t1 format 999
column t2 format 999
column t3 format 999
column t4 format 999
column t5 format 999
column t6 format 999
column t7 format 999
column t8 format 999
column t9 format 999
column t9 format 999

select /*+ ordered */
  substr(n.name, 1, 29)  event,
  t0,
  t1,
  t2,
  t3,
  t4,
  t5,
  t6,
  t7,
  t8,
  t9
from
  sys.${G}v_\$event_name  n,
  (select event e0, count(*)  t0 from sys.${G}v_\$session_wait group by event),
  (select event e1, count(*)  t1 from sys.${G}v_\$session_wait group by event),
  (select event e2, count(*)  t2 from sys.${G}v_\$session_wait group by event),
  (select event e3, count(*)  t3 from sys.${G}v_\$session_wait group by event),
  (select event e4, count(*)  t4 from sys.${G}v_\$session_wait group by event),
  (select event e5, count(*)  t5 from sys.${G}v_\$session_wait group by event),
  (select event e6, count(*)  t6 from sys.${G}v_\$session_wait group by event),
  (select event e7, count(*)  t7 from sys.${G}v_\$session_wait group by event),
  (select event e8, count(*)  t8 from sys.${G}v_\$session_wait group by event),
  (select event e9, count(*)  t9 from sys.${G}v_\$session_wait group by event)
where
  n.name != 'Null event' and
  n.name != 'rdbms ipc message' and
  n.name != 'pipe get' and
  n.name != 'virtual circuit status' and
  n.name not like '%timer%' and
  n.name not like 'SQL*Net message from %' and
  e0 (+) = n.name and
  e1 (+) = n.name and
  e2 (+) = n.name and
  e3 (+) = n.name and
  e4 (+) = n.name and
  e5 (+) = n.name and
  e6 (+) = n.name and
  e7 (+) = n.name and
  e8 (+) = n.name and
  e9 (+) = n.name and
  nvl(t0, 0) + nvl(t1, 0) + nvl(t2, 0) + nvl(t3, 0) + nvl(t4, 0) +
  nvl(t5, 0) + nvl(t6, 0) + nvl(t7, 0) + nvl(t8, 0) + nvl(t9, 0) > 0
order by
  nvl(t0, 0) + nvl(t1, 0) + nvl(t2, 0) + nvl(t3, 0) + nvl(t4, 0) +
  nvl(t5, 0) + nvl(t6, 0) + nvl(t7, 0) + nvl(t8, 0) + nvl(t9, 0)
/
prompt
prompt
EOF

elif [ "$TANEL" = "TRUE" ];then
#--------------------------------------------------------------------------------
#--
#-- Purpose:     Display current Session Wait info
#-- Author:      Tanel Poder
#-- Copyright:   (c) http://www.tanelpoder.com
#-- Usage:       @sw <sid>
#--              @sw 52,110,225
#-- 	        	@sw "select sid from v$session where username = 'XYZ'"
#--              @sw &mysid
#--
#--------------------------------------------------------------------------------
sqlplus -s "$CONNECT_STRING" <<EOF
set lines 190 pagesiz 66
col sw_event 	head EVENT for a40 truncate
col sw_p1transl head P1TRANSL for a26
col sw_sid   head SID for 99999
col sw_p1       head P1 for a20 justify right word_wrap
col sw_p2       head P2 for a18 justify right word_wrap
col sw_p3       head P3 for a18 justify right word_wrap
col sec_in_wait head 'Sec in|Wait' for 999999 justify l
col seq# for 999999 justify l

select 
    sid sw_sid, 
    CASE WHEN state != 'WAITING' THEN 'WORKING'
         ELSE 'WAITING'
    END AS state, 
    CASE WHEN state != 'WAITING' THEN 'On CPU / runqueue'
         ELSE event
    END AS sw_event, 
    seq#, 
    seconds_in_wait sec_in_wait, 
    NVL2(p1text,p1text||'= ',null)||CASE WHEN P1 < 536870912 THEN to_char(P1) ELSE '0x'||rawtohex(P1RAW) END SW_P1,
    NVL2(p2text,p2text||'= ',null)||CASE WHEN P2 < 536870912 THEN to_char(P2) ELSE '0x'||rawtohex(P2RAW) END SW_P2,
    NVL2(p3text,p3text||'= ',null)||CASE WHEN P3 < 536870912 THEN to_char(P3) ELSE '0x'||rawtohex(P3RAW) END SW_P3,
    CASE 
        WHEN event like 'cursor:%' THEN
            '0x'||trim(to_char(p1, 'XXXXXXXXXXXXXXXX'))
                WHEN event like 'enq%' AND state = 'WAITING' THEN 
            '0x'||trim(to_char(p1, 'XXXXXXXXXXXXXXXX'))||': '||
            chr(bitand(p1, -16777216)/16777215)||
            chr(bitand(p1,16711680)/65535)||
            ' mode '||bitand(p1, power(2,14)-1)
        WHEN event like 'latch%' AND state = 'WAITING' THEN 
              '0x'||trim(to_char(p1, 'XXXXXXXXXXXXXXXX'))||': '||(
                    select name||'[par' 
                        from sys.${G}v_\$latch_parent 
                        where addr = hextoraw(trim(to_char(p1,rpad('0',length(rawtohex(addr)),'X'))))
                    union all
                    select name||'[c'||child#||']' 
                        from sys.${G}v_\$latch_children 
                        where addr = hextoraw(trim(to_char(p1,rpad('0',length(rawtohex(addr)),'X'))))
              )
                WHEN event like 'library cache pin' THEN
                         '0x'||RAWTOHEX(p1raw)
    ELSE NULL END AS sw_p1transl
FROM 
    sys.${G}v_\$session_wait 
ORDER BY
    state,
    sw_event,
    p1,
    p2,
    p3
/

EOF
elif [ "$FRAC" = "TRUE" ];then
#-- +----------------------------------------------------------------------------+
#-- |                          Jeffrey M. Hunter                                 |
#-- |                      jhunter@idevelopment.info                             |
#-- |                         www.idevelopment.info                              |
#-- |----------------------------------------------------------------------------|
#-- |      Copyright (c) 1998-2007 Jeffrey M. Hunter. All rights reserved.       |
#-- |----------------------------------------------------------------------------|
#-- | DATABASE : Oracle                                                          |
#-- | FILE     : rac_waiting_sessions.sql                                        |
#-- | CLASS    : Real Application Clusters                                       |
#-- | PURPOSE  : This script produces a report of the top sessions that have     |
#-- |            waited (the entries at top have waited the longest) for         |
#-- |            non-idle wait events )event column). The Oracle Server          |
#-- |            Reference Manual can be used to further diagnose the wait event |
#-- |            (along with its parameters). Metalink can also be used by       |
#-- |            supplying the event name in the search bar.                     |
#-- |                                                                            |
#-- |            The INST_ID column shows the instance where the session resides |
#-- |            and the SID is the unique identifier for the session            |
#-- |            (sys.${G}v_\$session).  The p1, p2, and p3 columns will show event       |
#-- |            specific information that may be important to debug the         |
#-- |            problem.                                                        |
#-- | EXAMPLE  : For example, you can search Metalink by supplying the event     |
#-- | METALINK : name (surrounded by single quotes) as in the following example: |
#-- | SEARCH   :                                                                 |
#-- |                          [ 'Sync ASM rebalance' ]                          |
#-- | NOTE     : As with any code, ensure to test this script in a development   |
#-- |            environment before attempting to run it in production.          |
#-- +----------------------------------------------------------------------------+

sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on embedded on verify off heading off pause off
 
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Show session waits events in RAC ' nline from sys.dual
/   
SET LINESIZE  145
SET PAGESIZE  9999
SET VERIFY    off

COLUMN instance_name          FORMAT a11         HEAD 'Instance|Name / ID'
COLUMN sid                    FORMAT a13         HEAD 'SID / Serial#'
COLUMN oracle_username                           HEAD 'Oracle|Username'
COLUMN state                  FORMAT a7          HEAD 'State'
COLUMN event                  FORMAT a25         HEAD 'Event'
COLUMN last_sql               FORMAT a25         HEAD 'Last SQL'

SELECT
    i.instance_name || ' (' || sw.inst_id || ')'  instance_name
  , sw.sid || ' / ' || s.serial#                  sid
  , s.username                                    oracle_username
  , sw.state                                      state
  , sw.event
  , sw.seconds_in_wait seconds
  , sw.p1
  , sw.p2
  , sw.p3
  , sa.sql_text last_sql
FROM
    sys.${G}v_\$session_wait sw
        INNER JOIN sys.${G}v_\$session s   ON  ( sw.inst_id = s.inst_id AND sw.sid = s.sid)
        INNER JOIN sys.${G}v_\$sqlarea sa  ON  ( s.inst_id  = sa.inst_id AND s.sql_address = sa.address)
        INNER JOIN sys.${G}v_\$instance i  ON  ( s.inst_id = i.inst_id)
WHERE
      sw.event NOT IN (   'rdbms ipc message'
                        , 'smon timer'
                        , 'pmon timer'
                        , 'SQL*Net message from client'
                        , 'lock manager wait for remote message'
                        , 'ges remote message'
                        , 'gcs remote message'
                        , 'gcs for action'
                        , 'client message'
                        , 'pipe get'
                        , 'null event'
                        , 'PX Idle Wait'
                        , 'single-task message'
                        , 'PX Deq: Execution Msg'
                        , 'KXFQ: kxfqdeq - normal deqeue'
                        , 'listen endpoint status'
                        , 'slave wait'
                        , 'wakeup time manager'
                        , 'VKTM Logical Idle Wait'
                        , 'Space Manager: slave idle wait' 
                      )
  and sw.seconds_in_wait > 0 
ORDER BY seconds desc
/
EOF

elif [ "$J_DISP" = "TRUE" ];then

# This is "John Kanagaraj" approach. I don't can't say it is really superior. (bp) 
# more over the decode can show a session in (C) while the status is already inactive.
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on embedded on verify off heading off pause off
 
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Show session waits events ' nline from sys.dual
/   
set head on pause off feed off linesize 190
PROMPT   (C) : Wait event is done, currently on CPU          (W) Really Waiting 
column event format a33 head "Event type"
column waiting_Event format a45 head "Wating event"
column sid_Serial format a12 head "Sid"
col username format a18
  select
     s.sid || ',' || s.serial# sid_serial, p.spid, s.process,
     s.username || '/' || s.osuser username, s.status,
     w.Wait_time, s.last_call_et/60 last_call_et, decode(w.wait_time,0,'(W) ','(C) ') ||
     w.event || ' / ' || w.p1 || ' / ' || w.p2 || ' / ' || w.p3 waiting_event
from sys.${G}v_\$process p, sys.${G}v_\$session s, sys.${G}v_\$session_wait w
where 
   s.paddr=p.addr                          and
  w.sid = s.sid                            and
  s.sid = w.sid                            and
  w.event != 'pmon timer'                  and
  w.event != 'rdbms ipc message'           and
  w.event != 'PL/SQL lock timer'           and
  w.event != 'SQL*Net message from client' and
  w.event != 'client message'              and
  w.event != 'pipe get'                    and
  w.event != 'Null event'                  and
  w.event != 'wakeup time manager'         
  and w.event != 'class slave wait'
  and w.event != 'LogMiner: wakeup event for preparer'
  and w.event != 'Streams AQ: waiting for time management or cleanup tasks'
  and w.event != 'LogMiner: wakeup event for builder'
  and w.event != 'Streams AQ: waiting for messages in the queue'
  and w.event != 'ges remote message'
  and w.event != 'Streams AQ: qmn slave idle wait'
  and w.event != 'Streams AQ: qmn coordinator idle wait'
  and w.event != 'ASM background timer'
  and w.event != 'VKTM Logical Idle Wait'
  and w.event != 'DIAG idle wait' $AND_SID $ORDER
  and w.event != 'Space Manager: slave idle wait'
order by s.logon_time
/
EOF

elif [  "$ACTION" = "DEFAULT" ];then
#cat <<EOF
sqlplus -s $CONNECT_STRING <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on embedded on verify off heading off pause off
 
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Show session waits events ' nline from sys.dual
/   
set head on pause off feed off
set linesize 150

column event format a48 head "Event type"
column wait_time format 999999 head "Total| waits"
column seconds_in_wait format 999999 head " Time waited "
column sid format 999999 head "Sid"
column state format A17 head "State"
col seq# format 999999

select
  w.sid, s.status,w.seq#, w.event
  , w.wait_time, w.seconds_in_wait , w.p1 , w.p2 , w.p3 , w.state
from
  sys.${G}v_\$session_wait w    , sys.${G}v_\$session s
where
  s.sid = w.sid and
  w.event != 'pmon timer'                  and
  w.event != 'rdbms ipc message'           and
  w.event != 'PL/SQL lock timer'           and
   w.event != 'SQL*Net message from client' and
  w.event != 'client message'              and
  w.event != 'pipe get'                    and
  w.event != 'Null event'                  and
  w.event != 'wakeup time manager'         and
  w.event != 'slave wait'                  and
  w.event != 'smon timer' 
  and w.event != 'class slave wait'
  and w.event != 'LogMiner: wakeup event for preparer'
  and w.event != 'Streams AQ: waiting for time management or cleanup tasks'
  and w.event != 'LogMiner: wakeup event for builder'
  and w.event != 'Streams AQ: waiting for messages in the queue'
  and w.event != 'ges remote message'
  and w.event != 'gcs remote message'
  and w.event != 'Streams AQ: qmn slave idle wait'
  and w.event != 'Streams AQ: qmn coordinator idle wait'
  and w.event != 'ASM background timer'
  and w.event != 'DIAG idle wait' $AND_SID $ORDER
  and w.event != 'VKTM Logical Idle Wait'
  and w.event != 'Space Manager: slave idle wait'
  and w.event != 'LGWR worker group idle'
  and w.event != 'Data Guard: Gap Manager'
  and w.event != 'VKRM Idle'
  and w.event != 'AQPC idle'
  and w.event != 'Data Guard: Timer'
  and w.event != 'lreg timer'
  and w.event != 'Data Guard: controlfile update'
  and w.event != 'watchdog main loop'
  and w.seconds_in_wait > 0 $AND_SID $ORDER
/
prompt
EOF

fi
