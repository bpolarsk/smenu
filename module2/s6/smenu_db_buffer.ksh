#!/bin/ksh
# set -x
SBINS=$SBIN/scripts
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
ROWNUM=50
BUF_COUNT=10;
RAC_ORDER=tot_blk
function help
{
cat <<EOF

   All about buffers:

    buf -do <ID>                  : Show presence size in DB_CACHE for a given DATA_OBJECT_ID (use 'obj -do' )
    buf -lo [-t <TABLE> -u [OWNER]] -rn <nn> : List object repartitions in DB_CACHE sorted by biggest first
    buf -io                       : Report Buffer pool IO distribution
    buf -l   <nn>                 : List object presence in buffer pools (default 200)
    buf -d <nn>                   : List block duplicated in buffer (default 5)
    buf -drac <nn>                : Same as -d but add distribution for RAC
    buf -f                        : Report filesystem log block size
    buf -i                        : Some info from x\$kvit and events, stats linked to DBWR
    buf -cpt                      : List global count pert type of block in buffer (INDEX/TABLE)
    buf -pin <nn>                 : List tables that could be pined in mem
    buf -s                        : Average number of buffers to scan at the end of the LRU, to find a free buffer
    buf -r                        : buffer structural info
    buf -g                        : Report distribution in DB buffer per type : header,data, rollback
    buf -bu                        : Displays info on DB buffer usage
    buf -test                     : Find largest actual multiblock read size (work only with smenu local)
    buf -w                        : Report buffer busy wait distributions
    buf -rac                      : RAC : show cache fusion efficiency
    buf -bw                       : show pool waits
        
         -rn      : Limit display to first <ROWNUM>
         -v       : Verbose
EOF
exit
}
if [ -z "$1" ];then
     help
fi

while [ -n "$1" ]
do
  case "$1" in
  -bw ) ACTION=BW ; TITTLE="show pool waits" ;;
  -bu ) TTITLE="Displays info on DB buffer type and status" ; ACTION=TYPE2 ; S_USER=SYS;;
 -cpt ) TTITLE="List global count pert type of block in buffer (INDEX/TABLE)" ; ACTION=BLK_TYPE ; S_USER=SYS;;
   -d ) if [ -n "$2" -a ! "$2" = "-v" ] ;then
             NBR_BUFFER=$2 ; shift
        fi
        NBR_BUFFER=${NBR_BUFFER:-5}
        TTITLE="Report block duplicated more than $NBR_BUFFER in buffer"
        ACTION="DUP";;
-drac ) if [ -n "$2" -a ! "$2" = "-v" ] ;then 
               NBR_BUFFER=$2 ; shift
        fi 
        NBR_BUFFER=${NBR_BUFFER:-5}
        TTITLE="Report block duplicated more than $NBR_BUFFER in buffer"
        ACTION="DUPRAC";;
   -f ) TTITLE="Report filesystem log block size" ; ACTION=FILESYSTEM ; S_USER=SYS;;
   -g ) TTITLE="Report distribution in DB buffer per type" ; ACTION=TYPE ; S_USER=SYS;;
   -i ) TTITLE="Some info from x\$kvit and events, stats linked to DBWR" ; ACTION=INFO ; S_USER=SYS;;
  -io ) TTITLE="Buffer IO distribution" ; ACTION=BUFF_IO ;;
   -l ) if [ -n "$2" ] ;then
             NBR_BUFFER=$2 ; shift
        fi
        NBR_BUFFER=${NBR_BUFFER:-200}
        TTITLE="Report object presence in buffer is more than $NBR_BUFFER in pool" ; S_USER=SYS ; ACTION="PRES";;
  -do ) ACTION=LSIZ ; DATA_OBJ_ID=$2 ; shift ; TTITLE="List size of object ID : $DATA_OBJ_ID " ;;
  -lo ) ACTION=LSIZ_ALL ;  TTITLE="List TOP <n> buffer occupancy  by data_object ID " ;;
 -pin ) TTITLE="List tables that could be pined in mem" ; NBR_BUFFER=${NBR_BUFFER:-80} ; ACTION=PIN;;
   -r ) TTITLE="buffer structural info" ; ACTION=INFO;;
 -rac )TITTLE="RAC cache fusion efficiency" ; ACTION=RAC_EFF;;
  -rn ) ROWNUM=$2 ;shift ;;
   -s ) TTITLE="Average number of buffers to scan at the end of the LRU, to find a free buffer" ; ACTION="LRU";;
   -t ) ftable=$2 ; shift ;;
   -u ) fowner=$2 ; shift ;;
-test ) TTITLE="Find largest actual multiblock read size" ; ACTION=TEST;;
   -w ) TTITLE="Report buffer busy wait distributions" ; ACTION="BUSY";;
   -v ) VERBOSE=TRUE;;
    * ) help ;;
  esac
  shift
done

. $SBIN/scripts/passwd.env
. ${GET_PASSWD}

if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

if [ -n "$ftable" -a -z "$fowner" ];then
   ftable=`echo $ftable | awk '{print toupper($1)}'`
   var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select  trim(to_char(count(*))) cpt from dba_tables where table_name='$ftable' ;
EOF`
   ret=`echo "$var" | tr -d '\r' | awk '{print $1}'`
   if [ -z "$ret" ];then
      echo "Currently, there is no entry in dba_tables for $ftable"
      exit
   elif [ "$ret" -eq "0" ];then
     echo "Currently, there is no entry in dba_tables for $ftable"
     exit
  elif [ "$ret" -eq "1" ];then
   var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select owner from dba_tables where  TABLE_NAME='$ftable' and rownum=1 ;
EOF`
     fowner=`echo "$var" | tr -d '\r' | awk '{print $1}'`
     FOWNER="owner = '$fowner' "
     AND_FOWNER=" and  $FOWNER"
     A_FOWNER=" a.owner = '$fowner'"
  elif [ "$ret" -gt "0"  ];then
       if [ -z "$fowner" ];then
         echo " there are many tables for $ftable:"
         echo " Use : "
         echo
         echo " tbl -t $ftable -u <user> "
         echo
      sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 66 head on
select owner, table_name , 'table' from dba_tables where table_name='$ftable' ;
EOF
         exit
       fi
   fi
fi


#..................................................
#    List Object size in buffer cache
#..................................................
if [ "$ACTION" = "LSIZ_ALL" ];then
echo "+............................................................................................................
FREE: Not currently in use     XCUR: Exclusive                 SCUR: Shared current    CR: Consistent read
READ: Being read from disk     MREC: In media recovery mode    IREC: In instance recovery mode
+............................................................................................................"

  if [ -n "$ftable" ];then

     ftable=`echo $ftable | awk '{print toupper($1)}'`
     fowner=`echo $fowner | awk '{print toupper($1)}'`

     AND_WITH_B="
v as (
select owner, object_name table_name, OBJECT_ID , data_object_id
      from dba_objects 
      where 
            OBJECT_TYPE = 'TABLE' 
        and owner = '$fowner' 
        and OBJECT_NAME ='$ftable'
)
, vp as ( select o.owner, o.SUBOBJECT_NAME, o.data_object_id
           from  v , dba_objects o
                where
                    o.owner = v.owner
                and o.object_name = v.table_name
                and o.object_type in ( 'TABLE PARTITION' , 'TABLE SUBPARTITION')
)
, vi as ( select i.owner , index_name name ,   o.data_object_id
         from dba_indexes i,  v , dba_objects o
          where  v.owner = i.owner and v.table_name = i.table_name 
             and o.OBJECT_NAME = i.index_name
             and o.owner = i.owner
             and o.object_type = 'INDEX'
          )
, vpi as ( select o.data_object_id
           from  vi , dba_objects o
                where
                       o.owner = vi.owner
                   and o.object_name = vi.name
                   and o.object_type in ( 'INDEX PARTITION', 'INDEX SUBPARTITION')
)
, vl as ( select  l.owner, l.segment_name, l.table_name, o.data_object_id 
             from 
                   dba_lobs l, v, dba_objects o
             where 
                   l.owner = v.owner
               and l.table_name = v.table_name
               and o.object_name = l.segment_name
               and o.owner       = l.owner
               and o.object_type = 'LOB'
)
, vlp as ( select  o.data_object_id
             from 
                   dba_lob_partitions lp, vl, dba_objects o
             where 
                   lp.table_owner = vl.owner
               and lp.table_name  = vl.table_name
               and lp.lob_name    = vl.segment_name
               and o.object_name  = lp.lob_name
               and o.subobject_name = lp.LOB_PARTITION_NAME
               and o.owner       = vl.owner
               and o.object_type = 'LOB PARTITION'
)
, vlpi as ( 
    select o.data_object_id
   from
         v, dba_part_lobs l , dba_ind_partitions pi
         , dba_objects o
   where
         l.table_owner = v.owner
     and l.table_name = v.table_NAME
     and pi.index_owner = l.table_owner
     and pi.index_name =  l.LOB_INDEX_NAME
      and o.owner       = l.table_owner
      and o.object_name = l.lob_index_name
     and o.subobject_name =  pi.PARTITION_NAME
     and o.object_type ='INDEX PARTITION'
)
, viot as (  select o.data_object_id
             from
                  dba_tables t ,
                  v , dba_indexes i , dba_objects o
              where
                       t.owner      = v.owner
                   and t.table_name   = v.table_name
                    and i.owner      = t.owner
                    and i.table_name = t.iot_name
                    and o.owner = i.owner
                    and o.OBJECT_NAME = i.index_name
                    and o.object_type = 'INDEX'
),
b as (
select   data_object_id from v
union all
select  data_object_id from vi
union all
select  data_object_id from vp
union all
select  data_object_id from vpi
union all
select  data_object_id from vl
union all
select  data_object_id from vlp
union all
select  data_object_id from vlpi
union all
select  data_object_id from viot
)," 
           AND_B=" , b where a.objd = b.data_object_id"
  fi

SQL="
col obj_name for a45 head 'Name'
col blk head 'Number|of blocks|in memory' justify c for 9999990
col perc_m head 'Memory|perc' justify c for 9990.9
set lines 190 pages 66
col Object_TYPE for a16 head 'Type'
col db_block_buffers new_value db_block_buffers head 'Total Blocks| in db cache buffer'
col fdirty for 9999999 head 'Dirty' 
set verify off
-- retrieve block size
with v as
      ( select value db_block_size  from v\$parameter where name = 'db_block_size' )
select /*+ no_merge */  bytes/v.db_block_size as db_block_buffers 
        from v\$sgainfo a, v 
where name = 'Buffer Cache Size' 
/
-- main query
with $AND_WITH_B
bh as (  
              select 
                   objd, to_number(nvl(xcur,0))+to_number(nvl(cr,0))+to_number(nvl(read,0))+
                         to_number(nvl(scur,0))+to_number(nvl(free,0))+to_number(nvl(dirty,0)) as blk,
                   xcur,cr, dirty, read,scur,free
              from (
         select * from  (
                select /*+ no_merge */
                       objd, count(1 )num_blocks, status 
                from  (
                      select objd,
                              case
                                   when dirty = 'Y' then 'dirty'
                                   else status
                              end status
                           from v\$bh a $AND_B
                      )
                group by
                     status, objd
             )
            pivot
            (
              sum  ( num_blocks )
              for status in ( 'xcur' as xcur,'cr' as cr ,'read' as read,'scur' as scur,'free' as free,'dirty' as dirty)
            )
)
      order by to_number(nvl(xcur,0))+to_number(nvl(cr,0))+to_number(nvl(read,0))+to_number(nvl(scur,0))
              +to_number(nvl(free,0))+to_number(nvl(dirty,0)) desc
)
select * from (
select 
   a.owner||'.'|| a.object_name obj_name,a.object_type , 
    blk, (a.blk/&&db_block_buffers)*100 as perc_m , 
   xcur, cr, dirty as fdirty, read,scur,free
from (
                select
                       o.owner          owner,
                       o.object_name    ,
                       o.object_type    , 
                       blk, xcur,cr,read,scur,free,dirty
                    from
                       dba_objects  o, bh
                    where
                          o.data_object_id  = bh.objd
                      and owner not in ('SYS','SYSTEM' )
                    order by
                       blk desc
     ) a
) where rownum <=$ROWNUM
/

"
#..................................................
#    List Object size in buffer cache
#..................................................
elif [ "$ACTION" = "LSIZ" ];then
  if [ -s "$OBJ_ID" ];then
     echo "I need an data_object id"
     exit
  fi
SQL="
col cache_size for 99999999999
with  v as 
      ( select  /*+ no_merge */ value db_block_size  from v\$parameter where name = 'db_block_size' )
,v1 as (select /*+ no_merge */  bytes/v.db_block_size as db_block_buffers from v\$sgainfo a, v where name = 'Buffer Cache Size' )
,v2 as ( select  count(*) cpt from v\$bh where OBJD=$DATA_OBJ_ID )
select  v1.db_block_buffers ,v2.cpt as obj_blocks , round(v2.cpt/v1.db_block_buffers*100,1)  perc
  from v1, v2
/
"
#..................................................
#    Buffer IO distibution
#..................................................
elif [ "$ACTION" = "BUFF_IO" ];then
# *********************************************************** 
#
#	File: buffer_pool_stats.sql 
#       Description: Buffer pool IO statistics 
#  
#       From 'Oracle Performance Survival Guide' by Guy Harrison Chapter 18 Page 546
#       Description: Buffer pool IO statistics 
#  
# ********************************************************* 

SQL="
set pagesize 1000  lines 100
column name format a7
column block_size_kb format 99 heading 'Block|Size K'
column free_buffer_wait format 99,999 heading 'Free Buff|Wait'
column buffer_busy_wait format 99,999 heading 'Buff Busy|Wait'
column db_change format 999,999,999 heading 'DB Block|Chg /1000'
column db_gets format 99,999,999 heading 'DB Block|Gets /1000'
column con_gets format 99,999,999 heading 'Consistent|gets /1000'
column phys_rds format 99,999,999 heading 'Physical|Reads /1000'
column current_size format 9,999 heading 'Current|MB'
column prev_size format 9,999 heading 'Prev|MB'

SELECT b.name, b.block_size / 1024 block_size_kb, 
       current_size, prev_size,
       ROUND(db_block_gets / 1000) db_gets,
       ROUND(consistent_gets / 1000) con_gets,
       ROUND(physical_reads / 1000) phys_rds
  FROM v\$buffer_pool_statistics s
  JOIN v\$buffer_pool b
   ON (b.name = s.name AND b.block_size = s.block_size);
"
#..................................................
#
#..................................................
elif [ "$ACTION" = "BW" ];then
SQL="set lines 190 pagesize 66
col DIRTY_BUFFERS_INSPECTED head 'Dirty buffers|Instpected'
col name for a12
select id,name, set_msize,
      block_size, free_buffer_wait, buffer_busy_wait, dirty_buffers_inspected,
      physical_reads, physical_writes
    from
      v\$buffer_pool_statistics ;
"
#..................................................
#
#..................................................
elif [ "$ACTION" = "RAC_EFF" ];then
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
                  when 'INDEX PARTITION'    then 'idx part'
                  when 'TABLE PARTITION'    then 'tbl part'
                  when 'TABLE SUBPARTITION' then 'tbl subp'
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
   order  by $RAC_ORDER desc)
where  rownum <= $ROWNUM
/
"
#..................................................
#
#..................................................
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


#..................................................
#
#..................................................
elif [ "$ACTION" = "INFO" ];then
SQL=" col KVITTAG format a20
select KVITVAL,KVITTAG,KVITDSC from x\$kvit ;
prompt
prompt Waits per buffer pool:
prompt
select DBWR_NUM,SET_ID Working_set,BLK_SIZE,HBUFS, fbwait, wcwait, bbwait from x\$kcbwds;
prompt
select event, total_waits, time_waited, average_wait
       from sys.v_\$system_event
       where event like 'db file %' or event = 'free buffer waits' or event = 'write complete waits'
order by time_waited desc;
prompt
select class,name,value from sys.v_\$sysstat  where value > 0 and class = 8 and name like 'DBWR%'
       order by class,name,value ;
"

#..................................................
#
#..................................................
elif [ "$ACTION" = "PIN" ];then
SQL=" compute sum of blocks on report
select
   'alter '||s.segment_type||' '||t1.owner||'.'||s.segment_name||' storage (buffer_pool keep);' sql
from
   (select o.owner  owner, o.object_name object_name, o.subobject_name subobject_name, o.object_type object_type,
     count(distinct file# || block#) num_blocks from dba_objects  o, v\$bh bh where o.data_object_id  = bh.objd
     and o.owner not in ('SYS','SYSTEM') and bh.status != 'free'
     group by o.owner, o.object_name, o.subobject_name, o.object_type
     order by count(distinct file# || block#) desc
  ) t1, dba_segments s
where
   s.segment_name = t1.object_name and s.owner = t1.owner and s.segment_type = t1.object_type
and nvl(s.partition_name,'-') = nvl(t1.subobject_name,'-') and buffer_pool <> 'KEEP'
and object_type in ('TABLE','INDEX') group by s.segment_type, t1.owner, s.segment_name
having (sum(num_blocks)/greatest(sum(blocks), .001))*100 > $NBR_BUFFER ;
"
elif [ "$ACTION" = "TEST" ];then
SQL="-- perform a full table scan with tracing on
set feed off termout off
alter session set db_file_multiblock_read_count = 32768
/
alter session set events '10046 trace name context forever, level 8'
/
prompt Performing full scan ....
prompt
column cpt noprint
set timing on
select /*+ full(t) noparallel(t) nocache(t) */ count(*) cpt from dba_source t
/
set timing off ;
alter session set events '10046 trace name context off'
/

-- get trace file pathname

column trc_file new_value trc_file noprint
select
  p.value || '/*' ||'ora_' || u.spid || '*' || '.trc' trc_file
from
  v\$session s,
  v\$process u,
  v\$parameter p
where
  s.audsid = userenv('SESSIONID') and
  u.addr = s.paddr and
  p.name = 'user_dump_dest'
/

-- get multiblock read sizes
--
prompt
prompt
prompt LARGEST MULTIBLOCK READ (BLOCKS)
prompt ---------------------------------

prompt trace file : &trc_file
prompt
host sed -n '/scattered/s/.*p3=//p' &trc_file | sort -n | tail -1
"
#..................................................
#
#..................................................
elif [ "$ACTION" = "FILESYSTEM" ];then
SQL="set head off feed off verify off pause off termout off
select 'Filsesystem log block size buffer size : '|| max(l.lebsz)  log_block_size from sys.x\$kccle l;
"
#..................................................
#
#..................................................
elif [ "$ACTION" = "INFO" ];then
   SQL="select a.name,a.BUFFERS,a.CURRENT_SIZE,b.free_buffer_wait,b.buffer_busy_Wait,b.WRITE_COMPLETE_WAIT,cnum_write
   from v\$buffer_pool a, v\$buffer_pool_statistics b
    where  a.name = b.name;
"
#..................................................
#
#..................................................
elif [ "$ACTION" = "TYPE2" ];then
  SQL="
prompt +............................................................................................................
prompt FREE: Not currently in use     XCUR: Exclusive                 SCUR: Shared current    CR: Consistent read
prompt READ: Being read from disk     MREC: In media recovery mode    IREC: In instance recovery mode
prompt +............................................................................................................
prompt 

col cpt format 99999999
col cmt format a10 head 'Comment'
col dirt format a5  head 'Dirty' justify c
col not_dirt head 'Block|Not Dirty' justify c
col is_dirt head 'Block|is Dirty' justify c
select blk_type, 
       state, sum(not_dirt) not_dirt, sum(is_dirt) is_dirt, count(*) cpt, cmt
  from (
select 
    decode (obj,4294967295,'Undo block','data') blk_type, 
    state, 
    case when bitand(flag,1) = 0 then 1 end not_dirt,
    case when bitand(flag,1) = 1 then 1 end is_dirt,
    '  '||decode(state,0,'free',1,'xcur',2,'scur',3,'cr', 4,'read',5,'mrec',6,'irec',7,'write ',8,'pi', 9,'memory',10,'mwrite',11,'donated') cmt
from x\$bh  
 )
  group by blk_type,state, cmt
order by 1,5 desc
/
"
#..................................................
#
#..................................................
elif [ "$ACTION" = "TYPE" ];then
    SQL="
col class form A10
select decode(greatest(class,10),10,decode(class,1,'Data',2 ,'Sort',4,'Header',to_char(class)),'Rollback') Class,
       sum(decode(bitand(flag,1),1,0,1)) Not_Dirty, sum(decode(bitand(flag,1),1,1,0)) is_dirty,
       sum(dirty_queue) on_Dirty,count(*) Total
 from x\$bh
group by decode(greatest(class,10),10,decode(class,1,'Data',2 ,'Sort',4,'Header',to_char(class)),'Rollback');
"
#..................................................
#
#..................................................
elif [ "$ACTION" = "PRES" ];then
#
#       Script:         buff_obj.sql
#       Author:         J.P.Lewis
#       Dated:          25-Oct-1998 rem Purpose:        List blocks per object in buffer, by buffer pool rem
#       Notes:
#       This has to be run by SYS because the 'working data set' is
#       only present as an X$ internal, and the column of the buffer
#       header that we need is not exposed in the v$bh view
#
#       Objects are only reported if they have a signficant number of
#       blocks in the buffer.  The code here is set to show object
#       which have 5 times the number of latches active in the
#       working set with most latches.
#
#       There is one oddity - the obj number stored in the x$bh is
#       the dataobj#, not the obj$# - so some objects (e.g. tables in
#       clusters) will generate spurious figures where the count is
#       multiplied up by the number of objects in the data object.
#
#       Objects owned by SYS have been omitted (owner# > 0)
#
#       The various X$ tables and columns are undocumented, so the code
#       is written on a best-guess basis, but the results seems to be
#       as expected.

FOUT=$SBIN/tmp/db_buffer_distrib_pool$ORACLE_SID.txt
TMP=$SBIN/tmp
S_USER=SYS
SQL=" break on pool_name
select /*+ ordered */ bp.name pool_name, ob.name object, ob.subname sub_name, sum(ct) blocks
from ( select set_ds, obj, count(*) ct from x\$bh group by set_ds, obj
        having count(*)/$NBR_BUFFER >= ( select max(set_count) from v\$buffer_pool )
        ) bh, obj\$ ob, x\$kcbwds ws, v\$buffer_pool bp
where
        ob.dataobj# = bh.obj
and     ob.owner# > 0
and     bh.set_ds = ws.addr
and     ws.set_id between bp.lo_setid and bp.hi_setid
and     bp.buffers != 0         --  Eliminate any pools not in use
group by bp.name, ob.name, ob.subname order by sum(ct) desc,bp.name, ob.name, ob.subname;
"
#..................................................
#
#..................................................
elif [ "$ACTION" = "DUP" ];then
   SQL="select block#,file#,count(block#) cpt ,objd,object_name,owner
from v\$bh,dba_objects
where objd=object_id group by objd,file#,block#,object_name,owner having count(block#) >= $NBR_BUFFER;
"
#..................................................
#
#..................................................
elif [ "$ACTION" = "DUPRAC" ];then
   SQL="col file# format 99999
col inst_id format 9999 head 'inst|id' justify c
select objd,object_name,block#,file#,inst_id,count(block#) cpt ,owner
from gv\$bh,dba_objects
where objd=object_id 
     group by objd,file#,block#,object_name,inst_id,owner 
     having count(block#) >= $NBR_BUFFER
order by object_name,block#,inst_id;

"
#..................................................
#
#..................................................
elif [ "$ACTION" = "LRU" ];then
SQL="prompt  =========================================================================

prompt   AVG_SCAN  : Normally you would expect to see 1 or 2 buffers scanned, on
prompt   average. If more than this number are being scanned, you can increase
prompt   the size of the buffer cache or tune the DBWR.
prompt
prompt  DIRTY BUFF : number of buffers that were dirty at the end of the LRU
prompt  =========================================================================
prompt

select  (1+a.value)/b.value Avg_scan, c.value/a.value  dirty
from v\$sysstat a , v\$sysstat b, v\$sysstat c
where a.name = 'free buffer inspected' and
      b.name = 'free buffer requested'  and
      c.name = 'dirty buffers inspected';
"
#..................................................
#
#..................................................
elif [ "$ACTION" = "BUSY" ];then

# Second query from Alan Kendal
   SQL="select w.class  block_class, w.count  total_waits, w.time  time_waited
       from v\$waitstat  w where w.count > 0 order by 3 desc;
prompt
   select d.tablespace_name, sum(x.count)  total_waits, sum(x.time)  time_waited
     from x\$kcbfwait  x, dba_data_files  d
     where x.count > 0 and x.indx + 1 = d.file_id group by d.tablespace_name order by 3 desc;
prompt
select * from(
  select DECODE(GROUPING(a.object_name), 1, 'All Objects', a.object_name) AS \"Object\",
    sum(case when a.statistic_name = 'buffer busy waits' then a.value else null end) \"Buffer Busy Waits\",
    sum(case when a.statistic_name = 'physical reads' then a.value else null end) \"Physical_Reads\",
    sum(case when a.statistic_name = 'physical writes' then a.value else null end) \"Physical_writes\",
    sum(case when a.statistic_name = 'logical reads' then a.value else null end) \"Logical Reads\"
  from v\$segment_statistics a
       where a.owner like upper('%')
            group by rollup(a.object_name)) b
where b.\"Buffer Busy Waits\">0
order by 2 desc
/
"
fi

if [ "$VERBOSE" = "TRUE" ];then
   echo "$SQL"
fi
echo "MACHINE $HOST - ORACLE_SID : $ORACLE_SID      Page: 1 "
sqlplus -s "$CONNECT_STRING" <<EOF

set pagesize 66 linesize 124 termout on pause off embedded on verify off heading off
column nline newline
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  || ' $TTITLE (buf -h : help)' from sys.dual
/

set pages 0 linesize 124
set feedback off pause off termout on head on
col  block_class format a30
col  dirty head "   Number of dirty   |   Buffer at end LRU  "
col  AVG_SCAN head "  Average buffer scan   |in LRU to find a free one"
col  cpt format 99999 head "Count"
col owner format a28
column pool_name format a9 head "Pool Name"
column object format a34  head  "Object Name"
column object_name format a34  head  "Object Name"
column sub_name format a54 head  "Sub Name"
column blocks format 99,999,999 head  "Blocks"
column on_dirty head "On Dirty"
column not_dirty head "Not Dirty"
column is_dirty head "Dirty"
col f1 head "Category of usage|for DB_BLOCK_BUFFERS" justify c
col f2 head "Number in | this category" justify c
col current_size head "Current|size(m)"
col buffers head "Nbr|buffers" justify c
col buffer_busy_wait head "buffer|busy wait" justify c
col free_buffer_wait head "buffer wait|for free" justify c
col WRITE_COMPLETE_WAIT head "Write|complete wait" justify c
col cnum_write head "buffer on|write list"
column sql format A124 head  "Sql statement"

$SQL

exit
EOF

