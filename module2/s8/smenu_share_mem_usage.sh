#!/bin/ksh
#---------------------------------------------------------------------------------
# Shared Memory Usage Report
# Author :
# Date   : 27-Jul-2000
#          02-Jun-2006  Added overview reserved pool from Ixora
#          07-Jun-2006  Added free list in reserved pool from Ixora
#          20-Jun-2006  Added all advices
#                       added pga stats
#                       updated option -s to add link toward v$sga_dynamic_component
#          22-Jun-2006  added lru option over x$ksmlru
#---------------------------------------------------------------------------------

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
ACTION=SGA
function help
{
cat <<EOF

    sga            # list shared pool information
    sga -ab        # Show advice for db buffers
    sga -as        # Show advice for shared_pool
    sga -ap        # Show advice for pga target
    sga -c         # Show Current size of memory Dynamic component (11g)
    sga -f         # Shared pool freeable  overview
    sga -g         # Show granule type distribution
    sga -his       # show sga history
    sga -inf       # sga info from v\$sgainfo
    sga -k         # Show free chunks detail in shared pool
    sga -ko        # Show free chunks overview in shared pool
    sga -l         # Show free list summary in shared pool
    sga -lru       # Show least recently used shared pool chunks flushed from shared pool
    sga -lpar      # list all parameter related to memory size
    sga -nk        # List NO:KGL ACCESS
    sga -o         # Shared pool overview
    sga -p         # Show pga stats
    sga -r         # Shared pool reserved overview
    sga -s         # Shared pool overview summary
    sga -res       # Displays information about the last 800 completed SGA resize operations
    sga -u         # Display session private memory (aka:  Uga/pga distribution)
    sga -top       # Top pga allocation
        -rn <n>>     Limit to last ops resize

Additional options :
       -h          # this help

EOF

exit
}
ROWNUM=30
while [ -n "$1" ]
do
  case "$1" in
    -ab ) ACTION=ADVB;  ;;
    -as ) ACTION=ADVS;  ;;
    -ap ) ACTION=ADVP;  ;;
     -c ) ACTION=DYN_MEM ;;
     -f ) ACTION=SHP;  ;;
   -inf ) ACTION=INF;;
     -l ) ACTION=FREE_LIST;  ;;
  -lpar ) ACTION=LIST_LPAR;;
   -lru ) ACTION=LRU; ;;
   -his ) ACTION=SGA_HIS;;
     -k ) ACTION=FREE_CHUNKS;  ;;
     -g ) ACTION=GRANULE ;  ;;
    -ko ) ACTION=FREE_CHUNKS_SUMMARY;  ;;
    -nk ) ACTION=NOKGH;  ;;
     -o ) ACTION=OVERVIEW;  ;;
     -p ) ACTION=PGA;  ;;
     -r ) ACTION=RESERVED ;;
   -res ) ACTION=RESIZE_800 ;;
    -rn ) ROWNUM=$2; shift ;;
     -s ) ACTION=SUMMARY;;
     -u ) ACTION=UGA ;;
   -top ) ACTION=TOP_PGA ;;
     -v ) set -x ;;
     -h ) help ;;
  esac
  shift
done
#
. $SBIN/scripts/passwd.env
. ${GET_PASSWD}
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# .....................................................................
# a script from Tanel poder
# http://blog.tanelpoder.com/files/scripts/wrkasum.sql
# .....................................................................
if [ "$ACTION" = "TOP_PGA" ];then
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Top workaread allocations' nline from sys.dual
/
set lines 190 pages 66 
set head on
SELECT
     operation_type
   , policy
   , ROUND(SUM(actual_mem_used)/1048576) actual_pga_mb
   , ROUND(SUM(work_area_size)/1048576)  allowed_pga_mb
   , ROUND(SUM(tempseg_size)/1048576)    temp_mb
   , MAX(number_passes)                  num_passes
   , COUNT(DISTINCT qcinst_id||','||qcsid)   num_qc
   , COUNT(DISTINCT inst_id||','||sid)   num_sessions
 FROM
     gv\$sql_workarea_active
 GROUP BY 
     operation_type
   , policy
 ORDER BY 
     actual_pga_mb DESC NULLS LAST
/

PROMPT Top SQL_ID by TEMP usage...

 SELECT
     sql_id
   , policy
   , ROUND(SUM(actual_mem_used)/1048576) actual_pga_mb
   , ROUND(SUM(work_area_size)/1048576)  allowed_pga_mb
   , ROUND(SUM(tempseg_size)/1048576)    temp_mb
   , MAX(number_passes)                  num_passes
   , COUNT(DISTINCT qcinst_id||','||qcsid)   num_qc
   , COUNT(DISTINCT inst_id||','||sid)   num_sessions
 FROM
     gv\$sql_workarea_active
 GROUP BY 
     sql_id
   , policy
 ORDER BY 
     temp_mb DESC NULLS LAST
/
EOF
# .....................................................................
elif [ "$ACTION" = "UGA" ];then
sqlplus -s "$CONNECT_STRING" <<EOF
set lines 157 pagesize 66
col fsize head 'Size(m)' for 999990.9
Prompt show session private memory distributation
select 
  n.name , sum(value )/1024/1024 fsize
from 
    v\$sesstat s , v\$statname n 
where 
      s.statistic# = n.statistic# 
  and n.name like '%ga memory'
group by n.name
/
EOF
# .....................................................................
elif [ "$ACTION" = "LIST_LPAR" ];then
sqlplus -s "$CONNECT_STRING" <<EOF
col name for a46
col value for a30
set lines 157 pagesize 66
select name, value from v\$parameter where name like '%target'
union
select name, value from v\$parameter where name like '%size'
order by 1 
/
EOF
# .....................................................................
elif [ "$ACTION" = "DYN_MEM" ];then
sqlplus -s "$CONNECT_STRING" <<EOF
set lines 157 pagesize 66
col component for a30 head 'Component'
col LAST_TIME  head 'Last Operation' 
col  curr head 'Current|size(m)'
select COMPONENT,CURRENT_SIZE/1048576 curr , MIN_SIZE/1048576 min_size,MAX_SIZE/1048576 max_size,
       USER_SPECIFIED_SIZE/1048576 user_spec, LAST_OPER_TYPE oper_type, LAST_OPER_MODE last_oper,
       to_char(LAST_OPER_TIME, 'YYYY-MM-DD HH24:MI:SS') last_time , GRANULE_SIZE
from v\$MEMORY_DYNAMIC_COMPONENTS  where COMPONENT = 'SGA Target'
/
comput sum of Curr on report
break on report
select COMPONENT,CURRENT_SIZE/1048576 Curr, MIN_SIZE/1048576 min_size,MAX_SIZE/1048576 max_size,
       USER_SPECIFIED_SIZE/1048576 user_spec, LAST_OPER_TYPE oper_type, LAST_OPER_MODE last_oper,
       to_char(LAST_OPER_TIME, 'YYYY-MM-DD HH24:MI:SS') last_time , GRANULE_SIZE
from v\$MEMORY_DYNAMIC_COMPONENTS where COMPONENT  <>  'SGA Target' 
;
EOF
# .....................................................................
elif [ "$ACTION" = "NOKGH" ];then
# Based on work of Tanel Poder, specially the identication of the exact usage of b.ksmchptr
# makes this query possible.
sqlplus -s "$CONNECT_STRING" <<EOF
set lines 190 pagesize 66
col owner for a26
col object_name for a30
col DBARFIL for 9999 head 'File|id' justify l
col ba head 'Memory Address'
select
   dbarfil, dbablk, obj, ba, state , o.owner, o.object_name, o.object_type
  from
  x\$bh a,
  ( SELECT distinct ksmchptr FROM x\$ksmsp WHERE ksmchcom = 'KGH: NO ACCESS') b ,
  dba_objects o
where
  to_number(rawtohex(ba),'XXXXXXXXXXXXXXXX')
        BETWEEN
            to_number(b.ksmchptr,'XXXXXXXXXXXXXXXX')
        AND to_number(b.ksmchptr,'XXXXXXXXXXXXXXXX') + 32800 - 1
  and a.obj=o.data_object_id(+)
/
EOF
# .....................................................................
elif [ "$ACTION" = "INF" ];then
sqlplus -s "$CONNECT_STRING" <<EOF
col bytes for 999,999,990.9 head 'Size(meg)' justify c
col RESIZEABLE head 'Resiz|able' justify c for a5
set pages 66
select name, round(bytes/1048576,1) bytes, RESIZEABLE from v\$sgainfo;
EOF
# .....................................................................
elif [ "$ACTION" = "SGA_HIS" ];then
# a qeury from psoug.org
sqlplus -s "$CONNECT_STRING" <<EOF
set lines 190 pagesize 66
select * from (
SELECT time, instance_number,
       MAX(DECODE(name, 'free memory',shared_pool_bytes,NULL)) free_memory,
       MAX(DECODE(name,'library cache',shared_pool_bytes,NULL)) library_cache,
       MAX(DECODE(name,'sql area',shared_pool_bytes,NULL)) sql_area
FROM (
  SELECT TO_CHAR(begin_interval_time,'YYYY_MM_DD HH24:MI') time,
  dhs.instance_number, name, bytes - LAG(bytes, 1, NULL)
  OVER (ORDER BY dhss.instance_number,name,dhss.snap_id) AS
  shared_pool_bytes
  FROM dba_hist_sgastat dhss, dba_hist_snapshot dhs
  WHERE name IN ('free memory', 'library cache', 'sql area')
  AND pool = 'shared pool'
  AND dhss.snap_id = dhs.snap_id
  AND dhss.instance_number = dhs.instance_number
  ORDER BY dhs.snap_id,name)
GROUP BY time, instance_number
order by time desc) where rownum <=$ROWNUM ;
EOF
# .....................................................................
elif [ "$ACTION" = "FREE_CHUNKS_SUMMARY" ];then

sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline , 'Report free chunks oveview (help : sga -h)' nline from sys.dual
/
set linesize 124 head on pause off pagesize 333
col sga_heap format a15 
col size format a10 
col Total for 9999990.9 head 'Total'
col Used for 9999990.9 head 'Used'
col Free for 9999990.9 head 'Free'
col ksmdsidx head 'Sub Shared pool'

select ksmdsidx, a.bytes Total, a.bytes-b.bytes Used, b.bytes Free
from 
   (select ksmdsidx, SUM(ksmsslen)/1048576 bytes FROM x\$ksmss WHERE ksmsslen > 0 group by ksmdsidx ) a,
   (select ksmchidx,sum(ksmchsiz)/1048576 bytes from x\$ksmsp where KSMCHCOM = 'free memory' group by ksmchidx ) b
where a.ksmdsidx=b.ksmchidx
/
select KSMCHIDX "SubPool", 'sga heap('||KSMCHIDX||',0)'sga_heap,ksmchcom ChunkComment, 
      decode(round(ksmchsiz/1000),0,'0-1K', 1,'1-2K', 2,'2-3K',3,'3-4K', 
                                  4,'4-5K',5,'5-6k',6,'6-7k',7,'7-8k',8, 
                                  '8-9k', 9,'9-10k','> 10K') "size", 
      count(*),ksmchcls Status, sum(ksmchsiz) Bytes 
from x\$ksmsp 
where KSMCHCOM = 'free memory' 
group by ksmchidx, ksmchcls, 'sga heap('||KSMCHIDX||',0)',ksmchcom, ksmchcls,decode(round(ksmchsiz/1000),0,'0-1K', 
                             1,'1-2K', 2,'2-3K', 3,'3-4K',4,'4-5K',5,'5-6k',6, '6-7k',7,'7-8k',8,'8-9k', 9,'9-10k','> 10K')
order by 4;

EOF

# .....................................................................
elif [ "$ACTION" = "LRU" ];then
  # We need to spool this action

  SPOOL=$SBIN/tmp/KMSLRU_${ORACLE_SID}_`date +%m%d%H%M%S`.log

sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on pause off embedded on verify off heading off
spool $SPOOL
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report Least recently ysed shared memory chunks and obj/session responsible for flush (help : sga -h)' nline 
from sys.dual
/
set linesize 124 pagesize 66 head on
col ksmlrcom format A20 head "Namespace|affected"
col ksmlrsiz format 99999 head "Size |requested"
col ksmlrnum format 99999 head "Num Object|Flushed out"
col ksmlrhon format A32  head "What is loaded"
col ksmlrohv format 9999999999999 head "Hash_value"
col username format a20 head "Username"
col sid format 9999 head "Sid"
select 
    ksmlrcom, ksmlrsiz, ksmlrnum, ksmlrhon, ksmlrohv,
    sid,username
from x\$ksmlru a,v\$session b where a.addr=b.saddr (+)
/ 
spool off
EOF
# .....................................................................
elif [ "$ACTION" = "ADVP" ];then
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report advice on pga_aggregate_target (help : sga -h)' nline from sys.dual
/
set linesize 124 pagesize 66 head on
-- Donald K. Burleson, no need to present him
column c1       heading 'Target(M)'
column c2       heading 'Estimated|Cache Hit %'
column c3       heading 'Estimated|Over-Alloc.'

SELECT
   ROUND(pga_target_for_estimate /(1024*1024)) c1,
   estd_pga_cache_hit_percentage               c2,
   estd_overalloc_count                        c3
FROM
   v\$pga_target_advice;
EOF
# .....................................................................
elif [ "$ACTION" = "ADVS" ];then
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report advice on Shared pool size(help : sga -h)' nline from sys.dual
/
set linesize 124 pagesize 66 head on
-- Donald K. Burleson
-- ************************************************
-- Display shared pool advice
-- ************************************************

set lines  100
set pages  999

column  c1      heading 'Pool |Size(M)'
column  c2      heading 'Size|Factor'
column  c3      heading 'Est|LC(M)  '
column  c4      heading 'Est LC|Mem. Obj.'

column  c5      heading 'Est|Time|Saved|(sec)'
column  c6      heading 'Est|Parse|Saved|Factor'
column  c7      heading 'Est|Object Hits'   format 999,999,999


SELECT
   shared_pool_size_for_estimate        c1,
   shared_pool_size_factor              c2,
   estd_lc_size                 c3,
   estd_lc_memory_objects               c4,
   estd_lc_time_saved           c5,
   estd_lc_time_saved_factor    c6,
   estd_lc_memory_object_hits   c7
FROM
   v\$shared_pool_advice;
EOF
elif [ "$ACTION" = "ADVB" ];then
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report advice on shared pool (help : sga -h)' nline from sys.dual
/
set linesize 124 pagesize 66 head on
-- Donald K. Burleson
column c1   heading 'Cache Size (m)'        format 999,999,999,999
column c2   heading 'Buffers'               format 999,999,999
column c3   heading 'Estd Phys|Read Factor' format 999.90
column c4   heading 'Estd Phys| Reads'      format 999,999,999


select
   size_for_estimate          c1,
   buffers_for_estimate       c2,
   estd_physical_read_factor  c3,
   estd_physical_reads        c4
from
   v\$db_cache_advice
where
   name = 'DEFAULT'
and
   block_size  = (SELECT value FROM V\$PARAMETER WHERE name = 'db_block_size')
and
   advice_status = 'ON';
EOF
elif [ "$ACTION" = "PGA" ];then
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on pause off embedded on verify off heading off feed off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report pga stats (help : sga -h)' nline from sys.dual
/
prompt
 
prompt fixed pga memory = (aggregate PGA target parameter )-(aggregate PGA auto target)
prompt aggregate PGA auto target : memory left over for sorts, hash joins, bitmap operations
prompt total PGA inuse: amount of PGA currently in use 
prompt total PGA used for auto workareas: urrent amount of memory being used by tunable workareas (sorts/hashes)
prompt over allocation count: number of times Oracle had to allocate more PGA memory thann PGA_AGGREGATE_TARGET

prompt
col name format A40
col value format 999999999990.9 head "Size(mb)"
set linesize 190 pagesize 66 head on
select name,value/1048576 value from v\$pgastat;
col n1 head 'PGA Currently Allocated (mb)' for 9999999990.9
col n2 head 'PGA Max ever allocated (mb)' for 9999999990.9
col var3 head 'PGA Currently  Defined (mb)' for 9999999990.9
col perc for a6 head 'Perc'
prompt
prompt If either of the two PERC is > 100 then your PGA target is or was too small
prompt
select var3,
var1 n1, to_char(round((var1/var3)*100,1))||'%'  perc,
var2 n2, to_char(round(var2/var3*100,1))||'%' perc from 
( select name n1,round(value/1024/1024,1) var1 from v\$pgastat where name in ('total PGA allocated')) a,
(select name n2,round(value/1024/1024,1) var2 from v\$pgastat where name in ('maximum PGA allocated')) b,
(select name n3 ,round(value/1024/1024,1) var3 from v\$pgastat where name in ('aggregate PGA target parameter')) c
;
prompt
EOF

# .....................................................................
elif [ "$ACTION" = "RESIZE_800" ];then
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report free chunks in shared pool sort by bucket size (help : sga -h)' nline
from sys.dual
/
col component format a24
col parameter format A20
col oper_type format A8 head "Oper|Type"
col oper_mode format A9 head "Oper|Mode"
col status format A10
col start_time format A19
col END_time format A19
col initial_size head "Initial|size" for 99999999999999
col target_size head "Target|size" for 99999999999999
col final_size head "Final|size" for 99999999999999
col rnk noprint
set linesize 167 head on pause off pagesize 333
select * from (
select component, oper_type, oper_mode,parameter, initial_size, target_size, final_size, status,
  to_char(START_TIME,'YYYY-MM-DD HH24:MI:SS') start_time,
  to_char(END_TIME,'YYYY-MM-DD HH24:MI:SS') END_time
  from v\$sga_resize_ops order by start_time desc) where rownum<=$ROWNUM
/

EOF

# .....................................................................
elif [ "$ACTION" = "FREE_CHUNKS" ];then
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report free chunks in shared pool sort by bucket size (help : sga -h)' nline
from sys.dual
/
set linesize 124 head on pause off pagesize 333
col bucket format A20
col KSMCHCLS format a10

select '0 (<140)' BUCKET, KSMCHCLS, KSMCHIDX, 10*trunc(KSMCHSIZ/10) "From",
       count(*) "Count" , max(KSMCHSIZ) "Biggest",
       trunc(avg(KSMCHSIZ)) "AvgSize", trunc(sum(KSMCHSIZ)) "Total"
    from x\$ksmsp
       where KSMCHSIZ<140 and KSMCHCLS='free'
            group by KSMCHCLS, KSMCHIDX, 10*trunc(KSMCHSIZ/10)
UNION ALL
select '1 (140-267)' BUCKET, KSMCHCLS, KSMCHIDX,20*trunc(KSMCHSIZ/20) ,
        count(*) , max(KSMCHSIZ) , trunc(avg(KSMCHSIZ)) "AvgSize", trunc(sum(KSMCHSIZ)) "Total"
    from x\$ksmsp
       where KSMCHSIZ between 140 and 267 and KSMCHCLS='free'
            group by KSMCHCLS, KSMCHIDX, 20*trunc(KSMCHSIZ/20)
UNION ALL
       select '2 (268-523)' BUCKET, KSMCHCLS, KSMCHIDX, 50*trunc(KSMCHSIZ/50) ,
       count(*) , max(KSMCHSIZ) , trunc(avg(KSMCHSIZ)) "AvgSize", trunc(sum(KSMCHSIZ)) "Total"
    from x\$ksmsp
       where KSMCHSIZ between 268 and 523 and KSMCHCLS='free'
            group by KSMCHCLS, KSMCHIDX, 50*trunc(KSMCHSIZ/50)
UNION ALL
select '3-5 (524-4107)' BUCKET, KSMCHCLS, KSMCHIDX, 500*trunc(KSMCHSIZ/500) ,
       count(*) , max(KSMCHSIZ) , trunc(avg(KSMCHSIZ)) "AvgSize", trunc(sum(KSMCHSIZ)) "Total"
    from x\$ksmsp
        where KSMCHSIZ between 524 and 4107 and KSMCHCLS='free'
            group by KSMCHCLS, KSMCHIDX, 500*trunc(KSMCHSIZ/500)
UNION ALL
select '6+ (4108+)' BUCKET, KSMCHCLS, KSMCHIDX, 1000*trunc(KSMCHSIZ/1000) ,
       count(*) , max(KSMCHSIZ) , trunc(avg(KSMCHSIZ)) "AvgSize", trunc(sum(KSMCHSIZ)) "Total"
    from x\$ksmsp
        where KSMCHSIZ >= 4108 and KSMCHCLS='free'
group by KSMCHCLS, KSMCHIDX, 1000*trunc(KSMCHSIZ/1000);

EOF
# .....................................................................
elif [ "$ACTION" = "GRANULE" ];then
 # bpa: grantype naming is taken from x$kmgsct.component (sga_resize)
 # grantype=0 name is taken from  "alter session set events 'immediate trace name DUMP_ALL_COMP_GRANULE_ADDRS level 1'; "
 # can view it in x$ksmge with status = INVALID
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report granule type distribution (help : sga -h)' nline
from sys.dual
/
set head on pages 66 lines 120
col grantype head 'Granule Type'
select grantype id,
  case grantype
       when 0 then 'System memory'
       when 1 then 'Shared pool'
       when 2 then 'Large pool'
       when 3 then 'Java pool'
       when 4 then 'Streams pool'
       when 6 then 'Default Buffer cache'
       when 7 then 'KEEP Buffer cache'
       when 8 then 'RECYCLE Buffer cache'
       when 9 then 'DEFAULT 2K Buffer cache'
       when 10 then 'DEFAULT 4K Buffer cache'
       when 11 then 'DEFAULT 8K Buffer cache'
       when 12 then 'DEFAULT 16K Buffer cache'
       when 13 then 'DEFAULT 32K Buffer cache'
       when 14 then 'ASM Buffer Cache'
  else 'Other'
  end grantype,
  count(*) GRANULES, sum(gransize)/1048576 MB 
from x\$ksmge group by grantype order by 1;
EOF
# .....................................................................
elif [ "$ACTION" = "SHP" ];then
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report Shared Memory Usage Report (help : sga -h)' nline
from sys.dual
/
comp sum of recreatable freeable total on report
break on report
col contents format a30
set linesize 124 head on pause off pagesize 333
select
  ksmchcom  contents,
  count(*)  chunks,
  sum(decode(ksmchcls, 'recr', ksmchsiz))  recreatable,
  sum(decode(ksmchcls, 'freeabl', ksmchsiz))  freeable,
  sum(ksmchsiz)  total
from sys.x\$ksmsp where inst_id = userenv('Instance') and ksmchcls not like 'R%'
group by ksmchcom
/
EOF
# .....................................................................
#   this is the default action of 'sga'
# .....................................................................
elif [ "$ACTION" = "SGA" ];then

sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 90  termout on pause off  embedded on  verify off  heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER,15) || 'Report Shared Memory Usage Report (help : sga -h)' 
from sys.dual
/

set linesize 190  heading on
col object_mem for 99999990.99 head "Fixed Obj|in Memory (m)" justify c
col hidden_mem for 99999990.99 head "free mem|Part of|perm mem (m)" justify c
col shared_sql for 99999990.99 head "Shared|SQL (m)" justify c
col cursor_mem for 999999990.99 head "User Cursor|Mem (bytes)" justify c
col parameter format A40
col pool_size for 99999999990.9 head "Shared Pool |size(m)" justify c
col shared_pool_reserved_size for 99999999990.9 head "Shared Pool |reserved size(m)" justify c
col large_pool_size for 99999999990.9 head "lage Pool |size(m)" justify c
col min_alloc for A14 head "Shared Pool |reserved min |alloc size(b)" justify c
col free format  999999990.99 head "free Mem for|Allocation(m)" justify c
col reload head "Cache miss |while execution"
col exec head "Number of |Executions"
col pga format 999999.9 head "pga curr|alloc(mb)"
col sga format 999999.9 head "sga(mb)"
col sess_pga format 999999.9 head "Session|pga (mb)"
col Totused format 999999.9 head "Total Memory| used(mb)"

select * from (
select
   pool_size,
   large_pool_size,
   shared_pool_reserved_size,
   -- lpad(min_alloc,12)min_alloc,
   -- free,
   --hidden_mem,
   pga,  sga, 
   totused
from
     (SELECT  ROUND(NVL(sum(bytes)/1024/1024,0)) pool_size FROM   v\$sgastat WHERE  pool = 'shared pool') ,
     (select value/1048576 large_pool_size from v\$parameter where name='large_pool_size'),
     (select value/1048576 shared_pool_reserved_size from v\$parameter where name='shared_pool_reserved_size'),
     --(select val.KSPPSTVL min_alloc from x\$ksppi nam, x\$ksppsv val where nam.indx = val.indx and nam.ksppinm = '_shared_pool_reserved_min_alloc'),
     --(select sum(ksmsslen)/1048576 free from x\$ksmss where ksmssnam='free memory' and ksmsslen > 1 group by ksmssnam),
     -- (
     --   select fa-fb hidden_mem from
     --      (select sum(ksmsslen)/1048576 fa from x\$ksmss where ksmssnam='free memory' and ksmsslen > 1 group by ksmssnam),
     --      (select sum(ksmchsiz)/1048576 fb from sys.x\$ksmsp where ksmchcom = 'free memory'
     --             and inst_id = userenv('Instance') and ksmchcls not like 'R%' group by ksmchcom)
     --  ), --(select sum(value)/1048576 pga from v\$sesstat s, v\$statname n where n.STATISTIC# = s.STATISTIC# and name = 'session pga memory'),
     -- (select sum(value/1048576) sess_pga from v\$sesstat s, v\$statname n where n.STATISTIC# = s.STATISTIC# and n.name = 'session pga memory') sess_sga,
     (select round(value/1024/1024,1) pga from v\$pgastat where name in ('total PGA allocated')),
     (select sum(bytes)/1048576 sga from v\$sgastat) ,
     (select sum(bytes)/1048576 totused from (
             select bytes from v\$sgastat
             union all
             select value from v\$pgastat where name in ('total PGA allocated')
--             union all
--             select value from v\$sesstat s, v\$statname n where n.STATISTIC# = s.STATISTIC# and n.name = 'session pga memory'
             ) 
     )
)where rownum =1
/
prompt
prompt
prompt SHARED_POOL:
prompt ============
Prompt Inadequate size : if request failure > 0 and last_failure_size < min reserved alloc
prompt ................
prompt
Prompt fragmented      : if request failure > 0 and last_failure_size > min reserved alloc
prompt ................  Consider increasing 'shared_pool_reserved_size'
prompt
col nasp head 'Shared pool|unavailable(mb)|(KGH: NO ACCESS)' for 99990.99
select * from (
select nasp,REQUEST_FAILURES, last_failure_size, exec, reload from
    ( select REQUEST_FAILURES, last_failure_size,
             -- (select val.KSPPSTVL min_alloc from x\$ksppi nam, x\$ksppsv val
              --where nam.indx = val.indx and nam.ksppinm = '_shared_pool_reserved_min_alloc') min_alloc,
              (select sum(bytes)/1048576 MB from v\$sgastat where pool = 'shared pool' and name = 'KGH: NO ACCESS') nasp
      from V\$SHARED_POOL_RESERVED) a,
    ( SELECT SUM(PINS) "EXEC", SUM(RELOADS) reload FROM V\$LIBRARYCACHE ) b )
where rownum = 1
/
EOF

# .....................................................................
elif [ "$ACTION" = "RESERVED" ];then

sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on pause off embedded on verify off heading off


select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report Shared Memory Usage Report (help : sga -h)' nline
from sys.dual
/

Prompt
prompt Overview of chunks distribution in the reserved pool
prompt
set linesize 124 pagesize 33 head on
select
  ksmchcom  contents,
  count(*)  chunks,
  sum(decode(ksmchcls, 'R-recr', ksmchsiz))  recreatable,
  sum(decode(ksmchcls, 'R-freea', ksmchsiz))  freeable,
  sum(ksmchsiz)  total
from
  sys.x\$ksmspr
where
  inst_id = userenv('Instance')
group by
  ksmchcom
/
EOF
# .....................................................................
elif [ "$ACTION" = "FREE_LIST" ];then
     sqlplus -s "$CONNECT_STRING" <<EOF

clear screen

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 heading off pause off termout on embedded off verify off
spool $FOUT

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Shared Pool memory     -  Free List ' nline
from sys.dual
/
set head on
select
  decode(sign(ksmchsiz - 80), -1, 0, trunc(1/log(ksmchsiz - 15, 2)) - 5)
    bucket,
  sum(ksmchsiz)  "Free space",
  count(*)  "Free chunks",
  trunc(avg(ksmchsiz))  "Average Size",
  max(ksmchsiz)  "Biggest"
from
  sys.x\$ksmsp
where
  inst_id = userenv('Instance') and
  ksmchcls = 'free'
group by
  decode(sign(ksmchsiz - 80), -1, 0, trunc(1/log(ksmchsiz - 15, 2)) - 5)
/
prompt
exit

EOF

# .....................................................................
elif [ "$ACTION" = "SUMMARY" ];then

sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 170 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'Show SGA free memory (in mb)' nline
from sys.dual
/

set head on

COL tot_sga           FORMAT  999,999  justify c HEADING 'Size(mb)'
COL free_per          FORMAT  999        HEADING 'Free |Perc '
COL FREE              FORMAT  999,999   justify c HEADING 'Free'
COL pool              FORMAT  a20   justify c HEADING 'Pool'

select
   decode(pool,NULL,a.name,pool) pool, round(sum(a.bytes)/1048576,2) tot_sga,
   round(sum(decode(a.name,'free memory',a.bytes,0))/1048576,2) free,
   sum(decode(a.name,'free memory',a.bytes,0))/1048576/(sum(a.bytes)/1048576)*100 free_per,
   current_size/1048576 current_size,
   min_size/1048576 min_size,
   max_size/1048576 max_size
from
   v\$sgastat a,
   (select decode(component,'buffer cache','buffer_cache', component)component,
           current_size,min_size,max_size from v\$sga_dynamic_components
   )  b
where
   decode(pool,NULL,a.name,pool) =b.component(+)
group by
    decode(pool,NULL,name,pool), current_size/1048576 , min_size/1048576, max_size/1048576
order by 2 desc
/
EOF

# .....................................................................
elif [ "$ACTION" = "OVERVIEW" ];then
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 170 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'Show SGA free memory (in mb)' nline
from sys.dual
/

set head on

COL bytes           FORMAT  999,999,999,999
COL name              FORMAT  A30    HEADING 'Name'
COL pool              FORMAT  A12    HEADING 'Pool'
break on pool
select  decode(pool,NULL,name, pool) pool,
        decode(pool,NULL,NULL, name) name, bytes
from v\$sgastat order by pool, bytes desc
/
EOF
fi

