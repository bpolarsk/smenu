#!/bin/ksh
#set -xv
function help 
{
cat <<EOF

   All about locks:
       
         lck -b : Blocking and blocked users
         lck -b1 : what is doing the blockers
         lck -e : Count lock type
         lck -l : List locks ( use -ll to see extended lock name space )
        lck -lo -s[sid] : List locked objects and rowid locked
        lck -ls : List locked objects  and time lenght it is locked
         lck -p : Locks mode, requested and id1, id2 parameters
         lck -sta : System wide locks statistics
         lck -w : Waiters and object waited
         lck -rac : show rac wide locking accross instances
         lck -t : Display locks type by mode/requests counts and descriptions
         lck -tree : display lock tree 
         lck -his <nn> : List blocking session and text from AWR
         lck -his -b0 <SNAPID> -e0 <SNAPID> : List blocking session and text from AWR between SNAP b1 and e1
         lck -srow : Show the rowid locked. User 'select * from table wher rowid='nn' to see content
         lck -arow : Show all rowid locked. User 'select * from table wher rowid='nn' to see content
         lck -desc  : List a description of all locks
         
             -s <sid>
EOF
exit
}
if [ -z "$1" ];then
   help
fi
while [ -n "$1" ]
do
  case "$1" in
    -srow) ACTION=SROW ; SID="$2"; shift ; TITTLE="Show rowid" ;;
    -arow) ACTION=AROW ; TITTLE="Show all rowid" ;;
   -desc ) ACTION=TEMP ; TITTLE="Describe locks";;
      -w ) ACTION=WAIT
           TITTLE="Waiters and object waited";;
     -sta ) ACTION=STAT 
           TITTLE="System wide locks statistics" ;;
      -o ) ACTION=OBJ 
           TITTLE="Object locked and lock mode held";;
      -l ) ACTION=LIST 
           TITTLE="List locks and lock mode held";;
     -lo ) ACTION=LOCKED_OBJECT 
           TITTLE="List object and rowid locked";;
     -ll ) ACTION=LIST ; LONG=TRUE ;
           TITTLE="List locks and lock mode held";;
     -ls ) ACTION=LOCKED_TIME 
           TITTLE="List object and time locked";;
      -e ) ACTION=COUNT 
           TITTLE="Count lock type";;
      -p ) ACTION="PARAMETERS"
           TITTLE="Locks mode, requested and id1, id2 parameters";;
      -s ) SID=$2; shift ;;
      -row ) ROWID=TRUE ;;
      -b ) ACTION=BLOCKER
           TITTLE="Blocking and blocked users" ;;
      -b1 ) ACTION=BLOCKER1
           TITTLE="Blocking and blocked users" ;;
      -b0 ) SNAP1=$2 ; shift ;;
      -e0 ) SNAP2=$2 ; shift ;;
    -rac ) ACTION=RAC ; TITTLE="Rac locking" ;;
      -t ) ACTION=XT ; TITTLE="Display locks type by mode/requests counts and descriptions" ;;
      -tree ) ACTION=TREE ; TITTLE="Display locks tree" ;;
     -his) ACTION=HIST ; TITTLE="List blockking session in the past n days"
           if [ -n "$2" -a "$2" != "-b0" -a "$2" != "-e0" ];then
                PAR="$2" ; shift
           fi;;
      -h ) help ;;
      -v ) set -x ;;
      *  ) echo "Unknown parameters $1" ; echo ; help ;;
  esac
  shift
done

#S_USER=SYS
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# ------------------------------
# Describe locks
# ------------------------------
if [ "$ACTION" = "BLOCKER1" ];then
SQL="

set lines 200 pages 60

with v as (
 select distinct blocking_session as sid
FROM
   v\$session
WHERE
   blocking_session IS NOT NULL
)
SELECT
   s.sid, 
   s.SQL_ID, SQL_TEXT sql
FROM
   v\$session s, v\$sql  a, v
WHERE
   v.sid = s.sid
   and s.sql_id = a.sql_id(+) 
/
"
# ------------------------------
# Describe locks
# ------------------------------
elif [ "$ACTION" = "TEMP" ];then
SQL="
set pages 90 lines 190
col type for a3 head 'Typ'
col name for a32
col id1_tag for a22
col id2_tag for a22
col description for a105
select
    TYPE, NAME, ID1_TAG, ID2_TAG, DESCRIPTION
from sys.V_\$LOCK_TYPE
order by type
/
"
# ------------------------------
# OBJECT and time  locked
# ------------------------------
elif [ "$ACTION" = "LOCKED_TIME" ];then
SQL="
col lmode for 9999999990
col ctime for 999990 head 'Hold(s)'
col LOCK_TYPE for a20
col object_name for a30
select SESSION_ID, LOCK_TYPE, o.object_name, last_convert
  from dba_locks l, all_objects o
where
       o.object_id (+) =   l.LOCK_ID1 
and lock_type <> 'Media Recovery'
and lock_type <> 'AE'
/
"
# ------------------------------
# OBJECT and ROW id locked
# ------------------------------
elif [ "$ACTION" = "LOCKED_OBJECT" ];then
 if [ -n "$SID" ];then
    AND_SID=" and lo.session_id=$SID"
 fi
 if [  "$ROWID" = "TRUE" ];then
     COL_ROW=",decode( ROW_WAIT_OBJ#, -1, '-', dbms_rowid.rowid_create ( 1, ROW_WAIT_OBJ#, ROW_WAIT_FILE#, ROW_WAIT_BLOCK#, ROW_WAIT_ROW# )) f_rowid"
 fi
SQL="
col lmode for 9999999990
col owner for A20
select session_id sid,  o.object_name, o.owner, locked_mode lmode, 
  row_wait_obj#, row_wait_file#, row_wait_block#, row_wait_row# $COL_ROW
from 
   v\$locked_object lo, all_objects o, v\$session s --, v\$lock l
where 
       o.object_id = lo.object_id
       -- and o.object_id = l.id1 (+)
   and lo.session_id = s.sid (+) $AND_SID
order by session_id
/
"
# ------------------------------
# Lock tree
# ------------------------------
elif [ "$ACTION" = "TREE" ];then
SQL="
col username format a30
col sid for 99999
col program for a45
col module for a35
set lines 190
SELECT 
      s.sid,
    LPAD(' ', (level-1)*2, ' ') || NVL(s.username, '(oracle)') AS username,
       s.lockwait,
       s.status,
       -- s.machine,
       s.program,
        s.module,
       TO_CHAR(s.logon_Time,'HH24:MI:SS') AS logon_time
FROM   v\$session s
CONNECT BY PRIOR s.sid = s.blocking_session
START WITH s.blocking_session IS NULL
/
"
# ------------------------------
# Lock history
# ------------------------------
elif [ "$ACTION" = "AROW" ];then
SQL="
select s.sid, do.object_name,
       row_wait_obj#, row_wait_file#, row_wait_block#, row_wait_row#,
       dbms_rowid.rowid_create ( 1, ROW_WAIT_OBJ#, ROW_WAIT_FILE#, ROW_WAIT_BLOCK#, ROW_WAIT_ROW# ),
       s.BLOCKING_SESSION block_sid
    from v\$session s, dba_objects do, v\$session_wait w
    where 
           w.event = 'enq: TX - row lock contention'
      and s.sid = w.sid 
      and s.ROW_WAIT_OBJ# = do.OBJECT_ID ;
"
# ------------------------------
# Lock history
# ------------------------------
elif [ "$ACTION" = "SROW" ];then
SQL="
select do.object_name,
    row_wait_obj#, row_wait_file#, row_wait_block#, row_wait_row#,
    dbms_rowid.rowid_create ( 1, ROW_WAIT_OBJ#, ROW_WAIT_FILE#, ROW_WAIT_BLOCK#, ROW_WAIT_ROW# )
    from v\$session s, dba_objects do
    where sid=$SID
    and s.ROW_WAIT_OBJ# = do.OBJECT_ID ;
"
# ------------------------------
# Lock history
# ------------------------------
elif [ "$ACTION" = "HIST" ];then
# we should replace the v$sql with WRM$SQL
  if [ -z "$SNAP1" ];then
     PAR=${PAR:-7}
SQL="
set long 200
col blocking_session for 9999999 head 'Blocking|Session'
col program for a20 truncate
col session_id for a5
set feed on
col sql_text for a90
col rn noprint
select * from (
SELECT to_char(a.sample_time,'YYYY-MM-DD HH24:MI:SS') sample_time,a.sql_id , session_id,
COUNT(*) OVER (PARTITION BY a.blocking_session,a.user_id ,a.program) cpt,
ROW_NUMBER() OVER (PARTITION BY  a.blocking_session,a.user_id ,a.program 
   order by blocking_session,a.user_id ,a.program ) rn,
a.blocking_session,a.user_id ,a.program, s.sql_text
FROM  sys.WRH\$_ACTIVE_SESSION_HISTORY a  ,sys.wrh\$_sqltext s
where a.sql_id=s.sql_id
and blocking_session_serial# <> 0
and a.user_id <> 0
and a.sample_time > sysdate - $PAR
) where rn = 1
;
"
  else # we use snapid instead of date
     if [ -z "$SNAP2" ];then
        SNAP2=`expr $SNAP1 + 1`
    fi 
  SQL="
set long 200
col blocking_session for 9999999 head 'Blocking|Session'
col program for a20 truncate
col session_id for a5
set feed on
col sql_text for a95
    SELECT  
          to_char(a.sample_time,'YYYY-MM-DD HH24:MI:SS') sample_time, a.sql_id , session_id,
          a.blocking_session,a.user_id ,a.program, s.sql_text
       FROM  sys.WRH\$_ACTIVE_SESSION_HISTORY a  ,sys.wrh\$_sqltext s
where a.sql_id=s.sql_id
and blocking_session_serial# <> 0
and a.user_id <> 0
and a.SNAP_ID >= $SNAP1 and a.SNAP_ID<$SNAP2
order by a.sample_time
;
"

fi
# ------------------------------
# 
# ------------------------------
elif [ "$ACTION" = "XT" ];then
SQL="set linesize 190 pagesize 66
col KSQSTEXPL format a74
col INDX format 999 head 'idx'
col KSQSTREQ format 99999999 head 'Req'
col KSQSTRSN format a18
col KSQSTWAT head 'Had to|wait' justify c
col KSQSTSGT head 'Success'
col KSQSTFGT format 99999 head 'Failed' justify c
col KSQSTWTM head 'Total|Wait(s)'
SELECT  INDX , KSQSTREQ ,  KSQSTWAT  , KSQSTSGT ,  KSQSTFGT ,  KSQSTWTM/1000 KSQSTWTM ,KSQSTRSN   ,   KSQSTEXPL
    FROM x\$ksqst WHERE KSQSTSGT > 0 ;
"
# ------------------------------
# Waiters and object waited
# ------------------------------
elif [ "$ACTION" = "RAC" ];then
#-- +----------------------------------------------------------------------------+
#-- | Jeffrey M. Hunter :  jhunter@idevelopment.info                             |
#-- | PURPOSE  : Query all Blocking Locks in the databases. This query will      |
#-- |            display both the user(s) holding the lock and the user(s)       |
#-- |            waiting for the lock. This script is RAC enabled.               |
#-- +----------------------------------------------------------------------------+

SQL="
SET LINESIZE 145
SET PAGESIZE 9999

COLUMN locking_instance   FORMAT a17   HEAD 'LOCKING|Instance - SID'  JUST LEFT
COLUMN locking_sid        FORMAT a7    HEAD 'LOCKING|SID'             JUST LEFT
COLUMN waiting_instance   FORMAT a17   HEAD 'WAITING|Instance - SID'  JUST LEFT
COLUMN waiting_sid        FORMAT a7    HEAD 'WAITING|SID'             JUST LEFT
COLUMN waiter_lock_type                HEAD 'Waiter Lock Type'        JUST LEFT
COLUMN waiter_mode_req                 HEAD 'Waiter Mode Req.'        JUST LEFT
COLUMN instance_name      FORMAT a8    HEAD 'Instance|Name'           JUST LEFT
COLUMN sid                FORMAT a7    HEAD 'SID'                     JUST LEFT
COLUMN serial_number      FORMAT a7    HEAD 'Serial|Number'           JUST LEFT
COLUMN session_status                  HEAD 'Status'                  JUST LEFT
COLUMN oracle_user        FORMAT a20   HEAD 'Oracle|Username'         JUST LEFT
COLUMN os_username        FORMAT a20   HEAD 'O/S|Username'            JUST LEFT
COLUMN object_owner       FORMAT a15   HEAD 'Object|Owner'            JUST LEFT
COLUMN object_name        FORMAT a20   HEAD 'Object|Name'             JUST LEFT
COLUMN object_type        FORMAT a15   HEAD 'Object|Type'             JUST LEFT

CLEAR BREAKS

prompt 
prompt +----------------------------------------------------------------------------+
prompt | BLOCKING LOCKS                                                             |
prompt +----------------------------------------------------------------------------+
prompt 

SELECT
    ih.instance_name || ' - ' ||  lh.sid        locking_instance
  , iw.instance_name || ' - ' ||  lw.sid        waiting_instance
  , DECODE (   lh.type
             , 'CF', 'Control File'
             , 'DX', 'Distrted Transaction'
             , 'FS', 'File Set'
             , 'IR', 'Instance Recovery'
             , 'IS', 'Instance State'
             , 'IV', 'Libcache Invalidation'
             , 'LS', 'LogStartORswitch'
             , 'MR', 'Media Recovery'
             , 'RT', 'Redo Thread'
             , 'RW', 'Row Wait'
             , 'SQ', 'Sequence #'
             , 'ST', 'Diskspace Transaction'
             , 'TE', 'Extend Table'
             , 'TT', 'Temp Table'
             , 'TX', 'Transaction'
             , 'TM', 'Dml'
             , 'UL', 'PLSQL User_lock'
             , 'UN', 'User Name'
             , 'Nothing-'
           )                                    waiter_lock_type
  , DECODE (   lw.request
             , 0, 'None'
             , 1, 'NoLock'
             , 2, 'Row-Share'
             , 3, 'Row-Exclusive'
             , 4, 'Share-Table'
             , 5, 'Share-Row-Exclusive'
             , 6, 'Exclusive'
             , 'Nothing-'
           )                                    waiter_mode_req
FROM
    gv\$lock     lw
  , gv\$lock     lh
  , gv\$instance iw
  , gv\$instance ih
WHERE
   iw.inst_id = lw.inst_id
  AND ih.inst_id = lh.inst_id
  AND lh.id1     = lw.id1
  AND lh.id2     = lw.id2
  AND lh.request = 0
  AND lw.lmode   = 0
  AND (lh.id1, lh.id2) IN ( SELECT id1,id2
                            FROM   gv\$lock
                            WHERE  request = 0
                            INTERSECT
                            SELECT id1,id2
                            FROM   gv\$lock
                            WHERE  lmode = 0
                          )
ORDER BY
    lh.sid
/


prompt 
prompt +----------------------------------------------------------------------------+
prompt | LOCKED OBJECTS                                                             |
prompt +----------------------------------------------------------------------------+
prompt 

SELECT
    i.instance_name           instance_name
  , RPAD(l.session_id,7)      sid
  , RPAD(s.serial#,7)         serial_number
  , s.status                  session_status
  , l.oracle_username         oracle_user
  , l.os_user_name            os_username
  , o.owner                   object_owner
  , o.object_name             object_name
  , o.object_type             object_type
FROM
    dba_objects       o
  , gv\$session        s
  , gv\$locked_object  l
  , gv\$instance       i
WHERE
      i.inst_id    = l.inst_id
  AND l.inst_id    = s.inst_id
  AND l.session_id = s.sid
  AND o.object_id  = l.object_id
ORDER BY
    l.session_id
/
"
# ------------------------------
# Waiters and object waited
# ------------------------------
elif [ "$ACTION" = "WAIT" ];then
SQL="select w.sid, o.object_name, o.object_type 
     from v\$session_wait w, v\$session s, dba_objects o
     where ( o.object_id = s.row_wait_obj# or o.data_object_id = s.row_wait_obj# ) 
           and s.sid = w.sid
           and chr(bitand(w.p1,-16777216)/16777215) || chr(bitand(w.p1,16711860)/65535) = 'TX'
           and w.event = 'enqueue';"
         

# ------------------------------
# System wide locks statistics
# ------------------------------
elif [ "$ACTION" = "STAT" ];then
SQL="select INST_ID, EQ_TYPE, TOTAL_REQ#, TOTAL_WAIT#, succ_req#, failed_req#, cum_wait_time
       from v\$enqueue_stat where cum_wait_time > 0 order by inst_id,cum_wait_time;"
# ------------------------------
# List enqueue
# ------------------------------
elif [ "$ACTION" = "LIST" ];then
     if [ "$LONG" = "TRUE" ];then
          TRUNCATE=''
     else
          TRUNCATE=truncate
          PROMPT='prompt use lck -ll to see extended lock name space
                  prompt'
     fi
# Last version of showlock.sql as given by jared still
SQL="
set trimspool on linesize 190 pagesize 60
column command format a11
column osuser heading 'OS|Username' format a7 truncate
column process heading 'OS|Process' format a7 truncate
column machine heading 'OS|Machine' format a10 truncate
column program heading 'OS|Program' format a18 truncate
column object heading 'Database|Object' format a29 
column lock_type heading 'Lock|Type' format a4 truncate
column lock_description heading 'Lock Description'format a30 $TRUNCATE
column mode_held heading 'Mode|Held' format a10 truncate
column mode_requested heading 'Mode|Requested' format a10 truncate
column sid heading 'SID' format 999
column username heading 'Oracle|Username' format a17 truncate
column image heading 'Active Image' format a20 truncate
column sid format 99999
col waiting_session head 'WATR' format 9999
col holding_session head 'BLKR' format 9999
$PROMPT
with dblocks as (
   select /*+ ordered */
          l.kaddr, s.sid, s.username, lock_waiter.waiting_session, lock_blocker.holding_session, 
          ( select name from sys.user$ where user# = o.owner#) ||'.'||o.name object,
                  decode(command,
                                 0,'BACKGROUND', 1,'Create Table', 2,'INSERT', 3,'SELECT', 4,'CREATE CLUSTER', 5,'ALTER CLUSTER',
                                 6,'UPDATE', 7,'DELETE', 8,'DROP', 9,'CREATE INDEX', 10,'DROP INDEX', 11,'ALTER INDEX', 12,'DROP TABLE',
                                13,'CREATE SEQUENCE', 14,'ALTER SEQUENCE', 15,'ALTER TABLE', 16,'DROP SEQUENCE', 17,'GRANT', 18,'REVOKE',
                                19,'CREATE SYNONYM', 20,'DROP SYNONYM', 21,'CREATE VIEW', 22,'DROP VIEW', 23,'VALIDATE INDEX',
                                24,'CREATE PROCEDURE', 25,'ALTER PROCEDURE', 26,'LOCK TABLE', 27,'NO OPERATION', 28,'RENAME', 29,'COMMENT',
                                30,'AUDIT', 31,'NOAUDIT', 32,'CREATE EXTERNAL DATABASE', 33,'DROP EXTERNAL DATABASE', 34,'CREATE DATABASE',
                                35,'ALTER DATABASE', 36,'CREATE ROLLBACK SEGMENT', 37,'ALTER ROLLBACK SEGMENT', 38,'DROP ROLLBACK SEGMENT',
                                39,'CREATE TABLESPACE', 40,'ALTER TABLESPACE', 41,'DROP TABLESPACE', 42,'ALTER SESSION', 43,'ALTER USER',
                                44,'COMMIT', 45,'ROLLBACK', 46,'SAVEPOINT', 47,'PL/SQL EXECUTE', 48,'SET TRANSACTION', 49,'ALTER SYSTEM SWITCH LOG',
                                50,'EXPLAIN', 51,'CREATE USER', 52,'CREATE ROLE', 53,'DROP USER', 54,'DROP ROLE', 55,'SET ROLE', 56,'CREATE SCHEMA',
                                57,'CREATE CONTROL FILE', 58,'ALTER TRACING', 59,'CREATE TRIGGER', 60,'ALTER TRIGGER', 61,'DROP TRIGGER',
                                62,'ANALYZE TABLE', 63,'ANALYZE INDEX', 64,'ANALYZE CLUSTER', 65,'CREATE PROFILE', 66,'DROP PROFILE',
                                67,'ALTER PROFILE', 68,'DROP PROCEDURE', 69,'DROP PROCEDURE', 70,'ALTER RESOURCE COST', 71,'CREATE SNAPSHOT LOG',
                                72,'ALTER SNAPSHOT LOG', 73,'DROP SNAPSHOT LOG', 74,'CREATE SNAPSHOT', 75,'ALTER SNAPSHOT', 76,'DROP SNAPSHOT',
                                79,'ALTER ROLE', 85,'TRUNCATE TABLE', 86,'TRUNCATE CLUSTER', 87,'-', 88,'ALTER VIEW', 89,'-', 90,'-',
                                91,'CREATE FUNCTION', 92,'ALTER FUNCTION', 93,'DROP FUNCTION', 94,'CREATE PACKAGE', 95,'ALTER PACKAGE',
                                96,'DROP PACKAGE', 97,'CREATE PACKAGE BODY', 98,'ALTER PACKAGE BODY', 99,'DROP PACKAGE BODY', command||'-UNKNOWN'
                      ) COMMAND, l.type lock_type,
                 decode ( l.type,
                               'BL','Buffer hash table instance lock', 'CF',' Control file schema global enqueue lock',
                               'CI','Cross-instance function invocation instance lock', 'CS','Control file schema global enqueue lock',
                               'CU','Cursor bind lock', 'DF','Data file instance lock', 'DL','Direct loader parallel index create',
                               'DM','Mount/startup db primary/secondary instance lock', 'DR','Distributed recovery process lock',
                               'DX','Distributed transaction entry lock', 'FI','SGA open-file information lock', 'FS','File set lock',
                               'HW','Space management operations on a specific segment lock', 'IN','Instance number lock',
                               'IR','Instance recovery serialization global enqueue lock', 'IS','Instance state lock',
                               'IV','Library cache invalidation instance lock', 'JQ','Job queue lock', 'KK','Thread kick lock',
                               'LA','Library cache lock instance lock (A=namespace)', 'LB','Library cache lock instance lock (B=namespace)',
                               'LC','Library cache lock instance lock (C=namespace)', 'LD','Library cache lock instance lock (D=namespace)',
                               'LE','Library cache lock instance lock (E=namespace)', 'LF','Library cache lock instance lock (F=namespace)',
                               'LG','Library cache lock instance lock (G=namespace)', 'LH','Library cache lock instance lock (H=namespace)',
                               'LI','Library cache lock instance lock (I=namespace)', 'LJ','Library cache lock instance lock (J=namespace)',
                               'LK','Library cache lock instance lock (K=namespace)', 'LL','Library cache lock instance lock (L=namespace)',
                               'LM','Library cache lock instance lock (M=namespace)', 'LN','Library cache lock instance lock (N=namespace)',
                               'LO','Library cache lock instance lock (O=namespace)', 'LP','Library cache lock instance lock (P=namespace)',
                               'LS','Log start/log switch enqueue lock', 'MB','Master buffer hash table instance lock',
                               'MM','Mount definition gloabal enqueue lock', 'MR','Media recovery lock', 'PA','Library cache pin instance lock (A=namespace)',
                               'PB','Library cache pin instance lock (B=namespace)', 'PC','Library cache pin instance lock (C=namespace)',
                               'PD','Library cache pin instance lock (D=namespace)', 'PE','Library cache pin instance lock (E=namespace)',
                               'PF','Library cache pin instance lock (F=namespace)', 'PF','Password file lock',
                               'PG','Library cache pin instance lock (G=namespace)', 'PH','Library cache pin instance lock (H=namespace)',
                               'PI','Library cache pin instance lock (I=namespace)', 'PI','Parallel operation lock',
                               'PJ','Library cache pin instance lock (J=namespace)', 'PK','Library cache pin instance lock (L=namespace)',
                               'PL','Library cache pin instance lock (K=namespace)', 'PM','Library cache pin instance lock (M=namespace)',
                               'PN','Library cache pin instance lock (N=namespace)', 'PO','Library cache pin instance lock (O=namespace)',
                               'PP','Library cache pin instance lock (P=namespace)', 'PQ','Library cache pin instance lock (Q=namespace)',
                               'PR','Library cache pin instance lock (R=namespace)', 'PR','Process startup lock',
                               'PS','Library cache pin instance lock (S=namespace)', 'PS','Parallel operation lock',
                               'PT','Library cache pin instance lock (T=namespace)', 'PU','Library cache pin instance lock (U=namespace)',
                               'PV','Library cache pin instance lock (V=namespace)', 'PW','Library cache pin instance lock (W=namespace)',
                               'PX','Library cache pin instance lock (X=namespace)', 'PY','Library cache pin instance lock (Y=namespace)',
                               'PZ','Library cache pin instance lock (Z=namespace)', 'QA','Row cache instance lock (A=cache)',
                               'QB','Row cache instance lock (B=cache)', 'QC','Row cache instance lock (C=cache)',
                               'QD','Row cache instance lock (D=cache)', 'QE','Row cache instance lock (E=cache)', 'QF','Row cache instance lock (F=cache)',
                               'QG','Row cache instance lock (G=cache)', 'QH','Row cache instance lock (H=cache)', 'QI','Row cache instance lock (I=cache)',
                               'QJ','Row cache instance lock (J=cache)', 'QK','Row cache instance lock (L=cache)', 'QL','Row cache instance lock (K=cache)',
                               'QM','Row cache instance lock (M=cache)', 'QN','Row cache instance lock (N=cache)', 'QO','Row cache instance lock (O=cache)',
                               'QP','Row cache instance lock (P=cache)', 'QQ','Row cache instance lock (Q=cache)', 'QR','Row cache instance lock (R=cache)',
                               'QS','Row cache instance lock (S=cache)', 'QT','Row cache instance lock (T=cache)', 'QU','Row cache instance lock (U=cache)',
                               'QV','Row cache instance lock (V=cache)', 'QW','Row cache instance lock (W=cache)', 'QX','Row cache instance lock (X=cache)',
                               'QY','Row cache instance lock (Y=cache)', 'QZ','Row cache instance lock (Z=cache)', 'RE','USE_ROW_ENQUEUE enforcement lock',
                               'RT','Redo thread global enqueue lock', 'RW','Row wait enqueue lock', 'SC','System commit number instance lock',
                               'SH','System commit number high water mark enqueue lock', 'SM','SMON lock', 'SN','Sequence number instance lock',
                               'SQ','Sequence number enqueue lock', 'SS','Sort segment lock', 'ST','Space transaction enqueue lock',
                               'SV','Sequence number value lock', 'TA','Generic enqueue lock', 'TD','DDL enqueue lock', 'TE','Extend-segment enqueue lock',
                               'TM','DML enqueue lock', 'TO','Temporary Table Object Enqueue', 'TS',decode(l.id2, 0,'Temporary segment enqueue lock (ID2=0)',
                                1,'New block allocation enqueue lock (ID2=1)', 'UNKNOWN!'),
                 'TT','Temporary table enqueue lock', 'TX','Transaction enqueue lock', 'UL','User supplied lock', 'UN','User name lock',
                 'US','Undo segment DDL lock', 'WL','Being-written redo log instance lock', 'WS','Write-atomic-log-switch global enqueue lock',
                 'UNKOWN') lock_description,
                 decode ( l.lmode,
                                0, 'None', /* Mon Lock equivalent */ 1, 'No Lock', /* N */ 2, 'Row-S (SS)', /* L */ 3, 'Row-X (SX)', /* R */
                                4, 'Share', /* S */ 5, 'S/Row-X (SRX)', /* C */ 6, 'Exclusive', /* X */ to_char(l.lmode)) mode_held,
                 decode ( l.request,
                                0, 'None', /* Mon Lock equivalent */ 1, 'No Lock', /* N */ 2, 'Row-S (SS)', /* L */ 3, 'Row-X (SX)', /* R */
                                4, 'Share', /* S */ 5, 'S/Row-X (SSX)', /* C */ 6, 'Exclusive', /* X */ to_char(l.request)) mode_requested,
                 s.osuser, s.machine, s.program, s.process, l.ctime
         from
               v\$lock l
          join v\$session s on s.sid = l.sid
left outer join sys.dba_waiters lock_blocker on lock_blocker.waiting_session = s.sid
left outer join sys.dba_waiters lock_waiter on lock_waiter.holding_session = s.sid
left outer join sys.obj\$ o on o.obj# = l.id1
where s.type != 'BACKGROUND'
)
select --kaddr,
sid, username, waiting_session, holding_session, object, command, lock_type, 
     lock_description, mode_held, mode_requested, --osuser, --machine, 
     program, process, ctime
from dblocks
order by sid, object
/
"

# ------------------------------
# Count lock type
# ------------------------------
elif [ "$ACTION" = "COUNT" ];then
   SQL="select a.sid,username, osuser, a.type  ,count(1) Cpt
    from v\$lock a,v\$session b where a.sid = b.sid group by a.sid, a.type,username,osuser ;
"

# ------------------------------
# locks parameters
# ------------------------------
elif [ "$ACTION" = "BLOCKER" ];then
SQL="
prompt seen from v\$session:
SELECT
   s.blocking_session, 
   s.sid, 
   s.serial#, 
   s.seconds_in_wait
FROM
   v\$session s
WHERE
   blocking_session IS NOT NULL
/
prompt seen from v\$lock
SELECT 
   l1.sid || ' is blocking ' || l2.sid blocking_sessions
FROM 
   v\$lock l1, v\$lock l2
WHERE
   l1.block = 1 AND
   l2.request > 0 AND
   l1.id1 = l2.id1 AND
   l1.id2 = l2.id2
/
prompt overview
SELECT s1.username || '@' || s1.machine
    || ' ( SID=' || s1.sid || ' )  is blocking '
    || s2.username || '@' || s2.machine || ' ( SID=' || s2.sid || ' ) ' AS blocking_status
    FROM v\$lock l1, v\$session s1, v\$lock l2, v\$session s2
    WHERE s1.sid=l1.sid AND s2.sid=l2.sid
    AND l1.BLOCK=1 AND l2.request > 0
    AND l1.id1 = l2.id1
    AND l1.id2 = l2.id2
/

prompt  TX :  ID1 and ID2 point back to the rollback and transaction
prompt  TM :  ID1  is the object_id (use obj -n <id1>)
select s.username ,a.sid ,
        decode(a.type,
                'MR', 'Media Recovery',
                'RT', 'Redo Thread',
                'UN', 'User Name',
                'TX', 'Transaction',
                'TM', 'DML',
                'UL', 'PL/SQL User Lock',
                'DX', 'Distributed Xaction',
                'CF', 'Control File',
                'IS', 'Instance State',
                'FS', 'File Set',
                'IR', 'Instance Recovery',
                'ST', 'Disk Space Transaction',
                'TS', 'Temp Segment',
                'IV', 'Library Cache Invalidation',
                'LS', 'Log Start or Switch',
                'RW', 'Row Wait',
                'SQ', 'Sequence Number',
                'TE', 'Extend Table',
                'TT', 'Temp Table',
                a.type) lock_type,
        decode(a.lmode,
                0, 'None',           /* Mon Lock equivalent */
                1, 'Null',           /* N */
                2, 'Row-S (SS)',     /* L */
                3, 'Row-X (SX)',     /* R */
                4, 'Share',          /* S */
                5, 'S/Row-X (SSX)',  /* C */
                6, 'Exclusive',      /* X */
                to_char(a.lmode)) mode_held,
         a.ctime time_held, a.id1, a.id2,
         c.sid,
         decode(c.request,
                0, 'None',           /* Mon Lock equivalent */
                1, 'Null',           /* N */
                2, 'Row-S (SS)',     /* L */
                3, 'Row-X (SX)',     /* R */
                4, 'Share',          /* S */
                5, 'S/Row-X (SSX)',  /* C */
                6, 'Exclusive',      /* X */
                to_char(a.request)) mode_requested,
          c.ctime time_waited
      from v\$lock a, v\$session s, v\$enqueue_lock c
      where s.sid = a.sid     and
            a.id1 = c.id1 (+) and
            a.id2 = c.id2 (+) and
            c.type (+) = 'TX' and 
            a.type     = 'TX' and 
            a.block    = 1    
      order by time_held, time_waited ;
        
"

# ------------------------------
# locks parameters
# ------------------------------
elif [ "$ACTION" = "PARAMETERS" ];then
SQL="
  select
        s.username , a.sid ,
        decode(a.type,
                'MR', 'Media Recovery',
                'RT', 'Redo Thread',
                'UN', 'User Name',
                'TX', 'Transaction',
                'TM', 'DML',
                'UL', 'PL/SQL User Lock',
                'DX', 'Distributed Xaction',
                'CF', 'Control File',
                'IS', 'Instance State',
                'FS', 'File Set',
                'IR', 'Instance Recovery',
                'ST', 'Disk Space Transaction',
                'TS', 'Temp Segment',
                'IV', 'Library Cache Invalidation',
                'LS', 'Log Start or Switch',
                'RW', 'Row Wait',
                'SQ', 'Sequence Number',
                'TE', 'Extend Table',
                'TT', 'Temp Table',
                a.type) lock_type,
        decode(lmode,
                0, 'None',           /* Mon Lock equivalent */
                1, 'Null',           /* N */
                2, 'Row-S (SS)',     /* L */
                3, 'Row-X (SX)',     /* R */
                4, 'Share',          /* S */
                5, 'S/Row-X (SSX)',  /* C */
                6, 'Exclusive',      /* X */
                to_char(a.lmode)) mode_held,
         decode(request,
                0, 'None',           /* Mon Lock equivalent */
                1, 'Null',           /* N */
                2, 'Row-S (SS)',     /* L */
                3, 'Row-X (SX)',     /* R */
                4, 'Share',          /* S */
                5, 'S/Row-X (SSX)',  /* C */
                6, 'Exclusive',      /* X */
                to_char(a.request)) mode_requested,
         to_char(id1) lock_id1, to_char(id2) lock_id2,
         decode(block,
                0, 'Not Blocking',  /* Not blocking any other processes */
                1, 'Blocking',      /* This lock blocks other processes */
                2, 'Global',        /* This lock is global, so we can't tell */
                to_char(block)) blocking_others
      from v\$lock a, v\$session s
           where  a.sid = s.sid (+) and a.type != 'MR'
 order by 8,1;"

# ------------------------------
# list objects locked
# ------------------------------
elif [ "$ACTION" = "OBJ" ];then
SQL="break on sid on username on terminal
    select B.SID, C.USERNAME, C.TERMINAL, DECODE(B.ID2, 0, A.OBJECT_NAME,
                'Trans-'||to_char(B.ID1)) OBJECT_NAME, a.object_type,B.TYPE,
           DECODE(B.LMODE,0,'--Waiting--',
                          1,'Null',
                          2,'Row Share',
                          3,'Row Excl',
                          4,'Share',
                          5,'Sha Row Exc',
                          6,'Exclusive',
                          'Other') mode_held,
          DECODE(B.REQUEST,0,' ',
                         1,'Null',
                         2,'Row Share',
                         3,'Row Excl',
                         4,'Share',
                         5,'Sha Row Exc',
                         6,'Exclusive',
                        'Other') mode_requested
     from DBA_OBJECTS A, V\$LOCK B, V\$SESSION C
   where A.OBJECT_ID(+) = B.ID1 and B.SID = C.SID and C.USERNAME is not null order by B.SID, B.ID2;
"
fi


echo "MACHINE $HOST - ORACLE_SID : $ORACLE_SID "
sqlplus -s "$CONNECT_STRING" <<EOF

column nline newline
set pagesize 66 linesize 80 heading off pause off embedded off verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       '$TITTLE (help:lck -h)  ' nline from sys.dual
/
prompt
set embedded on  heading on  feedback off  linesize 190 pagesize 66
break on sid on username on terminal
column res heading 'Resource Type' format 999
column lmode heading 'Lock Held' format a16
column request heading 'Lock Requested' format a16
column object_name  format a22  heading "Object name"
column terminal heading Term format a8
column tab format a32 heading "Table Name"
column ck_type heading 'Lock Type' format a18
column mode_held heading 'Mode Held' format a11
column mode_requested heading 'Mode Requested' format a12
column sid heading 'SID' format 999999
column lock_id1 heading 'ID1' format a8
column lock_id2 heading 'ID2' format a8
column blocking_others heading 'Blocking| Others' format a12
column username heading 'User' format a14
column lock_type heading 'Lock Type' format a16
set feed on
$SQL
exit
EOF

