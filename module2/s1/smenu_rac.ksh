#!/bin/ksh 
# 

SBINS=$SBIN/scripts
TMP=$SBIN/tmp
ROWNUM=30

function help {

  cat <<EOF
  
       rac  -i            : list instances status
       rac  -gc           : show average cr block receive time since the last startup
       rac  -de <nn>      : Give all the rac system events delta for <nn> seconds
       rac  -buf          : Cache fusion efficiency
       rac  -t            : Show interconnect transfer stats
       
       rac  -h           : this help
EOF
   exit
}
if [ -z "$1" ];then
   help
fi
ROWNUM=15
while [ -n "$1" ]
do
  case "$1" in
     -i ) CHOICE=INST_LIST ;;
    -gc ) CHOICE=MONITOR_GC ;;
    -de ) CHOICE=DE ; SEC=$2 ; shift ;;
   -buf ) CHOICE=BUF ;;
     -t ) CHOICE=TRF_STAT ;;
   -rn  ) ROWNUM=$2 ; shift ;;
      * ) help ;;
  esac
  shift
done

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get the password of $S_USER"
   exit 0
fi


if [ "$CHOICE" = "TRF_STAT" ];then
SQL=" 
set head off lines 80 feed off verify off pause off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Interconnect      -  List trasfer statistics'
        from sys.dual
/

col max_snap new_value max_snap noprint
select max(snap_id) - $ROWNUM max_snap from sys.wrm\$_snapshot;
col snap_id head 'Snap|Id' for 99999 justify l
col instance_number head 'Inst|Id' justify l for 9999
col CR_BLOCK head 'CR block trf not|affected by remote|processing delays' justify l
col cr_busy head 'Current block|trf affected by|remote contention' justify l
col CR_CONGESTED head 'CR block trf|affected by|remote sys load' justify l
col CURRENT_BLOCK head 'Curr blk trf not|affected by remote|proc. delays' justify l
col CURRENT_BUSY head 'Curr blk trf|affected by|remote content'  justify l
col CURRENT_CONGESTED head 'Curr block trf|affected by|remote system load' justify l
col snap_begin format a21 head 'Date'

set feed off verify off pause off  head on lines 190 pages 66
select a.snap_id, a.instance_number, to_char(BEGIN_INTERVAL_TIME,' dd Mon YYYY HH24:mi:ss')    snap_begin,
  sum(abs(cr_block)) cr_block, sum(abs(cr_busy))cr_busy,
  sum(abs(CR_CONGESTED)) CR_CONGESTED, sum(abs(CURRENT_BLOCK))CURRENT_BLOCK,
  sum(abs(CURRENT_BUSY)) CURRENT_BUSY, sum(abs(CURRENT_CONGESTED))CURRENT_CONGESTED
from   (select   snap_id,
                 instance_number,
                 round ((cr_block - lag (cr_block, 1) over
                   (order by instance_number, snap_id)) / 1024 / 1024) cr_block,
                 round ((cr_busy - lag (cr_busy, 1) over
                   (order by instance_number, snap_id)) / 1024 / 1024) cr_busy,
                 round ((CR_CONGESTED - lag (CR_CONGESTED, 1) over
                   (order by instance_number, snap_id)) / 1024 / 1024) CR_CONGESTED,
                 round ((CURRENT_BLOCK - lag (CURRENT_BLOCK, 1) over
                   (order by instance_number, snap_id)) / 1024 / 1024) CURRENT_BLOCK,
                 round ((CURRENT_BUSY - lag (CURRENT_BUSY, 1) over
                   (order by instance_number, snap_id)) / 1024 / 1024) CURRENT_BUSY,
                 round ((CURRENT_CONGESTED - lag (CURRENT_CONGESTED, 1) over
                   (order by instance_number, snap_id)) / 1024 / 1024) CURRENT_CONGESTED
        from     DBA_HIST_INST_CACHE_TRANSFER
        where
                 snap_id > &max_snap
                 ) a,
                 sys.wrm\$_snapshot b
where a.snap_id = b.snap_id 
  and a.instance_number = b.instance_number
group by a.snap_id, a.instance_number, to_char(BEGIN_INTERVAL_TIME,' dd Mon YYYY HH24:mi:ss')
order by snap_begin desc
/
"
elif [ "$CHOICE" = "BUF" ];then
# a script from Christo Kutrovsky at http://www.pythian.com/blogs/282/oracle-rac-cache-fusion-efficiency-a-buffer-cache-analysis-for-rac.htm
# not bad effort
SQL="set lines 190 pagesize 66
col object_name format a45
col d1 head 'd%' format 999.99
col mbyte format 9999.9
col dirty1 format 99999 head 'Dirty|Blocks'
col assm format 9999
col sha1 head 'sha%'
col p1 head '% blk|over|total' format 990.9
col cfe2 format 999.9 head 'Cache|fusion|Eff %'
col type format a10
col owner format a14
col pi format 999.0
col cr1 format 99999 head 'blck|curr| mode' justify c
col cr_sha format 999999 head 'blck |curr|mode on|both node' justify c
prompt D%   : percent of the cache (for this object) that needs to be flushed to disk. Empty if under 1% - I added this for a clearer report
prompt SHA% : percent shared for the object
prompt SHA  : number of blocks that are cached (shared) on both nodes
prompt ASSM : number of blocks cached (for the object) that are used to manage intra-segment object space. Basically, space management .overhead..
prompt PI   : number of blocks that are representing a 'past image'. Blocks that were dirty on the current node,
prompt        and were requested in exclusive mode (for modifications) on the another node.

select *
from   (select *
   from   (select distinct o.owner ||'.'||
               decode(SUBOBJECT_NAME,null, o.object_name, o.object_name||'.'||SUBOBJECT_NAME) object_name,
               case o.object_type
                  when 'INDEX SUBPARTITION' then 'idx subp'
                  when 'INDEX PARTITION' then 'idx part'
                  when 'TABLE PARTITION'    then 'tbl part'
                  when 'TABLE SUBPARTITION'    then 'tbl subp'
               else o.object_type
               end as type,
          round(case
                   when sum(d_cnt) / sum(tot) * 100 >= 1 then sum(d_cnt) / sum(tot) * 100
               end, 2) as d1,
          sum(d_cnt) as dirty1, sum(tot) tot_blk, -- round(sum(tot) * p.bs / 1024, 1) as mbytes,
          round(sum(cur_sha) * p.bs / 1024, 1) as sha,
          round(sum(cur_sha) / sum(tot) * 100, 1) as sha1, round(sum(r) * 100, 1) as p1,
          round(sum(pi) * p.bs / 1024, 1) as pi, round(sum(cr) * p.bs / 1024, 1) as cr1,
          round((sum(cr_sha)) * p.bs / 1024, 1) as cr_sha,
          round((sum(assm)) * p.bs / 1024, 1) as assm,
          round((1 - sum(cur_sha) / sum(tot) * 2) * 100, 1) as cfe2
         --, sum(cur_x) as x
      from   (select to_number(decode(temp, 'Y', 9, decode(status, 'free', 0, objd))) as objd, temp,
          count(nullif(dirty, 'N')) as d_cnt, sum(pi) as pi, sum(cr) as cr, round(avg(cr), 1) as cr_i,
          sum(cr_min_inst / nullif(i, 1)) as cr_sha, sum(assm / i) as assm,
          sum(assm) - sum(assm / i) as assm_sha, sum(xcur) as cur_x,
          sum(scur / nullif(i, 1)) as cur_sha, sum(tot) as tot, sum(r) as r
         from   (select inst_id, file#, block#, temp, dirty, status, objd, class#, count(*) as tot,
             decode(status, 'cr', count(*)) as cr,
             case
              when status in ('scur') then
               count(*)
            end as sha1, decode(status, 'pi', count(*)) as pi,
             count(distinct inst_id) over(partition by class#, file#, block#) as i,
             sum(decode(status, 'cr', count(*))) over(partition by inst_id, file#, block#) as cr_min_inst,
             decode(status, 'xcur', count(*)) as xcur, decode(status, 'scur', count(*)) as scur,
             case
              when class# in (8, 9, 10) then
               count(*)
            end as assm, ratio_to_report(count(*)) over() as r
          from   gv\$bh
          group  by inst_id, file#, block#, status, temp, dirty, objd, class#)
         group  by decode(status, 'free', 0, objd), temp) h,
       (select owner, object_name, subobject_name, object_id, data_object_id, object_type,
          row_number() over(partition by data_object_id order by object_type) rn, 'N' as temp
         from   dba_objects
         where  data_object_id > 0
         union all
         select ' ', '<<<FREE BLOCKS>>>', null, null, 0, null, 1, 'N'
         from   dual
         union all
         select ' ', '<<<ROLLBACK>>>', null, /*to_char(rownum)*/ null, 4294967296 - rownum, '', 1, 'N'
         from   dual
         connect by dummy = dummy
           and  rownum < 100
         union all
         select ' ', '<<<TEMP SEGMENT>>>', null, null, 9, null, 1, 'Y' as temp
         from   dual) o,
       (select value / 1024 as bs
         from   v\$parameter
         where  name = 'db_block_size') p
      where  o.data_object_id = h.objd
      and  o.rn = 1
      and  o.temp = h.temp
      --and o.owner not in ('SYS','SYSTEM')
      group  by p.bs, rollup((o.owner, o.object_name, o.object_type), (SUBOBJECT_NAME)))
   order  by tot_blk desc)
where  rownum <= $ROWNUM
/
"
elif [ "$ACTION" = "BLK_TYPE" ];then
SQL="select
  count(case when o.object_type= 'INDEX' then 1 end) index_blocks,
  count(case when o.object_type= 'INDEX PARTITION' then 1 end) idx_part_blk,
  count(case when o.object_type= 'TABLE' then 1 end) table_blocks,
  count(case when o.object_type= 'TABLE PARTITION' then 1 end) tbl_part_blcks,
  count(case when o.object_type != 'TABLE' and o.object_type != 'INDEX'  and
                  o.object_type != 'TABLE PARTITION' and  o.object_type != 'INDEX PARTITION' then 1 end) others_blocks
from   dba_objects o, v\$bh bh
where  o.data_object_id = bh.objd;"

elif [ "$CHOICE" = "DE" ];then
$SBIN/module2/s6/smenu_sys_stats.ksh -d $SEC -p gc
elif [ "$CHOICE" = "MONITOR_GC" ];then
SQL="
select b1.inst_id, b2.value gcbr, b1.value gcbrt ,
     ((b1.value / b2.value) * 10) acbrt
from gv\$sysstat b1, gv\$sysstat b2
where b1.name = 'gc cr block receive time' and
      b2.name = 'gc cr blocks received' and b1.inst_id = b2.inst_id
/
"
#-- +----------------------------------------------------------------------------+
#-- |         Jeffrey M. Hunter  : jhunter@idevelopment.info                     |
#-- | PURPOSE  : Provide a summary report of all configured instances for the    |
#-- |            current clustered database.                                     |
#-- +----------------------------------------------------------------------------+

elif [ "$CHOICE" = "INST_LIST" ];then
SQL="
SET LINESIZE  145
SET PAGESIZE  9999
SET VERIFY    off

COLUMN instance_name          FORMAT a13         HEAD 'Instance|Name / Number'
COLUMN thread#                FORMAT 99999999    HEAD 'Thread #'
COLUMN host_name              FORMAT a13         HEAD 'Host|Name'
COLUMN status                 FORMAT a6          HEAD 'Status'
COLUMN startup_time           FORMAT a20         HEAD 'Startup|Time'
COLUMN database_status        FORMAT a8          HEAD 'Database|Status'
COLUMN archiver               FORMAT a8          HEAD 'Archiver'
COLUMN logins                 FORMAT a10         HEAD 'Logins?'
COLUMN shutdown_pending       FORMAT a8          HEAD 'Shutdown|Pending?'
COLUMN active_state           FORMAT a6          HEAD 'Active|State'
COLUMN version                                   HEAD 'Version'

SELECT
    instance_name || ' (' || instance_number || ')' instance_name
  , thread# , host_name , status , TO_CHAR(startup_time, 'DD-MON-YYYY HH:MI:SS') startup_time
  , database_status , archiver , logins , shutdown_pending , active_state , version
FROM gv\$instance ORDER BY instance_number;
"
fi

sqlplus -s "$CONNECT_STRING"   <<EOF
col gcbrt head "gc cr blocks|Receive Time"
col gcbr head "gcs cr blocks received"
col acbrt format 9990.99 head "avg cr block| receive time (ms)"
$SQL
EOF

