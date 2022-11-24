#!/bin/ksh
# set -xv
# program smenu_desc_idx.sh
# Author : Bernard Polarski : 07/12/99
#                             rewritten 23 september 2005
#                             Bart Debersaques : Add size on index
#                             bpa              : Add count on unusable indexes
#                             bpa              : add -inv options for quick list all invalids
#                             bpa              : reviewed 15-december-2009
#                                              : Added move tablespace and recognition of function based and domain index

#--------------- comments section ---------------------
# This script is part of the module 3 (DB utilities) in smenu
# Purpose : List all about indexes
# -----------------------------------------------------
function get_snap_beg_end
{
    ret=`sqlplus -s "$CONNECT_STRING"  <<EOF
column instance_number   new_value instance_number  noprint
select instance_number from   v\\$instance ;
 set head off verify off feed off pause off
col beg_id new_value beg_id
col end_id new_value end_id

select  beg_id,end_id from (
  select beg_id,end_id,rank() over (order by rownum ) rn from (
select  rownum, snap_id beg_id, lag(snap_id,1) over (order by begin_interval_time desc ) end_id
        from
            sys.wrm\\$_snapshot
         where instance_number=&instance_number $AND_DBID
        order by begin_interval_time desc)) where rn=2;
EOF`
 echo "$ret" | sed '/^$/d' | tr -d '\n'
# the output of 2 rows is the return of this function
}
#--------------- Environement section ---------------------
HOST=`hostname`
#--------------- Function variables section ---------------------
function help
    {
    cat <<EOF

       Usage  :
                idx -u <owner>  -i <index> -t <table> -h -cf -fb -p -s        : (see below for display options)
                idx -u <owner>  -tbs                                          : List all indexes for given schema, -tbs show tablspaces
                idx -u <owner>  -t <table_name>                               : List all index for given table
                idx -u <owner>  -i <index> -ntbs <new tablespace>  [-x]       : Gen. statements move index to new tablespace
                idx -u <owner>  -ief <index>  [ -spbl <nn> ]                  : Report Index efficiency, optionally using sample 'n' blocks
                idx -lief [-u <owner>] [-t <table>] [-pb <n> -pb <n>][-pct <n>]   : List index which are suspicious right handed (for schema or table)
                                                                                    optionally : pa -> percent > n ; pb <= percent < n
                idx -sief [-u <owner>] [-t <table>] -pct <nn> -wrk <nn> -par <n> : Generate statement to rebuild indexe which n% of Optimal (see -lief)
                                                                                 : -wkr <number of worker> -par <parallel>
                idx -u <owner>  -scoal <index>                                : Generate the statement to coalesce (partitionned)index
                idx -u <owner>  -inv / -sinv / -sinvall                       : List invalid index / sinv: generate statement to rebuld
                idx -u <owner> -i <index> -ddl                                : Generated the index creation statement
                idx -u  <owner> -i <index> -ph                                : List all partitions keys
                idx -u  <owner> [ -t <table> ] -lu -b <snap_id> -e <snap_id>  : List unused indexes, optionaly restrict to period
                                                                                delimited by snapshot_id. Use 'aw -l' to view periods
                idx -u <owner> [-i <index>][-like <index>] -use               : List the SQL ID where the index is used
                idx -lcl                                                      : List orphaned index to be cleaned
                idx -u <owner> -us                                            : List index usage
                idx -u <owner> -bu                                            : List index buckets usage


                 -u <owner> : Schema owner of the index
            -i <index_name> : index name to process
               -ntbs <ntbs> : Move index to new tablespace

      Display options:
                        -s  : Show the size in 'meg' instead of the blocks
                       -cf  : Show clustering factor in percentage. The lower is the best, 100% is the worst
                       -fb  : Add the text of the function based index
                       -hg  : Show system overal histograms distribution among indexes
                       -ix  : Alternate info on index from ixora
                        -p  : List index (sub)partitions info; Add '-s' -> Segment size from dba_segments instead of analysed date
                      -tbs  : Show tablespace instead of columns_namefors
      Other options:
                      -inv  : List invalid indexes, partitions and subpartitions, order by owner
                 -spbl <nn> : Sample n blocks rather full index scan when measuring index efficiency
                     -sinv  : Generate Rebuild statement for all invalid indexes, partitions and subpartitions
                  -sinvall  : Generate Rebuild statement for all indexes, partitions and subpartitions
                       -lu  : List unused indexes
                        -x  : Execute command


      Notes:
         Clustering factor : - if near the number of blocks, then the table is ordered : index entries
                               in a single leaf block tend to point to rows in same data block
                             - if near the number of rows, the table is randomly ordered : index entries in a single
                               leaf block are unlikely to point to rows in same data block

         Global stats      :   For partitioned indexes, YES means statistics are collected for the INDEX as a whole
                               NO means statistics are estimated from statistics on underlying index partitions or subpart.
         Pct_direct_access :   For secondary indexes on IOTs, rows with VALID guess

EOF
   }
if [[ -z "$1" ]];then
     help ; exit
fi
VAR_FIELD="to_char(a.LAST_ANALYZED,'DD-MM HH24:MI') la,"
VAR_FIELD2=" clustering_factor cf, "
TIT_IDX_NAME_LEN=30
TIT_COL_NAME=22
TIT_TABLE_NAME=30
typeset -u fowner
typeset -u findex
typeset -u ftable
ROWNUM=50
choice=default
while [[ -n "$1" ]]
    do
      case $1 in
        -bu ) choice="BUCKET_IDX" ;;
        -cf ) CLUSTER_FACTOR=TRUE ;;
       -fb ) FB=TRUE ;;
        -ddl) choice=ddl;;
         -h ) help ; exit ;;
         -b ) SNAP1=$2 ; shift ;;
        -lcl) choice=LIST_CLEANUP ;;
         -e ) SNAP2=$2 ; shift ;;
        -hg ) choice=HISTO;;
         -i ) findex=$2 ; shift;;
      -like ) LIKE=$2 ; shift;;
       -ief ) choice=INDEX_EFFICIENCY ;  findex=$2 ; shift ;;
       -inv ) choice=LIST_INVALID;;
        -ix ) choice=IX ;;
      -lief ) choice=LIST_RH ;;
        -lu ) choice=LIST_UNUSED ;;
      -sief ) choice=REBUILD_RH ;;
      -ntbs ) choice=MOVE_TBS ; typeset -u  ftbs=$2 ; shift ;;
         -p ) choice=PART ;;
        -ph ) choice=part_hv ;;
       -pct ) PCT=$2 ; shift ;;
        -pa ) PCT_B=$2 ; shift ;;
        -pb ) PCT_E=$2 ; shift ;;
       -par ) PAR=$2; shift;;
        -rn ) ROWNUM=$1 ; shift ;;
         -s ) VAR_FIELD="(select sum(bytes/1048576) bytes from dba_segments
                  where segment_name = b.index_name and owner = b.index_owner group by owner,segment_name) tot_seg_mb,"
              FVAR=TRUE;;
     -sinv ) choice=REBUILD_INVALID;;
  -sinvall ) choice=REBUILD_ALL;;
    -scoal ) choice=GEN_COALESCE ;;
     -spbl ) SAMPLE_BLOCK_N=$2 ; shift ;;
         -t ) ftable=$2 ; AND_TABLE=" and b.table_name ='$ftable' " ; shift;;
      -tbs ) COL_OR_TBS=b.tablespace_name ;;
        -u ) fowner=$2 ; shift ;;
       -us ) choice=IDX_USAGE ;;
      -use ) choice=USED;;
       -su ) S_USER=$2 ; shift  ;;
        -x ) EXECUTE=YES ;;
        -v ) VERBOSE=TRUE;;
         * )  echo "Unknonw parameter $1" ; help ; exit ;;
      esac
      shift
    done

    #--------------- Process section             ---------------------
    #--------------- Get system password section ---------------------
    . $SBIN/scripts/passwd.env
    . ${GET_PASSWD}
    if [  "x-$CONNECT_STRING" = "x-" ];then
          echo "could no get a the password of $S_USER"
          exit 0
    fi
    #--------------- Process section ---------------------

# a table name is given but no index and no owner:
# we output all index for this table or the list of table owner if multiple occurence exists
if [ -n "$ftable" -a -z "$findex" -a -z "$fowner" ];then
   var=`sqlplus -s "$CONNECT_STRING" <<EOF
        set feed off pagesize 0 head off
          select  trim(to_char(count(*))) cpt from dba_tables where table_name=upper('$ftable');
EOF`
   ret=`echo "$var" | tr -d '\r' | awk '{print $1}'`
   if [ -z "$ret" ];then
       echo
       echo "Currently, there is no entry in dba_tables for $ftable"
       exit
    elif [ "$ret" -eq "0" ];then
       echo
       echo "Currently, there is no entry in dba_tables for $ftable"
       exit
    elif [ "$ret" -eq "1" ];then
        var=`sqlplus -s "$CONNECT_STRING" <<EOF
        set feed off pagesize 0 head off
        col owner for a30
        select owner from dba_tables where table_name=upper('$ftable');
EOF`
        fowner=`echo "$var" | tr -d '\r' | awk '{print $1}'`
    elif [ "$ret" -gt "0"  ];then
      if [ -z "$fowner" ];then
         echo
         echo " there are many owner for table for $ftable:"
         echo " Use :  idx -u $ftable -u <owner> to view all indexes for this table"
         echo
         sqlplus -s "$CONNECT_STRING" <<EOF
         set feed off pagesize 66 head on
         col owner format a30                              
         col table_name format a30 
         select owner, table_name , 'table' from dba_tables where table_name=upper('$ftable') ;
EOF
         exit
      fi
    fi
fi

# Index is given, retrieve owners or propose list:

if [ -n "$findex" -a -z "$fowner" ];then
   unset ret
   var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off verify off trimspool on
col cpt for A11
select trim(to_char(count(*))) cpt from dba_indexes where index_name='$findex' ;
EOF`
   ret=`echo "$var" | tr -d '\r' | awk '{print $1}'`
   if [ -z "$ret" ];then
      echo
      echo "Currently, there is no entry in dba_index for $findex"
      exit
   elif [ "$ret" -eq 0 ];then
      echo
      echo "Currently, there is no entry in dba_index for $findex"
      exit
   elif [ "$ret" -eq 1 ];then
      var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select owner from dba_indexes where index_name='$findex' ;
EOF`
     fowner=`echo "$var" | tr -d '\r' | awk '{print $1}'`
     FOWNER=" owner = '$fowner' "
     AND_FOWNER=" and  $FOWNER"
   elif [ "$ret" -gt 0  ];then
      if [ -z "$fowner" ];then
        echo
        echo " there are many owners for the index '$findex':"
        echo
        echo " Use : "
        echo " idx -i $findex -u <owner> "
        echo
       sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 66 head on lines 190
        col owner for a30
        col index_name for a30
select owner, index_name, index_type  from dba_indexes where index_name='$findex' ;
EOF
    exit
     fi
   fi
fi
# ...........................................................
# List  index usages
# ...........................................................
if [ "$choice" = "IDX_USAGE" ];then
if [ -z "$AND_FOWNER" ];then 
   if [ -n "fowner" ];then
     FOWNER=`echo "$fowner" | tr -d '\r' | awk '{print $1}'`
     AND_FOWNER=" and  owner ='$FOWNER'"
   fi
fi 
  if [ -n "$ftable" ];then
     AND_TABLE="  and name in (select index_name from dba_indexes where table_name = upper('$ftable') $AND_OWNER)"
  else
     unset AND_TABLE
  fi 
SQL="
SET LINESIZE 190 pages 66
COLUMN owner FORMAT A30
COLUMN name  FORMAT A30
col total_rows_returned for 999999999999999999
col total_exec_count for 999999999999999999
col total_access_count for 999999999999999999
select * from (
SELECT owner,
       name,
       total_access_count,
       total_exec_count,
       total_rows_returned,
       to_char(last_used,'YYYY-MM-DD hh24:MI:SS' ) last_used
FROM   dba_index_usage
WHERE   1=1 $AND_FOWNER $AND_TABLE
ORDER BY 3 desc )
where rownum <=$ROWNUM
/
"
# ...........................................................
# List  index usages
# ...........................................................
 
elif [ "$choice" = "BUCKET_IDX" ];then
if [ -z "$AND_FOWNER" ];then 
   if [ -n "fowner" ];then
     FOWNER=`echo "$fowner" | tr -d '\r' | awk '{print $1}'`
     AND_FOWNER=" and  owner ='$FOWNER'"
   fi
fi 
  if [ -n "$ftable" ];then
     AND_TABLE="  and name in (select index_name from dba_indexes where table_name = upper('$ftable') $AND_OWNER)"
  else
     unset AND_TABLE
  fi 
SQL="
SET LINESIZE 210 pages 66
COLUMN owner FORMAT A30
COLUMN name  FORMAT A30
col bucket_0_access_count for 99999999999 head 'Bucket 0| Access count'
col bucket_1_access_count for 99999999999 head 'Bucket 1| Access count'
col bucket_2_10_access_count for 99999999999 head 'Bucket 2-10| Access count'
col bucket_11_100_access_count for 99999999999 head 'Bucket 11-100| Access count'
col bucket_101_1000_access_count for 99999999999 head 'Bucket 101-1000| Access count'
col bucket_1000_plus_access_count for 99999999999 head 'Bucket 1000+| Access count'
select * from (
SELECT owner, name,
       bucket_0_access_count,
       bucket_1_access_count,
       bucket_2_10_access_count,
       bucket_11_100_access_count,
       bucket_101_1000_access_count,
       bucket_1000_plus_access_count
FROM   dba_index_usage
WHERE   1=1 $AND_FOWNER $AND_TABLE
ORDER BY 3 desc )
where rownum <=$ROWNUM
/
"
# ...........................................................
# List  SQL ID where the index is used
# ...........................................................

elif [ "$choice" = "USED" ];then

if [ -n "$LIKE" ];then
   AND_OBJECT=" and object_name like upper('${LIKE}%') "
else
   AND_OBJECT=" and object_name= '$findex' and  object_owner = upper('$fowner') " 
fi

SQL="
col OBJECT_NAME  for a30
col OBJECT_owner  for a30
col ACCESS_PREDICATES for a30
col FILTER_PREDICATES for a30
col CHILD_NUMBER for 999 head 'chl'
col EXECUTIONS for 9999999 head 'Executions'
col ELAPSED_TIME for 999999999 head 'elapsed'
col ldate for a22 head 'Date'
set lines 190 pages 90
break on object_owner on OBJECT_NAME on report
compute sum of EXECUTIONS on report
select distinct
       object_owner, OBJECT_NAME, SQL_ID, CHILD_NUMBER, PLAN_HASH_VALUE --, ACCESS_PREDICATES, FILTER_PREDICATES 
       ,EXECUTIONS, ELAPSED_TIME, to_char(TIMESTAMP,'YYYY-MM-DD HH24:MI:SS') ldate
  from 
        v\$sql_plan_statistics_all 
  where
     object_type  like  '%INDEX%'
      $AND_OBJECT  
  order by ldate desc
/
"
# ...........................................................
# List   indexes with orhpaned entries to clean
# ...........................................................
elif [ "$choice" = "LIST_CLEANUP" ];then
SQL="
set pages 66 lines 230
col index_name for a30
col partition_name for a30
col status for a8
select s.owner,index_name, null partition_name, orphaned_entries, num_rows, s.blocks, leaf_blocks, status
from dba_indexes i, dba_segments s where i.index_name = s.segment_name  and partitioned = 'NO' and orphaned_entries =  'YES'
union
select s.owner, index_name, i.partition_name, orphaned_entries, num_rows, s.blocks, leaf_blocks, status
from dba_ind_partitions i, dba_segments s where i.partition_name = s.partition_name  and orphaned_entries =  'YES';
"
# ...........................................................
# List  unused indexes
# ...........................................................
elif [ "$choice" = "LIST_UNUSED" ];then


  if [ -z "$SNAP1" ];then
     VAR=`get_snap_beg_end`
     VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
     SNAP1=`echo $VVAR | cut -f2 -d' '`
     SNAP1=`expr $SNAP1 - 1`
     SNAP2=`expr $SNAP1 + 1`
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
  fi
  if [ -n "$ftable" ];then
     AND_TABLE="  and table_name = '$ftable'"
  else
     unset AND_TABLE
  fi 
TITLE="List of index not used in the snap interval $SNAP1 - $SNAP2"
SQL="
col owner heading 'Index Owner' format a30
col index_name heading 'Index Name' format a30

set linesize 95 trimspool on pagesize 80

-- based on an idea of Don burlson. adapted to smenu and from statpack to AWR.
-- better use 'alter index monitor usage' and quety v$object_usage.
-- but this query may be a quick check.

select a.owner, b.table_name, b.index_name  from
(
select owner, index_name
   from dba_indexes di where di.index_type != 'LOB'
   and owner = '$fowner' $AND_TABLE
minus
    select index_owner owner, index_name
    from dba_constraints dc
    where index_owner  = '$fowner' $AND_TABLE
minus
   select p.object_owner owner, p.object_name  index_name
   from wrm\$_snapshot       sn, wrh\$_sql_plan       p
   where sn.snap_id = p.snap_id
and sn.snap_id between $SNAP1 and $SNAP2
and p.object_type = 'INDEX'
) a,
dba_indexes b
where a.owner = '$fowner'
and a.owner = b.owner
and a.index_name = b.index_name
order by 1, 2
/
"
# ...........................................................
# List partition range
# ...........................................................
elif [ "$choice" = "part_hv" ];then
 if [ -n "$fowner" ];then
         AND_FOWNER=" and index_owner =  '$fowner' "
 fi
sqlplus -s "$CONNECT_STRING"  <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set termout on pause off embedded on verify off heading off
set lines 32000 pagesize 66
set serveroutput on
set long 32000

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline, 'Show partitions high values for index: $findex' from sys.dual
/
set head off
-- this query produce a concatened, comma separated,  list of column names
select 'Part col -->  ' ||   column_name
      from (
                    select
                         column_name
                    from
                          SYS.DBA_IND_COLUMNS
                    where index_owner = '$fowner' and index_name='$findex'
                          ) ;

declare
   tt varchar2(2000);
   loc long;
   v_col varchar2(30) ;
   function ff ( ll long) return varchar2 is
    var varchar2(2000);
   begin
     select ll into var from dual ;
     return var;
   end ff ;
begin
  dbms_output.put_line(rpad('Partion_name',30,' ')|| 'High_value');
  dbms_output.put_line(rpad('-',29,'-')||' '|| rpad('-',70,'-'));
  for  t in (select partition_name, high_value from dba_ind_partitions where index_name = '$findex' $AND_FOWNER
             order by partition_position)
  loop
     tt:= ff(t.high_value) ;
    dbms_output.put_line(rpad(t.partition_name,30,' ') || tt );
  end loop;
end;
/
EOF
# ...........................................................

# ...........................................................
# extract DDL
# ...........................................................
elif [ "$choice" = "ddl" ];then
FOUT=$SBIN/tmp/ddl_$findex.sql
sqlplus -s "$CONNECT_STRING"  <<EOF
set head off
SET PAGESIZE 0
SET LONG 90000
set linesize 124
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'CONSTRAINTS_AS_ALTER', true );
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', TRUE );
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'CONSTRAINTS', TRUE );
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'REF_CONSTRAINTS', TRUE );
execute dbms_metadata.set_transform_param(dbms_metadata.session_transform, 'TABLESPACE', true);
set serveroutput on size 99999 format wrapped
col fline for a4000
spool $FOUT.tmp
select dbms_metadata.get_ddl('INDEX','$findex','$fowner') fline from dual
/
EOF
cat $FOUT.tmp |sed -e 's/ *$//' -e '/^ *$/d' > $FOUT ; rm $FOUT.tmp
echo "results in $FOUT"
exit
#................................................
# Measure Index efficiency
#................................................
elif [  "$choice" = "REBUILD_RH" ];then
PCT=${PCT:-60}
if [ -n "$PAR" ];then
     F_PAR=" parallel $PAR" 
fi
TITLE=" Generate statements to rebuild indexes whose PCT to optimal blocks is less than $PCT %"
SQL="
set pages 66 lines 190 verify off feed off pages 0
col blk_size format 99999
col Xblks format 99999

col  blk_size new_value blk_size noprint
select to_number(value)-107 as blk_size from v\$parameter where name = 'db_block_size'
/
-- Regular heap tables
prompt
Prompt Processing Non-Partitioned tables
prompt
col leaf_blocks new_value leaf_blocks noprint
with v as (
    select c.index_owner, c.index_name,  sum(AVG_COL_LEN)+10 avg_key_len, i.degree
from
      dba_tab_columns b , dba_ind_columns c, dba_tables a, dba_indexes i
  where b.owner ='$fowner' $AND_TABLE
  and b.owner= c.table_owner
  and b.table_name = c.table_name
  and b.column_name = c.column_name
  and a.owner = c.table_owner
  and a.owner = i.owner
  and c.index_name = i.index_name
  and a.table_name = c.table_name
  and a.partitioned='NO'
  and a.iot_name is null
  and i.index_type='NORMAL'
group by c.index_name, c.index_owner, i.degree
)
select
    'prompt doing ' || index_name ||  ' blocks ' ||LEAF_BLOCKS || ' opt ' || Xblks||  chr(10)||
   'alter index ' || index_owner || '.\"' || index_name || '\" rebuild online $F_PAR ; ' ||  chr(10)||
   'alter index ' || index_owner || '.\"' || index_name || '\" parallel ' || degree || ';'
from (
select
        i.owner index_owner, i.index_name , i.LEAF_BLOCKS,
        ceil((num_rows*decode(v.avg_key_len , 0, 1, v.avg_key_len))/ &blk_size )+ blevel
        as Xblks , v.degree
from dba_indexes i , v
where i.owner=v.index_owner and
      i.index_name=v.index_name
  and i.num_rows is not null
  order by 3
)
where -- floor(Xblks*100/decode(leaf_blocks,0,1,leaf_blocks) )  > 0 and 
 leaf_blocks > 0 and floor(Xblks*100/decode(leaf_blocks,0,1,leaf_blocks) )  < $PCT
/
-- Partitioned tables
prompt
prompt Processing now partitioned tables
prompt
with v as (
    select c.index_owner, c.index_name,  sum(AVG_COL_LEN)+10 avg_key_len,
           a.table_name, d.partition_name
from
      dba_tab_columns b , dba_ind_columns c, dba_tables a, dba_ind_partitions d, dba_indexes i
  where b.owner ='$fowner' $AND_TABLE
  and b.owner= c.table_owner
  and b.table_name = c.table_name
  and b.column_name = c.column_name
  and a.owner = c.table_owner
  and a.table_name = c.table_name
  and a.partitioned='YES'
  and a.iot_name is null
  and d.index_owner=c.table_owner
  and d.index_name=c.index_name
  and d.SUBPARTITION_COUNT=0
  and i.owner = c.index_owner and i.index_name = c.index_name and i.index_type='NORMAL'
group by a.table_name, d.partition_name, c.index_name, c.index_owner
)
select 'prompt doing ' || index_name ||' partition ' || partition_name ||  ' blocks ' ||LEAF_BLOCKS || ' opt ' || xblks ||chr(10) ||
   'alter index ' || index_owner || '.\"' || index_name || '\" rebuild partition \"' || partition_name ||'\" online $F_PAR ; ' || chr(10)||
   'alter index ' || index_owner || '.\"' || index_name || '\" parallel ' || degree || ';'
from (
select
        i.index_owner, i.index_name, v.partition_name, i.LEAF_BLOCKS,
        ceil((i.num_rows*decode(v.avg_key_len , 0, 1, v.avg_key_len))/ &blk_size )+ i.blevel
        as Xblks, d.degree
from dba_ind_partitions i , v, dba_indexes d
where i.index_owner=v.index_owner and
      i.index_name=v.index_name
  and i.partition_name=v.partition_name
  and i.num_rows is not null
  and d.owner = i.index_owner
  and d.index_name = i.index_name
order by 4
)
where -- floor(Xblks*100/decode(leaf_blocks,0,1,leaf_blocks) )  > 0 and 
     leaf_blocks > 0 and floor(Xblks*100/decode(leaf_blocks,0,1,leaf_blocks) )  < $PCT
/
-- Subpartitioned tables
prompt
prompt Processing now partitioned tables
prompt
with v as (
    select c.index_owner, c.index_name,  sum(AVG_COL_LEN)+10 avg_key_len,
           a.table_name, d.partition_name, d.subpartition_name
from
      dba_tab_columns b , dba_ind_columns c, dba_tables a, dba_ind_subpartitions d, dba_indexes i
  where b.owner ='$fowner' $AND_TABLE
  and b.owner= c.table_owner
  and b.table_name = c.table_name
  and b.column_name = c.column_name
  and a.owner = c.table_owner
  and a.table_name = c.table_name
  and a.partitioned='YES'
  and a.iot_name is null
  and d.index_owner=c.table_owner
  and d.index_name=c.index_name
  and i.owner = c.index_owner and i.index_name = c.index_name and i.index_type='NORMAL'
group by a.table_name, d.partition_name, d.subpartition_name, c.index_name, c.index_owner
)
select
   'alter index ' || tb || ' rebuild subpartition ' || subpartition_name ||' online ;  '
from (
select
        i.index_owner||'.'|| i.index_name tb, i.partition_name, i.subpartition_name, i.LEAF_BLOCKS,
        ceil((num_rows*decode(v.avg_key_len , 0, 1, v.avg_key_len))/ &blk_size )+ blevel
        as Xblks
from dba_ind_subpartitions i , v
where i.index_owner=v.index_owner and
      i.index_name=v.index_name
  and i.partition_name=v.partition_name
  and i.subpartition_name=v.subpartition_name
 and i.num_rows is not null
)
where floor(Xblks*100/decode(leaf_blocks,0,1,leaf_blocks) )  > 1
     and floor(Xblks*100/decode(leaf_blocks,0,1,leaf_blocks) )  < $PCT
order by 1
/
"
#................................................
elif [  "$choice" = "LIST_RH" ];then
   TITLE="List index suspect of being right handed"
   if [ -n "$PCT" ];then
       WHERE_PCT=" where xblks > 0 and floor( xblks *100/decode(leaf_blocks,0,1,leaf_blocks)) <= $PCT "
      # WHERE_PCT=" where xblks = xblks "

   fi
   PCT_A=${PCT_A:-0}
   PCT_B=${PCT_B:-999}
SQL="
 set pages 66 lines 190 verify off
 col avg_key_len head 'Avg|key|len' for 999
 col tb for a45 head 'Table name'
 col Xblks head 'Maximum|Optimal|Blocks' for 9999999
 col blevel head 'B|Lvl' for 99
 col PCT_optimal for 999999999 head 'Pct  |optimal'
 col pct_direct_access head 'Pct |direct|Access' for 990.99
 col iot_redundant_pkey_elim head 'Iot |Redudndant|Key elim'
 col index_type head 'Index Type' for a16
 col index_name for a22
 col partition_name for a22
 col table_name for a22
 col blk_size new_value blk_size noprint
 select to_number(value) blk_size from v\$parameter where name = 'db_block_size' 
/

-- regular tables
select
  tb, index_name, pct_free , blevel, avg_key_len, num_rows , leaf_blocks,
  Xblks ,
  floor( Xblks*100/decode(leaf_blocks,0,1,leaf_blocks)) pct_optimal,
  pct_direct_access, IOT_REDUNDANT_PKEY_ELIM, index_type
from (
with v as (
 select c.index_owner, c.index_name,  sum(AVG_COL_LEN)+10 avg_key_len
from
      dba_tables a, dba_tab_columns b , dba_ind_columns c
  where b.owner ='$fowner' $AND_TABLE
  and b.owner= c.table_owner
  and b.table_name = c.table_name
  and b.column_name = c.column_name
  and a.owner = c.table_owner
  and a.table_name = c.table_name
  and a.partitioned='NO'
  and a.iot_name is null
group by  c.index_name, c.index_owner
)
    select /*+  rule */
        i.owner||'.'|| i.table_name tb, i.index_name , i.num_rows,
        i.LEAF_BLOCKS, v.avg_key_len,pct_free, blevel,
        ceil( (num_rows*decode(v.avg_key_len , 0, 1, v.avg_key_len))
                     / decode((&blk_size-(decode(pct_Free,0,0,(&blk_size/pct_free)))),0,1,(&blk_size-(decode(pct_Free,0,0,(&blk_size/pct_free))) ) )
         )+ blevel as Xblks,
        pct_direct_access, IOT_REDUNDANT_PKEY_ELIM, index_type
    from 
        dba_indexes i , v 
    where i.owner=v.index_owner and
          i.index_name=v.index_name  -- and i.index_type <> 'BITMAP'
       and  i.num_rows > 0 
) $WHERE_PCT  
-- )  where pct_optimal >= $PCT_A and pct_optimal <= $PCT_B
order by pct_optimal
/
  -- partitioned tables
col tb for a26
break on tb on index_name

prompt
prompt Processing now partitioned tables
prompt

with v as (
 select c.index_owner, c.index_name,   sum(AVG_COL_LEN)+10 avg_key_len ,
        a.table_name, d.partition_name
from
      dba_tables a, dba_tab_columns b , dba_ind_columns c,
      dba_ind_partitions d
  where b.owner ='$fowner' $AND_TABLE
  and b.owner= c.table_owner
  and b.table_name = c.table_name
  and b.column_name = c.column_name
  and a.owner = c.table_owner
  and a.table_name = c.table_name
  and a.partitioned='YES'
  and a.iot_name is null
  and d.index_owner=c.table_owner
  and d.index_name=c.index_name
  and d.SUBPARTITION_COUNT=0
group by a.table_name, d.partition_name, c.index_name, c.index_owner
)
select
  tb, index_name, partition_name, pct_free , blevel, avg_key_len, num_rows , leaf_blocks,
        Xblks ,floor(Xblks*100/decode(leaf_blocks,0,1,leaf_blocks) ) as pct_optimal
from (
select /*+ rule */
        v.table_name tb, i.index_name , i.partition_name, i.num_rows,
        i.LEAF_BLOCKS, v.avg_key_len,pct_free, blevel,
               ceil(
                    (num_rows*decode(v.avg_key_len , 0, 1, v.avg_key_len))/
                    decode((&blk_size-(decode(pct_Free,0,0,(&blk_size/pct_free)))),0,1,(&blk_size-(decode(pct_Free,0,0,(&blk_size/pct_free))) ) )
         )+ blevel as Xblks
from dba_ind_partitions i , v 
where i.index_owner=v.index_owner and
      i.index_name=v.index_name
  and i.partition_name=v.partition_name
 and i.num_rows is not null
)  $WHERE_PCT
/
  -- subpartitioned tables
prompt
prompt Processing now Sub-partitioned tables
prompt
col name for a40 head 'part.sub'
Prompt Subpartioned indexes

with v as (
 select /*+ rule */ c.index_owner, c.index_name,   sum(AVG_COL_LEN)+10 avg_key_len ,
        a.table_name, d.partition_name, d.subpartition_name, SUBPARTITION_POSITION
from
      dba_tables a, dba_tab_columns b , dba_ind_columns c,
      dba_ind_subpartitions d
  where a.owner ='$fowner' $AND_TABLE
  and a.table_name = b.table_name
  and a.owner = b.owner
  and a.partitioned='YES'
  and a.iot_name is null
  and c.table_owner= b.owner
  and c.table_name = b.table_name
  and c.column_name = b.column_name
  and d.index_owner=c.table_owner
  and d.index_name=c.index_name
group by a.table_name, d.partition_name, d.subpartition_name, c.index_name, c.index_owner, SUBPARTITION_POSITION
order by SUBPARTITION_POSITION
)
select
  tb, index_name, name, pct_free , blevel, avg_key_len, num_rows , leaf_blocks,
        Xblks ,floor(Xblks*100/decode(leaf_blocks,0,1,leaf_blocks) )  as pct_optimal
from (
select /*+ rule */
        v.table_name tb, i.index_name , i.partition_name||'.'||i.subpartition_name name, i.num_rows,
        i.LEAF_BLOCKS, v.avg_key_len,pct_free, blevel,
        ceil(
                    (num_rows*decode(v.avg_key_len , 0, 1, v.avg_key_len))/
                    decode((&blk_size-(decode(pct_Free,0,0,(&blk_size/pct_free)))),0,1,(&blk_size-(decode(pct_Free,0,0,(&blk_size/pct_free))) ) )
         )+ blevel as Xblks
from dba_ind_subpartitions i , v 
where i.index_owner=v.index_owner and
      i.index_name=v.index_name
  and i.partition_name=v.partition_name
  and i.subpartition_name=v.subpartition_name
 and i.num_rows is not null
) $WHERE_PCT  
order by pct_optimal
/
Prompt The List below could not be asserted for these indexes have not statistics
col tb format a60 head ' Table name'
col  index_name for a30
select b.owner||'.'|| b.table_name tb, b.index_name
  from dba_indexes b
  where b.owner ='$fowner' $AND_TABLE and b.num_rows is null
       and b.index_name not like 'SYS_IL%'
;
"
#................................................
# Measure Index efficiency
#................................................
elif [  "$choice" = "GEN_COALESCE" ];then
   TITLE="Generate statement to coalesc index '$findex'"
SQL="
  prompt
  set head off lines 1024 pages 0 feed off verify off
  col m_statement new_value m_statement

  select case
     when cpt = 1 then q'{ 'alter index ' || owner||'.'||index_name || ' coalesce ;'
               from all_indexes where owner= '$fowner' and index_name = '$findex' }'
     when cpt > 0 then
                 q'{  'alter index ' || owner||'.'||index_name || ' rebuild partition ' || partition_name || ' online;'
                  from ( select partition_name, b.index_name, b.owner  from all_tab_partitions a, all_part_indexes b
                               where
                                      a.table_owner=b.owner and b.owner='$fowner'
                                  and a.table_name=b.table_name and b.index_name='$findex'
                                  order by a.partition_position
                 )
                 }'
     else ' ''more than one partition'' from dual'
     end m_statement
   from ( select sum( cpt) cpt
          from (
                select 1 cpt from all_indexes where owner='$fowner' and index_name = '$findex'
                union
                select PARTITION_COUNT  from all_part_indexes where owner='$fowner' and index_name = '$findex'
               )
        )
/
-- prompt f=&&m_statement
 select &&m_statement
/
prompt
"
#................................................
# Measure Index efficiency
#................................................
elif [  "$choice" = "INDEX_EFFICIENCY" ];then
   TITLE="Measure Index efficiency for $findex"
#
#     Script:        index_efficiency.sql
#     Author:        Jonathan Lewis
#     Dated:         Sept 2003
#     Purpose:       Example of how to check leaf block packing
#
#     Notes
#     Last tested 9.2.0.4
#
#     Example of analyzing index entries per leaf block.
#     The code examines index T1_I1 on table T1.
#
#     The index is on (v1, small_pad). Both columns appear
#     the where clause with a not null test to avoid issues
#     relating to indexes with completely nullable entries.
#
#     For a simple b-tree index, the first parameter to the
#     sys_op_lbid() function has to be the object_id of the
#     index.
#     The query will work with a sample clause
#     Check that the execution path is an index fast full scan
#
#     Adapted to Smenu by BPA

    if  [ -n "$SAMPLE_BLOCK_N" ];then
         SAMPLE_BLOCK=" sample block ($SAMPLE_BLOCK_N)"
    fi
    SQL=" set term off echo off feed off
set verify off head off
column ind_id new_value m_ind_id noprint
col m_ftable new_value m_ftable noprint
col m_table new_value m_table noprint
col m_size new_value m_size noprint
select object_id ind_id from all_objects where object_name = '$findex'  and owner='$fowner' ;
select owner||'.'||table_name m_ftable, table_name m_table from all_indexes where index_name  = '$findex'  and owner='$fowner' ;
select value m_size from v\$parameter where name = 'db_block_size' ;

column col01    new_value m_col01 noprint
column col02    new_value m_col02 noprint
column col03    new_value m_col03 noprint
column col04    new_value m_col04 noprint
column col05    new_value m_col05 noprint
column col06    new_value m_col06 noprint
column col07    new_value m_col07 noprint
column col08    new_value m_col08 noprint
column col09    new_value m_col09 noprint

select
    nvl(max(decode(column_position, 1,column_name)),'null')        col01,
    nvl(max(decode(column_position, 2,column_name)),'null')        col02,
    nvl(max(decode(column_position, 3,column_name)),'null')        col03,
    nvl(max(decode(column_position, 4,column_name)),'null')        col04,
    nvl(max(decode(column_position, 5,column_name)),'null')        col05,
    nvl(max(decode(column_position, 6,column_name)),'null')        col06,
    nvl(max(decode(column_position, 7,column_name)),'null')        col07,
    nvl(max(decode(column_position, 8,column_name)),'null')        col08,
    nvl(max(decode(column_position, 9,column_name)),'null')        col09
from
    dba_ind_columns
where
        table_owner = upper('$fowner')
    and table_name  = '&m_table'
    and index_name  = upper('$findex')
order by
column_position
/
set term on echo on lines 190  head on pages 66
col fwn head 'Index' for a40
col fsize head 'Size(m)' format 999990

select
     owner||'.'||index_name fwn, table_name, LEAF_BLOCKS*&m_size/1048576 fsize, num_rows, distinct_keys
from
     all_indexes
where
     owner = upper('$fowner')
 and index_name  = upper('$findex')
/
col  CLUSTERING_FACTOR head 'Clustering|Factor' justify c
select LEAF_BLOCKS,
       AVG_LEAF_BLOCKS_PER_KEY, AVG_DATA_BLOCKS_PER_KEY,
       CLUSTERING_FACTOR, PARTITIONED, PCT_FREE , blevel
  from all_indexes
 where owner = upper('$fowner') and index_name  = upper('$findex')
/
col rows_per_block head 'Average rows|Per block' justify c
col blocks head 'Blocks' justify c
break on report skip 1
compute sum of blocks on report

select
        rows_per_block,
        count(*) blocks
from (
        select
               /*+
                       cursor_sharing_exact
                       dynamic_sampling(0)
                       no_monitoring
                       no_expand
                       index_ffs(t1,$findex)
                       noparallel_index(t,t1_i1)
               */
               sys_op_lbid( &m_ind_id ,'L',t1.rowid) as block_id,
               count(*)                              as rows_per_block
        from
               &m_ftable  $SAMPLE_BLOCK t1
        where
                &m_col01 is not null
        or      &m_col02 is not null
        or      &m_col03 is not null
        or      &m_col04 is not null
        or      &m_col05 is not null
        or      &m_col06 is not null
        or      &m_col07 is not null
        or      &m_col08 is not null
        or      &m_col09 is not null
group by
               sys_op_lbid( &m_ind_id ,'L',t1.rowid)
)
group by rows_per_block
order by rows_per_block
/
"
#echo "$SQL"

#...............................................
# Move index to a new tablespace
#................................................
elif [  "$choice" = "MOVE_TBS" ];then
  [[ -z "$ftbs" ]] && echo "I need a tablesspace name to move to a new tablespace" && exit
  [[ -z "$fowner" ]] && echo "I need at least schema name or a index name or maybe even both" && exit
  [[ -z "$findex" ]] && echo "I need at least schema name or a index name or maybe even both" && exit

if [ -n "$fowner" ];then
      AND_IOWNER="  and ai.owner = '$fowner' "
      AND_PART_OWNER="  and aii.index_owner = '$fowner' "
fi
if [ -n "$findex" ];then
      AND_INDEX="  and ai.index_name = '$findex' "
fi

# ... I am not in mood to be clear, so ....
[[  -z "$EXECUTE" ]]
doit=$?

sqlplus -s "$CONNECT_STRING" <<EOF
set pages 66 lines 190 serveroutput
declare
  P_ITBS         varchar2(30) :='$ftbs' ;
  P_OWNER        varchar2(30) :='$fowner' ;
  P_INDEX        varchar2(30) :='$findex' ;
  v_sql          varchar2(512) ;
  itbs_exists    varchar2(5) ;
  v_run_now      number :=$doit ;

 -- tbl_or_idx  : 1=table/IOT    2=index
 procedure doit ( action in number , sqlcmd in varchar2 ) is
    begin
       dbms_output.put_line(' itbs_exists=' || itbs_exists   );
        if action = 1 and itbs_exists = 'TRUE' then
           dbms_output.put_line('Doing : '|| sqlcmd || ';') ;
           execute immediate sqlcmd ;
       else
           dbms_output.put_line(sqlcmd || ';') ;
       end if;
   end;

begin
   -- check index to move is not an iot
   if v_run_now = 0 then
      dbms_output.put_line('Rem No execution requested');
   else
      dbms_output.put_line('Rem Execution of command requested');
   end if;

   -- check if ftbs exists
   if P_ITBS is not null then
      select decode(count(*),0,'FALSE','TRUE') into itbs_exists from dba_tablespaces where tablespace_name = P_ITBS  ;
      dbms_output.put_line('Rem Tablespace for index ' || P_ITBS || ' exists : ' ||itbs_exists );
      dbms_output.put_line('Rem');
   end if;
      for idx in (select index_name, ai.owner,  ai.partitioned from all_indexes ai
                         where 1=1  $AND_IOWNER $AND_INDEX )
      loop
         dbms_output.put_line('Rem');
         dbms_output.put_line('Rem Index name : ' ||idx.index_name );
         dbms_output.put_line('Rem');
         if  idx.partitioned = 'NO' then
             v_sql := 'ALTER INDEX '||idx.owner||'.'||idx.index_name||' REBUILD TABLESPACE ' || P_ITBS ;
              doit(v_run_now,v_sql);
         else
             for fpart in (select partition_name from all_ind_partitions where index_owner = idx.owner and index_name = idx.index_name)
             loop
                 v_sql:='ALTER INDEX ' || idx.owner|| '.'|| idx.index_name || ' REBUILD PARTITION ' || fpart.partition_name
                         ||' TABLESPACE ' || P_ITBS ;
                 doit(v_run_now,v_sql) ;
             end loop ;

             for fpart in (select subpartition_name from all_ind_subpartitions where index_owner = idx.owner and index_name = idx.index_name)
             loop
                 v_sql:='ALTER INDEX '||idx.owner||'.'||idx.index_name||' REBUILD SUBPARTITION ' ||fpart.subpartition_name ||
                       ' TABLESPACE ' || P_ITBS ;
                 doit(v_run_now,v_sql);
             end loop ;
         end if;
      end loop;
end;
/
EOF

exit

#................................................
# list invalid indexes
#................................................
elif [  "$choice" = "HISTO" ];then

SQL="
set termout off verify off feed off lines 132 pages 66
select  sum(case when max_cnt > 2 then 1 else 0 end) histograms,
                sum(case when max_cnt <= 2 then 1 else 0 end) no_histograms
    from (
        select table_name, max(cnt) max_cnt
                from (
                        select table_name, column_name, count(*) cnt
                                from dba_tab_histograms
                                group by table_name, column_name
                ) group by table_name
   )
/
"
#................................................
# list invalid indexes
#................................................
elif [ "$choice" = "IX"  ];then
#-------------------------------------------------------------------------------
#--
#-- Script:     index_access_paths.sql
#-- Purpose:    *** called from table_access_paths.sql ***
#--
#-- Copyright:  (c) Ixora Pty Ltd
#-- Author:     Steve Adams (http://www.ixora.com.au/scripts/sql/index_access_paths.sql)
#-- Adapted to Smenu by B. Polarski
#--------------------------------------------------------------------------------



if [ -z "$findex" ];then
   echo "I need an index name"
   exit
fi

sqlplus -s  "$CONNECT_STRING" <<EOF

set termout off verify off feed off
col value new_value BlkSz noprint
col object_id new_value idx_id noprint
col table_name new_value table_name noprint
col iotbit new_value IotBit noprint
col rpb new_value RowsPerBlock noprint

select value from v\$parameter where name = 'db_block_size'
/
select object_id from dba_objects  where object_type='INDEX' and object_name = '$findex' and owner = '$fowner'
/
select table_name from dba_indexes  where index_name = '$findex' and owner = '$fowner'
/
select decode(bitand(t.property, 64), 64, 'YES', 'NO')  iotbit from tab\$ t, obj\$ o
       where o.obj# =  t.obj# and o.type# = 2 and o.name = '&table_name'
         and o.owner# = (select user# from user\$ where name  = '$fowner') ;
/
select (1-(avg_space/&BlkSz))* round(nvl(floor(&BlkSz - 66 - INI_TRANS * 24)/greatest(AVG_ROW_LEN + 2, 11), 1),0)  rpb
  from dba_tables where table_name = '&table_name' and owner = '$fowner'
/
set termout on
set heading on pause off  feed off  verify off pagesize 56 linesize 132

column blocks         format 999999999
column density        format 9999999
column key_values     format 99999999999
column entries        format 99999999999 justify right
column table_ordering format 990.9999 head "ordering"

select /*+ ordered */
  o.name  index_name, i.leafcnt blocks,
  (
    least( 1, (
        select
          (
            sum(
              decode(sign(ic.pos# - nvl(i.spare2, 0)), 1, h.avgcln + 0.5, 0)
            ) + 11
          ) * i.rowcnt +
          (
            sum(
              decode(sign(nvl(i.spare2, 0) - ic.pos#), 1, h.avgcln + 0.5, 0)
            ) + 11
          ) * i.leafcnt
        from
          sys.icol\$  ic,
          sys.hist_head\$  h
        where
          ic.obj# = i.obj# and
          h.obj# (+) = ic.bo# and
          h.intcol# (+) = ic.intcol#
      ) / (i.leafcnt * (&BlkSz - 108 - i.initrans * 24))
    )
  )  density,
  i.distkey  key_values,
  i.rowcnt  entries,
  decode(
    '&IotBit',
    'YES',
    '           n/a',
    (
      round(1 - (i.clufac - i.rowcnt / &RowsPerBlock + 1) / i.rowcnt / (1 - 1 / &RowsPerBlock),4)
    )
  )  table_ordering
from
  sys.obj\$  o,
  sys.ind\$  i
where
  o.obj# = &idx_id and
  i.obj# = o.obj#
/

column storage         format a10
column bytes           format 99999 justify right
column buckets         format 999999
column popular         format a7
column non_pop_density format a15

select
  tc.name  column_name,
  decode(sign(ic.pos# - nvl(i.spare2, 0)), 1, 'NORMAL', 'COMPRESSED')  storage,
  h.avgcln  bytes,
  h.bucket_cnt  buckets,
  decode(
    h.bucket_cnt,
    1,
    null,
    decode(
      1 + h.bucket_cnt - h.row_cnt,
      0,
      '    nil',
      ((1 + h.bucket_cnt - h.row_cnt) / h.bucket_cnt)
    )
  )  popular,
  decode(
    sign(h.density * i.rowcnt - least(100, greatest(i.rowcnt/100, 10))),
    -1,
    lpad(to_char(h.density * i.rowcnt, '999') || decode(round(h.density * i.rowcnt), 1, '  row', ' rows'), 15)
  )  non_pop_density
from
  sys.ind\$  i,
  sys.icol\$  ic,
  sys.col\$  tc,
  sys.hist_head\$  h
where
  i.obj# = &idx_id and
  ic.obj# = i.obj# and
  tc.obj# = ic.bo# and
  tc.intcol# = ic.intcol# and
  h.obj# (+) = tc.obj# and
  h.intcol# (+) = tc.intcol#
order by
  ic.pos#
/


EOF
#................................................
elif [  "$choice" = "REBUILD_INVALID" -o "$choice" = "REBUILD_ALL" ];then
    if [ -n "$fowner" ];then
        AND_OWNER=" and owner = '$fowner' "
        AND_IDX_OWNER=" and index_owner = '$fowner' "
   fi
   if  [ "$choice" = "REBUILD_INVALID" ];then
       STATUS="status != 'VALID' and status != 'N/A'"
       PSTATUS="status != 'USABLE' and status != 'N/A'"
   else 
       STATUS=" 1=1 "
   fi
   TITLE="Generate statments to rebuild invalid indexes"

   SQL=" set heading on pause off pagesize 900 linesize 132
select 'alter index ' || owner||'.'|| index_name || ' rebuild online ;'
             from dba_indexes where $STATUS $AND_OWNER
union
select 'alter index ' ||  index_owner ||'.'|| index_name || ' rebuild partition ' || partition_name || ' ;'
              from dba_ind_partitions where $PSTATUS $AND_IDX_OWNER
union
select  'alter index ' || index_owner ||'.'|| index_name || ' rebuild  subpartition ' || subpartition_name || ' ;'
            from dba_ind_subpartitions where $PSTATUS $AND_IDX_OWNER
/
"
#................................................
elif [  "$choice" = "LIST_INVALID"  ];then
SQL="
col index_name for a35                                     
col partition_name for a25                                 
col status for a18                                         
set heading on pause off pagesize 56 linesize 150       
select owner, index_name, ' ' partition_name,status from dba_indexes where status != 'VALID' and status != 'N/A'
union
select  index_owner owner, index_name, partition_name, status from dba_ind_partitions where status != 'USABLE' and status != 'N/A'
union
select  index_owner owner, index_name, subpartition_name, status from dba_ind_subpartitions where status != 'USABLE' and status != 'N/A'
/
"
#................................................
# for all index if not index name given
#................................................
elif [ -z "$findex" ];then

    if [ -z "$COL_OR_TBS" ] ;then
        COL_OR_TBS="column_name"
    else
        COL_OR_TBS=" case nvl(b.tablespace_name,'0')
            when '0' then
                     case b.partitioned
                          when 'NO' then
                               case b.temporary
                                    when 'N' then '--Func base or Domain --'
                                    else '-- Temporary --'
                               end
                          else '-- partitioned --'
                     end
            else b.tablespace_name
       end tablespace_name "

    fi
    if [ -n "$LIKE" ];then
       AND_LIKE=" and a.index_name like upper('${LIKE}%') "
    fi
    TITLE="List all indexes for schema '$fowner'"
SQL="
set heading on pause off pagesize 56 linesize 190
column dg format A3 heading 'Par'
column f1 format a$TIT_IDX_NAME_LEN heading 'Index|Name'
column column_name format a$TIT_COL_NAME heading 'Column|Name'
column f0 format a$TIT_TABLE_NAME new_value the_table heading 'Table|Name'
column tablespace_name format a22 heading 'Tablespace'
column f2 format a1 heading 'U'
col cf format 999999999 head 'Clust| Factor'
col bytes format 99999999 head 'Size(m)'
col dk format 999999999 head 'Distinct| Keys' justify c
col la format A13  head 'last analysed'
col st format A3  head 'Sta|tus'
col un format  999999  head 'Unusable|Sub indx'
col status format a8
col meg format 9999999 head 'Size(m)'
col pct format 990.9 head 'Clust|f(%)' justify c
column blocks format 9999999 head 'Table|blocks' justify c
col idx_type for a10 head 'Index| Type'
col leaf_blocks head 'Leaf| blocks' for 99999999 justify c
col tot_seg_mb head 'Segment|size(m)' for 999990.9
set head off feed off


set head on feed on verify off
break on f0 on fw skip 1 on f0 on ft on f1 on f2

select a.table_name f0, a.index_name f1, substr(uniqueness,1,1)   f2,
       $COL_OR_TBS  , clustering_factor cf,
       decode(a.num_rows,0,0,((CLUSTERING_FACTOR/decode(c.blocks,0,1,c.blocks))/(a.NUM_ROWS/decode(c.blocks,0,1,c.blocks)))*100) pct,
       DISTINCT_KEYS dk, a.NUM_ROWS, $VAR_FIELD
       substr(a.status,1,3) st, ' '||substr(a.DEGREE,1,2) dg,
       case a.index_type
            when 'FUNCTION-BASED NORMAL' then 'Func based'
            when 'FUNCTION-BASED DOMAIN' then 'Func domain'
          else a.index_type
       end idx_type, a.tablespace_name, a.global_stats global
from dba_ind_columns b, dba_indexes a, dba_tables c
where a.table_owner     = '$fowner'  $AND_TABLE  and
      b.index_name      = a.index_name           and
      b.table_owner (+) = a.table_owner          and
      b.table_name  (+) = a.table_name           and
      c.table_name      = a.table_name           and
      c.owner           = a.table_owner $AND_LIKE
order
   by a.table_type, a.table_name, a.index_name, column_position
/
"
# ...............................................................................
elif [[ "$choice" = "PART" ]];then

    if [ -n "$FVAR" ];then
         VAR_FIELD="(select sum(bytes/1048576) bytes from dba_segments
                  where segment_name = a.index_name and owner = a.index_owner  and PARTITION_NAME=a.PARTITION_NAME group by owner,segment_name) tot_seg_mb,"
    else
         VAR_FIELD="to_char(nvl(b.last_analyzed,a.last_analyzed),'DD-MM-YY HH24:MI') la,"
    fi
    if [ -n "$LIKE" ];then
       AND_LIKE=" and a.index_name like upper('${LIKE}%') "
    fi

    TITLE="List partitions for '$findex'"
    SQL="
       set head on lines 190 pages 66 verify off feed off pause off
       break on partition_position on partition_name on status on report on tablespace_name
       COL sel                  FORMAT  999999999 heading 'Num rows'
       COL dstk                 FORMAT  999999999 heading 'Distinct rows'
       COL partition_position   FORMAT  9999 heading 'Part| Pos'
       COL fsize                FORMAT  9999999   heading 'Size (m)'
       COL partition_name       FORMAT  A25 head 'Partition name'
       COL subpartition_name    FORMAT  A25 head 'System generated|Subartition name'
       COL tablespace_name      FORMAT  A25   justify c HEAD ' Tablespace name'
       col last_analyzed        format  A18  head 'Last Analyzed'
       col status               format  A8
       col db_block_size new_value fsize noprint
       col tot_seg_mb  for 99999990.9 head 'Total|seg(m)' justify c
       select value db_block_size from v\$parameter where name = 'db_block_size' ;
       comp sum of fsize on report

       select a.partition_position, a.partition_name,  b.subpartition_name,
             (nvl(b.leaf_blocks,a.leaf_blocks) * &fsize )/1024/1024 fsize, a.leaf_blocks,
              rpad(nvl(b.tablespace_name,a.tablespace_name),25) tablespace_name,
              nvl(b.num_rows,a.num_rows) sel , nvl(b.distinct_keys,a.distinct_keys) dstk, $VAR_FIELD
             substr(nvl(b.status,a.status),1,6) status
      from
            dba_ind_partitions a,
            dba_ind_subpartitions b
          where
                  a.index_name     = '$findex' and  a.index_owner= '$fowner'
             and  a.index_owner    = b.index_owner   (+)
             and  a.index_name     = b.index_name  (+)
             and  a.partition_name = b.partition_name  (+)
order by a.partition_position; "
# ...........................................
elif [[  "$choice" = "default" ]];then

    if [[ -n "$CLUSTER_FACTOR" ]];then
             var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off verify off trimspool on
select table_name from dba_indexes where index_name='$findex' and owner = '$fowner' ;
EOF`
             ftable=`echo "$var" | tr -d '\r' | awk '{print $1}'`
             VAR_FIELD2=" round(decode(num_rows,0,0,((CLUSTERING_FACTOR/(select blocks from dba_tables
                           where table_name = '$ftable' and owner='$fowner' ))
                           /(NUM_ROWS/( select blocks from dba_tables
                           where table_name = '$ftable' and owner='$fowner')) ))*100,1) pct ,"
              BLOCKS="c.blocks,"
    fi

    #  add text for function based index
    if [[ -n "$FB" ]];then
        SQL_FB="select COLUMN_POSITION, COLUMN_EXPRESSION from
                     DBA_IND_EXPRESSIONS a where INDEX_NAME = '$findex' and index_owner = '$fowner';"
    fi
    if [ -n "$LIKE" ];then
       AND_LIKE=" and a.index_name like upper('${LIKE}%') "
    fi
    TITLE="Table List - Index stats for $findex"
    SQL=" col db_block_size new_value fsize noprint
col tablespace_name for a26 head 'Tablespace'
set head off feed off
select value db_block_size from v\$parameter where name = 'db_block_size' ;
set heading on pause off  feed off  verify off pagesize 56 linesize 132

break on f1 on f2 on descend on tablespace_name on dg on PARTITIONED on GLOBAL_STATS on USER_STATS on PCT_FREE on FREELISTS on FREELIST_GROUPS on PCT_DIRECT_ACCESS on status
set lines 190
col ini_trans for 999 head 'ini|trs'
col max_trans for 999 head 'max|trs'
select owner, table_name from dba_indexes where index_name ='$findex'  and owner = '$fowner';
select a.index_name f1, substr(uniqueness,1,1)  f2,
       column_name  f3, COLUMN_POSITION cp, descend,
       case nvl(tablespace_name,'0')
            when '0' then
                     case partitioned
                          when 'NO' then
                               case temporary
                                    when 'N' then '--Func base or Domain --'
                                    else '-- Temporary --'
                               end
                          else '-- partitioned --'
                     end
            else tablespace_name
       end tablespace_name,
       substr(DEGREE,1,2) dg,
       PARTITIONED ,GLOBAL_STATS,  USER_STATS,
       PCT_FREE, FREELISTS, FREELIST_GROUPS,
       PCT_DIRECT_ACCESS,
       status
from dba_ind_columns a, dba_indexes b
where  b.index_name      = '$findex'        and 
       b.owner           = '$fowner'        and
       a.index_name (+)     = b.index_name     and
       a.index_owner(+)     = b.owner $AND_LIKE
order
   by b.index_name, column_position
/
break on compression
prompt
-- col table_name new_value table_name noprint
select  Blevel, index_type typ, LEAF_BLOCKS,
        AVG_DATA_BLOCKS_PER_KEY , AVG_LEAF_BLOCKS_PER_KEY ,
        $VAR_FIELD2 DISTINCT_KEYS dk, NUM_ROWS,
        (select sum(bytes/1024/1024) bytes from dba_segments
                where segment_name = '$findex' and owner = '$fowner') bytes,
        decode(nvl(distinct_keys,0),0,0,num_rows/distinct_keys) sel,
        to_char(LAST_ANALYZED,'DD-MM-YY HH24:MI') la , compression, INI_TRANS, max_trans
from
     dba_indexes
where
     index_name = '$findex'  and owner = '$fowner'
/
$SQL_FB
prompt
prompt
"
fi


if [ -n "$VERBOSE" ];then
   echo "$SQL"
fi
       cat <<EOF
MACHINE $HOST - ORACLE_SID : $ORACLE_SID                                     Page:   1
Date              -  `date +%a' '%d' '%B' '%Y' '%H:%M:%S`
Username          -  $S_USER  $TITLE
EOF


sqlplus -s "$CONNECT_STRING" <<EOF
col AVG_DATA_BLOCKS_PER_KEY format 999999 head 'Avg data| Blocks | Per Key'
col AVG_LEAF_BLOCKS_PER_KEY format 999999 head 'Avg leaf| Blocks | Per Key'
col Blevel format 999 head 'Blevel' justify c
col bytes format 99999999 head 'Size(m)' justify c
col compression format A8 head 'Compress' justify c
col cf format 9999999999 head 'Clust| Factor'
col cp format 999 heading 'Col|Pos'
col FREELISTS format 99 head 'Free|List'
col FREELIST_GROUPS format 99 head 'Free| List|Group'
col descend format a4 heading 'Ord'
col dg format A4 heading 'Para|llel'
col dk format 9999999999 head 'Distinct| Keys'
col f1 format a32 heading 'Index Name'
col f2 format a1 heading 'U'
col f3 format a27 heading 'Column name'
col la format A14  head 'last analysed'
col leaf_blocks format 99999999 head 'Leaf|Blocks' justify c
col num_rows format 9999999999 head 'Num rows'
col pct format 990.9 head 'cf(%)'
col USER_STATS format A5 head 'user |Stat' justify c
col GLOBAL_STATS format A6 head 'Global |Stats' justify c
col partitioned format A4 head 'Part|tion'
col PCT_DIRECT_ACCESS format 999999 head '  Pct |Direct|Access' justify c
col pct_free format 999 head 'Pct|Free' justify c
col sel format 99999999.9  head 'Selectivity' justify c
col status format A5 head 'Sta|tus'
col table_name heading 'Table name' format a30
col table_owner heading 'Table owner'
col typ format A10 head 'Index|type' justify c
col owner format a22
col object_owner format a30
col object_name format a31

$SQL
EOF

