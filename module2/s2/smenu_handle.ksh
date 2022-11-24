#!/bin/bash
# set -xv
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
# Jan vermue for soc -t
# Ixora for soc -a
# Adapted to Smenu 02-Jun-2006
#                  14-Sept-2006 : added non shared cursor (-sa)
# --------------------------------------------------------------------------------------------
function help
{
 
cat <<EOF
 
    Report on miscelleanous elements in SGA
 
         soc -o <sid>                        # List open cursor for session <sid>
         soc -p                              # show cursor cache performance
         soc -a  -raw                        # List current active cursor
         soc -la [-u <usr>  [-ln <nn>]       # List last ctive cursor
         soc -sa -rn <nn>                    # list cursor not shared and the reason
         soc -srt                            # view sorting info
         soc -w                              # Show actual work area size plus tempseg when spilled on disk
         soc -ls                             # Show opened cursors distribution from orig machine
         soc -dml [-o <sid>]                 # List all DML cursors currently opened
         soc -cpt                            # count opened cursor per sessions, including inactive
         soc -curr -rn <nn>                  # count opened current cursor per sessions against 'open_cursor'
         soc -s <sid>                        # list open cursor for a gigen session and the sql text
         soc -prg <program>                  # list open cursor for session user <PROGRAM>%
 
 
    additional parameters:
 
             -raw       : add rawhex address
              -rn       : top <nn> cursors
              -ln <nn>  : text length of sql_text is nn. Default is 64
              -u  <usr> : restricts selection to <USR>
 
 
EOF
exit
}
# --------------------------------------------------------------------------------------------
TITTLE="session open cursor"
TLEN=64
typeset -u fowner
if  [ -z "$1" ];then
   help
fi
while [ -n "$1" ]
do
  case $1 in
   -a ) ACTION=ACTIVE ; S_USER=SYS;;
  -dml) ACTION=DML ;;
-cpt ) ACTION=CPT ;;
-curr ) ACTION=CURRENT ;;
  -la ) ACTION=LAST_ACTIVE ;;
  -ls ) ACTION=DIST_ORIG ;;
  -ln ) TLEN=$2 ; shift ;;
   -p ) ACTION="PERF" ;;
   -r ) HRAW="decode(piece,0,s.address,1,rawtohex(s.address),'') hashadr, ";;
  -rn ) ROWNUM=$2; shift ;;
  -sa ) ACTION=SHARED ; TITTLE="Currsor not shared and the reason";;
  -srt ) ACTION=SORTING ;;
   -s ) ACTION=LIST_CUR; F_SID=$2 ; shift ;;
   -v ) VERBOSE=TRUE;;
   -u ) fowner=$2 ; shift ;;
   -h ) help ;;
   -o ) ACTION=SESSION ; SID=" s.sid = $2 and" ; shift ;;
   -w ) ACTION=WSIZ;;
-prg ) ACTION=PROG; PROGRAM=$2 ; shift ;;
    * ) echo "Invalid parameters : $1 " ; help ;;
  esac
  shift
done
ROWNUM=${ROWNUM:-40}
 
# ............................................................
# a nice query from Radoslav Rusinov
# ............................................................
if [ "$ACTION" = "PERF" ];then
TITTLE="Cursor cache performance"
SQL="
SELECT
  'session_cached_cursors'  parameter,
  LPAD(value, 5)  value,
  DECODE(value, 0, '  n/a', to_char(100 * used / value, '990') || '%')  usage
FROM
  (SELECT
      MAX(s.value)  used
    FROM
      v\$statname  n,
      v\$sesstat  s
    WHERE
      n.name = 'session cursor cache count' and
      s.statistic# = n.statistic#
  ),
  (SELECT
      value
    FROM
      v\$parameter
    WHERE
      name = 'session_cached_cursors'
  )
UNION ALL
SELECT
  'open_cursors',
  LPAD(value, 5),
  to_char(100 * used / value,  '990') || '%'
FROM
  (SELECT
      MAX(sum(s.value))  used
    FROM
      v\$statname  n,
      v\$sesstat  s
    WHERE
      n.name in ('opened cursors current', 'session cursor cache count') and
      s.statistic# = n.statistic#
    GROUP BY
      s.sid
  ),
  (SELECT
      value
    FROM
      v\$parameter
    WHERE
      name = 'open_cursors'
  )
/
"
# ............................................................
elif [ "$ACTION" = "CURRENT" ];then
ROWNUM=${ROWNUM:-50}
SQL="
col name for a30
col usernames for a26
col user_name for a30
col machine for a30
set lines 190
set pages 900
 
select * from (
select a.sid,s.username,name,value, program , s.machine
from v\$sesstat a,v\$statname b, v\$session s
where name ='opened cursors current'
and a.statistic# = b.statistic#
and a.sid = s.sid
order by value desc
) where rownum <= $ROWNUM
/
"
# ............................................................
elif [ "$ACTION" = "LIST_CUR" ];then
 
if [ ! -n "$F_SID" ];then
   echo "I need a session"
   exit
fi
SQL="
col username for a30
col CURSOR_TYPE for a25
set lines 200
set pages 200
select a.sid ,sql_id, sql_text, count(*) over ( partition by a.sid order by a.sid) cpt,
  CURSOR_TYPE, to_char(LAST_SQL_ACTIVE_TIME,'YYYY-MM-DD HH24:MI:SS') last_active
from v\$open_cursor a
where a.sid = $F_SID
order by 6 desc
/
"
# ............................................................
elif [ "$ACTION" = "PROG" ];then
TITTLE="Count open cursor for program"
if [ ! -n "$PROGRAM" ];then
  echo "I need a program string"
  exit 0
fi
ROWNUM=${ROWNUM:-50}
SQL="
set pages 9999
col machine for a25
col username for a30
col cpt head 'Open|Cursors' justify c
compute sum of cpt on report
break on sid on report
 
 
select /*+ rule */ sid, username, program,machine,cpt  from (
select o.sid, s.username, s.program, s.machine,
count(*)  over ( partition by o.sid  ) cpt,
row_number() over ( partition by o.sid  order by 2) rnk
from v\$open_cursor  o , v\$session s
where o.sid = s.sid (+) and s.type != 'BACKGROUND' and s.program like '${PROGRAM}%'
) where rnk = 1 and rownum <=$ROWNUM
order by cpt desc
/
"
# ............................................................
elif [ "$ACTION" = "CPT" ];then
TITTLE="Count open cursor by sessions"
 
ROWNUM=${ROWNUM:-50}
SQL="
set pages 9999
col machine for a25
col username for a30
col cpt head 'Open|Cursors' justify c
compute sum of cpt on report
break on sid on report
 
select * from (
select /*+ rule */ sid, username, program,machine,cpt  from (
select o.sid, s.username, s.program, s.machine,
count(*)  over ( partition by o.sid  ) cpt,
row_number() over ( partition by o.sid  order by 2) rnk
from v\$open_cursor  o , v\$session s
where o.sid = s.sid (+) and s.type != 'BACKGROUND'
) where rnk = 1
order by cpt desc ) where rownum <=$ROWNUM
/
"
# ............................................................
elif [ "$ACTION" = "DML" ];then
TITTLE="List all DML cursors currently opened"
SQL="col piece noprint
        col cpu_time head 'Cpu |time (ms)'  for 99999990.9 justify c
        col sql_text format A64
        col child_number head child for 9999
        col sid for 99999 head 'Sid'
        col last_active_time for a16 head 'Last|active time' justify c
        col command for a8
        col text for a50
 
       break on sid on username on hash_value on command on cpu_time on last_active_time
 
SELECT ses.sid, ses.username, a.hash_value, a.child_number,
       decode(a.COMMAND_TYPE,3,'SELECT', 7,'DELETE',6,'UPDATE',2,'INSERT', 189, 'MERGE', a.command_type) command,
       a.CPU_TIME/1048576 cpu_time,to_char(a.LAST_ACTIVE_TIME,'MON-DD HH24:MI:SS') last_active_time,
       substr(a.sql_text,1,50) text
FROM
       V\$open_cursor s,
       v\$sql a,
       v\$session ses
WHERE $SID
           ses.sid = s.sid
       and a.COMMAND_TYPE in ( 2, 6, 7, 189 )
       and s.ADDRESS=a.ADDRESS
       and s.hash_value=a.hash_value
ORDER by sid, last_active_time  desc ,s.hash_value;
"
# ............................................................
elif [ "$ACTION" = "DIST_ORIG" ];then
  # got this from Natalka Roshak - http://www.orafaq.com/node/758
TITTLE="List open cursor from origin"
SQL="
col avg_cur for 9990.9
select sum(a.value) total_cur, avg(a.value) avg_cur, max(a.value) max_cur,
       s.username, s.machine
from
      v\$sesstat a, v\$statname b, v\$session s
where
      a.statistic# = b.statistic#  and s.sid=a.sid
  and b.name = 'opened cursors current'
group by s.username, s.machine
order by 1 desc;
"
# ............................................................
elif [ "$ACTION" = "WSIZ" ];then
       TITTLE="Display sql work area sizes"
SQL="
set pagesize 66 linesize 80 termout on pause off embedded on verify off heading off
 
col version new_value version noprint
col field new_value field noprint
select substr(version,1,instr(version,'.',1)-1) version from v\$instance
/
select decode(&version,9,'''-'' sql_id','sql_id') field from dual;
/
col actual_mem_used  format 999999999 head 'Actual| used| Memory' justify c
col expected_size  format 9999999999 head 'Expected |Memory' justify c
col tempseg_size  format 9999999999 head 'Size on|disk (temp)' justify c
col operation_type format A20 head 'Operation|  Type'
 
set linesize 132 pagesize 64 head on
select
   &field,operation_type,work_area_size,expected_size,actual_mem_used,max_mem_used,tempseg_size
from v\$sql_workarea_active
/
"
# ............................................................
elif [ "$ACTION" = "SORTING" ];then
# First query
#**********************************************************************
# File: sort_use.sql
# Type: SQL*Plus script
# Author:       Tim Gorman (Evergreen Database Technologies, Inc.)
# Date: 20-May-99
# Description:
# Query the V$SORT_USAGE view to determine what sessions (and
# What SQL statements) are using sorting resources...
#
# Modifications:
#*********************************************************************/
# second query
#
#-- +----------------------------------------------------------------------------+
#-- |                          Jeffrey M. Hunter                                 |
#-- |                      jhunter@idevelopment.info                             |
#-- |                         www.idevelopment.info                              |
#-- |----------------------------------------------------------------------------|
#-- |      Copyright (c) 1998-2007 Jeffrey M. Hunter. All rights reserved.       |
#-- |----------------------------------------------------------------------------|
#-- | DATABASE : Oracle                                                          |
#-- | FILE     : temp_status.sql                                                 |
#-- | CLASS    : Temporary_Tablespace                                            |
#-- | PURPOSE  : List all temporary tablespaces along with a brief status.       |
#-- | NOTE     : As with any code, ensure to test this script in a development   |
#-- |            environment before attempting to run it in production.          |
#-- +----------------------------------------------------------------------------+
 
    SQL="break on report
compute sum of mb on report
compute sum of pct on report
set head on
col sid format a10 heading 'Session ID'
col username format a10 heading 'User Name'
col sql_text format a8 heading 'SQL'
col tablespace format a10 heading 'Temporary|TS Name'
col mb format 999,999,990 heading 'Mbytes|Used'
col pct format 990.00 heading '% Avail|TS Spc'
col value new_value dbblocksize noprint
col segtype format A9 head 'Segment|Type'
set linesize 124
 
select value from v\$parameter where name = 'db_block_size'
/
select  s.sid || ',' || s.serial# sid,
        s.username,
        u.tablespace,
        substr(a.sql_text, 1, (instr(a.sql_text, ' ')-1)) sql_text,u.sqlhash, u.segtype,
        (u.blocks*&dbblocksize)/1024/1024 mb,
        ((u.blocks)/(sum(f.blocks)))*100 pct
from    v\$sort_usage   u,
        v\$session      s,
        v\$sqlarea      a,
        dba_temp_files  f
where   s.saddr = u.session_addr
and     a.address (+) = s.sql_address
and     a.hash_value (+) = s.sql_hash_value
and     f.tablespace_name = u.tablespace
group by
        s.sid || ',' || s.serial#,
        s.username,
        substr(a.sql_text, 1, (instr(a.sql_text, ' ')-1)),u.sqlhash, u.segtype,
        u.tablespace,
        u.blocks
/
 
COLUMN tablespace_name       FORMAT a18               HEAD 'Tablespace Name'
COLUMN tablespace_status     FORMAT a9                HEAD 'Status'
COLUMN tablespace_size       FORMAT 99,990.9   HEAD 'Size'
COLUMN used                  FORMAT 99,990.9   HEAD 'Used'
COLUMN used_pct              FORMAT 999               HEAD 'Pct. Used'
COLUMN current_users         FORMAT 9,999             HEAD 'Current Users'
BREAK ON report
COMPUTE SUM OF tablespace_size  ON report
COMPUTE SUM OF used             ON report
COMPUTE SUM OF current_users    ON report
 
SELECT
    d.tablespace_name                      tablespace_name
  , d.status                               tablespace_status
  , NVL(a.bytes/1048576, 0)                        tablespace_size
  , NVL(t.bytes/1048576, 0)                        used
  , TRUNC(NVL(t.bytes / a.bytes * 100, 0)) used_pct
  , NVL(s.current_users, 0)                current_users
FROM
    dba_tablespaces d
  , ( select tablespace_name, sum(bytes) bytes
      from dba_temp_files
      group by tablespace_name
    ) a
  , ( select tablespace_name, sum(bytes_cached) bytes
      from v\$temp_extent_pool
      group by tablespace_name
    ) t
  , v\$sort_segment  s
WHERE
      d.tablespace_name = a.tablespace_name(+)
  AND d.tablespace_name = t.tablespace_name(+)
  AND d.tablespace_name = s.tablespace_name(+)
  AND d.extent_management like 'LOCAL'
  AND d.contents like 'TEMPORARY'
/
set pagesize 66 linesize 80 termout on pause off embedded on verify off heading off
col version new_value version noprint
col field new_value field noprint
select substr(version,1,instr(version,'.',1)-1) version from v\$instance
/
select decode(&version,9,'a.hash_value','a.sql_id') field from dual;
/
 
set linesize 132 pagesize 64 head on
col sid format 99999
col hash_value format  99999999999
col operation_type format A20 head 'Operation|  Type'
col total_executions format 9999999 head 'Total|Executions'
col act format 999999 head 'Active| Time'
col eos format 9999999999 head 'Estimated| Size'
col ltm format 9999999999 head 'Used| Memory'
col actual_mem_used  format 999999999 head 'Actual| used| Memory' justify c
col expected_size  format 9999999999 head 'Expected |Memory' justify c
col tempseg_size  format 9999999999 head 'Size on|disk (temp)' justify c
col operation_id format 999 head 'Sql|Plan|Id' justify c
 
select  --+ ordered
c.sid, &field,'   '||b.operation_type operation_type,
TOTAL_EXECUTIONS, b.ACTIVE_TIME/1000000 act, b.OPERATION_ID,
estimated_optimal_size eos, last_memory_used ltm,
d.expected_size,d.actual_mem_used, d.tempseg_size
from v\$sql a, v\$sql_workarea b, v\$session c , v\$sql_workarea_active d
  where
a.address = b.address
and a.hash_value = c.sql_hash_value
and b.workarea_address = d.workarea_address (+)
order by c.sid
/
"
# ............................................................
elif [ "$ACTION" = "SHARED" ];then
     SQL=" select distinct a.address f_addr,sql_id,cpt ,
  CASE
when UNBOUND_CURSOR = 'Y' then 'UNBOUND_CURSOR'
when SQL_TYPE_MISMATCH = 'Y' then 'SQL_TYPE_MISMATCH'
when OPTIMIZER_MISMATCH = 'Y' then 'OPTIMIZER_MISMATCH'
when OUTLINE_MISMATCH = 'Y' then 'OUTLINE_MISMATCH'
when STATS_ROW_MISMATCH = 'Y' then 'STATS_ROW_MISMATCH'
when LITERAL_MISMATCH = 'Y' then 'LITERAL_MISMATCH'
-- when SEC_DEPTH_MISMATCH = 'Y' then 'SEC_DEPTH_MISMATCH'
when EXPLAIN_PLAN_CURSOR = 'Y' then 'EXPLAIN_PLAN_CURSOR'
when BUFFERED_DML_MISMATCH = 'Y' then 'BUFFERED_DML_MISMATCH'
when PDML_ENV_MISMATCH = 'Y' then 'PDML_ENV_MISMATCH'
when INST_DRTLD_MISMATCH = 'Y' then 'INST_DRTLD_MISMATCH'
when SLAVE_QC_MISMATCH = 'Y' then 'SLAVE_QC_MISMATCH'
when TYPECHECK_MISMATCH = 'Y' then 'TYPECHECK_MISMATCH'
when AUTH_CHECK_MISMATCH = 'Y' then 'AUTH_CHECK_MISMATCH'
when BIND_MISMATCH = 'Y' then 'BIND_MISMATCH'
when DESCRIBE_MISMATCH = 'Y' then 'DESCRIBE_MISMATCH'
when LANGUAGE_MISMATCH = 'Y' then 'LANGUAGE_MISMATCH'
when TRANSLATION_MISMATCH = 'Y' then 'TRANSLATION_MISMATCH'
-- when ROW_LEVEL_SEC_MISMATCH = 'Y' then 'ROW_LEVEL_SEC_MISMATCH'
when INSUFF_PRIVS = 'Y' then 'INSUFF_PRIVS'
when INSUFF_PRIVS_REM = 'Y' then 'INSUFF_PRIVS_REM'
when REMOTE_TRANS_MISMATCH = 'Y' then 'REMOTE_TRANS_MISMATCH'
when LOGMINER_SESSION_MISMATCH = 'Y' then 'LOGMINER_SESSION_MISMATCH'
when INCOMP_LTRL_MISMATCH = 'Y' then 'INCOMP_LTRL_MISMATCH'
when OVERLAP_TIME_MISMATCH = 'Y' then 'OVERLAP_TIME_MISMATCH'
-- when SQL_REDIRECT_MISMATCH = 'Y' then 'SQL_REDIRECT_MISMATCH'
when MV_QUERY_GEN_MISMATCH = 'Y' then 'MV_QUERY_GEN_MISMATCH'
when USER_BIND_PEEK_MISMATCH = 'Y' then 'USER_BIND_PEEK_MISMATCH'
when TYPCHK_DEP_MISMATCH = 'Y' then 'TYPCHK_DEP_MISMATCH'
when NO_TRIGGER_MISMATCH = 'Y' then 'NO_TRIGGER_MISMATCH'
when FLASHBACK_CURSOR = 'Y' then 'FLASHBACK_CURSOR'
when ANYDATA_TRANSFORMATION = 'Y' then 'ANYDATA_TRANSFORMATION'
-- when INCOMPLETE_CURSOR = 'Y' then 'INCOMPLETE_CURSOR'
when TOP_LEVEL_RPI_CURSOR = 'Y' then 'TOP_LEVEL_RPI_CURSOR'
when DIFFERENT_LONG_LENGTH = 'Y' then 'DIFFERENT_LONG_LENGTH'
when LOGICAL_STANDBY_APPLY = 'Y' then 'LOGICAL_STANDBY_APPLY'
when DIFF_CALL_DURN = 'Y' then 'DIFF_CALL_DURN'
when BIND_UACS_DIFF = 'Y' then 'BIND_UACS_DIFF'
when PLSQL_CMP_SWITCHS_DIFF = 'Y' then 'PLSQL_CMP_SWITCHS_DIFF'
ELSE 'undefined'
  END  reason
from
   (select address,count(1) cpt, UNBOUND_CURSOR,SQL_TYPE_MISMATCH,OPTIMIZER_MISMATCH,OUTLINE_MISMATCH,STATS_ROW_MISMATCH,LITERAL_MISMATCH,
   -- SEC_DEPTH_MISMATCH,
   EXPLAIN_PLAN_CURSOR,BUFFERED_DML_MISMATCH,PDML_ENV_MISMATCH,INST_DRTLD_MISMATCH,SLAVE_QC_MISMATCH,TYPECHECK_MISMATCH,AUTH_CHECK_MISMATCH,BIND_MISMATCH,DESCRIBE_MISMATCH,LANGUAGE_MISMATCH,TRANSLATION_MISMATCH,
    -- ROW_LEVEL_SEC_MISMATCH,
    INSUFF_PRIVS,INSUFF_PRIVS_REM,REMOTE_TRANS_MISMATCH,LOGMINER_SESSION_MISMATCH,INCOMP_LTRL_MISMATCH,OVERLAP_TIME_MISMATCH,
    --SQL_REDIRECT_MISMATCH,
    MV_QUERY_GEN_MISMATCH,USER_BIND_PEEK_MISMATCH,TYPCHK_DEP_MISMATCH,NO_TRIGGER_MISMATCH,FLASHBACK_CURSOR,ANYDATA_TRANSFORMATION, -- INCOMPLETE_CURSOR,
    TOP_LEVEL_RPI_CURSOR,DIFFERENT_LONG_LENGTH,LOGICAL_STANDBY_APPLY,DIFF_CALL_DURN,BIND_UACS_DIFF,PLSQL_CMP_SWITCHS_DIFF,
    rank () over (order by count(1) desc) as rank from
     v\$sql_shared_cursor group by address,UNBOUND_CURSOR,SQL_TYPE_MISMATCH,OPTIMIZER_MISMATCH,OUTLINE_MISMATCH,STATS_ROW_MISMATCH,LITERAL_MISMATCH,
     -- SEC_DEPTH_MISMATCH,
     EXPLAIN_PLAN_CURSOR,BUFFERED_DML_MISMATCH,PDML_ENV_MISMATCH,INST_DRTLD_MISMATCH,SLAVE_QC_MISMATCH,TYPECHECK_MISMATCH,AUTH_CHECK_MISMATCH,BIND_MISMATCH,DESCRIBE_MISMATCH,LANGUAGE_MISMATCH,TRANSLATION_MISMATCH,
      --ROW_LEVEL_SEC_MISMATCH,
      INSUFF_PRIVS,INSUFF_PRIVS_REM,REMOTE_TRANS_MISMATCH,LOGMINER_SESSION_MISMATCH,INCOMP_LTRL_MISMATCH,OVERLAP_TIME_MISMATCH,
      --SQL_REDIRECT_MISMATCH,
      MV_QUERY_GEN_MISMATCH,USER_BIND_PEEK_MISMATCH,TYPCHK_DEP_MISMATCH,NO_TRIGGER_MISMATCH,FLASHBACK_CURSOR,ANYDATA_TRANSFORMATION, -- INCOMPLETE_CURSOR,
   TOP_LEVEL_RPI_CURSOR,DIFFERENT_LONG_LENGTH,LOGICAL_STANDBY_APPLY,DIFF_CALL_DURN,BIND_UACS_DIFF,PLSQL_CMP_SWITCHS_DIFF
) a , v\$sql b
where rank <= $ROWNUM and a.address = b.address order by a.address,cpt desc;
"
# ............................................................
elif [ "$ACTION" = "LAST_ACTIVE" ];then
 
     if [ -n "$fowner" ];then
          AND_USER=" and PARSING_SCHEMA_NAME = '$fowner' "
     fi
     TITTLE="List last active SQL in DB"
 
     SQL="
col sql_text for a64
set lines 190
col cpu_time_ms head 'Cpu time |(ms)'  for 9999999990.9 justify c
col PARSING_SCHEMA_NAME head 'Parsing|Schema Name' for a20 justify c
col ROWS_PROCESSED head 'Row|Processed' justify c for 999999999999
col last_active head 'Last active|Time' justify c
col executions head 'Eexecutions' for 999,999,999
break on last_Active on report
 
select to_char(last_active_time,'HH24:MI:SS') last_active, sa.hash_value  ,
     cpu_time/1048576 cpu_time_ms, ROWS_PROCESSED,executions,PARSING_SCHEMA_NAME, sql_text
   from
     (select last_active_time, hash_value, ROWS_PROCESSED, executions,cpu_time,PARSING_SCHEMA_NAME, sql_text
             from
                  (select last_active_time, hash_value , ROWS_PROCESSED,executions,cpu_time, PARSING_SCHEMA_NAME, substr(sql_text,1,$TLEN) sql_text
                          from v\$sqlarea  where last_Active_time  is not null  $AND_USER
                          order by last_active_time desc)
             where rownum <$ROWNUM
     ) sa
where
   exists (select 1 from v\$open_cursor where hash_Value = sa.hash_value) ;
"
# ............................................................
elif [ "$ACTION" = "ACTIVE" ];then
SQL=" select s.sid, c.kglnaobj  sql_text
from
  sys.x\$kglpn  p,
  sys.x\$kglcursor  c,
  v\$session  s
where
  p.inst_id = userenv('Instance') and
  c.inst_id = userenv('Instance') and
  p.kglpnhdl = c.kglhdadr and
  c.kglhdadr != c.kglhdpar and
  p.kglpnses = s.saddr
order by
  s.sid;
"
# ............................................................
elif [ "$ACTION" = "SESSION" ];then
   SQL="col piece noprint
        col cpu_time head 'Cpu time (ms)'  for 9999999990.9
        col sql_text format A64
        col executions head 'Tot|execs' for 99999999
       break on sql_id on command on cpu_time on last_active_time on executions
 
SELECT distinct s.sql_id, d.piece ,decode(d.COMMAND_TYPE,3,'SELECT', 7,'DELETE',6,'UPDATE',2,'INSERT',d.command_type) command,
       a.CPU_TIME/1048576 cpu_time,to_char(a.LAST_ACTIVE_TIME,'MON-DD HH24:MI:SS') last_active_time, executions,
       d.sql_text
               FROM V\$open_cursor s, v\$sqltext d, v\$sqlarea a
                    WHERE $SID s.ADDRESS=d.ADDRESS and s.HASH_VALUE=d.hash_Value
                      and s.hash_value=a.hash_value(+)
                    ORDER by last_active_time  desc ,s.sql_id,d.piece asc; "
# ............................................................
#else #
#  SQL="break on sid on logon_time on buffer_gets on parse_calls on hash_value
#SELECT s.sid,to_char(logon_time,'DDMM HH24:MI') logon_time ,
#       lockwait, b.buffer_gets,  b.parse_calls, $HRAW d.sql_text
#   FROM v\$open_cursor s,v\$sql b, v\$session c , v\$sqltext d
#   WHERE $SID s.address=b.address and s.address=d.address and s.hash_value=c.sql_hash_value and s.sid = c.sid (+)
#   ORDER by sid,b.address,s.hash_value,piece ; "
fi
 
 
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
 
if [ -n "$VERBOSE" ];then
   echo "$SQL"
fi
 
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  rigth 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline , '$TITTLE (help : soc -h) 'nline from sys.dual
/
set heading on
 
set linesize 190 pagesize 64
col username format A24
col command format A14
col sid format 99999
col address format A6
col f_addr format A16 head "Address"
col cpt head "Number of|cursors" justify c
col piece format 99 head 'Pi'
col sql_text format A64 head 'Sql Text'
col logon_time format A12
col buffer_gets format 9999999999 head 'buffer| Gets'
col parse_calls format 99999 head 'Parse| Calls'
col lockwait format A4 head 'Lock|wait'
col hashadr format 9999999999 head 'SQL |addr/hash' justify c
$SQL
exit
 
EOF
 
