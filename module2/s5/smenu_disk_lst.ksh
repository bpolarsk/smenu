#!/bin/ksh
# set -xv
# Program : smenu_lst_disk.sh
# Author  : Bernard Polarski
# note    : The resize datafiles part is from Jonathan Lewis book Practical Oracle 8i
HOST=`hostname`
PAR1=$1
PAR2=$2
# --------------------------------------------------------------
function help {

      cat <<EOF

   List datfiles utility:

        lstd  [ -t <tablespace_name>] : List datafiles size and auto extend info, eventually limit to <tbs>
        lstd -m  [-t <tablespace_name>] : List candidate shrink datafiles
        lstd -e                       : List datafile in autoextend that cannot extend anymore
        lstd -es                      : Show statement to set off datafiles that cannot extend anymore
        lstd -ck                      : List last checkpoint time  for each datafile
        lstd -fs                      : List file stats
        lstd -fp                      : List file stats percentage break  by tablespace
        lstd -lx  <file_id>           : List datafile extents occupancy by segments
        lstd -gap <file_id> -rn       : List datafile extents size and hole starting from top
        lstd -sgap <file_id> -rn      : Generate object move statements starting from top
        lstd -y                       : list datafile ASYNC IO flag per datafile
        lstd -fsa                     : list file number for temporary tempfile
        lstd -d <sec>                 : list differential read/writes per tablespace for <sec> seconds
        lstd -s [ -t <tablespace_name>][-f <n>]  : show SQL statement to shink datafiles, default is all unless TBS name is given for a given datafile

EOF
exit
}
# --------------------------------------------------------------
TMP=$SBIN/tmp
FOUT=$TMP/tmp_dsc$ORACLE_SID.txt
ROWNUM=40
while [ -n "$1" ]
do
  case "$1" in
     -ck ) PAR1=checkpoint ;;
      -d ) PAR1=diff ; SLEEP_TIME=$2 ; shift ;;
     -es ) PAR1=es ;;
      -e ) PAR1=autoextend ;;
      -f ) FID=$2; shift ;;
     -fp ) PAR1=stats2 ;;
     -fs ) PAR1=stats ;;
    -fsa ) PAR1=FSA; S_USER=SYS; export S_USER ;;
    -gap ) PAR1=GAP;  FID=$2; shift ;; 
      -h ) help ;;
     -lx ) PAR1=LX  ; FID=$2; shift ;;
      -m ) PAR1=shrink ;;
      -s ) PAR1=shrink2  ;;
     -rn ) ROWNUM=$2 ; shift ;;
   -sgap ) PAR1=SGAP;  FID=$2; shift ;; 
      -t ) TBS="$2" ; shift ;;
      -y ) PAR1=ASYNC ;;
      -v ) VERBOSE=TRUE ; set -xv;;
  esac
  shift
done
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# --------------------------------------------------------------
if [ "$PAR1" = "GAP" ];then
SQL="
set line 190
set pages  90
col gap for 999999999 head 'Gap (m)'
col segment_name for a50 head 'Name'
col EXTENT_ID for 99999 head 'Ext|id' justify c
col partition_name for a24 head 'Partition'
col ftop for 999999 head 'dist from|bottom (m)'
with v as ( select value block_size from v\$parameter where name = 'db_block_size')
select * from (
    select 
         owner||'.'||segment_name segment_name, partition_name, EXTENT_ID,
        BLOCK_ID-blocks start_blk, BLOCK_ID end_blk, round(blocks * v.block_size/1048576,1) size_m, 
        round( (block_id - lag(BLOCK_ID) over  (order by BLOCK_ID)) * v.block_size/1048576,1)  gap, 
        trunc(block_id*v.block_size/1048576) ftop, segment_type
from dba_extents ,v where FILE_ID = $FID  order by block_id desc ) 
where rownum <= $ROWNUM
/
"
# --------------------------------------------------------------
elif [ "$PAR1" = "SGAP" ];then
SQL="
set pages 0
set lines 210 
col fline for a180
col block_id noprint
set head off
with v as ( select value block_size from v\$parameter where name = 'db_block_size')
select fline from (
select rank () over (partition by fline order by block_id desc) rnk, fline from 
  (
    select 
         block_id, 'alter table '|| owner||'.'||segment_name || ' move online ;' as fline
from dba_extents ,v where FILE_ID = $FID  and segment_type = 'TABLE' 
union all 
    select 
         block_id, 'alter index '|| owner||'.'||segment_name || ' rebuild online ;' as fline
from dba_extents ,v where FILE_ID = $FID  and segment_type = 'INDEX' 
union all 
    select 
         block_id, 'alter table '|| owner||'.'||segment_name || ' move partition ' || partition_name || ' update indexes ;' as fline
from dba_extents ,v where FILE_ID = $FID  and segment_type = 'TABLE PARTITION' 
union all
    select 
         block_id, 'alter table ' || l.owner||'.'||l.table_name || ' move lob (' || l.column_name||') 
         store as ' || l.segment_name ||' (tablespace '||l.tablespace_name||') ;' as fline
from 
     dba_extents x ,v, 
     dba_lobs l 
where
         x.FILE_ID = $FID  and x.segment_type = 'LOBSEGMENT' 
     and l.owner = x.owner 
     and l.segment_name =  x.segment_name
     and l.tablespace_name = x.tablespace_name
union all 
    select 
         block_id, 'alter table ' || l.table_owner||'.'||l.table_name || ' move partition ' || l.partition_name ||
         ' online lob (' || l.column_name||') store as (tablespace '||l.tablespace_name||') ;' as fline
from 
     dba_extents x ,v, 
     dba_lob_partitions l 
where
         x.FILE_ID = $FID  and x.segment_type in( 'LOB PARTITION' , 'LOB INDEX')
     and l.table_owner = x.owner 
     and l.lob_name =  x.segment_name
     and l.lob_partition_name = x.partition_name
     and l.tablespace_name = x.tablespace_name
order by block_id desc
  )
where rownum <= $ROWNUM order by block_id desc
)  where rnk = 1
/
"
# --------------------------------------------------------------
elif [ "$PAR1" = "ASYNC" ];then
SQL="
set lines 190 pages 66 feed off
col name format a100
SELECT name, asynch_io FROM v\$datafile f, v\$iostat_file i
  WHERE f.file#        = i.file_no
  AND   filetype_name  = 'Data File'
 /
"
# --------------------------------------------------------------
elif [ "$PAR1" = "FSA" ];then
SQL="
set pages 66 lines 190
col name for a120
select  a.tfnum, a.tfafn, b.name from sys.x\$kcctf a , v\$tempfile b
where a.tfnum = b.file#
/
"
# --------------------------------------------------------------
elif [ "$PAR1" = "LX" ];then
ROWNUM=${ROWNUM:-30}
SQL="
set lines 190 pages 66 feed off
col segment_name for a34
col sum_seg head 'Tot Seg(mb)| in file' justify c
col bytes head 'Ext|Size(mg)' justify c
col bstart head 'Start|block id' justify c
col bend head 'End|block id' justify c
col blocks head 'Blocks count|in extent' justify c
col owner format a30
col partition_name format a30
select * from (
select
   owner,SEGMENT_NAME, PARTITION_NAME, SEGMENT_TYPE, 
   lag(BLOCK_id) over( order by BLOCK_ID ) bstart, BLOCK_ID-1 bend, BLOCKS ,
   round(bytes/1048576,1) bytes,
   round(sum(bytes) over ( partition by SEGMENT_NAME, PARTITION_NAME )/1048576,1)sum_seg
from dba_Extents
  where FILE_ID =  $FID
order by BLOCK_ID desc
) where rownum <= $ROWNUM
/
"

# --------------------------------------------------------------
elif [ "$PAR1" = "diff" ];then

   SLEEP_TIME=${SLEEP_TIME:-1}


sqlplus -s "$CONNECT_STRING"    <<EOF

set linesize 190 pagesize 333 feed off head off
set serveroutput on size 999999
declare
  type s is table of number INDEX BY varchar2(30) ;
  -- type t  is table of  varchar2(30) INDEX BY  varchar2(30) ;
  read1 s ;
  read2 s ;
  write1 s ;
  write2 s ;
  v_id varchar2(30) ;
begin
   for c in ( select
                    ts.name id,
                    sum(PHYRDS ) read,
                    sum(PHYWRTS) write
              from
                   v\$datafile df,
                   v\$filestat fs,
                   v\$tablespace ts
               where
                       df.FILE# = fs.FILE#
                   and ts.ts# = df.ts#
               group by ts.name,ts.ts#
               order by  1
            )
   loop
       read1(c.id) :=c.read;
       write1(c.id):=c.write;
   end loop;
   dbms_lock.sleep($SLEEP_TIME);
   for c in ( select
                    ts.name id, 
                    sum(PHYRDS ) read,
                    sum(PHYWRTS) write 
              from
                   v\$datafile df,
                   v\$filestat fs,
                   v\$tablespace ts
               where
                       df.FILE# = fs.FILE#
                   and ts.ts# = df.ts#
               group by ts.name,ts.ts#
               order by  1
            )
   loop
       read2(c.id) :=c.read;
       write2(c.id):=c.write;
       --DBMS_OUTPUT.PUT_LINE( 'id=' ||to_char(c.id) || ' name=' ||c.name || ' val=' || to_char(c.read)  );
   end loop;
   DBMS_OUTPUT.PUT_LINE ('.                                                        Diff                             Diff');
   DBMS_OUTPUT.PUT_LINE ('Name                              Read1      Read2       read      Write1      Write2     write  ' );
   DBMS_OUTPUT.PUT_LINE ('------------------------------- ----------- ----------- -------- ----------- ----------- --------') ;
   v_id:=read1.first ;
   WHILE v_id IS NOT NULL
   loop
          if read1(v_id) <> read2(v_id) or  write1(v_id) <> write2(v_id) then
            DBMS_OUTPUT.PUT_LINE(rpad(v_id,31,' ')
                                 || lpad(to_char(read1(v_id)) ,12,' ')
                                 || lpad(to_char(read2(v_id)) ,12,' ')
                                 || lpad(to_char(read2(v_id)-read1(v_id)),9,' ')
                                 || lpad(to_char(write1(v_id)) ,12,' ')
                                 || lpad(to_char(write2(v_id)) ,12,' ')
                                 || lpad(to_char(write2(v_id)-write1(v_id)),9,' ')
              );
          end if ;
          v_id:=read1.next(v_id);
    end loop ;
end ;
/


EOF
exit
# --------------------------------------------------------------
elif [ "$PAR1" = "stats2" ];then
SQL="
set lines 190 pages 66
col name format a66
col read format 99999999999 head 'Physical|Reads' justify c
col pread  head 'Read %'
col write head 'Physical| Writes'
col pwrite head 'Writes %'
col TotIO head 'Total |Block| I/O'
 break on tablespace  skip 1 on report
break on tablespace  
select  ts.name tablespace,   
        sum(PHYRDS ) read, 
        sum(round((PHYRDS / PD.PHYS_READS)*100,2)) pread,
        sum(PHYWRTS) write ,
        sum(round(PHYWRTS * 100 / PD.PHYS_WRTS,2)) pwrite,
        sum(fs.PHYBLKRD+FS.PHYBLKWRT ) totIO
        , df.NAME
from (
        select  sum(PHYRDS) PHYS_READS,
                sum(PHYWRTS) PHYS_WRTS
        from    v\$filestat
        ) pd,
        v\$datafile df,
        v\$filestat fs,
        v\$tablespace ts
where   df.FILE# = fs.FILE#
     and ts.ts# = df.ts#
group by rollup( ts.name, df.name)
union all
select  ts.name tablespace,   
        sum(PHYRDS ), 
        0 read,
        sum(PHYWRTS) write ,
        0 pwrite,
        sum(fs.PHYBLKRD+FS.PHYBLKWRT ) totIO
         ,df.NAME
from (
        select  sum(PHYRDS) PHYS_READS,
                sum(PHYWRTS) PHYS_WRTS
        from    v\$tempstat
        ) pd,
        v\$tempfile df,
        v\$tempstat fs,
        v\$tablespace ts
where   df.FILE# = fs.FILE#
     and ts.ts# = df.ts#
group by rollup( ts.name, df.name)
order   by  tablespace,name nulls first
/
"
        # , round((PHYRDS / PD.PHYS_READS)*100,2) read ,  PHYWRTS write ,  round(PHYWRTS * 100 / PD.PHYS_WRTS,2) pwrite,  fs.PHYBLKRD+FS.PHYBLKWRT totIO
# --------------------------------------------------------------
elif [ "$PAR1" = "stats" ];then
SQL="
set lines 190 pages 66
   col PHYBLKRD format a10 head 'Block|read' justify c
   col PHYBLKWRT format a10 head 'Blocks|write' justify c
   col PHYRDS format a10 head 'Physical|Reads' justify c
   col READTIM  format 9999999990.99 head 'Time | read(s)'
   col WRITETIM  format 9999999990.99 head 'Time | write(s)'
   col MAXIORTM  format 9999990.99 head 'Max read|Time(s)'
   col MAXIOWTM  format 9999990.99 head 'Max write|Time(s)'
   col MAXIOWTM  format 9999990.99 head 'Max IO|Time(s)'
   col AVGIOTIM  format 9999990.99 head 'Avg IO|Time(s)'
   col readtime format 9999990.999 head 'Avg read|(cent s)'
   col writetime format 9999990.999 head 'Avg Write|(cent s)'
   col name format a58
   select d.name,
          case 
            when PHYRDS < 1000 then lpad(to_char(PHYRDS),10)
            when PHYRDS >= 1000 and PHYRDS< 100000  then lpad(trim(to_char(PHYRDS/100000,'9990.99')||' k'),10)
            when PHYRDS >= 100000 then lpad(trim(to_char(PHYRDS/100000,'9990.99')||' m'),10)
          end  PHYRDS,
          case 
            when PHYBLKRD < 1000 then lpad(to_char(PHYBLKRD),10)
            when PHYBLKRD >= 1000 and PHYBLKRD< 100000  then lpad(trim(to_char(PHYBLKRD/100000,'9990.99')||' k'),10)
            when PHYBLKRD >= 100000 then lpad(trim(to_char(PHYBLKRD/100000,'9990.99')||' m'),10)
          end  PHYBLKRD,
          case 
            when PHYBLKWRT < 1000 then lpad(to_char(PHYBLKWRT),10)
            when PHYBLKWRT >= 1000 and PHYBLKWRT< 100000  then lpad(trim(to_char(PHYBLKWRT/100000,'9990.99')||' k'),10)
            when PHYBLKWRT >= 100000 then lpad(trim(to_char(PHYBLKWRT/100000,'9990.99')||' m'),10)
          end  PHYBLKWRT
          , READTIM/100 READTIM, WRITETIM/100 WRITETIM
          , MAXIORTM/100 MAXIORTM, MAXIOWTM/100  MAXIOWTM, AVGIOTIM/100 AVGIOTIM,
           (f.readtim / decode(f.phyrds,0,-1,f.phyrds)) readtime,
           (f.writetim / decode(f.phywrts,0,-1,phywrts)) writetime
   from v\$filestat f, v\$datafile d
   where f.file# = d.file#
/
"
# --------------------------------------------------------------
elif [ "$PAR1" = "checkpoint" ];then

SQL="
set echo off pause off feedback off verify off pagesize 100 linesize 120
set termout on heading off embedded off verify off

ttitle skip 1 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List last checkpoint time  for each datafile ' nline from sys.dual
/
set linesize 190
set heading on
col name format A90 heading 'Name'
col ltime format A20 heading 'Date'
col Checkpoint format 999,999,999,999.0  heading 'Checkpoint'

select name, checkpoint_change# Checkpoint,
       to_char(checkpoint_time, 'YYYY-MM-DD HH24:MI:SS')  ltime
       from v\$datafile_header
/
"
# --------------------------------------------------------------
elif [ "$PAR1" = "es" ];then
sqlplus -s  "$CONNECT_STRING" <<EOF
set head off pagesize 333 linesize 190
select 'alter database datafile '''|| a.file_name ||''' autoextend off;'  from
   dba_data_files a, (
select file_name, bytes/1024/1024 bytes,increment_by next,maxbytes/1024/1024 maxsize from dba_data_files where
autoextensible='YES' and (bytes + increment_by) > maxbytes) b
where a.file_name = b.file_name
/
EOF

# --------------------------------------------------------------
elif [ "$PAR1" = "autoextend" ];then
sqlplus -s  "$CONNECT_STRING" <<EOF

ttitle  'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pause off pagesize 66 linesize 80 heading off embedded off verify off termout on

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List - Datafile that cannot extend ' from dual;
set pagesize 333 linesize 124 head on
col file_name format a65
col bytes format 99990.99 head "Size(meg)"
col maxsize format 99990.99 head "Maxsize(meg)"
select file_name, bytes/1024/1024 bytes,increment_by next,maxbytes/1024/1024 maxsize from dba_data_files where
autoextensible='YES' and (bytes + increment_by) > maxbytes;
EOF
exit
# --------------------------------------------------------------------------
elif [ "$PAR1" = "shrink" ];then

if [ -n "$TBS" ];then
    WHERE_TBS=" where tablespace_name = upper('$TBS') "
fi
SQL="
ttitle  'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pause off pagesize 66 linesize 80 heading off embedded off verify off termout on

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List - Datafile shrinkable ' from sys.dual
/

Prompt .        lstd -s   to display SQL statement to shrink
prompt
set embedded on linesize 124 pagesize 66 heading on
col name format a65
col fdiff head 'Diff' format 9999990
break on report
compute sum LABEL 'TOTAL'  of hwm  on report 
compute sum  of target  on report 
compute sum of curr on report 
compute sum of fdiff on report 


select 
   name, curr, hwm, target,
   case when fdif  < 0 then 0 else fdif end fdiff
from (
select
       df.name, ceil(hwm.mb)              hwm,
       20*ceil((hwm.mb-1)/20)+1           target,
       round(df.bytes/1048576,0)          curr,
       round(df.bytes/1048576,0) - (20*ceil((hwm.mb-1)/20)+1 ) fdif
from v\$datafile df,
     ( select file_id,
              max((bytes/blocks)*(block_id+blocks-1))/1048576  mb
         from dba_extents $WHERE_TBS group by file_id ) hwm
where hwm.file_id = df.file# 
  -- and 20*ceil((hwm.mb-1)/20)+1 < ceil(df.bytes/1048576)
order by df.ts#, df.name
)
/
"
# --------------------------------------------------------------------------
elif [ "$PAR1" = "shrink2" ];then
TBS="$TBS"
FID="$FID"
if [ -n "$TBS" ];then
    WHERE_TBS=" where tablespace_name = upper('$TBS') "
    if [ -n "$FID" ];then
       WHERE_TBS="$WHERE_TBS and file_id = $FID"
    fi
elif [ -n "$FID" ];then
    WHERE_FID=" where file_id= $FID"
fi
SQL="
set linesize 125
set head off
select
       'alter database datafile '''||df.name|| ''' resize ' ||
       to_char(20*ceil((hwm.mb-1)/20)+1)    || 'm;'
from 
   v\$datafile df, 
   ( select file_id, max((bytes/blocks)*(block_id+blocks-1))/1048576  mb
         from dba_extents $WHERE_TBS $WHERE_FID group by file_id 
   ) hwm
where 
      hwm.file_id = df.file# and
      20*ceil((hwm.mb-1)/20)+1 < ceil(df.bytes/1048576)
order by df.ts#, df.name
/
"
# --------------------------------------------------------------------------
else

if [ -n "$TBS" ];then
    WHERE_TBS=" where tablespace_name = upper('$TBS') "
    AND=" and 1=2"
fi
sqlplus -s  "$CONNECT_STRING" <<EOF
   ttitle  'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pause off pagesize 66 linesize 80 heading off embedded off verify off termout on

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List of all datafiles, size, autoextent, next, maxsize and tablespaces  '
from sys.dual
/
        set pages 0 verify off feed off echo off head off linesize 190
        column nline newline
        col member format a70
        col ctrl format a70
        col ctl for a16
        col name format a70
        col gr format a5
        col file_id format a8
        col megs format 9999999990.9
        col mmegs format 99999990.9
        col next format 9999
        col file_name format a70
        col tablespace_name format a25
        col status format a1
        col value new_value db_block_size noprint
        select '                                                                          Size                  Auto    Max      Next' nline , 'Datafile/redo/control                                                    (meg)     Type  id    Extend   Size    (meg) Tablespace' nline , '========================================================================================================================' nline ,
        value from v\$parameter where name = 'db_block_size'  ;

        break on tablespace_name
        select rpad(name,72) ctrl, 0 megs , 'Control file' ctl, null gr ,null,null from v\$controlfile where 1=1 $AND
        union all
        select  member, (bytes/1024/1024) megs,
               'Redo', 'gr:'||to_char(l.group#) gr, ' ',lower(l.status)
               from v\$log l, v\$logfile f
               where f.group# = l.group# $AND
        union
        select  member, (bytes/1024/1024) megs,
               'stbyRedo', 'gr:'||to_char(l.group#) gr, ' ',lower(l.status)
               from v\$standby_log l, v\$logfile f
               where f.group# = l.group# $AND
        order by  gr  ;

        select file_name , trunc(bytes/1024/1024,1)  megs,
               'Dbf', ' id:' || to_char(file_id) file_id , lower(substr(autoextensible,1,1)) satus,
                maxbytes/1024/1024 mmegs, (increment_by*&db_block_size)/1024/1024 next, tablespace_name
               from dba_data_files $WHERE_TBS order by tablespace_name,file_name;

        select file_name , trunc(bytes/1024/1024,1)  megs,
               'Tmp', ' id:' || to_char(file_id) file_id , lower(substr(autoextensible,1,1)) status,
                maxbytes/1024/1024 mmegs, (increment_by*&db_block_size)/1024/1024 next,tablespace_name
               from dba_temp_files  $WHERE_TBS order by tablespace_name,file_name;
EOF
exit
fi

if [ -n "$VERBOSE" ];then
   echo "$SQL"
fi

sqlplus -s "$CONNECT_STRING" <<EOF
$SQL
EOF
