#!/bin/ksh
# program : smenu_seg.ksh
# author  : B. Polarski
# Date    : 27 Jul 2006
# set -xv
ROWNUM=30
function help
{
      cat <<EOF

       List segment statistics (v\$segment_statistics):

         seg -s                      # System wide segments statistics
         seg -l                      # List statistics name and number. Usefull for seg -n
         seg -n  <stat#>  -rn <nn>   # List values for statistics#
         seg -hot [-pr|-wr|-ss]      # List all host segments, order by 
                                               -pr : Phyiscal read     -bbw   : Buffer busy wait
                                               -wr : Physcal Write     -itl   : ITL waits
                                               -ss : Segment Scan      -rw    : Row lock wait
                                               -lo : Logical read
         seg -tch                    # List touch counts on segments blocks in SGA
         seg -w                      # List ITL/buffer busy waits segments
         seg -b                      # List counts of buffer in memory compared to blocks to object
         seg -o  <obj_id>            # List all statistics for object_id=<nn>  ; use 'obj -o' to get obj_id
         seg -top  -rn <nn>          # List Top Segment size
         seg -pread  [-sys]          # List segments with more Read IO than table blocks, -sys : include system users
         seg -d <sec> -pread  [-sys] # Measure IO related info during <n> seconds  segments with more Read IO 
         seg -d <sec> -av  [-sys]   # Segment Activity overview during  <n> seconds  

        -rn  : limit output to ROWNUM rows
         -u  : retrict selection to <OWNER>


EOF
exit
}
    
if [ -z "$1" ];then
   help
   exit
fi
while [ -n "$1" ]
do
  case "$1" in
       -pr ) HOT_ORDER=phy_r ;;
       -wr ) HOT_ORDER=phy_w ;;
       -ss ) HOT_ORDER=ss ;;
       -lo ) HOT_ORDER=lo_r ;;
       -itl ) HOT_ORDER=itlw ;;
       -bbw ) HOT_ORDER=bbw ;;
       -rw ) HOT_ORDER=rw ;;
      -av ) ACTION=ACTIVITY ; TITTLE="Segments activity" ;;
        -b ) ACTION=BUF ; TITTLE="List counts of buffer in memory compared to object blocks" ;;
        -d ) NBR_SECS=$2 ; shift ;;
      -hot ) ACTION=HOT ; TITTLE="ist all host segments" ;;
        -l ) ACTION=LIST  ; TITTLE="List statistics name and number";;
        -n ) ACTION=FILTER1 ; STATN=$2 ; shift ; TITTLE="List all for statistic#=$STATN" ;;
        -o ) ACTION=ONEOBJ ; OBJ_ID=$2 ; shift ; TITTLE="List all for object_id=$OBJ_ID" ;;
    -pread ) ACTION=PREAD ; TITTLE="List segments Read and Write IO" ;;
        -s ) ACTION=STATS ; TITTLE="System wide segments statistics" ;;
      -sys ) SYS=TRUE ;;
      -tch ) ACTION=TCH ; TITTLE="Touch counts on segments blocks in SGA"; S_USER=SYS ;;
      -top ) TITTLE="List top segment size" ; ACTION=TOP;;
        -u ) WHERE_OWNER=" where owner = upper('$2') "; shift ;;
        -w ) ACTION=BUSY  ; TITTLE="List ITL and buffer busy wait" ;;
       -rn )  ROWNUM=$2 ; shift ;;
        -v ) VERBOSE=TRUE;;
        -h ) help ;;
         * ) help ;;
  esac
  shift
done


. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID

if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# -----------------------------------------------------
#  segment activity During n seconds
# -----------------------------------------------------
if [ "$ACTION" = "ACTIVITY"  -a  -n "$NBR_SECS" ];then
  if  [ "$SYS"  = "TRUE" ];then
     unset AND_NOT_SYS
  else
     AND_NOT_SYS=" and s.owner not in ('SYS','SYSTEM') "
  fi
SQL="
   set linesize 190 pagesize 333 feed off head off
   set serveroutput on size 999999
declare

   type  rec_type is record (
          obj#            number,
          owner           varchar2(30),
          object_name     varchar2(30),
          subobject_name  varchar2(30),
          object_type     varchar2(19),
          lread           number,
          pread           number,
          pwrite          number,
          itl             number,
          bbw             number,
          blocks          number, 
          blocks_change   number, 
          locks           number,
          seg_scan        number,
          d_pread         number,
          d_pwrite        number,
          d_lread         number,
          d_bbw           number,
          d_itl           number,
          d_lock          number,
          d_seg_scan      number,
          d_blocks_change number
        );

   type  rec_sort is record (
         hash_key varchar2(30),
         value   number ) ;

    type TC is table of REC_TYPE index by  varchar2(30);
    type TC_sort is table of REC_SORT index by  binary_integer ;

    thv1 TC ;
    thv2 TC ;
    tsort TC ;
    v_int   number ;
    v_rec   rec_type ;
    v0      rec_type;
    rownum  number:=0;
    beg_date date;
    end_date date;
    mid_date date;
    v_dur   number:=$NBR_SECS ;
    ------------------------------------------------------------------------------------------------------
    procedure load_data (p_thv IN OUT tc) is
       v_rec   rec_type ;
    begin
       for c1 in ( select a.obj#, b.object_name , b.owner, 
                          max(Pread) Pread, max(pwrite) pwrite, max(lread) lread, max(seg_scan) seg_scan,
                          max(itl) itl, max(blocks_change) blocks_change, max(locks) locks, max(bbw) bbw
                     from
                           ( SELECT
                                  case statistic_name when  'physical reads'    then value else 0 end Pread,
                                  case statistic_name when  'physical writes'   then value else 0 end pwrite,
                                  case statistic_name when  'logical reads'     then value else 0 end lread,
                                  case statistic_name when  'segment scans'     then value else 0 end seg_scan,
                                  case statistic_name when  'ITL waits'         then value else 0 end itl,
                                  case statistic_name when  'db block changes'  then value else 0 end blocks_change,
                                  case statistic_name when  'row lock waits'    then value else 0 end locks,
                                  case statistic_name when  'buffer busy waits' then value else 0 end bbw,
                                  s.obj#
                             FROM v\$segstat s
                             WHERE
                                  statistic_name IN ( 'logical reads','db block changes','segment scans','ITL waits','row lock waits','buffer busy waits',
                                                      'physical reads','physical writes' ) and value > 1000
                           ) a , all_objects b
                     where a.obj# = b.object_id
                     group by a.obj#, b.object_name , b.owner order by pread desc   
               )
               loop

                  v_rec.owner:=c1.owner;
                  v_rec.object_name:=c1.object_name;
                  -- v_rec.subobject_name:=c1.subobject_name;
                  -- v_rec.object_type:=c1.object_type;
                  -- v_rec.blocks:=c1.blocks;
                  v_rec.pread:=c1.pread;
                  v_rec.lread:=c1.lread;
                  v_rec.pwrite:=c1.pwrite;
                  v_rec.itl:=c1.itl;
                  v_rec.bbw:=c1.bbw;
                  v_rec.blocks_change:=c1.blocks_change ;
                  v_rec.locks:=c1.locks;
                  v_rec.seg_scan:=c1.seg_scan;
                  v_rec.d_pread:=0;
                  v_rec.d_pwrite:=0;
                  v_rec.d_lread:=0;
                  v_rec.d_itl:=0;
                  v_rec.d_bbw:=0;
                  v_rec.d_lock:=0;
                  v_rec.d_seg_scan:=0;
                  v_rec.d_blocks_change:=0;
                  p_thv(c1.obj# ):=v_rec;
               end loop ;
    end ;
begin
   -- load a dummy record 0, it serves only to initiate the loop whithout having to process first rec outside the loop
   v_rec.owner:='dummy';
   thv1(0):=v_rec;
   thv2(0):=v_rec;
   beg_date:=sysdate;
   load_data(thv1);
   v_int:=sysdate-beg_date;
   if v_dur - v_int > 0 then 
      dbms_lock.sleep(v_dur-v_int);
   else
      dbms_lock.sleep(0);
   end if;
   end_date:=sysdate;
   load_data(thv2);

   v_int:= 0 ;  -- load the dummy one. good news, it always exists since we created it.
   while v_int is not null
   loop
      v_int:=thv2.next(v_int);
      if thv1.exists(v_int) then
         thv2(v_int).d_pread:=thv2(v_int).pread-thv1(v_int).pread ;
         thv2(v_int).d_pwrite:=thv2(v_int).pwrite-thv1(v_int).pwrite ;
         thv2(v_int).d_lread:=thv2(v_int).lread-thv1(v_int).lread ;
         thv2(v_int).d_itl:=thv2(v_int).itl-thv1(v_int).itl ;
         thv2(v_int).d_bbw:=thv2(v_int).bbw-thv1(v_int).bbw ;
         thv2(v_int).d_lock:=thv2(v_int).locks-thv1(v_int).locks ;
         thv2(v_int).d_seg_scan:=thv2(v_int).seg_scan-thv1(v_int).seg_scan ;
         thv2(v_int).d_blocks_change:=thv2(v_int).blocks_change-thv1(v_int).blocks_change ;
         rownum:=rownum+1;
         tsort(rownum):=thv2(v_int);
      end if;
   end loop ;  
   -- good old buble. one day should be less lazy an improve this
   for i in 1..tsort.last
   loop
        if tsort.exists(i) then
           for j in 1..tsort.last
           loop
              if tsort.exists(j) then
                 if tsort(j).d_lread < tsort(i).d_lread then
                    v0:=tsort(i);
                    tsort(i):=tsort(j);
                    tsort(j):=v0;
                  end if;
               end if;
            end loop;
        end if;
   end loop;
   -- displ
   dbms_output.put_line('Start: ' || to_char(beg_date,'HH24:MI:DD') || ' End : ' ||to_char(end_date,'HH24:MI:SS') ) ;  
   dbms_output.put_line('.                                             Logical     Physical     Seg         Physical        Blocks                     Buffer      Rows ');
   dbms_output.put_line('Object                                          read        read        scan          write        change        ITL        busy waits    locks ');
   dbms_output.put_line('-------------------------------------------- ----------- ------------ ------------ ------------ ------------ ------------ ------------ ------------');

   for i in 1..tsort.last
   loop
       if (tsort(i).d_pread+tsort(i).d_pwrite)+tsort(i).d_seg_scan+tsort(i).d_blocks_change+tsort(i).d_itl+tsort(i).d_lock > 0 then
           dbms_output.put_line(rpad(tsort(i).owner||'.'||tsort(i).object_name,43) || ' ' ||
                             lpad(to_char(tsort(i).d_lread),12)         || ' ' ||
                             lpad(to_char(tsort(i).d_pread),12)         || ' ' ||
                             lpad(to_char(tsort(i).d_seg_scan),12)      || ' '  ||
                             lpad(to_char(tsort(i).d_pwrite),12)        || ' ' ||
                             lpad(to_char(tsort(i).d_blocks_change),12) || ' ' ||
                             lpad(to_char(tsort(i).d_itl),12)           || ' ' ||
                             lpad(to_char(tsort(i).d_bbw),12)           || ' ' ||
                             lpad(to_char(tsort(i).d_lock),12)  )        ; 
          exit when i = $ROWNUM ;
       end if ;
   end loop ;  
end;
/
"
# -----------------------------------------------------
#  List physical reads per segment During n seconds
# -----------------------------------------------------
elif [ "$ACTION" = "PREAD"  -a  -n "$NBR_SECS" ];then
  if  [ "$SYS"  = "TRUE" ];then
     unset AND_NOT_SYS
  else
     AND_NOT_SYS=" and s.owner not in ('SYS','SYSTEM') "
  fi
SQL="
   set linesize 190 pagesize 333 feed off head off
   set serveroutput on size 999999

declare

   type  rec_type is record (
          obj#            number,
          owner           varchar2(30),
          object_name     varchar2(30),
          subobject_name  varchar2(30),
          object_type     varchar2(19),
          lread           number,
          pread           number,
          pwrite          number,
          blocks          number, 
          ldelta          number,
          rdelta          number,
          wdelta          number);

   type  rec_sort is record (
         hash_key varchar2(30),
         value   number ) ;

    type TC is table of REC_TYPE index by  varchar2(30);
    type TC_sort is table of REC_SORT index by  binary_integer ;

    thv1 TC ;
    thv2 TC ;
    tsort TC ;
    v_int   number ;
    v_rec   rec_type ;
    v0      rec_type;
    rownum  number:=0;
    beg_date date;
    end_date date;
    mid_date date;
    v_dur   number:=$NBR_SECS ;
    ------------------------------------------------------------------------------------------------------
    procedure load_data (p_thv IN OUT tc) is
       v_rec   rec_type ;
    begin
       for c1 in ( select obj#, owner, OBJECT_NAME, SUBOBJECT_NAME,  object_type, Pread, pwrite , blocks  , lread
                   from ( select
                              a.obj#, a.owner, a.OBJECT_NAME, a.SUBOBJECT_NAME,  a.object_type,
                              max(Pread) Pread, max(pwrite) pwrite, max(lread) lread,
                              (decode (  a.object_type,'TABLE'
                                     , (select  blocks from all_tables t where t.owner = a.owner and t.table_name  = a.object_name )
                                     ,'TABLE PARTITION'
                                     , (select  blocks from all_tab_partitions  t where t.table_owner  = a.owner
                                                 and t.table_name = a.object_name and t.partition_name=a.SUBOBJECT_NAME)
                                     ,'TABLE SUBPARTITION'
                                     , (select  blocks from all_tab_subpartitions  t where t.table_owner  = a.owner
                                                 and t.table_name = a.object_name and t.subpartition_name=a.SUBOBJECT_NAME)
                                     , -1
                              )) blocks
                         from  
                           ( SELECT
                                  case statistic_name
                                      when 'physical reads' then value
                                  else 0
                                  end Pread,
                                  case statistic_name
                                       when  'physical writes' then value
                                 else 0
                                 end pwrite,
                                 case statistic_name
                                      when  'logical reads' then value
                                 else 0
                                 end lread, s.OBJECT_NAME, s.SUBOBJECT_NAME, s.owner,  s.object_type, s.obj#
                             FROM v\$segment_statistics s, all_objects o
                            WHERE
                                  statistic_name IN ('logical reads', 'physical reads','physical writes')
                              and substr(s.object_type,1,5) = 'TABLE' $AND_NOT_SYS
                              and s.obj# = o.object_id --  the join is just to avoid object from recyclebin
                              and s.DATAOBJ# = o.DATA_OBJECT_ID
                       ) a
                       group by a.obj#, a.OBJECT_NAME, a.SUBOBJECT_NAME, a.owner,  a.object_type 
                       order by pread desc)
               where Pread > blocks and pread > 1000 
               )
               loop
                  v_rec.owner:=c1.owner;
                  v_rec.object_name:=c1.object_name;
                  v_rec.subobject_name:=c1.subobject_name;
                  v_rec.object_type:=c1.object_type;
                  v_rec.pread:=c1.pread;
                  v_rec.lread:=c1.lread;
                  v_rec.pwrite:=c1.pwrite;
                  v_rec.blocks:=c1.blocks;
                  v_rec.rdelta:=0;
                  v_rec.wdelta:=0;
                  v_rec.ldelta:=0;
                  p_thv(c1.obj# ):=v_rec;
               end loop ;
    end ;
begin
   -- load a dummy record 0, it serves only to initiate the loop whithout having to process first rec outside the loop
   v_rec.owner:='dummy';
   thv1(0):=v_rec;
   thv2(0):=v_rec;
   beg_date:=sysdate;
   load_data(thv1);
   v_int:=sysdate-beg_date;
   if v_dur - v_int > 0 then 
      dbms_lock.sleep(v_dur-v_int);
   else
      dbms_lock.sleep(0);
   end if;
   end_date:=sysdate;
   load_data(thv2);

   v_int:= 0 ;  -- load the dummy one. good news, it always exists since we created it.
   while v_int is not null
   loop
      v_int:=thv2.next(v_int);
      if thv1.exists(v_int) then
         thv2(v_int).rdelta:=thv2(v_int).pread-thv1(v_int).pread ;
         thv2(v_int).wdelta:=thv2(v_int).pwrite-thv1(v_int).pwrite ;
         thv2(v_int).ldelta:=thv2(v_int).lread-thv1(v_int).lread ;
         rownum:=rownum+1;
         tsort(rownum):=thv2(v_int);
      end if;
   end loop ;  
   -- good old buble. one day should be less lazy an improve this
   for i in 1..tsort.last
   loop
        if tsort.exists(i) then
           for j in 1..tsort.last
           loop
              if tsort.exists(j) then
                 if tsort(j).rdelta < tsort(i).rdelta then
                    v0:=tsort(i);
                    tsort(i):=tsort(j);
                    tsort(j):=v0;
                  end if;
               end if;
            end loop;
        end if;
   end loop;
   -- displ
   dbms_output.put_line('Start: ' || to_char(beg_date,'HH24:MI:DD') || ' End : ' ||to_char(end_date,'HH24:MI:SS') ) ;  
   dbms_output.put_line('.                                                                  Blocks      Logical                  Physical                   Physical ');
   dbms_output.put_line('Object                                      Partition              In Seg       Read         Delta      Reads          Delta         Write        Delta ');
   dbms_output.put_line('---- -------------------------------------- --------------------- --------- ------------ ------------ ------------ ------------ ------------ ------------');

   for i in 1..tsort.last
   loop
       if (tsort(i).rdelta+tsort(i).wdelta) > 0 then
           dbms_output.put_line(rpad(tsort(i).owner||'.'||tsort(i).object_name,43) || ' ' ||
                             rpad(nvl(tsort(i).subobject_name,'         -'),22) || ' ' ||
                             lpad(to_char(tsort(i).blocks),8) || ' ' ||
                             lpad(to_char(tsort(i).lread),12) || ' ' ||
                             lpad(to_char(tsort(i).ldelta),12) || ' ' ||
                             lpad(to_char(tsort(i).pread),12) || ' ' ||
                             lpad(to_char(tsort(i).rdelta),12) || ' ' ||
                             lpad(to_char(tsort(i).pwrite),12) || ' ' ||
                             lpad(to_char(tsort(i).wdelta),12) ) ;
          exit when i = $ROWNUM ;
       end if ;
   end loop ;  
end;
/
"
# -----------------------------------------------------
#  List physical reads per segment
# -----------------------------------------------------
elif [ "$ACTION" = "PREAD"  -a  -z "$NBR_SECS" ];then
  if  [ "$SYS"  = "TRUE" ];then
     unset AND_NOT_SYS
  else
     AND_NOT_SYS=" and s.owner not in ('SYS','SYSTEM') "
  fi
# this procedure uses a manual pivot, so it is compatible 10g and 11g. 
SQL="
set lines 190
col OBJECT_NAME for a44
col subOBJECT_NAME for a30
col perc head '% Pread|/Lread' for 990.9999
col Pread format 9999999999 head 'Pysical|Read' justify c
col lread format 9999999999 head 'Logical|Read' justify c
col Pwrite format 9999999999 head 'Pysical|Write' justify c
select owner||'.'|| OBJECT_NAME OBJECT_NAME, SUBOBJECT_NAME,  object_type, 
       lread, Pread, pwrite , blocks, decode(lread,0, 0 ,pread*100/lread)  perc  from (
select
      a.owner,a.OBJECT_NAME , a.SUBOBJECT_NAME,  a.object_type,
      max(Pread) Pread, max(pwrite) pwrite, max(lread) lread,
     (decode (  a.object_type,'TABLE'
                            , (select  blocks from all_tables  t where t.owner  = a.owner and t.table_name  = a.object_name )
                            ,'TABLE PARTITION'
                            , (select  blocks from all_tab_partitions  t where t.table_owner  = a.owner
                                        and t.table_name  = a.object_name and t.partition_name=a.SUBOBJECT_NAME)
                            ,'TABLE SUBPARTITION'
                            , (select  blocks from all_tab_subpartitions  t where t.table_owner  = a.owner
                                        and t.table_name  = a.object_name and t.subpartition_name=a.SUBOBJECT_NAME)
                            , -1
              )
      ) blocks
  from  
        ( SELECT
                  case statistic_name
                       when 'physical reads' then value
                  else 0
                  end Pread,
                  case statistic_name
                       when  'physical writes' then value
                  else 0
                  end pwrite,
                  case statistic_name
                       when  'logical reads' then value
                  else 0
                  end lread, 
                  s.OBJECT_NAME, s.SUBOBJECT_NAME, s.owner,  s.object_type
           FROM v\$segment_statistics s, all_objects o
           WHERE
                   statistic_name IN ( 'physical reads', 'physical writes','logical reads')
               and substr(s.object_type,1,5) = 'TABLE' $AND_NOT_SYS
               and s.obj# = o.object_id --  the join is just to avoid object from recyclebin
               and s.DATAOBJ# = o.DATA_OBJECT_ID
        ) a
        group by a.OBJECT_NAME, a.SUBOBJECT_NAME, a.owner,  a.object_type 
        order by pread desc)
where Pread > blocks and pread > 1000 and rownum <=$ROWNUM
/
"

# -----------------------------------------------------
#  List Top Segments size
# -----------------------------------------------------
elif [ "$ACTION" = "TOP" ];then
SQL="col SEGMENT_NAME for a30
col owner format a24
col segment_type format a18
col tablespace_name format a24
set lines 190
break on tablespace_name on  owner on segment_name
select * from (
	select tablespace_name, owner, segment_name , 
		partition_name, segment_type, round(bytes/1048576) MB 
	from dba_segments $WHERE_OWNER
	order by MB desc
)
where rownum <= $ROWNUM;
"

# -----------------------------------------------------
# List counts of buffer in memory compared to objects blocks 
# -----------------------------------------------------
elif [ "$ACTION" = "BUF" ];then
#Copyright © 2005 by Rampant TechPress
SQL=" set lines 190 pages 66
break on c0
select t1.owner c0, object_name  c1,
   case when object_type = 'TABLE PARTITION' then 'TAB PART'
        when object_type = 'INDEX PARTITION' then 'IDX PART'
        else object_type end c2,
   sum(num_blocks)                                     c3,
   (sum(num_blocks)/greatest(sum(blocks), .001))*100 c4,
   buffer_pool                                       c5,
   sum(bytes)/sum(blocks)                            c6
from (
select
   o.owner          owner,
   o.object_name    object_name,
   o.subobject_name subobject_name,
   o.object_type    object_type,
   count(distinct file# || block#)         num_blocks
from
   dba_objects  o,
   v\$bh         bh
where
   o.data_object_id  = bh.objd and
   o.owner not in ('SYS','SYSTEM') and
   bh.status != 'free'
group by
   o.owner,
   o.object_name,
   o.subobject_name,
   o.object_type
order by
   count(distinct file# || block#) desc
) t1,
   dba_segments s
where
   s.segment_name = t1.object_name and
   s.owner = t1.owner and
   s.segment_type = t1.object_type and
   nvl(s.partition_name,'-') = nvl(t1.subobject_name,'-')
group by
   t1.owner,
   object_name,
   object_type,
   buffer_pool
having
   sum(num_blocks) > 10
order by
   sum(num_blocks) desc;
"
# -----------------------------------------------------
# List ITL and buffer busy wait
# -----------------------------------------------------
elif [ "$ACTION" = "BUSY" ];then
SQL="
col itl head 'ITL Waits'
col rlw head 'Row Lock Waits'
col pr head 'Physical Reads'
col lr head 'Logical Reads'
col bbw head 'Buffer Busy Waits'
col obj head 'Objects'
select * from
    (
       select
          DECODE
          (GROUPING(a.object_name), 1, 'All Objects', a.object_name)
        obj,
    sum(case when a.statistic_name = 'ITL waits' then a.value else null end) itl,
    sum(case
             when a.statistic_name = 'buffer busy waits' then a.value
             when a.statistic_name = 'gc buffer busy waits' then a.value
              else null end) bbw ,
    sum(case when a.statistic_name = 'row lock waits' then a.value else null end) rlw ,
   sum(case when a.statistic_name = 'physical reads' then a.value else null end) pr ,
   sum(case when a.statistic_name = 'logical reads' then a.value else null end) lr
   from v\$segment_statistics a 
  group by rollup(a.object_name)) b where (b.itl>0 or b.bbw >0)
/
"
# -----------------------------------------------------
# Query found on metallink forum from  Andrew Allen.
#  Touch counts on segments blocks in SGA
# -----------------------------------------------------
elif [ "$ACTION" = "TCH" ];then
SQL="set linesize 148 

col owner for a22 
COL tch FOR 9,999 HEAD 'Touch|Count' 
COL file_name FOR a40 
COL dbablk HEAD 'Block Num' 
COL hladdr HEAD 'Cache Buffer|Chain Latch|Address' 
col object_name format a30

PROMPT List the top 100 data blocks by touch counts. A ZERO touch count does not 
PROMPT necessarily mean a cold block because the touch count gets reset to zero 
PROMPT when a block is moved from the cold to the hot end of the LRU list. 
PROMPT . 

SELECT a.hladdr, a.file#, 
  -- f.name AS file_name, 
  a.dbablk, a.tch, a.obj, b.object_type, b.owner, b.object_name 
FROM 
   (select * from (SELECT hladdr, file#, dbablk, tch, obj FROM x\$bh ORDER BY tch DESC ) where rownum <= $ROWNUM) a, 
   dba_objects b, 
   v\$datafile f 
WHERE     ( a.obj = b.object_id OR a.obj = b.data_object_id) 
      AND a.file# = f.file# 
ORDER BY 
a.tch  desc ; 
"
# -----------------------------------------------------
# Query found on metallink forum from  Andrew Allen.
#  List all hot segments
# -----------------------------------------------------
elif [ "$ACTION" = "HOT" ];then
HOT_ORDER=${HOT_ORDER:-lo_r}
  if [ $HOT_ORDER = lo_r ];then
       TITTLE="Hot Segments, ordered by Logical Reads"
  elif [ $HOT_ORDER = phy_r ];then
       TITTLE="Hot Segments, ordered by Physical Reads"
  elif [ $HOT_ORDER = ss ];then
       TITTLE="Hot Segments, ordered by Segments Scans"
  elif [ $HOT_ORDER = phy_w ];then
       TITTLE="Hot Segments, ordered by Physical Writes"
  elif [ $HOT_ORDER = rw ];then
       TITTLE="Hot Segments, ordered by Row lock wait"
  elif [ $HOT_ORDER = bbw ];then
       TITTLE="Hot Segments, ordered by Buffer busy wait"
  elif [ $HOT_ORDER = itlw ];then
       TITTLE="Hot Segments, ordered by ITL Waits"
  fi
SQL="
col lo_r for 9999999999 head 'Logical|reads'
col phy_r for 9999999999 head 'Physical|reads'
col phy_w for 9999999999 head 'Physical|Writes'
col phy_r_d for 9999999999 head 'Physical|reads dir'
col phy_w_d for 9999999999 head 'Physical|writes dir'
col rw for 9999999999 head 'Row lock|wait' justify c
col bbw for 9999999999 head 'Buffer |busy wait' justify c
col itlw for 9999999999 head 'ITL| wait' justify c
col ss for 9999999999 head 'Segment|scan' justify c
col mv head 'Total|hits' for 999999999999 justify c
col obj for a30 head 'Name'
col owner for a20 head 'Owner'
break on report on owner
set pages  66 lines 190
select owner, 
   case 
      when OBJECT_TYPE = 'INDEX PARTITION' then OBJECT_NAME||'.'||SUBOBJECT_NAME
      when OBJECT_TYPE = 'TABLE PARTITION' then OBJECT_NAME||'.'||SUBOBJECT_NAME
      else OBJECT_NAME
   end obj,
   mv, lo_r,phy_r,phy_w,phy_r_d,phy_w_d,ss,rw, bbw, itlw
from (
select * from (
SELECT obj#, statistic_name, value, DATAOBJ#,
       sum(value) OVER (partition by obj#, DATAOBJ#) mv
FROM v\$segstat a
WHERE statistic_name IN
        ( 'logical reads', 'physical reads', 'physical writes', 'physical reads direct', 'physical writes direct' ,
          'segment scans','row lock waits','buffer busy waits','ITL waits')
)
pivot
  ( max(value )
  for statistic_name  in ('logical reads' as lo_r, 'physical reads' as phy_r, 'physical writes' as phy_w,
                          'physical reads direct' as phy_r_d, 'physical writes direct' as phy_w_d, 'segment scans' as ss,
                          'row lock waits' as rw ,'buffer busy waits' as bbw ,'ITL waits' as itlw)
  )
order by $HOT_ORDER desc
) a, all_objects b
where  a.obj# = b.object_id and DATAOBJ# = DATA_OBJECT_ID
 and rownum <= $ROWNUM
/
"

# ------------------------------
#  system wide stats
# ------------------------------
elif [ "$ACTION" = "ONEOBJ" ];then
SQL="break on obj_name on tablespace_name
 select owner||'.'||object_name obj_name, tablespace_name, statistic_name,  value
                   from v\$segment_statistics where obj#=$OBJ_ID order by 1  ;"

# ------------------------------
#  system wide stats
# ------------------------------
elif [ "$ACTION" = "FILTER1" ];then
SQL="break on statistic_name on obj_name
select statistic_name, value,obj_name, SUBOBJECT_NAME, tablespace_name
       from (select statistic_name, owner||'.'||object_name obj_name, SUBOBJECT_NAME, value, tablespace_name
                   from v\$segment_statistics where statistic# = $STATN order by value desc) 
     where rownum < $ROWNUM ;"
#SQL="select statistic_name, owner||'.'||object_name obj_name, SUBOBJECT_NAME, value, tablespace_name,
#            rank() over ( order by value desc) rank
#    from v\$segment_statistics where statistic# = $STATN and rownum < $ROWNUM
#    order by value ;"


# ------------------------------
#  system wide stats
# ------------------------------
elif [ "$ACTION" = "LIST" ];then
  SQL="select distinct statistic_name, statistic# from v\$segment_statistics order by 1;"

# ------------------------------
#  system wide stats
# ------------------------------
elif [ "$ACTION" = "STATS" ];then
  SQL="select count(1) cpt , statistic#, statistic_name, sum(value) value 
        from v\$segment_statistics  group by statistic_name , statistic#
       order by statistic_name;"
fi
$SETXV

if [ "$VERBOSE"  = "TRUE" ];then
   echo "$SQL"
fi

sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '      'Page:' format 999 sql.pno skip 2
column nline newline
set pause offset pagesize 66 linesize 85 heading off embedded on termout on verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  || ' $TITTLE (help : seg -h)  ' nline
from sys.dual
/
set linesize 132 head on pagesize 66
col segment_name format A34
col TABLESPACE_NAME format A20
col SEGMENT_TYPE format A8 head "segment|type"
col statistic_name format A27 head "Statistics name"
col cpt format 9999999 head "Count"
col rank noprint
col obj_name format a37
col subobject_name format a27
column c0 heading 'Owner'                        format a16
column Owner heading 'Owner'                        format a16
column c1 heading 'Object|Name'                  format a30
column c2 heading 'Object|Type'                  format a18
column c3 heading 'Number of|Blocks in|Buffer|Cache' format 99,999,999
column c4 heading 'Percentage|of object|blocks in|Buffer' format 999
column c5 heading 'Buffer|Pool'                  format a7
column c6 heading 'Block|Size'                   format 99,999
$BREAK
$SQL
EOF
