#!/bin/ksh
# set -x
# program : smenu_show_redo_logs.ksh
SBINS=$SBIN/scripts
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
function help
{
cat  <<EOF

      rdl                 : List redo information
      rdl -h              : this help
      rdl -size <nn>      : Generate a script to change redo size
      rdl -s              : show redo stats
      rdl -t              : Show redo log strands (private redo)
      rdl -la [nn]        : Show redo history. Optionally show last [nn] days [default is today=0]
     
     -v : set -xv

  # show the last 2 days log switches count  :   rdl -la 1 

EOF
exit
}
NDAYS=0
while [ -n "$1" ]; do
   case "$1" in
       -size  ) CHANGE_SIZE=$2 ; shift ;;
           -s ) STATS=TRUE ;;
           -i ) INSTANCE=$2 ; shift ;; # for thread distinction in RAC
          -la ) HIST=TRUE 
                if [ -n "$2" ];then
                    NDAYS=$2
                    shift
                fi ;;
           -t ) STRANDS=TRUE ;;
           -f )  LIST_WRITES_INFO=true ;;
           -h ) help ;;
           -v ) set -xv ;;
            * ) echo "Invalid parameter $1" ; help ;;
   esac
   shift
done
S_USER=${S_USER:-SYS}
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi


if [ -n "$INSTANCE" ];then
   AND_INST=" and thread# = $INSTANCE" 
fi
if [ -n "$HIST" ];then
#
# A great classic SQL, by Tom Kyte?
#
    sqlplus -s "$CONNECT_STRING" <<EOF 
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 92 termout on heading off pause off embedded on verify off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List              -  List Redo Logs switch count per hour (rdl -la <n> to see <n> last days' from sys.dual 
/
set head on
SET LINESIZE 190
SET PAGESIZE 9999
SET VERIFY off
COLUMN DAY format a12
COLUMN H00 FORMAT 999 HEADING '00'
COLUMN H01 FORMAT 999 HEADING '01'
COLUMN H02 FORMAT 999 HEADING '02'
COLUMN H03 FORMAT 999 HEADING '03'
COLUMN H04 FORMAT 999 HEADING '04'
COLUMN H05 FORMAT 999 HEADING '05'
COLUMN H06 FORMAT 999 HEADING '06'
COLUMN H07 FORMAT 999 HEADING '07'
COLUMN H08 FORMAT 999 HEADING '08'
COLUMN H09 FORMAT 999 HEADING '09'
COLUMN H10 FORMAT 999 HEADING '10'
COLUMN H11 FORMAT 999 HEADING '11'
COLUMN H12 FORMAT 999 HEADING '12'
COLUMN H13 FORMAT 999 HEADING '13'
COLUMN H14 FORMAT 999 HEADING '14'
COLUMN H15 FORMAT 999 HEADING '15'
COLUMN H16 FORMAT 999 HEADING '16'
COLUMN H17 FORMAT 999 HEADING '17'
COLUMN H18 FORMAT 999 HEADING '18'
COLUMN H19 FORMAT 999 HEADING '19'
COLUMN H20 FORMAT 999 HEADING '20'
COLUMN H21 FORMAT 999 HEADING '21'
COLUMN H22 FORMAT 999 HEADING '22'
COLUMN H23 FORMAT 999 HEADING '23'
COLUMN TOTAL FORMAT 999,999 HEADING 'Total'
SELECT
SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH:MI:SS'),1,10) DAY
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'00',1,0)) H00
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'01',1,0)) H01
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'02',1,0)) H02
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'03',1,0)) H03
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'04',1,0)) H04
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'05',1,0)) H05
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'06',1,0)) H06
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'07',1,0)) H07
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'08',1,0)) H08
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'09',1,0)) H09
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'10',1,0)) H10
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'11',1,0)) H11
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'12',1,0)) H12
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'13',1,0)) H13
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'14',1,0)) H14
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'15',1,0)) H15
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'16',1,0)) H16
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'17',1,0)) H17
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'18',1,0)) H18
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'19',1,0)) H19
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'20',1,0)) H20
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'21',1,0)) H21
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'22',1,0)) H22
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH24:MI:SS'),12,2),'23',1,0)) H23
, COUNT(*) TOTAL
FROM
v\$log_history a
where first_time > trunc(sysdate) - $NDAYS
GROUP BY SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH:MI:SS'),1,10)
ORDER BY SUBSTR(TO_CHAR(first_time, 'YYYY/MM/DD HH:MI:SS'),1,10)  desc;
EOF
elif [ -n "$STRANDS" ];then
# another query from Tanel.Poder; just to satisfy curiosity
    sqlplus -s "$CONNECT_STRING" <<EOF 
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 92 termout on heading off pause off embedded on verify off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List              -  List Redo Logs stands' from sys.dual
/
set lines 190 pages 66 head on
col stradr format a16
select INDX,
       PNEXT_BUF_KCRFA_CLN nxtbufadr,
       NEXT_BUF_NUM_KCRFA_CLN nxtbuf#,
       BYTES_IN_BUF_KCRFA_CLN "B/buf",
       PVT_STRAND_STATE_KCRFA_CLN state,
       STRAND_NUM_ORDINAL_KCRFA_CLN strand#,
       INDEX_KCRF_PVT_STRAND stridx,
       SPACE_KCRF_PVT_STRAND strspc,
       TXN_KCRF_PVT_STRAND txn,
       TOTAL_BUFS_KCRFA totbufs#,
       STRAND_SIZE_KCRFA strsz
from X\$KCRFSTRAND
/

set pagesize 66 linesize 190 termout on pause off head on
EOF
elif [ -n "$STATS" ];then

    sqlplus -s "$CONNECT_STRING" <<EOF 
#-- +----------------------------------------------------------------------------+
#-- |                          Jeffrey M. Hunter                                 |
#-- |                      jhunter@idevelopment.info                             |
#-- |                         www.idevelopment.info                              |
#-- |----------------------------------------------------------------------------|
#-- |      Copyright (c) 1998-2007 Jeffrey M. Hunter. All rights reserved.       |
#-- |----------------------------------------------------------------------------|
#-- | DATABASE : Oracle                                                          |
#-- | FILE     : perf_redo_log_contention.sql                                    |
#-- | CLASS    : Tuning                                                          |
#-- | PURPOSE  : Report on overall redo log contention for the instance since    |
#-- |            the instance was last started.                                  |
#-- | NOTE     : As with any code, ensure to test this script in a development   |
#-- |            environment before attempting to run it in production.          |
#-- +----------------------------------------------------------------------------+

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 92 termout on heading off pause off embedded on verify off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List              -  List Redo Logs stats' from sys.dual
/
set pagesize 66 linesize 190 termout on pause off head on
SET PAGESIZE 9999
SET VERIFY   off

prompt
prompt =======================================
prompt Latches
prompt =======================================
prompt 

COLUMN name             FORMAT a30           HEADING 'Latch Name'
COLUMN gets             FORMAT 999,999,999   HEADING 'Gets'
COLUMN misses           FORMAT 999,999,999   HEADING 'Misses'
COLUMN sleeps           FORMAT 999,999,999   HEADING 'Sleeps'
COLUMN immediate_gets   FORMAT 999,999,999   HEADING 'Immediate Gets'
COLUMN immediate_misses FORMAT 999,999,999   HEADING 'Immediate Misses'

BREAK ON report
COMPUTE SUM OF gets             ON report
COMPUTE SUM OF misses           ON report
COMPUTE SUM OF sleeps           ON report
COMPUTE SUM OF immediate_gets   ON report
COMPUTE SUM OF immediate_misses ON report

SELECT 
    INITCAP(name) name
  , gets
  , misses
  , sleeps
  , immediate_gets
  , immediate_misses
FROM  sys.v_\$latch
WHERE name LIKE 'redo%'
ORDER BY 1;


prompt
prompt =====================================================
prompt System Statistics  (Use  'wp redo' for explanations)
prompt =====================================================
prompt

COLUMN name    FORMAT a30               HEADING 'Statistics Name'
COLUMN value   FORMAT 999,999,999,999   HEADING 'Value'

SELECT
    name
  , value
FROM
    v\$sysstat
WHERE
    name LIKE 'redo%';

EOF
elif [ -n "$LIST_WRITES_INFO" ];then

    sqlplus -s "$CONNECT_STRING" <<EOF 
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 92 termout on heading off pause off embedded on verify off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List              -  Last Redo Logs' from sys.dual
/
set pagesize 66 linesize 190 termout on pause off head on
select TARGET_MTTR,ESTIMATED_MTTR,WRITES_MTTR,WRITES_LOGFILE_SIZE, RECOVERY_ESTIMATED_IOS, 
        CKPT_BLOCK_WRITES, OPTIMAL_LOGFILE_SIZE from  
v\$instance_recovery;
select 
    WRITES_MTTR, WRITES_LOGFILE_SIZE, WRITES_LOG_CHECKPOINT_SETTINGS, 
    WRITES_OTHER_SETTINGS,WRITES_AUTOTUNE,WRITES_FULL_THREAD_CKPT 
from v\$instance_recovery;
EOF

elif [ -n "$CHANGE_SIZE" ];then

   $SBIN/module2/s1/smenu_chg_redo_size.sh $CHANGE_SIZE

else

    sqlplus -s "$CONNECT_STRING" <<EOF 

clear screen

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 92 termout on heading off pause off embedded on verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List              -  Last Redo Logs'
from sys.dual
/
set pagesize 66 linesize 190
set termout on pause off
set head on
 
col group# 	format 999      heading 'Group'  
col member 	format a55	heading 'Member' justify c 
col status 	format a10	heading 'Status' justify c	 
col archived	format a10	heading 'Archived' 	 
col fsize 	format 99999 	heading 'Size|(MB)'  
col first_change# for 9999999999999
 
select  l.group#, thread#,  member, archived, l.status, l.sequence#, first_change#,(bytes/1024/1024) fsize
from    v\$log l, v\$logfile f
where f.group# = l.group#
union
select  l.group#, thread#,  member, archived, l.status, l.sequence#, first_change#,(bytes/1024/1024) fsize
from    v\$standby_log l, v\$logfile f
where f.group# = l.group#
$AND_WHERE order by 1
/
EOF
   if [ "$S_USER" = "SYS" ];then
    sqlplus -s "$CONNECT_STRING" <<EOF 
select
  le.leseq  log_sequence#, substr(to_char(100 * cp.cpodr_bno / le.lesiz, '999.00'), 2) || '%'  used
from
  sys.x\$kcccp  cp,
  sys.x\$kccle  le
where
  le.inst_id = userenv('Instance') and
  cp.inst_id = userenv('Instance') and
  le.leseq = cp.cpodr_seq
  and le.lesiz <> 0 and cp.CPODR_SEQ >0
/
EOF
   fi
echo
fi
