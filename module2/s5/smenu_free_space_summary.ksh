#!/bin/ksh
# set -xv
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SBIN2=${SBIN}/module2
WK_SBIN=${SBIN}/module2/s5
TMP=$SBIN/tmp
FOUT=$TMP/free_space_summary_$ORACLE_SID.txt
function help
{
cat <<EOF

     Tablespace informations:

     frg
     frg -b|-g [-t <tablespace name> ]
     frg -os -t <tablespace name> -rn <nn> -u <OWNER>
     frg -xt -t <tablespace>
     frp -id <file id>
     frg -i
     frg -dus <user>                                       # If <user> is not given then all schema are processed
     frg -cr [<tablespace name>] [-q]                      # Generate statement to create tablespace, if no tbs name, 
                                                           # then create statement for all.
 
     frg -s                                                # summary of quota for all tablespaces
     frg -f                                                # fast summary without free frags size details
     frg -tmp                                              # List temp usage
     frg -aux                                              # List sysaux usage
     frg -rcb [-ot] -cpt                                   # Show recyclebin objects & size, -ot : sort by time -cpt : only show counts
     frg -t <tablespace> -hist <n>

     frg [-xt <tablespace_name>] [-id <datafile_id>]

        -b : figures in bytes
      -dus : Disk usage per user per tablespace
        -g : figures in Giga bytes
        -i : List metadata info on tablespaces
       -rn : Limite selection to <nn> rows
        -q : add user quota on tbs 
       -os : List Object size
        -t : limit to this tablespace, it accpet partial name
       -xt : list extend occupation per datafile per tablespace
       -id : list extend occupation for the datafile id  <datafile_id>
     -hist : report tablespace history growth for the last n month

        -h : this help



EOF
exit
}
typeset -u PAR2
typeset -u fnew
typeset -u ftbs
ROWNUM=50
while [ -n "$1" ]
do
 case "$1" in
    -aux   ) CHOICE=SYSAUX ;;
    -b | b ) UNIT=B;;
        -f ) CHOICE=FAST;;
    -g | g ) UNIT=G ; VAR=Gigs;;
      -cr  ) CHOICE=CREATE 
             if [ -n "$2" -a ! "$2" = '-q' ] ;then
                  ftbs=$2; shift
             fi
             ;;
     -dus  ) CHOICE=DUS
             if [ -n "$2" ];then
               TARGET_OWNER=$2 ; shift
               WHERE=where
               unset OWN_SYS
               AND_OWNER=" OWNER=upper('$TARGET_OWNER')"
             fi
              ;;
       -i  ) CHOICE=INFO ;;
      -id  ) FILE_ID=$2; shift ;;
      -os  ) CHOICE=LIST_OBJECT_SIZE;;
     -hist ) CHOICE=HIST_GROWTH  ; ROWNUM=$2 ;;
     -new  ) fnew=$2 ; shift ;;
       -q  ) QUOTA=TRUE ;;
     -rcb  ) CHOICE=RECYCLEBIN ;;
     -cpt  ) COUNT_RECYCLE=TRUE;;
       -ot ) R_ORDER=fdate; BREAK="comp sum of fsize on fdate" ;;
       -s  ) CHOICE=SUMMARY ;;
       -t  ) PAR2=$2 ; AND_TBS=" and b.tablespace_name like '%$PAR2%'"; shift ;;
-tmp|-temp ) CHOICE=TEMP  ;;
       -u  ) AND_OWNER=" and owner = upper('$2')"; shift ;;
      -rn  ) ROWNUM=$2; shift ;;
       -v  ) set -xv ;;
      -xt  ) CHOICE=XT ;;
       -h  ) help ;;
        *  ) echo "Unknonw parameters $1";;
    esac
    shift
done
if [ -n "$FILE_ID" -a -z "$CHOICE" ];then
        CHOICE=XT
fi
UNIT=${UNIT:-M}
VAR=${VAR:-Megs}
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get the password of $S_USER"
   exit 0
fi
echo
if [ $UNIT = 'B' ];then
     sqlplus -s  "$CONNECT_STRING" @$WK_SBIN/smenu_free_space_summary $HOST $ORACLE_SID $FOUT
     exit
fi

if [ "$UNIT" = "M" ];then
   DIV=1048576
   SIZE_MB="Size(mb)"
else
   DIV=1073741824
   SIZE_MB="Size(G)"
fi
# ........................................................
#          Main
# ........................................................
# ........................................................
# ........................................................
if [ "$CHOICE" = "HIST_GROWTH" ];then
   if [ -n "$PAR2" ] ;then
        ftbs=`echo $PAR2 | awk '{print toupper($0)}'`
        AND_TBS="and  tablespace_name = '$ftbs' "
   fi

sqlplus -s "$CONNECT_STRING" <<EOF

column nline newline
set pagesize 66 linesize 80 heading off pause off embedded off verify off
select host_name ' - ORACLE_SID : $ORACLE_SID  ', 
'Date                -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username            -  '||USER || '       Tablespace growth history: $fstab ' 
from v\$instance
/
set lines 190 pages 900 head on
set numwidth 20 
set pagesize 50 
COL NAME FOR A30 
col SNAP_ID for 9999999 
col Fdiff head 'Delta|per day' for 999999
col perc head '%|occupancy' justify C for 999999.99
col fdate head 'Date'
set serveroutput off; 
col size_mb head 'Size(mb)' for 9999999999
col used_mb head 'Used(mb)' for 9999999999
SPOOL TBS_TREND.xls; 
set verify off; 
set echo off; 

select name, fdate,USED_MB, SIZE_MB, used_mb - lead(USED_MB) over ( order by fdate desc) Fdiff,
  round(USED_MB/SIZE_MB*100,2)perc
  from (
with v1 as ( select value as bs from v\$parameter where name = 'db_block_size' )
   , v2 as ( select dbid from v\$database )
   , v3 as (
             select SNAP_ID, fdate from (
             select SNAP_ID,
                    to_char(END_INTERVAL_TIME,'YYYY-MM-DD HH24:MI' ) fdate,   
                    rank ( ) over ( partition by to_char(END_INTERVAL_TIME,'YYYY-MM-DD') order by END_INTERVAL_TIME desc ) rnk
             from DBA_HIST_SNAPSHOT h, v2 where v2.dbid =  h.dbid
                  order by END_INTERVAL_TIME desc
             )
              where rnk = 1
              order by fdate
           )
select * from (
SELECT 
    distinct T.NAME, v3.fdate,
    ROUND((ht.TABLESPACE_USEDSIZE*v1.bs)/1048576) AS USED_MB, 
    ROUND((ht.TABLESPACE_SIZE*v1.bs)/1048576) AS SIZE_MB
FROM 
    DBA_HIST_TBSPC_SPACE_USAGE ht,
    V\$TABLESPACE t,
    v1, V2 , v3
WHERE 
        t.name = '$ftbs'
    and t.TS#=ht.TABLESPACE_ID 
    and ht.SNAP_ID=v3.SNAP_ID 
    and ht.dbid = v2.dbid
ORDER BY 2 desc )
where ROWNUM <=$ROWNUM
) order by fdate desc
/
EOF

  
# ........................................................
elif [ "$CHOICE" = "RECYCLEBIN" ];then
R_ORDER=${R_ORDER:-space}
if [ "$COUNT_RECYCLE" = "TRUE" ];then
    VAR1='count(*) rcpt'
    ROWNUM=100000000000
else
    VAR1='*'
fi
echo "MACHINE $HOST - ORACLE_SID : $ORACLE_SID  "
sqlplus -s "$CONNECT_STRING" <<EOF
column nline newline
set pagesize 66 linesize 80 heading off pause off embedded off verify off
select 'Date                -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username            -  '||USER || '        Show recyclebin usage:'
from sys.dual
/
set lines 190 pages 900 head on
col type for a20
col ORIGINAL_NAME head 'Name' for a30
col OBJECT_NAME head 'Original Name' for a30
col owner format a30
col fdate for a10 head "drop Date"
col ftime for a10 head "drop Time"
col rcpt for 9999999 head "Objects in recycle_bin"

break on fdate on report
$BREAK
comp  sum Label 'Grand total' of fsize on report

select $VAR1 from (
with v as ( select value as bs from v\$parameter where name = 'db_block_size' )
select OWNER, ORIGINAL_NAME, 
       substr(droptime,1,10) fdate , substr(droptime,12,8) ftime ,
       can_undrop undrop, can_purge purge, 
      round(space * bs/1048576,1) fsize, object_name, type, ts_name as tablespace
     from dba_recyclebin, v order by $R_ORDER desc
) where rownum  <= $ROWNUM
/
EOF
# ........................................................
elif [ "$CHOICE" = "SYSAUX" ];then
sqlplus -s "$CONNECT_STRING" <<EOF
  set lines 190 pages 66
  col occupant_name for a30
  SELECT occupant_name, occupant_desc, round(space_usage_kbytes/1024,1) as usage_mb 
         FROM v\$sysaux_occupants  order by 3 desc;
EOF
# Taken from tanel script
# http://blog.tanelpoder.com/files/scripts/temp.sql
# ........................................................
elif [ "$CHOICE" = "TEMP" ];then
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 1 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID ' right 'Page:' format 999 sql.pno skip 1
column nline newline
set pagesize 66 linesize 80 heading off pause off embedded off verify off
select 'Date                -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username            -  '||USER || '        Show Temp usage:'
from sys.dual
/
col username for a30
set lines 190 head on pages 90
SELECT 
    u.inst_id
  , u.username
  , s.sid
  , u.session_num serial#
  , u.sql_id
  , u.tablespace
  , u.contents
  , u.segtype
  , ROUND( u.blocks * t.block_size / (1024*1024) ) MB
  , u.extents
  , u.blocks
FROM 
    gv\$tempseg_usage u
  , gv\$session s
  , dba_tablespaces t
WHERE
    u.session_addr = s.saddr
AND u.inst_id = s.inst_id
AND t.tablespace_name = u.tablespace
ORDER BY
    mb DESC
/
EOF
exit
# ........................................................
elif [ "$CHOICE" = "FAST" ];then
# found in Oracle forum, posted by a Guest :
# https://forums.oracle.com/thread/507636?start=0&tstart=0
sqlplus -s "$CONNECT_STRING" <<EOF
col "Tablespace" for a22
col "Used MB" for 99,999,999
col "Free MB" for 99,999,999
col "Total MB" for 99,999,999

select 
       df.tablespace_name "Tablespace", totalusedspace "Used MB",
      (df.totalspace - tu.totalusedspace) "Free MB",
      df.totalspace "Total MB",
      round(100 * ( (df.totalspace - tu.totalusedspace)/ df.totalspace)) "Pct. Free"
from
      (select tablespace_name, round(sum(bytes) / 1048576) TotalSpace
              from dba_data_files 
       group    by tablespace_name ) df,
      (select round(sum(bytes)/(1048576)) totalusedspace, tablespace_name
              from dba_segments 
              group by tablespace_name) tu
where 
       df.tablespace_name = tu.tablespace_name 
order by 1;
EOF
# ........................................................
# ........................................................
# based on an Idea of J.Lewis : http://jonathanlewis.wordpress.com/tablespace-hwm
# adapted to Smenu by bpa
elif [ "$CHOICE" = "XT" ];then
   if [ -n "$PAR2" ] ;then
         DBA_DATA_FILES=" , dba_data_files "
      ftbs=`echo $PAR2 | awk '{print toupper($0)}'`
      AND_TBS="and  tablespace_name = '$ftbs' "
   fi
   if [ -n "$FILE_ID" ] ;then
         AND_FID=" and FILE_ID=$FILE_ID "
         DBA_DATA_FILES=" , dba_data_files "
   fi
   # redefine ROWNUM if is was left to default 30
   if [ $ROWNUM  = 30 ];then
         ROWNUM=11
   fi 
   echo "List the HWM Extent occupancy per datafile"
sqlplus -s "$CONNECT_STRING" <<EOF
set pagesize 66 long 100000 linesize 190
col segment_name for a30
set head on
col mb_so_far head 'Address|in(Meg) ' for 999999 justify c
col size_mb head 'Total|File| size(mb)' for 999999 justify c
with v as ( select value as bs from v\$parameter where name = 'db_block_size' )
select 
     x.file_id, block_id, end_block, owner,segment_name, partition_name, 
     segment_type, bs*end_block/1048576 mb_so_far, 
     trunc(a.bytes/1048576) size_mb
     from (
select 
     file_id, block_id, end_block, owner,segment_name, partition_name, segment_type,
     row_number () over ( partition by file_id order by block_id desc ) rnk
     from (
select     
   file_id, block_id, 
   block_id + blocks - 1   end_block,     
   owner,     
   segment_name,     
   partition_name,     
   segment_type 
from     dba_extents 
where 1=1  $AND_TBS $AND_FID
union all 
select     
   file_id,     
   block_id,     
   block_id + blocks - 1   end_block,     
   'free'   owner,     
   'free' segment_name,     
   null   partition_name,     
   null   segment_type 
from  dba_free_space where      1=1 $AND_TBS $AND_FID
union all
select 
   file# file_id, 
   block# block_id,
   block# + space -1 end_block,
   'recyclebin' owner ,
   original_name segment_name ,
   partition_name,
   decode(type#, 1, 'TABLE', 2, 'INDEX', 3, 'INDEX',
                       4, 'NESTED TABLE', 5, 'LOB', 6, 'LOB INDEX',
                       7, 'DOMAIN INDEX', 8, 'IOT TOP INDEX',
                       9, 'IOT OVERFLOW SEGMENT', 10, 'IOT MAPPING TABLE',
                       11, 'TRIGGER', 12, 'CONSTRAINT', 13, 'Table Partition',
                       14, 'Table Composite Partition', 15, 'Index Partition',
                       16, 'Index Composite Partition', 17, 'LOB Partition',
                       18, 'LOB Composite Partition',
                       'UNDEFINED') segment_type
from 
   sys.recyclebin$ a , dba_data_files
      where  file# = file_id $AND_TBS $AND_FID
order by 3 desc, 1,2
) order by 3 desc, 1,2
) x, v, dba_data_files a
where a.file_id = x.file_id
  and rnk < $ROWNUM
order by 3 desc, 1,2
/

EOF
exit   
# ........................................................

elif [ "$CHOICE" = "SUMMARY" ];then
  # 
  # Flying Sideways : bill doyle
  # A nice procedure from 'http://freespace.virgin.net/bill.doyle/or1_tsus.htm'
  # 
sqlplus -s "$CONNECT_STRING" <<EOF
set serveroutput  on
set pagesize 0 long 100000 heading off linesize 132 

declare
  cursor c_datafiles is
    select tablespace_name, sum( bytes ) "SumBytes"
    from dba_data_files
    group by tablespace_name;
  cursor c_sum_used ( x_ts_name in varchar2 ) is
    select sum( bytes )
    from dba_segments
    where tablespace_name = x_ts_name;
  cursor c_user_segs ( x_ts_name in varchar2 ) is
    select owner, sum( bytes ) "SumBytes"
    from dba_segments
    where tablespace_name = x_ts_name
    group by owner;
  li_sum_used number;
  ls_hdr1 varchar2( 2000 );
  ls_hdr2 varchar2( 2000 );
  ls_outline varchar2( 2000 );
  li_counter number := 0;
begin
  ls_hdr1 := rpad( 'Tablespace', 30 ) ||
             'Size (Mb)' || ' ' ||
             '     Used' || ' ' ||
             rpad( 'Owner', 33 ) || ' ' ||
             ' Used (Mb)' || ' ' ||
             '   % Total' || ' ' ||
             '    % Used';
  ls_hdr2 := rpad( '----------', 30 ) ||
             '---------' || ' ' ||
             '---------' || ' ' ||
             rpad( '-----', 33 ) ||
             '  ---------' || ' ' ||
             '   -------' || ' ' ||
             '    ------';
  dbms_output.put_line ( ls_hdr1 );
  dbms_output.put_line ( ls_hdr2 );
  for i in c_datafiles loop
    li_counter := li_counter + 1;
    open c_sum_used( i.tablespace_name );
    fetch c_sum_used into li_sum_used;
    close c_sum_used;
    ls_outline := rpad( i.tablespace_name, 30 ) ||
                  to_char( ( i."SumBytes" )/ ( 1024 * 1024 ), '9999,999' ) || ' ' ||
                  to_char( ( li_sum_used )/ ( 1024 * 1024 ), '9999,999' );
    for j in c_user_segs( i.tablespace_name ) loop
      if li_counter > 1 then
        ls_outline := '.' ||rpad( ' ', 47 ) || ' ';
      end if;
      ls_outline := ls_outline || ' ' ||
                                  rpad( j.owner, 30 ) ||
                                  to_char( ( j."SumBytes" )/ ( 1024 * 1024 ), '99,999,999.99' ) ||
                                  to_char( ( j."SumBytes" / i."SumBytes" ) * 100 , '999,999.99' ) ||
                                  to_char( ( j."SumBytes" / li_sum_used ) * 100, '999,999.99' );
      dbms_output.put_line( ls_outline );
      li_counter := li_counter + 1;
    end loop;
    dbms_output.put_line( ' ' );
    li_counter := 0;
  end loop;
end;
/
EOF
elif [ "$CHOICE" = "CREATE" ];then
   if [ -n "$ftbs" ];then
       WHERE=" where tablespace_name = '$ftbs' "
   fi
   if [ "$QUOTA" = "TRUE" ];then
       SQL_QUOTA="select 'alter user ' || USERNAME || ' quota ' || decode (MAX_BYTES,-1,' unlimited' , MAX_BYTES ) ||
                ' on ' ||  TABLESPACE_NAME || ';' from dba_ts_quotas $WHERE order by username ;"
   fi
sqlplus -s "$CONNECT_STRING" <<EOF
set serveroutput on 
set pagesize 0 long 100000 heading off linesize 132 

select dbms_metadata.get_ddl('TABLESPACE',dba_tablespaces.tablespace_name) from dba_tablespaces $WHERE;
$SQL_QUOTA
EOF
exit
# ........................................................
elif [ "$CHOICE" = "DUS" ];then
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID ' right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 heading off pause off embedded off verify off
select 'Date                -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username            -  '||USER  nline ,
       'Database usage per user and tablespace' nline
from sys.dual
/
prompt
set linesize 190
comp sum of ttotal on report
break on report
col Owner head "User" justify l
col tablespace_name format A27 head "Tablespace" justify l
col ttotal format 999,999,990 head "Total space|By $SIZE_MB" justify c
col totbytes justify center format 999,999,999 head "Tablespace|$SIZE_MB" justify c
col tbsperc justify right format A10 head "Percent in|Tablespace"
col pctusdf format   a14 justify c heading '% tbs used| with Auto ext'
col Owner head "User" justify l
col fsize format 99990.99 head "$SIZE_MB"

set embedded on pause off heading on feedback off PAGESIZE 50 FEEDBACK OFF LINESIZE 124 space 1

select owner, a.tablespace_name, sum(bytes/$DIV)   ttotal,
       totbytes, '   '||lpad(decode(totbytes,0,'0.0','   ' || to_char(round((sum(bytes/$DIV)*100)/totbytes,2))),4,' ')   || '%' tbsperc,
       '   '||lpad(decode(b.maxbytes,0, 0,round(100-((b.maxbytes-(b.totbytes-c.freebytes))/b.maxbytes*100),2)),4,' ') || '%  ' pctusdf
    from dba_extents a ,
         ( select tablespace_name, trunc(sum(bytes/$DIV)) totbytes, sum(maxbytes/$DIV) maxbytes
                 from dba_data_files group by tablespace_name
         union all
          select tablespace_name, sum(bytes/$DIV) totbytes,  sum(maxbytes/$DIV) maxbytes
                 from dba_temp_files group by tablespace_name) b,
         (select sum(bytes/$DIV) freebytes ,tablespace_name from dba_free_space group by tablespace_name) c
    where  $OWN_SYS $AND_OWNER
    and a.tablespace_name = b.tablespace_name
    and a.tablespace_name = c.tablespace_name (+)
  group by owner, a.tablespace_name, totbytes,decode(b.maxbytes,0, 0,round(100-((b.maxbytes-(b.totbytes-c.freebytes))/b.maxbytes*100),2))
  order by owner;
EOF
exit
elif [ "$CHOICE" = "INFO" ];then

sqlplus -s "$CONNECT_STRING" <<!EOF
clear screen
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID ' right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 190 heading off pause off embedded off verify off
select 'Date                -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username            -  '||USER  nline ,
       'Tablespace default values ' nline
from sys.dual
/
prompt
set embedded on pause off
set heading on
set feedback off PAGESIZE 50 FEEDBACK OFF LINESIZE 164 space 1
COLUMN Tablespace_name FORMAT           A25 HEADING 'Tablespace Name'
COLUMN INITIAL_EXTENT FORMAT  9,999,999 HEADING 'Default|Initial|Extent(k)' justify c
COLUMN NEXT_EXTENT FORMAT  9,999,999 HEADING 'Default|Next|Extent(k)' justify c
COLUMN MIN_EXTENTS FORMAT 9,999 HEADING 'Min|Ext.' justify c
COLUMN logging FORMAT  A12 HEADING 'Logging|mode' justify c
COLUMN force_logging FORMAT  A4 HEADING 'Force|Logging' justify c
COLUMN PCT_INCREASE FORMAT  990 HEADING 'Pct|Increase' justify c
COLUMN STATUS FORMAT  A9 HEADING 'Status'  justify c
COLUMN EXTMAN FORMAT  A8 HEADING 'Extent|Manag.'  justify c truncate
COLUMN ALLOC FORMAT  A6 HEADING 'Alloc.|Type.'  justify c truncate
COLUMN CONTENTS FORMAT  A4 HEADING 'Type'  justify c truncate
COLUMN assm FORMAT  A4 HEADING 'ASSM'  justify c truncate
COLUMN AUTO FORMAT  A6 HEADING 'Auto|Ext'  justify c truncate
column block_size format 999999 heading "Block|size"
col xtprob  format a8 justify c heading 'next ext|problem'

select a.tablespace_name,INITIAL_EXTENT/1024 INITIAL_EXTENT,NEXT_EXTENT/1024 NEXT_EXTENT,
       decode(s.fext,0,'',NULL,'','S') xtprob,
       logging,PCT_INCREASE,STATUS, CONTENTS,
       decode(FILEXT,'Y','  Y','  N')  AUTO , EXTENT_MANAGEMENT EXTMAN, ALLOCATION_TYPE ALLOC,SEGMENT_SPACE_MANAGEMENT assm, a.block_size
from  dba_tablespaces a,
      ( select distinct tablespace_name, 'Y' FILEXT from dba_data_files where AUTOEXTENSIBLE = 'YES') b,
      ( select count(*) fext , tablespace_name from dba_segments x
          where next_extent > (Select Max(bytes)
                                      From dba_free_space
                                      Where Tablespace_name = x.Tablespace_name)
          and next_extent > (Select Max(Maxbytes - Bytes)
                                      From dba_data_files
                                      Where Tablespace_name = x.Tablespace_name)
          Group by tablespace_name
       ) s
where a.tablespace_name = b.tablespace_name (+)
   and a.Tablespace_name = S.Tablespace_name(+)
/
prompt
exit
!EOF

elif [ "$CHOICE" = "LIST_OBJECT_SIZE" ];then
     if [ -n "$PAR2" ];then
        WHERE_TABLESPACE_NAME="where tablespace_name = upper('$PAR2')"
     else
         TBS=" , tablespace_name "
     fi
     #cat  <<EOF
     sqlplus -s  "$CONNECT_STRING" <<EOF

set pause off pagesize 66 linesize 80 heading off embedded off verify off termout on
ttitle  'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   '         Page:' format 999 sql.pno skip 2
column nline newline
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List object size into tablespace $PAR2 (limited to first $ROWNUM rows) ' nline from sys.dual
/
set linesize 132 head on
col segment_name format a55
col owner format a14
col mb format 999990.9 head "$SIZE_MB"
col tablspace_name format a16
prompt  Type 'frg -h' for help
prompt
break on owner on report
comp sum of mb  on report
select s.owner $TBS,
       s.segment_name || (case when s.partition_name is null then ''
                 else '.' || s.partition_name end) as segment_name,
       s.segment_type, s.size_m as mb
from
  (select segment_name $TBS, partition_name, owner, bytes/$DIV size_M, segment_type
     from dba_segments $WHERE_TABLESPACE_NAME $AND_OWNER order by size_M desc) s
  where rownum <= $ROWNUM;

EOF
# --------------------- main ---------------------------------------------------------
else # default --> return tablespace list
#ttitle  'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
     sqlplus -s  "$CONNECT_STRING" <<EOF

column nline newline
set pause off pagesize 66 linesize 80 heading off embedded off verify off termout on
select 'Machine ' || rpad(host_name,9) || ' -  ORACLE_SID : $ORACLE_SID  ', 
       'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'FREE - Free space summary by Tablespace  ' nline
 from v\$instance
/
prompt  Type 'frg -h' for help
prompt
set embedded on pagesize 66 linesize 124 heading on
comp sum of nfrags totsiz avasiz on report
break on report

set feed on
column dummy noprint
col name  format         a25 justify c heading 'Tablespace'
col nfrags  format     999,990 justify c heading 'Free|Frags'
col mxfrag  format 9,999,990.0 justify c heading 'Largest|Frag ($VAR)'
col totsiz  format 99,999,990.0 justify c heading 'Total|($VAR)'
col avasiz  format 99,999,990.0 justify c heading 'Available|($VAR)'
col pctusd  format         990 justify c heading '%|Used'
col pctusdf format         990 justify c heading '% used| Auto ext'


SELECT -- /*+ ordered */ 
       h.tablespace_name name, 0 nfrags,0 mxfrag,
       sum(h.bytes_free+h.bytes_used)/$DIV totsiz,
       ROUND ( SUM ( (h.bytes_free + h.bytes_used) - NVL (p.bytes_used, 0)) / $DIV) avasiz,
       ROUND (SUM (NVL (p.bytes_used, 0)) / $DIV)  pctusd, 0 pctusdf
FROM v\$temp_space_header h, 
     sys.v_\$Temp_extent_pool p
WHERE p.file_id(+) = h.file_id
      AND p.tablespace_name(+) = h.tablespace_name
GROUP BY h.tablespace_name
union all
select  b.tablespace_name  name,
        nfrags,
        nvl(mxfrag/$DIV,0) mxfrag,
        nvl(totbytes/$DIV,0) totsiz,
        nvl(freebytes/$DIV,0) avasiz,
        decode(b.totbytes,0, 0,round(100-((b.totbytes-(b.totbytes-a.freebytes))/b.totbytes*100),2)) pctusd,
        decode(b.maxbytes,0, 0,round(100-((b.maxbytes-(b.totbytes-a.freebytes))/b.maxbytes*100),2)) pctusdf
from
  (select sum(bytes) freebytes ,tablespace_name from dba_free_space group by tablespace_name) a,
  (select sum(bytes) totbytes, sum(decode(maxbytes,0,bytes,maxbytes)) maxbytes, tablespace_name from  dba_data_files group by tablespace_name)  b,
  (select count(1)  nfrags , max(bytes) mxfrag , tablespace_name from dba_free_space group by tablespace_name) c
where
      b.tablespace_name = a.tablespace_name(+) $AND_TBS
  and b.tablespace_name = c.tablespace_name (+)
order by  1
/
exit
EOF

fi

