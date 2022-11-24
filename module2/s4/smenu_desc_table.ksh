#!/bin/ksh
# author :  B. Polarski
# 20 September 2005
# set -x
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
# ----------------------------------------------------
function get_ftype
{
if [ -n "$fpart" ];then
   var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select 'TABLE PARTITION' ftype from dba_tab_partitions
        where table_name = upper('$ftable') and table_owner=upper('$fowner') and PARTITION_NAME=upper('$fpart')
union
select 'TABLE SUBPARTITION' ftype from dba_tab_subpartitions
         where table_name = upper('$ftable') and table_owner=upper('$fowner') and SUBPARTITION_NAME=upper('$fpart')
union
select 'LOB PARTITION' ftype from dba_lob_partitions
        where table_name = upper('$ftable') and table_owner=upper('$fowner') and LOB_PARTITION_NAME=upper('$fpart')
union
select 'LOB SUBPARTITION' ftype from dba_lob_subpartitions
         where table_name = upper('$ftable') and table_owner=upper('$fowner') and LOB_SUBPARTITION_NAME=upper('$fpart');
EOF`
  ftype=`echo "$var" | tr -d '\r' | awk '{print $0}'`
else # fpart is not given, we search the table type
   var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select ftype from (
select 2 a, 'TABLE PARTITION' ftype from dba_tab_partitions
        where table_name = upper('$ftable') and table_owner=upper('$fowner')
union
select 1 a,'TABLE SUBPARTITION' ftype from dba_tab_subpartitions
         where table_name = upper('$ftable') and table_owner=upper('$fowner')
union
select 4 a,'LOB PARTITION' ftype from dba_lob_partitions
        where lob_name = upper('$ftable') and table_owner=upper('$fowner')
union
select 3 a,'LOB SUBPARTITION' ftype from dba_lob_subpartitions
         where lob_name = upper('$ftable') and table_owner=upper('$fowner')
order by a
) where rownum=1;
EOF`
  ftype=`echo "$var" | tr -d '\r' | awk '{print $0}'`
fi
echo "$ftype" | sed '/session/d'
}
# ----------------------------------------------------
function help
{
cat  <<EOF

           tbl -u <owner>  [-ord <n>]
           tbl -u <owner> -t <table_name> [-al]                     tbl -ext
           tbl -u <owner> -t <table_name> -ldl                      tbl -u <owner> -ext <table_name> -drop
           tbl -u <owner> -t <table_name>  -p  -d                   tbl -u <owner> -t <table_name> -ddl      # get the ddl
           tbl -u <owner> -t <table_name>  -c  -d                   tbl -u <owner> -t <table_name>  -pred    # list table predicate usage
           tbl -u <owner> -t <table_name>  -a  -d -i                tbl -u <owner> -cd <CONSTRAINT TYPE : ie 'P'> -x
           tbl -u <owner> -t <table_name>  -s                       tbl -u <owner> -log|-logc | -logu
           tbl -u <owner> -t <table_name>  -l                       tbl -t <table_name>  -lbs <lob column_name>
           tbl -u <owner> -cl <CONSTRAINT TYPE : ie 'P'>            tbl -u <owner> -t <table_name> -noidxfk
           tbl -u <owner> -ce <CONSTRAINT TYPE : ie 'P'> -x         tbl -like <table_name> (Add a % before, after or at both end) to the part name
           tbl -txn -t <table_name> -u < OWNER> [ -rn <nn> ]        tbl -t <table_name>  -spc|-uspc  -part <PARTITION_NAME>  [-u <OWNER>]
           tbl -g -u <OWNER> -t <table_name>                        tbl [-u <owner>] -t <table_name> -col <COLUMN_NAME>
           tbl -dep -t <table_name> -u < OWNER>                     tbl -ntbs <tbs> -t <table> -u <owner> [-nitbs <tbs>]
           tbl -fk_tree  -u <OWNER> -t <table_name>  -depth <n>     tbl -mkctl -t <table> [-u <OWNER>]
           tbl -luse -u <owner>    
           tbl -rdef -u <OWNER> -t <table_name> -t2  <table_name>   -pm <nbr_par> -col <COL_NAME> -seg <n> -rowid
           tbl -wst -u <OWNER> [-t <table>  [-part <partname>] -lp ]
           tbl -swst -u <OWNER> [-t<table>] [-cascade]
           tbl -tsiz -u <OWNER> [-t<table>]  -pct <n> [-tl <TBL TBL TBL ...>]
           tbl -hist [<nn>] [-u <owner>] -t <table_name> [-rn <nn>]
           tbl -tis  -u <OWNER> -t<table>
           

           add to -t :
           ==============
                 -u  limit to owner                                -a  Chained rows                -d  Table description
                 -c  Constraints                               -fk_tree  List cascading FK on <table> with <table> as root [with <n> depth recursive]
                 -i  additional info on  table                   -lob  show lobs info              -slob generate statement to shrink lob
                 -p  (sub)partitions                               -s  List stats info gathered on columns
               -ldl  display last ddl applied on the table       -ddl  extract ddl of table
              -drop  drop external table                         -lbs  List lob size distrubtion
               -spc  List space map using dbms_space.space_usage -uspc List unused space using dbms_space.unused_space
               -dep  List all dependent segments                 -txn  List transaction available in flash.
              -pred  show predicate usage;                       -ord <n> # values are 1 to 7 and represent columns
                -g   List table columns with histogram on them   -col <COLUMN_NAME> List histograms on COLUMN_NAME
                -cl  List schema Constraints. Constraint type is the letter representing the type of the constraint.  type 'ALL' to see all constraintstype
                -cd  Generate script to Disable schema|table Constraints. Constraint type is the letter representing the type of the constraint.
                     type 'ALL' affect all constraintstype. If you omit table and leave only schema, then all constraints are taken in account
                -ce  Generate script to Enable schema|table Constraints. Constraint type is the letter representing
                     the type of the constraint.  type 'ALL' affect all constraintstype. If you omit table and leave
                     only schema, then all constraint are taken in account
          -truncate  Generate script to truncate all tables in a given schema. '-x' option will not execute this.
               -ext  List all  externamal tables; drop it if -t <table> -drop is added
           -noidxfk  List Foreign key without index and the Parent table name and columns
              -ntbs  Move table to new tbs <tablespace_name>. with -mi move also the indexes
             -nitbs  In conjunction with '-ntbs', move also the indexes to new tablespace
              -like  List all tables whose name is like %xxx%. You need to provide the % yourself : ie: tlb -u soe -like MV_%
                -ph  List all partitions keys
             -mkctl  Create Sqlloader control file for given table  -unload   : Unload table to ascii file, separator is '|'
              -luse  List usage occupancy (ratio (nbr rows*avg size)*blocks size  and compare to current size, sort by worst first
              -rdef  Generated the script for the table redefinition to partition
                          -col       : partition on this column
                          -pm        : number of months back to generate
                          -seg       : create n partiton per month. if 31 then it is one partition per day
              -wst   List table wasted occupancy. Add '-lp' to check partititons status
              -swst  Generate script to shrink table. Add '-cascade to shrink cascade'
              -tsiz  List all object size related to the table : table segment, index, lob
              -al    List allocated extents
              -pct   List only tables whose % is over <pct>
              -hist  List tables grow history sort by day, using dbms_space.object_growth_trend. Add '-hh' sort by hour, add '-mm' sort by 15 minutes.
              -tsiz -tl TBL01 TBL02 ...   :  All words after -tl must be table name. 
              -tis   Show data for table, index, columns. this is the combination of tbl -t, idx -t, tbl -s

               -log  Supplemental log groups    -logc  supplemental column       -logu  supplemental column in table that without FK, PK or BITMAP

      Also you can use : 'idx -t <table_name>' to list associated indexes.  It is intentional that -drop only access external table.
     If you want to drop a table, connect into db.  The time it takes gives you a chance to realize what you do.

     Example:

          tbl -t EMP -u SCOTT -s                  # List all columns statistics
          tbl -t EMP -u SCOTT -p                  # List all partitions
          tbl -t EMP -u SCOTT -g                  # display all colums of table EMP with histogram on them
          tbl -t EMP -u SCOTT -col DEPNO          # display the histogram on column DEPNO
          tbl -t EMP -u SCOTT -ce ALL             # generate script to enable all constraints
          tbl -t EMP -u SCOTT -pred               # list column when they used as predicated and the type of predicate
          tbl -t EMP -u SCOTT -col EMPNO -pred    # list queries that use the column as predicate (from v\$sql_plan)
          tbl -t emp -u SCOTT -ph                 # List the partitions keys
          tbl -u scott -pct 50                    # List table which wastage is equal or over 50%
          tbl -t emp -u SCOTT -unload [-cvs]      # unload data, add -cvs for comma separated (","). Default is pipe
          tbl -rdef -t invoice -pm 12 -col datmaj -seg 5
EOF

exit
}
# ----------------------------------------------------
if [ -z "$1" ];then
  help
fi
PROMPT="
prompt .          tbl -h for extended help
prompt .          use : idx -t <table_name> to list associated indexes of this table
"

ALTERNATE_FIELD="b.num_rows snum,"
IALTERNATE_FIELD="ib.num_rows snum,"

FDATE_FORMAT='YYYY-MM-DD'
LENGHT_FDATE_COL=A12
TRUNC_DATE="TRUNC(systimestamp, 'DD')"
INTERVAL='1 00:00:00'
NBR_MIN=1440
NUM_ROWS=30
desc=FALSE
AND=" and "
typeset -u COL_NAME
typeset -u CONS_TYPE
while [ -n "$1" ]
do
  case "$1" in
    -hist )  req=HIST_GROW ;
             if [ -n "${2}" ];then
                if [ -n "${2%%*[a-z]*}" ];then
                   NUM_ROWS=$2 ;
                   shift;
                fi
             fi
             ;;
      -hh )  NBR_MIN=60 ; TRUNC_DATE="TRUNC(systimestamp, 'HH24')" ; FDATE_FORMAT='YYYY-MM-DD HH24:MI:SS' ; LENGHT_FDATE_COL=A21 ; INTERVAL='0 01:00:00' ;;
      -mm )  NBR_MIN=15 ; TRUNC_DATE="trunc(systimestamp,'mi') - numtodsinterval( mod(to_char(systimestamp,'mi'),15),'minute')" ; FDATE_FORMAT='YYYY-MM-DD HH24:MI:SS' ; LENGHT_FDATE_COL=A21 ;
INTERVAL='0 00:15:00' ;;
       -a )  req=chain  ;;
      -al )  SHOW_ALLOCATED=Y ;;
       -c )  req=constraints  ;;
   -cascade ) CASCADE=CASCADE ;;
      -ce )  req=enable_constraints  ; CONS_TYPE=$2; shift ;;
      -cd )  req=disable_constraints  ; CONS_TYPE=$2; shift ;;
     -col )  COL_NAME=`echo $2|awk '{print toupper($0)}'`; shift ;;
      -cl )  req=list_constraints  ; CONS_TYPE=`echo $2|awk '{print toupper($0)}'`; shift ;;
     -cvs )  CVS=TRUE ;;
  -fk_tree)  req=CTREE ;;
       -d )  desc=TRUE ;;
     -dep )  req=DEP ;;
    -deph )  DEPTH=$2 ; shift ;;
     -ext )  EXTERNAL=TRUE
             if [ -n "$2" -a "$2" != "-u" ]; then
                ftable=`echo $2|awk '{print toupper($0)}'`
                shift
             fi;;
     -ldl )  SQL_DDL=TRUE ;;
     -ddl )  req=ddl ;;
    -drop )  DROP=TRUE ;;
       -g )  req=list_hist_col ;;
      -gv )  req=histogram ;;
       -i )  ADDITIONAL_INFO=TRUE ;;
     -lbs )  req=dis ; COL=$2; shift;;
     -lob )  req=lobs;;
    -slob )  req=slobs;;
     -log )  req=LOG_GROUP ;;
     -luse)  req=LUSE ;;
    -logc )  req=LOG_COL ;;
    -logu )  req=LOG_NO_KEY ;;
      -lp )  LIST_PARTITIONS=TRUE ;;
    -lstx )  LIST_TBL_LAST_EXTENT ;;
      -lt )  list_table="'"$2"'"; shift ; shift
             while [ -n "$1" ]; do
                  list_table="$list_table, '"$1"'"
                  if [ -n "$2" ];then
                     shift
                  else
                     break
                  fi
             done ;; 
   -mkctl )  req=MAKE_SQLLOADER_CTL ;;
    -like )  ftable=${2}% ; OBJECT_LIKE=" and OBJECT_NAME = '$ftable'" ; 
             AND_TABLE_LIKE=" and TABLE_NAME like '$ftable'" ; 
             A_TABLE_LIKE=" and a.TABLE_NAME like upper('$ftable')" ; OBJECT_LIKE=" and a.OBJECT_NAME = upper('$ftable')" ; shift;;
 -noidxfk )  req=noidxfk ;;
    -ntbs )  req=MOVE_TBS; ftbs=`echo "$2" |awk '{print toupper($0) }'`  ; shift ;;
   -nitbs )  MV_ITBS=TRUE
             if [ -n "$2" -a ! "$2" = "-x" -a ! "$2" = "-v" ];then
                   fitbs=`echo "$2" |awk '{print toupper($0) }'` ; shift
             fi
              ;;
     -ord )  ORD_PRED=$2; shift ;;
       -p )  req=part ;;
    -part )  fpart=$2 ;  AND_PART_NAME=" and partition_name = upper('$2') "
             shift ;;
      -ph )  req=part_hv ;;
      -pm )  NUM_PART=$2; shift ;;
     -pct )  PCT=$2 ; shift ;;
    -pred )  req=predicate_usage  ;;
    -rdef )  req=REDEF ;;
    -rowid)  CONS_ROWID=TRUE ;;
      -t2 )  ftable2=`echo "$2" |awk '{print toupper($0) }'` ; shift ;;
      -rn )  NUM_ROWS=$2 ; shift ;;
       -s )  req=stats  ;;
      -seg)  SEG=$2; shift ;;
     -spc )  req=SPACE_USAGE ;;
       -t )  ftable=`echo $2 | awk '{print toupper($0)}'`
             AND_B_TABLE=" and b.TABLE_NAME = upper('$ftable') "
             AND_A_TABLE=" and a.TABLE_NAME = upper('$ftable') "
             AND_TABLE=" and TABLE_NAME = upper('$ftable') "
             OBJECT_LIKE=" and OBJECT_NAME = '$ftable'"
             shift;;
     -tis)   req=TIS; ftable=`echo $2 | awk '{print toupper($0)}'`; shift ;;
     -tsiz)  req=TSIZ ;;
     -txn )  EXECUTE=YES; req=TXN ;;
-truncate )  req="truncate" ;;
       -u )  fowner=`echo "$2" | awk '{print toupper($0)}'` ; 
             FOWNER="owner = '$fowner' " ; AND_FOWNER=" and  $FOWNER" 
             A_FOWNER="a.owner = '$fowner' " ;  AND_A_FOWNER=" and a.owner = '$fowner' "
             AND_L_OWNER=" and l.owner='$fowner'"
             shift;;
  -unload )  req=UNLOAD ;;
    -uspc )  req=UNUSED_SPACE ;;
       -v )  SETXV="set -x" ;;
       -x )  EXECUTE="YES" ;;
       -h )  help ; exit ;;
       -w )  ALTERNATE_FIELD="(nvl(b.blocks,a.blocks) * &fsize)/1048576 fsize,nvl(b.blocks,a.blocks)blocks,"
             IALTERNATE_FIELD="(nvl(ib.leaf_blocks,ia.leaf_blocks) * &fsize)/1048576 fsize,nvl(ib.leaf_blocks,ia.leaf_blocks)blocks," ;;
     -wst )  req=WASTAGE ;;
    -swst )  req=SWASTAGE ;;
        * ) echo "Invalid parameter $1" ;help ; exit ;;
  esac
  shift
done

if [ -z "$fowner" ];then
   FOUT=$SBIN/tmp/tbl_${ORACLE_SID}_${ftable}.log
else
   FOUT=$SBIN/tmp/tbl_${ORACLE_SID}_${fowner}_${ftable}.log
fi

if [ -n "$SQL_DDL" ];then
     if [ -n "$FOWNER" ];then
       AND=" and "
     else
       unset AND
     fi
     SQL_DDL=" select object_name table_name, owner, to_char(created,'YYYY-MM-DD HH24:MI:SS') Created,
               to_char(last_ddl_time, 'YYYY-MM-DD HH24:MI:SS') last_ddl_time, temporary, object_id, data_object_id
                  from dba_objects where object_type = 'TABLE' $AND_FOWNER $OBJECT_LIKE order by 2;"
fi
# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# --------------------------------------------------------------------------
if [ -z "$DBID" ];then
    SHOW_INST=${SHOW_INST:-FALSE}
    ret=`sqlplus -s "$CONNECT_STRING"<<EOF
    set head off verify off pause off
         select dbid , i.instance_number from sys.v_\\$database d, sys.v_\\$instance i;
EOF`
    ret=`echo $ret| tr -d '\n'|tr -d '\r'`
    DBID=`echo "$ret" |awk '{print $1}'`
    if [ -z "$INST_NUM" ];then
       INST_NUM=`echo "$ret" |awk '{print $2}'`
    fi
fi
# --------------------------------------------------------------------------
if [ "$EXTERNAL" = "TRUE"  ];then
   FIELD_LIST="a.owner||'.'|| a.table_name tbl ,  a.DIRECTORY_NAME, b.directory_path||'/'||a.location fil"
   if [ -n "$ftable" ];then
      if [ "$DROP" = "TRUE" ];then
         if [ -z "$fowner" ];then
             echo " I need an owner "
             exit
         fi
         # check the table is a real external table
         var=`sqlplus -s "$CONNECT_STRING" <<EOF
         set pause off lines 190 pages 0 feed off verify off
         select count(*) from all_EXTERNAL_TABLES where TABLE_NAME = '$ftable' and owner = upper('$fowner') ;
EOF`
         ret=`echo $var | tr -d '\r' | awk '{print $1}'`
         if [ $ret -eq 1 ];then
            SQL="DROP TABLE $ftable ;"
            sqlplus -s "$CONNECT_STRING" <<EOF
            $SQL
EOF
         else
            echo "I did not found an external table for ${fowner}.${ftable}"
         fi
         exit
      else
         SQL="select $FIELDS_LIST from dba_external_locations a, dba_directories b
               where table_name = 'ftable' and a.DIRECTORY_NAME = b.DIRECTORY_NAME"
      fi
   else
      SQL="select $FIELD_LIST from dba_external_locations a, dba_directories b
                  where a.DIRECTORY_NAME = b.DIRECTORY_NAME"
   fi
   sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'List external table(s)' nline
from sys.dual
/
prompt

set head on PAGESIZE 55
set linesize 159
col fil format A70 head "File path"
col directory_name format A18
col tbl format A38 head "Owner|Table name"
select tbl,directory_name, fil from ($SQL)
/
EOF
   exit
fi

# we don't perfom an external table operation

# ................................................
$SETXV
if [ "$desc" = "TRUE" -a -n "$ftable" ];then
    # we take only the first one
    if [ -n "$fowner" ];then
    sqlplus -s "$CONNECT_STRING" <<EOF
desc $fowner.$ftable
exit
EOF
    else
    sqlplus -s "$CONNECT_STRING" <<EOF
col owner new_value owner
select owner from dba_tables where table_name = '$ftable' and rownum = 1 ;
desc "&owner"."$ftable"
exit
EOF
    fi
fi
# ................................................
if [ -n "$ftable" -a -z "$fowner"  -a  -z "$A_TABLE_LIKE" ];then
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
set lines 190
col owner for a30
col table_name for a30
select owner, table_name , 'table' from dba_tables where table_name='$ftable' ;
EOF
exit
      fi
   fi
fi
# ...........................................................
# main structure start now
# ...........................................................

# ...........................................................
#  List table size : table segment, index, lob
# ...........................................................
if [ "$req" = "TSIZ" ];then
  if [ -n "$fowner" ];then
    AND_A_OWNER=" and  a.owner = '$fowner' "
  fi
  if [ -n "$ftable" ];then
     AND_A_FTABLE=" and a.table_name = '$ftable'"
  fi
  if [ -n "$list_table" ];then
     AND_A_FTABLE=" and a.table_name in ($list_table)"
  fi

  if [ -n "$AND_TABLE_LIKE"  -o -n "$A_TABLE_LIKE" ];then
     unset AND_TABLE
     unset AND_A_FTABLE
     VAR_SPOOL="spool $SBIN/tmp/tbl_tsiz_`date +%Y%m%d%H%M`.log"
  fi
 ORD_PRED=${ORD_PRED:-tot_tbl}

 if [ -n "$PCT" ];then
    AND_PCT="  vt.wasted is not null and vt.wasted > 0 and vt.wasted/decode(vt.mbs,0,1,vt.mbs)*100   >= $PCT and "
 fi

     sqlplus -s "$CONNECT_STRING"  <<EOF

set lines 170 pages 66
col OWNER for a14 head 'Owner'
col SEG for a30 head 'Segment name'
col mbs head 'Table size'
col wasted head 'Table alloc|but unused'
col tot_tbl head 'Total table|Size(m)' justify c
col idx_mbs head 'Tot idx|Size(m)' justify c
col lob_mbs head 'Tot lob|Size(m)' justify c
col idx_lob_mbs head 'Tot idx|lob(m)' justify c
col pct head 'Wastage' format a8
compute sum of mbs on report
compute sum of idx_mbs on report
compute sum of WASTED on report
compute sum of lob_mbs on report
compute sum of idx_lob_mbs on report
compute sum of tot_tbl on report
break on report
$VAR_SPOOL

 with v as (
  select value block_size from v\$parameter where name = 'db_block_size'
 )
, a as  ( select a.owner, a.table_name, a.partitioned, num_rows, avg_row_len  , blocks
       from dba_tables a where 1=1 $AND_A_OWNER $AND_A_FTABLE $A_TABLE_LIKE
)
,vt as  (  -- non partitioned
select owner, seg , sum(mbs) mbs, sum(wasted) wasted from (
select a.owner, s.segment_name seg, round(s.bytes/1048576,0) MBS,
     round((s.bytes-(a.num_rows*a.avg_row_len) )/1048576,0) WASTED
from
        dba_segments s, a
where
          s.owner=a.owner  $AND_A_OWNER $AND_A_FTABLE
      and s.segment_name = a.table_name $A_TABLE_LIKE
      and s.segment_type='TABLE'  and a.partitioned='NO'
group by
   a.owner, s.segment_name, s.segment_type,
   round (s.bytes/1048576,0) ,
   round((s.bytes-(a.num_rows*a.avg_row_len) )/1048576,0)
-- having round(bytes/1048576,0) >100
union   -- partitioned
   select a.owner, a.table_name seg ,
          round((sum(p.BLOCKS*t.block_size))/1048576,0) MBS,
          round(((sum(p.BLOCKS*t.block_size))-(sum(p.num_rows)*avg(p.avg_row_len)) )/1048576,0) WASTED 
     FROM DBA_TABLES a, DBA_TAB_PARTITIONS p, dba_tablespaces  t
     WHERE
             a.IOT_TYPE is null and a.tablespace_name is null $AND_F  $AND_A_OWNER $AND_A_TABLE $A_TABLE_LIKE 
        and  a.owner = p.table_owner   and a.TABLE_NAME = p.table_name
        and p.tablespace_name = t.tablespace_name 
        and p.num_rows > 0 and p.avg_row_len > 0
            group by a.table_name, a.owner
) group by owner, seg 
)
,vi as ( -- index
 select  owner, table_name, sum( idx_mbs) idx_mbs from (
  select  a.owner, a.table_name, round(s.bytes/1048576,0) idx_MBS
  from
        a, dba_indexes i, dba_segments s
  where
        a.owner=i.owner  $AND_A_OWNER $AND_A_FTABLE $A_TABLE_LIKE
    and a.table_name = i.table_name
    and s.owner = i.owner
    and s.segment_name = i.index_name
  ) group by  owner, table_name
)
,vl as(   -- lobs segment
   select  owner, table_name, sum( lob_mbs) lob_mbs from (
  select
      a.owner, a.table_name, round(s.bytes/1048576,0) lob_MBS
  from
        a,  dba_segments s , dba_lobs l
  where  1=1 $AND_A_OWNER $AND_A_FTABLE $A_TABLE_LIKE
      and a.table_name = l.table_name and a.owner = l.owner and s.segment_name = l.segment_name and l.owner = s.owner) group by  owner, table_name) ,vli as ( select  owner, table_name, sum( lob_mbs) idx_lob_mbs from ( select a.owner, a.table_name, round(s.bytes/1048576,0) lob_MBS from a,  dba_segments s , dba_lobs l where  1=1 $AND_A_OWNER $AND_A_FTABLE $A_TABLE_LIKE and a.table_name = l.table_name and a.owner = l.owner and s.segment_name = l.index_name and s.owner = l.owner) group by  owner, table_name) select vt.owner, vt.seg, vt.mbs, vt.wasted , case when vt.wasted is null then null when vt.wasted = 0 then null else to_char( round((vt.wasted/decode(vt.mbs,0,1,vt.mbs)*100),1)  )  || ' %' end pct, nvl(idx_mbs,0) idx_mbs, nvl(vl.lob_mbs,0) lob_mbs,  nvl(vli.idx_lob_mbs,0) idx_lob_mbs, vt.mbs + nvl(idx_mbs,0) + nvl(vl.lob_mbs,0)  + nvl(vli.idx_lob_mbs,0) tot_tbl
from
   vt  , vi , vl, vli
where
    $AND_PCT  vt.owner = vi.owner (+) 
  and  vt.seg = vi.table_name (+)
  and  vt.owner = vl.owner (+)
  and  vt.seg = vl.table_name (+)
  and  vt.owner = vli.owner (+)
  and  vt.seg = vli.table_name (+) 
order by $ORD_PRED 
/
EOF
exit
# ...........................................................
#  Generate statement to shrink tables
# ...........................................................
elif [ "$req" = "SWASTAGE" ];then

  if [ -n "$fowner" ];then
    AND_A_OWNER=" and  a.owner = '$fowner' "
  fi
  if [ -n "$ftable" ];then
     AND_A_FTABLE=" and b.table_name = '$ftable'"
  fi

  if [ "$LIST_PARTITIONS" = "TRUE" ];then
     if [ -z "$ftable" ];then
        echo "I need a table "
        exit
     fi
  fi
  if [ "$LIST_PARTITIONS" = "TRUE" ];then
     sqlplus -s "$CONNECT_STRING"  <<EOF
   set lines 190 pages 0 feed off
prompt 
   select 
      'alter table ' || owner ||'.'|| table_name || ' enable row movement ;' 
   from 
      dba_tables where  owner = '$fowner' and table_name = '$ftable'
/
prompt 
   select 
      'alter table ' || a.owner ||'.'|| a.segment_name || ' modify partition ' ||
                b.partition_name ||  ' shrink space $CASCADE ;' 
from
        dba_segments a, dba_tab_partitions b
where
         a.owner=b.table_owner $AND_A_OWNER $AND_A_FTABLE
     and a.segment_name = b.table_name
     and a.partition_name = b.PARTITION_NAME
     and a.segment_type='TABLE PARTITION'
group by
   a.owner, a.segment_name, a.segment_type,  b.partition_name,
   round(a.bytes/1048576,0) ,
   round((a.bytes-(b.num_rows*b.avg_row_len) )/1048576,0)
having round(bytes/1048576,0) >100
order by round(bytes/1048576,0) desc
/
prompt 
select
      'alter table ' || owner ||'.'|| table_name || ' disable row movement ;' 
   from 
      dba_tables where  owner = '$fowner' and table_name = '$ftable'
/
prompt 
EOF
  else 
sqlplus -s "$CONNECT_STRING"  <<EOF
set lines 190 pages 0
   select 
      'alter table ' || a.owner ||'.'|| a.segment_name || ' enable row movement ;' ||chr(10) ||
      'alter table ' || a.owner ||'.'|| a.segment_name || ' shrink space $CASCADE ;' ||chr(10) ||
      'alter table ' || a.owner ||'.'|| a.segment_name || ' disable row movement ;' ||chr(10) fline
from
        dba_segments a, dba_tables b
where
         a.owner=b.owner $AND_A_OWNER $AND_A_FTABLE
     and a.owner not like 'SYS%'
     and a.segment_name = b.table_name
     and a.segment_type='TABLE'
group by
   a.owner, a.segment_name, a.segment_type,
   round(a.bytes/1048576,0) ,
   round((a.bytes-(b.num_rows*b.avg_row_len) )/1048576,0)
having round(bytes/1048576,0) >100
order by round(bytes/1048576,0) desc
/
EOF
 fi
# ...........................................................
# list table wastage
# ...........................................................
# small script found on the web, can't remember where, sorry 
# for the author.
elif [ "$req" = "WASTAGE" ];then

  if [ -n "$fowner" ];then
    AND_A_OWNER=" and  a.owner = '$fowner' "
  fi
  if [ -n "$ftable" ];then
     AND_A_FTABLE=" and b.table_name = '$ftable'"
  fi
  if [ "$LIST_PARTITIONS" = "TRUE" ];then
     if [ -z "$ftable" ];then
        echo "I need a table "
        exit
     fi
  fi
  if [ "$LIST_PARTITIONS" = "TRUE" ];then

sqlplus -s "$CONNECT_STRING"  <<EOF
set lines 159 pages 66
col OWNER for a22 head 'Owner'
col SEGMENT_NAME for a26 head 'Segment name' 
col a.segment_type for a12

   select 
     a.owner, a.segment_name, a.partition_name,
     round(a.bytes/1048576,0) MBS,
     round((a.bytes-(b.num_rows*b.avg_row_len) )/1048576,0) WASTED
from 
        dba_segments a, dba_tab_partitions b
where 
         a.owner=b.table_owner $AND_A_OWNER $AND_A_FTABLE
     and a.segment_name = b.table_name
     and a.partition_name = b.PARTITION_NAME
     and a.segment_type='TABLE PARTITION'
group by 
   a.owner, a.segment_name, a.segment_type,  a.partition_name,
   round(a.bytes/1048576,0) ,
   round((a.bytes-(b.num_rows*b.avg_row_len) )/1048576,0)
having round(bytes/1048576,0) >100
order by round(bytes/1048576,0) desc
/
EOF

  else    

sqlplus -s "$CONNECT_STRING"  <<EOF
set lines 159 pages 66
col OWNER for a28 head 'Owner'
col SEGMENT_NAME for a30 head 'Segment name' 
col a.segment_type for a12
compute sum of mbs on report
compute sum of WASTED on report
break on report

select 
     a.owner, a.segment_name, a.segment_type,
     round(a.bytes/1048576,0) MBS,
     round((a.bytes-(b.num_rows*b.avg_row_len) )/1048576,0) WASTED
from 
        dba_segments a, dba_tables b
where 
         a.owner=b.owner $AND_A_OWNER $AND_A_FTABLE
     and a.owner not like 'SYS%'
     and a.segment_name = b.table_name
     and a.segment_type='TABLE'  and b.partitioned='NO'
group by 
   a.owner, a.segment_name, a.segment_type, 
   round(a.bytes/1048576,0) ,
   round((a.bytes-(b.num_rows*b.avg_row_len) )/1048576,0)
having round(bytes/1048576,0) >=10
union
   select 
     a.owner, a.table_name, 'TABLE PARTITIONED',
     round(sum(BLOCKS*t.block_size))/1048576,0) MBS,
     round(sum((BLOCKS*t.block_size)-(a.num_rows*a.avg_row_len)) )/1048576,0) WASTED
from 
         dba_tables a , v , dba_tablespaces t
where 1=1 $AND_A_OWNER $AND_TABLE
     and a.owner not like 'SYS%'
     and a.partitioned='YES'
     and round(BLOCKS*v.block_size/1048576,0) >=10
     and a.tablespace = t.tablespace
group by a.owner, a.table_name, 'TABLE PARTITIONED'
order by 5 desc
/
EOF
 fi
# ...........................................................
#   Table redefinition
# ...........................................................
elif [ "$req" = "REDEF" ];then
# if redef fails, use this to clean TEMPORARY SEG:
# select ts# from sys.ts$ where name = '<Tablespace name>' and online$ != 3;
# If ts# is 5, an example of dropping the temporary segments in that tablespace 
# alter session set events 'immediate trace name DROP_SEGMENTS level 6';
# set -x
#union all
#select table_name, 'constraints', constraint_name 
#       from dba_constraints where table_name = '$ftable' and owner = '$fowner'
if [ -z "$ftable2" ] ;then
    ftable2=R_${ftable}
    flen=`echo $ftable2|wc -c`
    if [ $flen -gt 30 ];then
        echo "ftable2 name $ftable2 is over 30 at $flen"
        exit
    fi
else
   ftable2=`echo "$ftable2" |awk '{print toupper($0) }`
   ftable=`echo "$ftable" |awk '{print toupper($0) }`
fi

  if [ -n "$NUM_PART" ];then
     is_partitionned='y'
     SEG=${SEG:-1}
     if [ -z "$COL_NAME" ];then
          echo "partition requested but not partition column name given";
          exit ;
     fi
  else
     is_partitionned='n'
     NUM_PART=0
  fi
#bpa
var=`sqlplus -s "$CONNECT_STRING"  <<EOF
set feed off pagesize 0 head off
    select count(*) from all_tables where table_name = '$ftable2' and owner=upper('$fowner');
EOF`
ret=`echo "$var" | awk '{print $1}'`

if [ "$ret" -gt 0 ];then
   echo  "Warning : the table $fouwner.$ftable2  already exists"
fi
  echo "Run this before"
  echo "-- abort :"
  echo "-- execute dbms_redefinition.abort_redef_table( '$fowner','$ftable', '$ftable2',null ) ;"   
 sqlplus -s "$CONNECT_STRING"  <<EOF
 set serveroutput on 
 set lines 32000 pages 0
 set long 300000 longchunksize 300000
 set trimspool on
 set feed off
declare
  metadata_handle number;
  transform_handle number;
  ddl_handle number;
  result_array sys.ku\$_ddls;
  sqlcmd clob := ' ';
  v_line varchar(1256);
  v_var varchar2(40) ;
  v_comma varchar2(1):=' ';
  v_day_in_month number ;
  v_date date;
  v_periode number;
  v_mod_rest number ;
  v_month number ;
  v_seg number ;
  cpt number ;
  pos number ;

  procedure  print_clob(p_clob IN CLOB) IS
   l_offset     INT := 1;
  BEGIN
    loop
        exit when l_offset > dbms_lob.getlength(p_clob);
        dbms_output.put_line( dbms_lob.substr( p_clob, 3999, l_offset ) );
        l_offset := l_offset + 3999;
    end loop;
 end print_clob;

begin
  metadata_handle := dbms_metadata.open('TABLE');
  transform_handle := dbms_metadata.add_transform(metadata_handle, 'MODIFY');
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.session_transform,'SQLTERMINATOR', true);
  dbms_metadata.set_remap_param(transform_handle, 'REMAP_NAME', '$ftable', '$ftable2');
  ddl_handle := dbms_metadata.add_transform(metadata_handle, 'DDL' ) ;
  dbms_metadata.set_transform_param(ddl_handle, 'PRETTY', FALSE);  
  dbms_metadata.set_filter(metadata_handle, 'SCHEMA', '$fowner');
  dbms_metadata.set_filter(metadata_handle, 'NAME', '$ftable');
  sqlcmd:=dbms_metadata.get_ddl('TABLE','$ftable','$fowner') ; 
   
  if  '$is_partitionned' = 'n' then 
       print_clob(sqlcmd || ';' ) ;
  else
       sqlcmd:=sqlcmd || chr(10) || 'PARTITION BY RANGE ("$COL_NAME")' || chr(10) || '(' || chr(10);
       for c in ( select level as flevel from dual connect by level<=$NUM_PART order by level desc)
       loop
          -- (PARTITION "PM2000_01"  VALUES LESS THAN ('20000201') SEGMENT CREATION IMMEDIATE
          -- v_line := v_comma || 'PARTITION "PM'||to_char(add_months(sysdate,-c.flevel+1),'YYYY') || '_'||to_char(add_months(sysdate,-c.flevel+1),'MM') ||
          --           '" VALUES LESS THAN (''' || to_char(add_months(sysdate,-c.flevel+2),'YYYYMM') || '01'') SEGMENT CREATION IMMEDIATE' || chr(10);

          v_date:=last_day(add_months(sysdate,-c.flevel+1));
          v_day_in_month:=to_number(to_char(v_date,'DD'));
          if v_seg = 0  or v_seg is null then
             v_seg:=1 ;
          end if ;
          if v_seg > v_day_in_month then
             v_seg:=v_day_in_month;
           end if ;
  
          v_periode:=trunc(v_day_in_month/v_seg); 
          if v_periode=0 then
             v_periode:=1;
          end if ;
          v_mod_rest:=mod(v_day_in_month, v_seg);
          -- smooth the periode 
          pos:=0;
          for p in 1..v_seg
          loop
             if v_mod_rest > 0 then
                cpt:=v_periode+1 ;
                v_mod_rest:=v_mod_rest-1;
             else
                cpt:=v_periode ;
             end if ;
             pos:=pos+cpt;
             v_line := v_comma || 'PARTITION "PM'||to_char(add_months(sysdate,-c.flevel+1),'YYYY') || '_'||to_char(add_months(sysdate,-c.flevel+1),'MM') ||
                    '_'||to_char(p) || '" VALUES LESS THAN (''' || 
                    to_char(to_date(to_char(add_months(sysdate,-c.flevel+1),'YYYYMM') || '01','YYYYMMDD')+pos,'YYYYMMDD') ||''') SEGMENT CREATION IMMEDIATE' || chr(10);
             sqlcmd  :=sqlcmd||v_line ;
             v_comma :=',' ; 
          end loop ;
          --sqlcmd  :=sqlcmd||v_line ;
       end loop ;
       print_clob(sqlcmd || ');' ) ;
  end if ;
  dbms_metadata.close(metadata_handle);
  -- indexes  
  for  idx in ( select index_name from all_indexes where owner =upper('$fowner') and table_name = upper('$ftable' ) )
  loop 
     dbms_output.put_line('-- prompt idx='|| idx.index_name);
     metadata_handle := dbms_metadata.open('INDEX');
     transform_handle := dbms_metadata.add_transform(metadata_handle, 'MODIFY');
     DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.session_transform,'SQLTERMINATOR', true);
     v_var:=idx.index_name ||'_R';
     dbms_metadata.set_remap_param(transform_handle, 'REMAP_NAME', idx.index_name, v_Var);
     dbms_metadata.set_filter(metadata_handle, 'NAME', idx.index_name);
     dbms_metadata.set_remap_param(transform_handle, 'REMAP_NAME', '$ftable', '$ftable2');
     ddl_handle := dbms_metadata.add_transform(metadata_handle, 'DDL' ) ;
     dbms_metadata.set_transform_param(ddl_handle, 'PRETTY', FALSE);  
     dbms_metadata.set_filter(metadata_handle, 'SCHEMA', '$fowner');
     sqlcmd:=dbms_metadata.fetch_clob(handle => metadata_handle);
     --dbms_output.put_line(sqlcmd || ';' ) ;
      print_clob(sqlcmd || ');' ) ;
     dbms_metadata.close(metadata_handle);
   end loop ;
  -- triggers  
  for  trg in ( select trigger_name from dba_triggers where owner =upper('$fowner') and table_name = upper('$ftable' ) )
  loop 
     dbms_output.put_line('-- prompt trg='|| trg.trigger_name);
     v_var:=trg.trigger_name ||'_R';
     metadata_handle := dbms_metadata.open('TRIGGER');
     transform_handle := dbms_metadata.add_transform(metadata_handle, 'MODIFY');
     ddl_handle := dbms_metadata.add_transform(metadata_handle, 'DDL' ) ;
     dbms_metadata.set_transform_param(ddl_handle, 'PRETTY', FALSE);  
     dbms_metadata.set_filter(metadata_handle, 'NAME', trg.trigger_name);
     dbms_metadata.set_filter(metadata_handle, 'SCHEMA', '$fowner');
     dbms_metadata.set_remap_param(transform_handle, 'REMAP_NAME', trg.trigger_name, v_Var);
     sqlcmd:=dbms_metadata.fetch_clob(handle => metadata_handle);
     --dbms_output.put_line(sqlcmd || ';' ) ;
     print_clob(sqlcmd || ';' ) ;
     dbms_metadata.close(metadata_handle);
   end loop ;
end;
/
EOF
if  [ $S_USER = 'SYS' ];then
if [ -n "$CONS_ROWID=TRUE" ];then
    CONS_ROWID=",DBMS_REDEFINITION.CONS_USE_ROWID"
    OPT_FLAG=",options_flag => DBMS_REDEFINITION.CONS_USE_ROWID"
fi
sqlplus -s "$CONNECT_STRING"  <<EOF
 set serveroutput on 
 set lines 190 pages 90 
 exec sys.dbms_redefinition.can_redef_table('$fowner', '$ftable' $CONS_ROWID);
EOF
fi
cat <<EOF

 alter session enable parallel dml ;
 alter session force parallel dml parallel 4 ;
 alter session force parallel query parallel 4 ;
 alter session set deferred_segment_creation=FALSE;

execute DBMS_REDEFINITION.start_redef_table( uname => '$fowner', orig_table => '$ftable', int_table  => '$ftable2' $OPT_FLAG );
EOF
#generate the index dependent objects
   sqlplus -s "$CONNECT_STRING"  <<EOF
set lines 2000 pages 0 feed off
select 
 'execute DBMS_REDEFINITION.REGISTER_DEPENDENT_OBJECT(''$fowner'', ''$ftable'', ''$ftable2'',2,''$fowner'',''' ||upper(index_name) || ''','''|| upper(index_name)||'_R'');'
 from dba_indexes where owner='$fowner' and table_name = '$ftable'
/
select 
 'execute DBMS_REDEFINITION.REGISTER_DEPENDENT_OBJECT(''$fowner'', ''$ftable'', ''$ftable2'',4,''$fowner'',''' ||upper(trigger_name) || ''','''|| upper(trigger_name)||'_R'');'
 from dba_triggers where owner='$fowner' and table_name = '$ftable'
/
EOF

cat <<EOF
variable error_count number ;
execute DBMS_REDEFINITION.COPY_TABLE_DEPENDENTS('$fowner', '$ftable', '$ftable2', dbms_redefinition.cons_orig_params, TRUE,TRUE,TRUE,TRUE, :error_count);
print error_count ;

-- Optionally synchronize new table with interim data before index creation
execute DBMS_REDEFINITION.sync_interim_table( uname => '$fowner', orig_table => '$ftable', int_table  => '$ftable2');
execute DBMS_REDEFINITION.FINISH_REDEF_TABLE( uname => '$fowner', orig_table => '$ftable', int_table  => '$ftable2');
/
EOF
exit
# ...........................................................
#  Show table internal occupancy
# ...........................................................
elif [ "$req" = "LUSE" ];then
  [[ -z "$fowner" ]] && echo "I need at least schema name " && exit
  EXECUTE=YES
  sqlplus -s "$CONNECT_STRING" <<EOF
  col b_size new_value b_size noprint 
  select value b_size from v\$parameter where name = 'db_block_size' ;
  set lines 190  pages 90 verify off 
  col m_size format 999990.99 head 'Size(m)'
  col OPTIMAL_BLOCKS for 99999990.9 head 'Optimal nbr|of blocks' justify c
  col AVG_ROW_PER_BLOCK for 9999 head 'Avg row|per block'
  col empty_blocks head 'Empty|blocks'
  col ratio for 99990.9 head 'Ratio|Block/Optim'
  col has_long_col head 'Long' for a4
  prompt .    Tables without long may be shrinked online:
  prompt
  prompt .         alter table [table] enable row movement;
  prompt .         alter table [table] shrink space cascade;
  prompt .         alter table [table] disable row movment;

  with v as 
    ( select sum(BYTES)/1048576 m_size, segment_name 
          from dba_segments where owner='$fowner' group by segment_name
  ), v1 as 
  (
   select distinct table_name,'X' has_long_col from dba_tab_columns where owner =  '$fowner' and DATA_TYPE='LONG'
  )
  select * from (
     select
          has_long_col, a.table_name,  NUM_ROWS, 
          decode(AVG_ROW_LEN,0,0, trunc(&&b_size/AVG_ROW_LEN) ) avg_row_per_block,
          blocks,
          decode(AVG_ROW_LEN,0,0, num_rows/trunc(&&b_size/AVG_ROW_LEN)) optimal_blocks,
           blocks/decode(AVG_ROW_LEN,0,decode(blocks,0,1,blocks), num_rows/trunc(&&b_size/AVG_ROW_LEN)) ratio,
           m_size,
          empty_blocks, 
          to_char(LAST_ANALYZED,'YYYY-MM-DD HH24:MI:SS') Last_analyzed
     from 
           all_tables a , v , v1
     where 
           a.owner='$fowner' and a.blocks > 5
      and  a.table_name = v.segment_name
      and a.table_name = v1.table_name (+)
   order by blocks/decode(AVG_ROW_LEN,0,decode(blocks,0,1,blocks), num_rows/trunc(&&b_size/AVG_ROW_LEN)) desc
   ) where 
      rownum <=   $NUM_ROWS 
/
EOF
# ...........................................................
# Create sql loader control file
# ...........................................................
elif [ "$req" = "UNLOAD" ];then

  [[ -z "$ftable" ]] && echo "I need a tables name" && exit
  [[ -z "$fowner" ]] && echo "I need at least schema name " && exit
SPOOL=$SBIN/tmp/doit.sql
if [ "$EXECUTE" = "YES" ];then
    DOIT="@$SPOOL"
else
    unset DOIT
fi
if [ "$CVS" = TRUE ];then
     SEP='","'
     SEP_BEG='"'
     SEP_END='"'   
else
     SEP='|'
     SEP_BEG=''
     SEP_END=''   
fi
sqlplus -s "$CONNECT_STRING"  > $SPOOL 2>&1 <<EOF

set serveroutput on  FORMAT WORD_WRAPPED;
set trimspool on longchunksize 32000 long 32000 
set lines 190 pages 0 feed off verify off head off

declare

v_owner varchar2(30):='$fowner';
v_table varchar2(30):='$ftable';
sql_01 varchar2(32000);
sql_02 varchar2(32000);
sql_03 varchar2(32000);
v_sep varchar2(3):='$SEP' ;
v_sep_beg varchar2(3):='$SEP_BEG' ;
v_sep_end varchar2(3):='$SEP_END' ;
v_com varchar2(1):='';
v_com20 varchar2(20):='';
cpt  number:=0;

lStr Varchar2(1000);
PROCEDURE put_long_line(Ptext IN LONG, Plen  IN NUMBER DEFAULT 80, Pwhsp IN VARCHAR2 DEFAULT
                                   CHR(10) || CHR(32) || CHR(9) || ',')
  IS
 
    NL CONSTANT VARCHAR2(1) := CHR(10);    -- newline character (OS-independent)
    SP CONSTANT VARCHAR2(1) := CHR(32);    -- space character
    TB CONSTANT VARCHAR2(1) := CHR(9);     -- tab character
    CM CONSTANT VARCHAR2(1) := ',';        -- comma
    start_pos   INTEGER := 1;              -- start of string to print
    stop_pos    INTEGER;                   -- end of substring to print
    done_pos    INTEGER := LENGTH(Ptext);  -- end of string to print
    nl_pos      INTEGER;       -- point where newline found
    len         INTEGER := GREATEST(LEAST(Plen, 255), 10);  -- 10 <= len <= 255!
 
  BEGIN
 
    IF (done_pos <= len) THEN  -- short enough to write in one chunk
      DBMS_OUTPUT.put_line(Ptext);
    ELSE  -- must break up string
      WHILE (start_pos <= done_pos) LOOP
        nl_pos := INSTR(SUBSTR(Ptext, start_pos, len), NL) + start_pos - 1;
 
        IF (nl_pos >= start_pos) THEN  -- found a newline to break on
          DBMS_OUTPUT.put_line(SUBSTR(Ptext, start_pos, nl_pos-start_pos));
 
          start_pos := nl_pos + 1;  -- skip past newline
        ELSE  -- no newline exists in chunk; look for whitespace
 
          stop_pos := LEAST(start_pos+len-1, done_pos);  -- next chunk not EOS
 
          IF (stop_pos < done_pos) THEN  -- intermediate chunk
            FOR i IN REVERSE start_pos .. stop_pos LOOP
 
              IF (INSTR(Pwhsp, SUBSTR(Ptext, i, 1)) != 0) THEN
                stop_pos := i;  -- found suitable break pt
                EXIT;  -- break out of loop
              END IF;
            END LOOP;  -- find break pt
          ELSE  -- this is the last chunk
            stop_pos := stop_pos + 1;  -- point just past EOS
          END IF;  -- last chunk?
 
          DBMS_OUTPUT.put_line(SUBSTR(Ptext, start_pos, stop_pos-start_pos+1));
          start_pos := stop_pos + 1;  -- next chunk
        END IF;  -- find newline to break on
      END LOOP;  -- writing chunks
    END IF;  -- short enou
 end;

begin
  sql_01:='select '|| chr(10) || '                     ';
  for c in ( select column_name, data_type
              from all_tab_columns
                    where owner=upper(v_owner) and table_name = upper(v_table)  order by column_id )
  loop
       sql_01:=sql_01|| v_com|| c.column_name ;
       cpt :=cpt+1;
       if cpt=3 then
          sql_01:=sql_01||chr(10)||'                    ';
          cpt:=0;
       end if;
       v_com:=',' ;
  end loop;
  sql_01:=sql_01||chr(10) || '                from ' || v_owner ||'.'|| v_table ;
  sql_02:=q'{set serveroutput on
set lines 32000 longchunksize 32000 head off pages 0
set verify off feed off trimspool on
declare
      ret    varchar2(32000);
      v_user varchar2(30);
      function frlob( loc blob) return varchar2
    is
      l_buffer    varchar2(32000);
      ret         varchar2(32000);
      l_amount    BINARY_INTEGER := 32767;
      l_pos       INTEGER := 1;
      l_blob_len  INTEGER;
   begin
       l_blob_len := DBMS_LOB.getlength(loc);
       WHILE l_pos < l_blob_len LOOP
            DBMS_LOB.read(loc, l_amount, l_pos, l_buffer);
            l_pos := l_pos + l_amount;
            ret:=ret||l_buffer;
       END LOOP;
       return ret;
   end ;
   begin
      for c in (}';
  sql_02:=sql_02||sql_01 || ' )'||chr(10) || '    Loop';

  -- We start now to buid the output query
  sql_03:=sql_02||chr(10)||' dbms_output.put_line( ''' || v_sep_beg ||'''||';
  v_com:='';
  cpt:=0;
  for c in ( select column_name, data_type
              from all_tab_columns
                    where owner=upper(v_owner)
                    and table_name = upper(v_table) order by column_id )
  loop
       if c.data_type = 'BLOB' then
           sql_03:=sql_03|| v_com20|| ' frlob(  c.'||c.column_name ||')';
       elsif  c.data_type = 'NUMBER' then
           sql_03:=sql_03|| v_com20|| ' to_char(c.'||c.column_name ||')';
       else
           sql_03:=sql_03|| v_com20|| 'c.'||c.column_name ;
       end if;
        cpt :=cpt+1;
        if cpt=3 then
           sql_03:=sql_03||chr(10)||'                    ';
           cpt:=0;
        end if;
       v_com20:='||'''||v_sep||'''||';
  end loop;
  sql_03:=sql_03||'||'''||v_sep_end||''');'||chr(10)||' end loop;' || chr(10) || 'end;'||chr(10)||'/';
  dbms_output.put_line(sql_03);
  -- put_long_line(sql_03);
end;
/
EOF
cat $SPOOL
if [ "$EXECUTE" = "YES" ];then
   sqlplus -s "$CONNECT_STRING" <<EOF
set head off lines 32000 trimspool on pause off verify off feed off head off pages 0
@$SPOOL
EOF
fi
exit
# ...........................................................
# Create sql loader control file
# ...........................................................
elif [ "$req" = "MAKE_SQLLOADER_CTL" ];then

  [[ -z "$ftable" ]] && echo "I need a tables name" && exit
  [[ -z "$fowner" ]] && echo "I need at least schema name " && exit

#cat <<EOF
sqlplus -s "$CONNECT_STRING" <<EOF
set head off lines 190 trimspool on pause off verify off feed off
-- spool $fowner_$ftable.ctl

col column_id noprint;
col v_max_pos new_value v_max_pos noprint;
select max(column_id) v_max_pos from all_tab_columns
        where table_name = upper('$ftable') and owner = upper('$fowner')
/
prompt v_max_pos=&v_max_pos
select 'load data' || chr(10) ||
      'infile ' || ''''|| lower('$ftable') || '.txt' || '''' || chr(10) ||
      'bad file ' || ''''|| lower('$ftable') || '.bad' || '''' || chr(10) ||
      'discard file ' || ''''|| lower('$ftable') || '.disc'||  '''' || chr(10) ||
      'into table $fowner.$ftable' || chr(10) ||
        'fields terminated by ' || '''' || '|' || '''' ||
        ' optionally enclosed by ' || '''' || '"' || '''',0 column_id  from dual
union
select
      case column_id
        when 1 then '( ' ||column_name || ','
        when &v_max_pos then ','|| column_name ||') '
        else  column_name ||','
      end ,
      column_id
     from
            all_tab_columns
     where
          table_name = upper('$ftable')
      and owner = upper('$fowner')
order by 2
/
EOF
exit
# ...........................................................
# Move table to another tablespace
# ...........................................................
elif [ "$req" = "CTREE" ];then

  [[ -z "$ftable" ]] && echo "I need a tables name" && exit
  [[ -z "$fowner" ]] && echo "I need at least schema name " && exit

DEPTH=${DEPTH:-4}

sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 130 termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  || '            Show cascading FK on $ftable: Recursive depth = $DEPTH (use -depth <n> to increase) ' from sys.dual
/
set linesize 190 head on pagesize 0
set serveroutput on
declare
  ls_owner         varchar2( 30 ) := upper( '$fowner' );
  ls_table_name    varchar2( 30 ) := upper( '$ftable' );
  li_depth         integer        := $DEPTH;

  cursor c_no_pks is
    select table_name
    from dba_tables a
    where owner = ls_owner
      and not exists
      ( select 1
        from dba_constraints
        where owner = ls_owner
          and table_name = a.table_name
          and constraint_type = 'P' )
   order by table_name;


  cursor c_no_fks is
    select *
    from dba_constraints a
    where owner = ls_owner
      and constraint_type = 'P'
      and not exists
      ( select 1
        from dba_constraints
        where r_constraint_name = a.constraint_name
            and R_OWNER = a.owner )
   order by table_name;

  cursor c_pks_with_fks is
    select *
    from dba_constraints a
    where owner = ls_owner
      and table_name = nvl( ls_table_name, table_name )
      and constraint_type = 'P'
      and exists
      ( select 1
        from dba_constraints
        where r_constraint_name = a.constraint_name
               and R_OWNER = a.owner)
   order by table_name;

   cursor c_get_pk ( x_table_name in varchar2 ) is
     select constraint_name
     from dba_constraints
     where owner = ls_owner
       and table_name = x_table_name
       and constraint_type = 'P';

  cursor c_fks_attached ( x_pk in varchar2 ) is
    select count(*)
    from dba_constraints a
    where r_owner = ls_owner
      and r_constraint_name = x_pk;

  li_fks_attached integer;

  li_counter integer := 0;

  ls_attached varchar2( 4000 );

  cursor c_get_cons_cols (x_constraint_name in varchar2 ) is
    select * from dba_cons_columns
    where owner = ls_owner and constraint_name = x_constraint_name
    order by position;

  li_tab_counter integer := 0;
  -- ----------------------------------------------------------------------------------------------------------
  procedure p_attached ( x_table_name in varchar2 ) is
    ls_pk     dba_constraints.constraint_name%type;
    ls_fk_pk  dba_constraints.constraint_name%type;

    cursor c_get_fk_tables is
      select table_name, constraint_name, status
      from dba_constraints
      where r_constraint_name = ls_pk
        and r_owner = ls_owner
      order by table_name;

    ls_tabs varchar2( 100 ) := '';

  begin

    li_tab_counter := li_tab_counter + 1;

    if li_tab_counter > li_depth then
      li_tab_counter := li_tab_counter - 1;
      return;
    end if;

    for x in 1..li_tab_counter loop
      ls_tabs := ls_tabs || chr(9);
    end loop;

    for i_c_get_pk in c_get_pk ( x_table_name ) loop
      ls_pk := i_c_get_pk.constraint_name;
    end loop;

    for i_c_get_fk_tables in c_get_fk_tables loop
      if i_c_get_fk_tables.table_name = x_table_name then
        dbms_output.put_line( ls_tabs || '<' || rpad( '-', li_tab_counter, '-' ) || i_c_get_fk_tables.table_name || ' >>> SELF REFERENCING <<<' );
      else
        dbms_output.put_line( ls_tabs || '<' || rpad( '-', li_tab_counter, '-' ) || i_c_get_fk_tables.table_name );
      end if;

      if ls_table_name is not null then

        if nvl( i_c_get_fk_tables.status, 'xx' ) = 'DISABLED' then
          dbms_output.put_line( ls_tabs || chr(9) || 'Foreign Key : ' || i_c_get_fk_tables.constraint_name || ' * * * DISABLED * * *' );
        else
          dbms_output.put_line( ls_tabs || chr(9) || 'Foreign Key : ' || i_c_get_fk_tables.constraint_name );
        end if;

        for i_c_get_cons_cols in c_get_cons_cols( i_c_get_fk_tables.constraint_name ) loop
          dbms_output.put_line( ls_tabs || chr(9) || i_c_get_cons_cols.position || '. ' || i_c_get_cons_cols.column_name );
        end loop;
        -- dbms_output.put_line( chr(10) );

        if li_tab_counter < li_depth then
          for i_c_get_pk in c_get_pk ( i_c_get_fk_tables.table_name ) loop
            ls_fk_pk := i_c_get_pk.constraint_name;
          end loop;


          if ls_fk_pk is not null then
            open c_fks_attached ( ls_fk_pk );
            fetch c_fks_attached into li_fks_attached;
            close c_fks_attached;
            if li_fks_attached > 0 then
              dbms_output.put_line( ls_tabs || chr(9) || 'Primary Key : ' || ls_fk_pk );
              for i_c_get_cons_cols in c_get_cons_cols( ls_fk_pk ) loop
                dbms_output.put_line( ls_tabs || chr(9) || i_c_get_cons_cols.position || '. ' || i_c_get_cons_cols.column_name );
              end loop;
              -- dbms_output.put_line( chr(10) );
            end if;
          end if;
        end if;

      end if;

      -- if a table has a pk referencing its own pk an infinite loop occurs
      if i_c_get_fk_tables.table_name <> x_table_name then
        p_attached( i_c_get_fk_tables.table_name );
      end if;
    end loop;

    li_tab_counter := li_tab_counter - 1;

  end;
  -- ----------------------------------------------------------------------------------------------------------

begin

  if ls_table_name is null then
    dbms_output.put_line( chr(10) );

    dbms_output.put_line( 'Tables without a primary key' );
    dbms_output.put_line( '----------------------------' );
    li_counter := 0;
    for i_c_no_pks in c_no_pks loop
      dbms_output.put_line( i_c_no_pks.table_name );
      li_counter := li_counter + 1;
    end loop;
    if li_counter = 0 then
      dbms_output.put_line( 'None found.' );
    end if;

    dbms_output.put_line( chr(10) );

    dbms_output.put_line( 'Tables with primary key but no foreign keys attached' );
    dbms_output.put_line( '----------------------------------------------------' );
    li_counter := 0;
    for i_c_no_fks in c_no_fks loop
      dbms_output.put_line( rpad( i_c_no_fks.table_name, 30 ) || ' ' ||
                            rpad( i_c_no_fks.constraint_name, 30 ) );
      li_counter := li_counter + 1;
    end loop;
    if li_counter = 0 then
      dbms_output.put_line( 'None found.' );
    end if;

  end if;

  dbms_output.put_line( chr(10) );

  for i_c_pks_with_fks in c_pks_with_fks loop
    li_tab_counter := 0;
    dbms_output.put_line( chr(10) || i_c_pks_with_fks.table_name || '   Primary Key : ' || i_c_pks_with_fks.constraint_name );
    if ls_table_name is not null then
      dbms_output.put_line( rpad( '-', length(  i_c_pks_with_fks.table_name || '   Primary Key : ' || i_c_pks_with_fks.constraint_name ), '-' ) );
      for i_c_get_cons_cols in c_get_cons_cols( i_c_pks_with_fks.constraint_name ) loop
        dbms_output.put_line( chr(9) || i_c_get_cons_cols.position || '. ' || i_c_get_cons_cols.column_name );
      end loop;
    end if;
    dbms_output.put_line( rpad( '-', length(  i_c_pks_with_fks.table_name || '   Primary Key : ' || i_c_pks_with_fks.constraint_name ), '-' ) );
    p_attached( i_c_pks_with_fks.table_name );
  end loop;

end;
/
EOF
exit
# ...........................................................
# Move table to another tablespace
# ...........................................................
elif [ "$req" = "MOVE_TBS" ];then

  [[ -z "$ftbs" ]] && echo "I need a tablespace name to move to a new tablespace" && exit
  [[ -z "$fowner" ]] && echo "I need at least schema name or a table name or maybe even both" && exit

  if [ -n "$fowner" ];then
      AND_OWNER="  and at.owner = '$fowner' "
      AND_IOWNER="  and ai.owner = '$fowner' "
      AND_PART_OWNER="  and atp.table_owner = '$fowner' "
  fi
  if [ -n "$ftable" ];then
      AND_TABLE=" and at.table_name='$ftable' "
      AND_ITABLE=" and ai.table_name='$ftable' "
  fi
echo
if [[ "$MV_ITBS" = "TRUE" ]];then
    mv_idx=1
    [[ -z "$fitbs" ]] && fitbs=$ftbs
else
    mv_idx=0
fi
# ... I am not in mood to be clear, so ....
[[  -z "$EXECUTE" ]]
doit=$?
sqlplus -s "$CONNECT_STRING" <<EOF
set pages 66 lines 190 serveroutput on
declare
  P_TBS          varchar2(30) :=upper('$ftbs') ;
  P_ITBS         varchar2(30) :=upper('$fitbs') ;
  P_TABLE        varchar2(30) :=upper('$ftable') ;
  P_OWNER        varchar2(30) :=upper('$fowner') ;
  v_sql          varchar2(512) ;
  mv_idx         number :=$mv_idx;
  tbs_exists     varchar2(5) ;
  itbs_exists    varchar2(5) ;
  v_run_now      number :=$doit ;

 -- tbl_or_idx  : 1=table/IOT    2=index
 procedure doit ( action in number , sqlcmd in varchar2, f_tbs number ) is
    istbs number:=0 ;
    begin
        -- dbms_output.put_line('f_tbs=' || to_Char(f_tbs) || ' tbs_exists=' || tbs_exists || ' itbs_exists=' || itbs_exists );
        if f_tbs=1 and tbs_exists = 'TRUE' then
           istbs:=1 ;
        elsif f_tbs=2 and itbs_exists = 'TRUE' then
           istbs:=1 ;
        end if ;
        if action = 1 and istbs = 1 then
           dbms_output.put_line('Doing : '|| sqlcmd || ';') ;
           execute immediate sqlcmd ;
       else
           dbms_output.put_line(sqlcmd || ';') ;
       end if;
   end;

begin
   if v_run_now = 0 then
      dbms_output.put_line('Rem No execution requested');
   else
      dbms_output.put_line('Rem Execution of command requested');
   end if;
   -- check if ftbs exists
   select decode(count(*),0,'FALSE','TRUE') into tbs_exists from dba_tablespaces where tablespace_name = P_TBS  ;
   dbms_output.put_line('Rem Tablespace for table ' || P_TBS || ' exists : ' ||tbs_exists );
   dbms_output.put_line('Rem');


   -- check if fitbs exists
   if P_ITBS is not null then
      select decode(count(*),0,'FALSE','TRUE') into itbs_exists from dba_tablespaces where tablespace_name = P_ITBS  ;
      dbms_output.put_line('Rem Tablespace for index ' || P_ITBS || ' exists : ' ||itbs_exists );
      dbms_output.put_line('Rem');
   end if;

   -- possible values for iot_type are null, IOT, IOT_OVERFLOW
   for t in (select /* regular table */ decode (at.iot_type, null,'REGULAR', 'IOT' ) as type,
                 at.table_name, at.owner as owner,  '-' as partition, '-' as subpartition
                 from all_tables at where at.partitioned='NO'  $AND_OWNER $AND_TABLE
            union  all
             select /* partitioned */ 'PARTITIONED' as type, atp.table_name,
                    atp.table_owner as owner , atp.partition_name as partition,  '-' as subpartition
                    from all_tab_partitions atp,  all_tables at
                    where atp.table_name = at.table_name
                       and atp.table_owner = at.owner
                          and at.iot_type is null
                          and atp.SUBPARTITION_COUNT = 0 $AND_PART_OWNER $AND_TABLE
             union all
             select /* SUB PART */ 'SUB PART' as type, atp.table_name,
                    atp.table_owner as owner , '-' as partition,  atp.subpartition_name as subpartition
                    from all_tab_subpartitions atp,  all_tables at
                    where atp.table_name = at.table_name
                      and atp.table_owner = at.owner
                      and at.iot_type is null  $AND_PART_OWNER $AND_TABLE
             union all
             select /*IOT PART */ 'IOT PART' as type, table_name,
                    index_owner as owner, aip.partition_name as partition,  ai.index_name as subpartition
                    -- partition_name as partition,  '-' as subpartition
                   from all_indexes ai, all_ind_partitions aip
                   where 1=1 $AND_ITABLE $AND_IOWNER
                     and ai.index_type = 'IOT - TOP'
                     and aip.index_name = ai.index_name
                     and aip.index_owner = ai.owner
                order by table_name, partition
            )
   loop
       -- dbms_output.put_line('table: '|| t.table_name || ' type=' || t.type || ' part=' || t.partition || ' sub=' ||t.subpartition );
       if t.type = 'REGULAR' then
          v_sql:='alter table ' || t.owner||'.'|| t.table_name || ' move tablespace '|| P_TBS ;
       elsif t.type = 'IOT' then
          v_sql:='alter table ' || t.owner||'.'|| t.table_name || ' move tablespace '|| P_TBS || ' overflow tablespace ' || P_TBS;
       elsif t.type = 'PARTITIONED' then
          v_sql:='alter table ' || t.owner||'.'|| t.table_name || ' move partition ' ||t.partition || '  tablespace '|| P_TBS ;
       elsif t.type = 'SUB PART' then
          v_sql:='alter table ' || t.owner||'.'|| t.table_name || ' move subpartition ' ||t.subpartition || '  tablespace '|| P_TBS ;
       elsif t.type ='IOT PART' then
          v_sql:='alter table ' || t.owner||'.'|| t.table_name ||  ' move partition ' ||t.partition || '  tablespace '|| P_TBS ||
                              ' overflow tablespace ' || P_TBS ;
       end if;

       doit(v_run_now, v_sql, 1) ;

       -- Move  LOB for this table
       if t.type = 'PARTITIONED' then
          FOR lob IN (  SELECT alp.column_name
                             FROM all_lob_partitions alp
                        WHERE
                              alp.table_name  = t.table_name
                          and alp.table_owner = t.owner
                          and alp.partition_name = t.partition
                              ORDER BY 1)
          LOOP
            v_sql:= 'ALTER TABLE '|| t.owner||'.'|| t.table_name || ' MOVE PARTITION '|| t.partition ||
                     ' LOB ('||lob.column_name||') STORE AS ( TABLESPACE ' || P_TBS ||')';
               doit(v_run_now,v_sql, 1) ;
          END LOOP;

       elsif t.type = 'SUB PART' then
          FOR lob IN (  SELECT alp.column_name
                             FROM all_lob_subpartitions alp
                        WHERE
                              alp.table_name  = t.table_name
                          and alp.table_owner = t.owner
                          and alp.subpartition_name = t.subpartition
                              ORDER BY 1)
           LOOP
               v_sql:= 'ALTER TABLE '|| t.owner||'.'|| t.table_name || ' MOVE SUBPARTITION '|| t.subpartition ||
                     ' LOB ('||lob.column_name||') STORE AS ( TABLESPACE ' || P_TBS ||')';
               doit(v_run_now,v_sql,1) ;
           END LOOP;
       end if ;

   end loop ;

   -- we move the index now
   if mv_idx=1 then

      dbms_output.put_line('Rem');
      dbms_output.put_line('Rem Index processing requested');
      dbms_output.put_line('Rem');
      for idx in (select index_name, ai.owner,  ai.partitioned from all_indexes ai, all_tables at
                         where
                               at.iot_type is null
                           and ai.table_name = at.table_name
                           and ai.owner = at.owner $AND_OWNER $AND_TABLE )
      loop
         dbms_output.put_line('Rem');
         dbms_output.put_line('Rem Index name : ' ||idx.index_name );
         dbms_output.put_line('Rem');
         if  idx.partitioned = 'NO' then
             v_sql := 'ALTER INDEX '||idx.owner||'.'||idx.index_name||' REBUILD TABLESPACE ' || P_ITBS ;
              doit(v_run_now,v_sql,2);
         else
             for fpart in (select partition_name from all_ind_partitions where index_owner = idx.owner and index_name = idx.index_name)
             loop
                 v_sql:='ALTER INDEX ' || idx.owner|| '.'|| idx.index_name || ' REBUILD PARTITION ' || fpart.partition_name
                         ||' TABLESPACE ' || P_ITBS ;
                 doit(v_run_now,v_sql,2) ;
             end loop ;

             for fpart in (select subpartition_name from all_ind_subpartitions where index_owner = idx.owner and index_name = idx.index_name)
             loop
                 v_sql:='ALTER INDEX '||idx.owner||'.'||idx.index_name||' REBUILD SUBPARTITION ' ||fpart.subpartition_name ||
                       ' TABLESPACE ' || P_ITBS ;
                 doit(v_run_now,v_sql,2);
             end loop ;
         end if;
      end loop;
   end if;
end;
/
EOF
# ...........................................................
# List transactions in flashback
# ...........................................................

elif [ "$req" = "TXN" ];then
sqlplus -s "$CONNECT_STRING" <<EOF
set pages 66 lines 190
col VERSIONS_OPERATION for a20 head 'Operation'
col VERSIONS_STARTSCN for 999999999999 head 'Start Scn'
col VERSIONS_ENDSCN for 999999999999 head 'End Scn'
col VERSIONS_STARTTIME for a21 head 'Start Time'
col VERSIONS_ENDTIME for a21 head 'End Time'
select * from (
  SELECT     VERSIONS_XID,  VERSIONS_STARTTIME, VERSIONS_ENDTIME, VERSIONS_STARTSCN,VERSIONS_ENDSCN ,VERSIONS_OPERATION
  FROM   $fowner.$ftable  versions BETWEEN TIMESTAMP MINVALUE AND MAXVALUE
where VERSIONS_XID is not null
    ORDER  BY VERSIONS_STARTTIME desc
) where  rownum < $NUM_ROWS
/
EOF
# ...........................................................
# List dependent segements
# ...........................................................
elif [ "$req" = "DEP" ];then
fpart=${fpar:-NULL}
sqlplus -s "$CONNECT_STRING" <<EOF
set linesize 190 pagesize 140
break on segment_owner on segment_name on segment_type on tablespace_name
col segment_owner format a22
col segment_name format a30
col segment_type format a18
col tablespace_name format a20
col partition_name format a23
col lob_column_name format a17

set serveroutput on

SELECT * FROM (TABLE(dbms_space.object_dependent_segments('$fowner', '$ftable', $fpart, 1)));
EOF
# ...........................................................
# show dbms_space.space_usage facts
# ...........................................................
elif [ "$req" = "UNUSED_SPACE" ];then
   ftype=`get_ftype`
   ftype=${ftype:-TABLE}
   if [ -z "${ftype%%*SUB*}"  ];then
       SUB=SUB
   else
      unset SUB
   fi
echo
echo "owner=$fowner Table=$ftable  Partition=$fpart type=$ftype"
echo
sqlplus -s "$CONNECT_STRING" <<EOF
set serveroutput on
set lines 190

DECLARE
 segown   VARCHAR2(30) := '$fowner';
 segname  VARCHAR2(30) := '$ftable';
 segtype  VARCHAR2(30) := '$ftype';
 partname VARCHAR2(30) := '$fpart';

 totblock NUMBER:=0;
 totbytes NUMBER:=0;
 unusedbl NUMBER:=0;
 unusedby NUMBER:=0;
 lu_ef_id NUMBER:=0;
 lu_eb_id NUMBER:=0;
 lu_block NUMBER:=0;
 v_totbk  NUMBER:=0;
 v_totby  NUMBER:=0;
 v_unby   NUMBER:=0;
 v_unbk   NUMBER:=0;
BEGIN
  if ( segtype like 'LOB%' ) then
      select lob_name into segname from (
      select lob_name from dba_lob_subpartitions
              where table_name = upper('$ftable') and table_owner=upper('$fowner') and LOB_SUBPARTITION_NAME=upper('$fpart')
      union
      select lob_name from dba_lob_partitions
         where table_name = upper('$ftable') and table_owner=upper('$fowner') and LOB_PARTITION_NAME=upper('$fpart'));
  end if;

  dbms_output.put_line('segtype=' || segtype );
  if segtype = 'TABLE ${SUB}PARTITION' then
      for c in (select ${SUB}partition_name part from dba_tab_${SUB}partitions where table_owner = segown and TABLE_NAME = segname )
      loop
          dbms_space.unused_space(segown, segname, segtype, v_totbk, v_totby, v_unbk, v_unby, lu_ef_id, lu_eb_id, lu_block, c.part);

         dbms_output.put_line('partition ' || c.part || ' Total Blocks: ' || TO_CHAR(v_totbk) || ' Total Bytes: ' || TO_CHAR(v_totby)||
                               '  Unused Blocks: ' || TO_CHAR(v_unbk)|| ' Unused Bytess: ' || TO_CHAR(v_unby));


          totblock:=totblock+v_totbk;
          totbytes:=totbytes+v_totby;
          unusedbl:=unusedbl+v_unbk;
          unusedby:=unusedby+v_unby;
      end loop ;
  else
      dbms_space.unused_space(segown, segname, segtype, totblock, totbytes, unusedbl, unusedby, lu_ef_id, lu_eb_id, lu_block, partname);
  end if ;

  dbms_output.put_line('Total Blocks: ' || TO_CHAR(totblock));
  dbms_output.put_line('Total Bytes: ' || TO_CHAR(totbytes));
  dbms_output.put_line('Unused Blocks: ' || TO_CHAR(unusedbl));
  dbms_output.put_line('Unused Bytess: ' || TO_CHAR(unusedby));
  dbms_output.put_line('Last Used Extent File ID: ' || TO_CHAR(lu_ef_id));
  dbms_output.put_line('Last Used Extent Block ID: ' || TO_CHAR(lu_eb_id));
  dbms_output.put_line('Last Used Block: ' || TO_CHAR(lu_block));
END;
/
EOF
# ...........................................................
# show dbms_space.space_usage facts
# ...........................................................
elif [ "$req" = "SPACE_USAGE" ];then

ftype=`get_ftype`
ftype=${ftype:-TABLE}

if [ -z "${ftype%%*SUB*}"  ];then
    SUB=SUB
else
    unset SUB
fi
if [ -z "${ftype%%*LOB*}"  ];then
   TAB=lob
   FTABLE=LOB
   LOB=LOB_
else
   TAB=tab
   FTABLE=TABLE
   unset LOB
fi
echo
echo "owner=$fowner Table=$ftable  Partition=$fpart type=$ftype"
echo
sqlplus -s "$CONNECT_STRING" <<EOF
set serveroutput on
set lines 190

DECLARE

 segown   VARCHAR2(30) := '$fowner';
 segname  VARCHAR2(30) := '$ftable';
 segtype  VARCHAR2(30) := '$ftype';
 partname VARCHAR2(30) := '$fpart';

v_unformatted_blocks number:=0;
vt_unformatted_blocks number:=0;
v_unformatted_bytes number;
v_fs1_blocks number:=0;
vt_fs1_blocks number:=0;
v_fs1_bytes number;
v_fs2_blocks number:=0;
vt_fs2_blocks number:=0;
v_fs2_bytes number;
v_fs3_blocks number:=0;
vt_fs3_blocks number:=0;
v_fs3_bytes number;
v_fs4_blocks number:=0;
vt_fs4_blocks number:=0;
v_fs4_bytes number:=0;
v_full_blocks number:=0;
vt_full_blocks number:=0;
v_full_bytes number;
BEGIN
/* if ( segtype like 'LOB%' ) then
      select lob_name into segname from (
      select lob_name from dba_lob_subpartitions
              where table_name = upper('$ftable') and table_owner=upper('$fowner') and LOB_SUBPARTITION_NAME=upper('$fpart')
      union
      select lob_name from dba_lob_partitions
         where table_name = upper('$ftable') and table_owner=upper('$fowner') and LOB_PARTITION_NAME=upper('$fpart'));
  end if;
*/
  dbms_output.put_line('segtype=' || segtype );
  if segtype = '${FTABLE} ${SUB}PARTITION' then
      for c in (select ${LOB}${SUB}partition_name part from dba_${TAB}_${SUB}partitions where table_owner = segown and ${FTABLE}_NAME = segname )
      loop
          dbms_space.space_usage (segown, segname, segtype, vt_unformatted_blocks, v_unformatted_bytes, vt_fs1_blocks, v_fs1_bytes, vt_fs2_blocks, v_fs2_bytes, vt_fs3_blocks, v_fs3_bytes, vt_fs4_blocks, v_fs4_bytes, vt_full_blocks, v_full_bytes,c.part);

           dbms_output.put_line('partition ' || c.part || ' Unformatted Blocks = '||vt_unformatted_blocks|| '   fs1=' || to_char(vt_fs1_blocks)
                                             || '   fs2=' || to_char(vt_fs2_blocks) || '   fs3=' || to_char(vt_fs3_blocks)
                                             || '   fs4=' || to_char(vt_fs4_blocks) || ' Full Blocks = '||vt_full_blocks);
          v_fs1_blocks :=v_fs1_blocks + vt_fs1_blocks;
          v_fs2_blocks :=v_fs2_blocks + vt_fs2_blocks;
          v_fs3_blocks :=v_fs3_blocks + vt_fs3_blocks;
          v_fs4_blocks :=v_fs4_blocks + vt_fs4_blocks;
          v_unformatted_blocks:=v_unformatted_blocks+vt_unformatted_blocks;
          v_full_blocks:=v_full_blocks+vt_full_blocks;
      end loop ;
  else
  dbms_space.space_usage (segown, segname, segtype, v_unformatted_blocks, v_unformatted_bytes, v_fs1_blocks, v_fs1_bytes, v_fs2_blocks, v_fs2_bytes, v_fs3_blocks, v_fs3_bytes, v_fs4_blocks, v_fs4_bytes, v_full_blocks, v_full_bytes,partname);
  end if ;
dbms_output.put_line('Unformatted Blocks          = '||v_unformatted_blocks);
dbms_output.put_line('0-25%   free space  Blocks# = '||v_fs1_blocks);
dbms_output.put_line('25-50%  free space  Blocks# = '||v_fs2_blocks);
dbms_output.put_line('50-75%  free space  Blocks# = '||v_fs3_blocks);
dbms_output.put_line('75-100% free space  Blocks# = '||v_fs4_blocks);
dbms_output.put_line('Full Blocks                 = '||v_full_blocks);
dbms_output.put_line('Total blocks                = '||to_char(v_full_blocks+v_fs4_blocks+v_fs3_blocks+v_fs2_blocks+v_fs1_blocks+v_unformatted_blocks));
end;
/
EOF

# ...........................................................
# show lob size distribution size
# ...........................................................
elif [ "$req" = "dis" ];then
    if [  -z "$ftable" ];then
        echo "I need a table name"
        exit
    fi
sqlplus -s "$CONNECT_STRING" <<EOF
col fsizz head 'Size(k)'
select
  case
   when fsiz = -1 then '-'
   when fsiz = 0 then ' 0 - 1k'
   when fsiz = 1 then ' 1 - 2k'
   when fsiz = 2 then ' 2 - 3k'
   when fsiz = 3 then ' 3 - 4k'
   when fsiz = 4 then ' 4 - 5k'
   when fsiz = 5 then ' 5 - 6k'
   when fsiz = 6 then ' 6 - 7k'
   when fsiz = 7 then ' 7 - 8k'
   when fsiz = 8 then ' 8 - 9k'
   when fsiz = 9 then ' 9 - 10k'
   when fsiz = 10 then '10- 20k'
   when fsiz = 20 then '20 - 30k'
   when fsiz = 30 then '30 - 50k'
   when fsiz = 50 then '50 - 100K'
   when fsiz = 100 then '100 - 1000K'
   when fsiz = 1000 then '1 - 10m'
   when fsiz = 10000 then '10m+'
  end fsizz,
  cpt from (
select count(*) cpt, fsiz from
(
select
  case
     when  fsize  > 9999999 then 10000
     when  fsize  between 1000000 and 9999999 then 1000
     when  fsize  between 100000 and 999999 then 100
     when  fsize  between 50000 and 99999 then 50
     when  fsize  between 30000 and 49999 then 30
     when  fsize  between 20000 and 29999 then  20
     when  fsize  between 10000 and  19999 then  10
     when  fsize  between 9000 and 9999 then 9
     when  fsize  between 8000 and 8999 then 8
     when  fsize  between 7000 and 7999 then 7
     when  fsize  between 6000 and 6999 then 6
     when  fsize  between 5000 and 5999 then 5
     when  fsize  between 4000 and 4999 then 4
     when  fsize  between 3000 and 3999 then 3
     when  fsize  between 2000 and 2999 then 2
     when  fsize  between 1000 and 1999 then 1
     when  fsize  between 1 and 999 then 0
     when fsize  = 0 then -1
  else fsize
  end  fsiz
from (
select ceil(dbms_lob.getlength($COL))fsize from $fowner.$ftable)
) group by fsiz) order by 1 ;
EOF
# ...........................................................
# histogram : show columns historgrams
# ...........................................................
elif [ "$req" = "histogram" ];then
   if [ -n "$FOWNER" ];then
      AND=" and"
   else
      unset AND
   fi
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
spool $FOUT
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline, 'Show table histogram for $ftable columns $COL_NAME ' nline from sys.dual
/
set linesize 150 head on pagesize 66
col column_name format a25
col ENDPOINT_NUMBER format 99999999999999999 head 'End Point Number'
col ENDPOINT_VALUE head 'End Point Value' format 99999999999999999
col frequency head 'Frequency'
break on COLUMN_NAME on report
Prompt # .................................................

prompt # This query is only valid if there are no nulls

Prompt # .................................................
prompt

-- select table_name, COLUMN_NAME  , ENDPOINT_NUMBER , ENDPOINT_VALUE , ENDPOINT_ACTUAL_VALUE
-- from DBA_TAB_HISTOGRAMS

select  COLUMN_NAME,
    endpoint_value,
    endpoint_number,
    endpoint_number - nvl(prev_number,0) frequency,
    endpoint_actual_value
from    (
    select COLUMN_NAME,
        endpoint_value,
        endpoint_number,
        lag(endpoint_number,1) over(
            order by endpoint_number
        ) prev_number,
        endpoint_Actual_value
    from
        dba_tab_histograms
where
    table_name = '$ftable' $AND $FOWNER  and COLUMN_NAME = '$COL_NAME'
)
order by ENDPOINT_NUMBER
/
EOF

# ...........................................................
# noidxfk : no index on foreign key
# ...........................................................
elif [ "$req" = "noidxfk" ];then
 unset AND_OWNER
 unset AND_TABLE
 if [ -n "$ftable" ];then
    AND_TABLE=" and acc.table_name = '$ftable' "
 fi
 if [ -n "$fowner" ];then
    AND_OWNER="  and acc.owner = '$fowner' "
 fi

#cat <<EOF
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
spool $FOUT
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline, 'Show foreign key without index' nline from sys.dual
/
set linesize 155 head on pagesize 66
col tbl0 format a35 head "Child Table"
col tbl1 format a35 head "Parent Table"
col cons0 format a25 head "FK without| index" justify c
col cons1 format a25 head "Parent Table| Cons/index" justify c
col cn format a25 head "FK  Columns"
col position format 99 head "Pos"
break on cons0 on tbl0 on report

select a.constraint_name cons0 ,a.owner||'.'|| a.table_name tbl0, a.column_name cn, a.position, a.r_constraint_name cons1
          , b.owner ||'.' || b.table_name tbl1 from
    (
    SELECT ac.constraint_name,acc.owner, acc.table_name, acc.column_name, acc.position, ac.r_constraint_name
        FROM
           all_cons_columns acc,
           dba_constraints ac
        WHERE ac.constraint_name = acc.constraint_name
        and  ac.owner=acc.owner
       AND ac.constraint_type = 'R' $AND_OWNER $AND_TABLE
   MINUS
   SELECT ' ',table_owner, table_name, column_name, column_position,' '
   FROM all_ind_columns
   ) a
   , dba_constraints b
   where
    b.owner = a.owner
   and b.constraint_name =  a.r_constraint_name
  order by  1,5,4,3
/

EOF
# ...........................................................
elif [ "$req" = "truncate" ];then
   TMP_CONS=$SBIN/tmp/truncate_$fowner_$ORACLE_SID.sql
   sqlplus -s "$CONNECT_STRING" <<EOF
spool $TMP_CONS
set pagesize 0 head off linesize 120 trimspool on feed off
select 'truncate table ${fowner}.'|| table_name || ' reuse storage ;' from dba_tables
         where owner = upper('$fowner') $AND_TABLE  order by table_name
/
EOF

# ...........................................................
# ...........................................................
elif [ "$req" = "LOG_GROUP" ];then
     if [ -n "$fowner" ];then
          WHERE_USER=" where owner = upper('$fowner') "
      elif [ -n "$ftable" ];then
          AND_TABLE=" where table_name = upper('$ftable') "
     fi
    sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
spool $FOUT
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline, 'Show table supplemental log group' nline from sys.dual
/
set head on linesize 132 pagesize 66
break on owner on log_group_name on report
col owner format a20
col LOG_GROUP_NAME format a30
col COLUMN_NAME format a20
select OWNER, LOG_GROUP_NAME, TABLE_NAME, LOG_GROUP_TYPE, ALWAYS, GENERATED from DBA_LOG_GROUPS $WHERE_USER $AND_TABLE
  order by owner,log_group_name,table_name;
EOF

# ...........................................................
# ...........................................................
elif [ "$req" = "LOG_NO_KEY" ];then
     if [ -n "$fowner" ];then
          AND_USER=" and owner = upper('$fowner') "
     elif [ -n "$ftable" ];then
          AND_TABLE=" AND table_name = upper('$ftable') "
     fi

    sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
spool $FOUT
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline, 'Show table column in supplemental log group not derived from PK, FK, BITMAP' nline from sys.dual
/
set head on linesize 132 pagesize 66
break on table_name on report
col COLUMN_NAME format a30
SELECT distinct table_name, log_group_name , column_name FROM all_log_group_columns
   where (table_name, column_name) IN
       (SELECT table_name, column_name
          FROM all_log_group_columns
           where logging_property = 'LOG'
        MINUS
        SELECT acc.table_name, acc.column_name
          FROM dba_constraints t, all_cons_columns acc
           where acc.owner = t.owner
           AND acc.constraint_name = t.constraint_name
           AND t.constraint_type IN ('P','R')
        MINUS
        SELECT aic.table_name, aic.column_name
          FROM all_indexes t, all_ind_columns aic
           where aic.index_owner = t.owner
           AND aic.index_name = t.index_name
           AND (t.index_type like '%BITMAP' OR t.uniqueness = 'UNIQUE'))  $AND_USER $AND_TABLE
order by table_name ;
EOF
# ...........................................................
elif [ "$req" = "LOG_COL" ];then
     if [ -n "$fowner" ];then
          WHERE_USER=" where owner = upper('$fowner') "
     elif [ -n "$ftable" ];then
          AND_TABLE=" where table_name = upper('$ftable') "
     fi
    sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
spool $FOUT
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline, 'Show table column in supplemental log group' nline from sys.dual
/
set head on linesize 132 pagesize 66
break on owner on log_group_name on report
col owner format a20
col LOG_GROUP_NAME format a30
col COLUMN_NAME format a20
select  OWNER, LOG_GROUP_NAME, TABLE_NAME, COLUMN_NAME, POSITION,LOGGING_PROPERTY from DBA_LOG_GROUP_COLUMNS $WHERE_USER $AND_TABLE;

EOF
# ...........................................................
# ...........................................................
elif [ "$req" = "enable_constraints" ];then
   if [ -z "$fowner" ];then
     echo "I need a constraints owner"
     exit 0
   fi

   if [ "$CONS_TYPE" = "ALL" ];then
      unset AND_TYPE
   else
      AND_TYPE=" and constraint_type = '$CONS_TYPE' "
   fi

   if [ -n "$ftable" ];then
      AND_TABLE=" and table_name = upper('$ftable') "
   else
      unset AND_TABLE
   fi

   TMP_CONS=$SBIN/tmp/ena_const_$fowner_$ORACLE_SID.sql

   sqlplus -s "$CONNECT_STRING" <<EOF
spool $TMP_CONS
set pagesize 0 head off linesize 120 trimspool on feed off
select 'alter table ${fowner}.'|| table_name || ' enable constraint '||constraint_name||';'
from dba_constraints where owner = upper('$fowner') $AND_TABLE $AND_TYPE order by table_name
/
spool off
EOF

   if [ "$EXECUTE" = "YES" ];then
   sqlplus -s "$CONNECT_STRING" <<EOF
@$TMP_CONS
EOF
   fi
# ...........................................................
# ...........................................................
elif [ "$req" = "disable_constraints" ];then
   if [ -z "$fowner" ];then
     echo "I need a constraints owner"
     exit 0
   fi
   if [ "$CONS_TYPE" = "ALL" ];then
      unset AND_TYPE
   else
      AND_TYPE=" and constraint_type = '$CONS_TYPE' "
   fi
   if [ -n "$ftable" ];then
      AND_TABLE=" and table_name = upper('$ftable') "
   else
      unset AND_TABLE
   fi
   TMP_CONS=$SBIN/tmp/dis_const_$fowner_$ORACLE_SID.sql
   sqlplus -s "$CONNECT_STRING" <<EOF
spool $TMP_CONS
set pagesize 0 head off linesize 120 trimspool on feed off
select 'alter table ${fowner}.'|| table_name || ' disable constraint '||constraint_name||' cascade;'
from dba_constraints where owner = upper('$fowner') $AND_TABLE $AND_TYPE order by table_name
/
spool off
EOF
   if [ "$EXECUTE" = "YES" ];then
   sqlplus -s "$CONNECT_STRING" <<EOF
@TMP_CONS
EOF
   fi
# ...........................................................
# ...........................................................
elif [ "$req" = "list_constraints" ];then
   if [ -z "$fowner" ];then
     echo "I need a constraints owner"
     exit 0
   fi
   if [ "$CONS_TYPE" = "ALL" ];then
      unset AND_TYPE
   else
      AND_TYPE=" and constraint_type = '$CONS_TYPE' "
      AND_TYPE_A=" and a.constraint_type = '$CONS_TYPE' "
   fi
   if [ -n "$ftable" ];then
      AND_TABLE=" and table_name = upper('$ftable') "
      AND_TABLE_A=" and a.table_name = upper('$ftable') "
   else
      unset AND_TABLE
   fi
   sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
spool $FOUT
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER,15)  || 'List table $ftable constraints' nline from sys.dual
/
set linesize 150 head on
col r_owner format a18 head "Remote owner"
col R_CONSTRAINT_NAME format a22  head "Remote constraint|Name" justify l
col CONSTRAINT_NAME for a22 head 'Constraint name'
col CONSTRAINT_TYPE head 'Type' for a4
col table_name for a44
select owner||'.'||TABLE_NAME table_name, CONSTRAINT_NAME, CONSTRAINT_TYPE,
       STATUS,to_char(LAST_CHANGE,'YYYY-MM-DD HH24:MI') last_change,
       r_owner , R_CONSTRAINT_NAME
from  dba_constraints where OWNER = '$fowner' $AND_TABLE $AND_TYPE
union
select b.owner||'.'||b.table_name table_name,b.constraint_name,b.constraint_type
       STATUS,b.status,to_char(b.LAST_CHANGE,'YYYY-MM-DD HH24:MI') last_change,
       b.r_owner, b.R_CONSTRAINT_NAME
     from
          dba_constraints a,
          dba_constraints b
     where
            a.OWNER = '$fowner' $AND_TABLE_A $AND_TYPE_A
        and b.r_constraint_name = a.constraint_name
  and b.r_owner = a.owner
 order by table_name;
EOF
# ...........................................................
# "predicate_usage"
# ...........................................................
elif [ "$req" = "predicate_usage" ];then
 unset AND_OWNER
 unset AND_TABLE
 if [ -n "$ftable" ];then
    AND_TABLE=" o.name = '$ftable' and"
 fi
 if [ -n "$fowner" ];then
    AND_OWNER=" r.name = '$fowner' and"
    AND_A_OWNER=" and  a.object_owner = '$fowner' "
 fi
 ORD_PRED=${ORD_PRED:-4}
 if [ -n "$COL_NAME" ];then
    AND_COL=" c.name = '$COL_NAME' and"
    SQL1=" col PLAN_HASH_VALUE for 999999999999 head 'Plan hash |value' justify c
     col id for 999 head 'Id'
     col child for 99 head 'Ch|ld'
     col cost for 999999 head 'Oper|Cost'
     col tot_cost for 999999 head 'Plan|cost' justify c
     col est_car for 999999999 head 'Estimed| card' justify c
     col cur_car for 999999999 head 'Avg seen| card' justify c
     col ACC for A3 head 'Acc|ess'
     col FIL for A3 head 'Fil|ter'
     col OTHER for A3 head 'Oth|er'
     col ope for a30 head 'Operation'
     col exec for 999999 head 'Execution'
     break on PLAN_HASH_VALUE on sql_id on child
     select distinct
       a.PLAN_HASH_VALUE, a.id , a.sql_id, a.CHILD_NUMBER child , a.cost, c.cost tot_cost,
       a.cardinality est_car,  b.output_rows/decode(b.EXECUTIONS,0,1,b.EXECUTIONS) cur_car,
       b.EXECUTIONS exec,
       case when length(a.ACCESS_PREDICATES) > 0 then ' Y' else ' N' end ACC,
       case when length(a.FILTER_PREDICATES) > 0 then ' Y' else ' N' end FIL,
       case when length(a.projection) > 0 then ' Y' else ' N' end OTHER,
        a.operation||' '|| a.options ope
 from
    v\$sql_plan  a,
    v\$sql_plan_statistics_all b ,
    v\$sql_plan_statistics_all c
 where
        a.PLAN_HASH_VALUE =  b.PLAN_HASH_VALUE
    and a.sql_id = b.sql_id
    and a.child_number = b.child_number
    and a.id = b.id
    and a.PLAN_HASH_VALUE=  c.PLAN_HASH_VALUE (+) and a.sql_id = c.sql_id and a.child_number = c.child_number and c.id=0
    and  a.OBJECT_NAME = '$ftable'  $AND_A_OWNER
    and   (instr(a.FILTER_PREDICATES,'$COL_NAME') > 0
        or instr(a.ACCESS_PREDICATES,'$COL_NAME') > 0
        or instr(a.PROJECTION, '$COL_NAME') > 0
        )
order by sql_id, PLAN_HASH_VALUE, id
/
"
 fi
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
spool $FOUT
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline, 'Show table/col predicate usage' nline from sys.dual
/
set linesize 132 head on pagesize 90
col obj format a35 head "Table name"
col col1 format a26 head "Column"
col equijoin_preds format 9999999 head "equijoin|Preds" justify c
col nonequijoin_preds format 9999999 head "non|equijoin|Preds" justify c
col range_preds format 999999 head "Range|Pred" justify c
col equality_preds format 9999999 head "Equality|Preds" justify c
col like_preds format 999999 head "Like|Preds" justify c
col null_preds format 999999 head "Null|Preds" justify c
prompt
prompt Order by (-ord <n>) : 3=equality_preds 4=equijoin_preds 5=nonequijoin_preds
prompt .                   : 5=range_preds    6=like_preds     7=null_preds
prompt
prompt Use  tbl -t <table_name> -col <col_name> -pred to view SQL that uses this column as predicate
select r.name ||'.'|| o.name "obj" , c.name "col1",
      equality_preds, equijoin_preds, nonequijoin_preds, range_preds,
      like_preds, null_preds, to_char(timestamp,'DD-MM-YY HH24:MI:SS') "Date"
 from sys.col_usage$ u, sys.obj$ o, sys.col$ c, sys.user$ r
  where o.obj# = u.obj#    and $AND_TABLE $AND_OWNER $AND_COL
        c.obj# = u.obj#    and
        c.col# = u.intcol# and
        o.owner# = r.user# and
       (u.equijoin_preds > 0 or u.nonequijoin_preds > 0)
   order by $ORD_PRED desc 
/
$SQL1
EOF
# ...........................................................
# Columns histograms
# ...........................................................
elif [ "$req" = "list_hist_col" ];then
   if [ -n "$ftable" ] ;then
      AND_TABLE=" and a.table_name= '$ftable'"
   fi
   if [ -n "$fowner" ] ;then
      AND_FOWNER=" and a.owner= '$fowner'"
   fi

   if [ -n "$COL_NAME" ] ;then
      AND_COL=" and a.COLUMN_NAME = '$COL_NAME' "
   fi

sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
spool $FOUT
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline, 'Show table/col stats' nline from sys.dual
/
set head ON PAGESIZE 55 linesize 190
col selectivity format 9999999999.9 head "Rows per key|(Selectivity)"
col num_buckets format 999999 head " Num  |Bucket"
col dtyp format A16 head "Data Type"
col num_distinct for 9999999999 head 'Num|distinct' justify c
col num_nulls head 'Num|Nulls' justify c
col Density head 'Density:|eqjoin ret|% of rows'
col Histogram head 'Histogram' for a15
col column_name for a22
col column_id for 999 head 'Col|id'
col partitions head 'Partitions' for a22
col ENDPOINT_ACTUAL_VALUE head 'actual value' format a50
col nullable for a4 head 'Null|able'
col partition_position noprint
$PROMPT
prompt
rem set termout off
col ENDPOINT_ACTUAL_VALUE for a40
col density for 990.999999 head 'Density:|eqjoin ret|% of rows'
select partition, COLUMN_NAME, bucket_number, ENDPOINT_VALUE, bucket_number-nvl(lag,0) nbr , ENDPOINT_ACTUAL_VALUE
 from (
select  '-ALL TABLE-' partition, a.COLUMN_NAME,
        ENDPOINT_NUMBER bucket_number ,ENDPOINT_VALUE , lag(ENDPOINT_NUMBER)over(order by ENDPOINT_VALUE) lag, ENDPOINT_ACTUAL_VALUE
        from dba_tab_histograms a,  dba_tables b, dba_tab_columns c
        where  1=1 $AND_TABLE $AND_FOWNER $AND_COL
          and  a.owner = b.owner
          and  a.table_name = b.table_name
          and  a.owner = c.owner (+)
          and  a.table_name = c.table_name
          and  a.column_name = c.column_name
union
select   a.partition_name partition, a.COLUMN_NAME, a.bucket_number, a.ENDPOINT_value, lag(bucket_NUMBER)over(order by ENDPOINT_VALUE) lag, ENDPOINT_ACTUAL_VALUE
         from dba_part_histograms a, dba_tab_partitions b,
              dba_part_col_statistics c
         where 1=1 $AND_TABLE $AND_FOWNER $AND_COL
                   and a.owner = b.table_owner
                   and a.table_name = b.table_name
                   and a.partition_name = b.partition_name
                   and  a.owner = c.owner (+)
                   and  a.table_name = c.table_name
                   and  a.partition_name = c.partition_name
                   and  a.column_name = c.column_name
union
select   a.subpartition_name partition, a.COLUMN_NAME, a.bucket_number, a.ENDPOINT_value, lag(bucket_NUMBER)over(order by ENDPOINT_VALUE) lag, ENDPOINT_ACTUAL_VALUE
         from dba_subpart_histograms a, dba_tab_subpartitions b,
              dba_subpart_col_statistics c
         where 1=1 $AND_TABLE  $AND_FOWNER $AND_COL
                   and  a.owner = b.table_owner
                   and  a.table_name = b.table_name
                   and  a.subpartition_name = b.subpartition_name
                   and  a.owner = c.owner (+)
                   and  a.table_name = c.table_name
                   and  a.subpartition_name = c.subpartition_name
                   and  a.column_name = c.column_name
order by bucket_number
)

/
EOF
# ...........................................................
# Columns stats
# ...........................................................
elif [ "$req" = "stats" ];then
   if [ -n "$FOWNER" ];then
      AND=" and"
   else
      unset AND
   fi
   ftype=`get_ftype`
   if [ -z "$fpart" ];then 
        # no tab part given so we disable partition code
        unset ftype
        AND_1=0
   else
      TITLE_PART=" Partition $fpart"
      AND_1=1
   fi
   ftype=${ftype:-TABLE}
   if [ -z "${ftype%%*SUB*}"  ];then
       SUB=SUB
   else
      unset SUB
   fi
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
spool $FOUT
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline, 'Show table/col stats for $ftable $TITLE_PART' nline from sys.dual
/
set head ON PAGESIZE 55 linesize 190
col selectivity format 9999999999.9 head "Rows per key|(Selectivity)"
col num_buckets format 999999 head " Num  |Bucket"
col avg_col_len format 999 head "Agv|Col|Len"
col la format A18 head "Last Analysed"
col dtyp format A16 head "Data Type"
col num_rows new_value row_num noprint
col num_distinct for 9999999999 head 'Num|distinct' justify c
col global_stats for a4 head 'Glob|Stat'
col num_nulls head 'Num|Nulls' justify c
col Density head 'Density:|eqjoin ret|% of rows' for 990.999999
col Histogram head 'Histogram' for a15
col column_name format a30
$PROMPT
prompt
rem set termout off
select num_rows from dba_tables where $FOWNER  $AND  table_name = '$ftable'
    and '$ftype'= 'TABLE' 
union 
select b.num_rows from dba_tables a,  DBA_TAB_PARTITIONS b
  where '$ftype'= 'TABLE PARTITION' and 
        $A_FOWNER  $AND  a.table_name = '$ftable'
        and b.table_name = a.table_name and b.table_owner=a.owner
        and b.PARTITION_NAME  = upper('$fpart') 
union 
select b.num_rows from dba_tables a,  DBA_TAB_SUBPARTITIONS b
  where '$ftype'= 'TABLE SUBPARTITION' and 
        $A_FOWNER  $AND  a.table_name = '$ftable'
        and b.table_name = a.table_name and b.table_owner=a.owner
        and b.SUBPARTITION_NAME  = upper('$fpart') 
/
rem set termout on
select a.column_name, a.data_type||'('||a.data_length||')' dtyp, a.num_distinct,
           decode(nvl(a.num_distinct,0),0,0,(&row_num-num_nulls)/a.num_distinct) selectivity, density density,
           a.global_stats, a.num_nulls,
           HISTOGRAM,(select count(1) from dba_tab_histograms where
                       $FOWNER $AND table_name = '$ftable' and column_name=a.column_name) num_buckets,
           a.avg_col_len, to_char(a.last_analyzed,'DD-MM-YY HH24:MI:SS') la
    from   dba_tab_columns a
   where  
           '$ftype' = 'TABLE' and  $FOWNER  $AND  table_name = '$ftable' and 0=$AND_1
union
select a.column_name, a.data_type||'('||a.data_length||')' dtyp, b.num_distinct,
           decode(nvl(b.num_distinct,0),0,0,(&row_num-b.num_nulls)/b.num_distinct) selectivity, b.density density,
           b.global_stats, b.num_nulls,
           b.HISTOGRAM,(select count(1) from dba_part_histograms where
                       $FOWNER $AND table_name = '$ftable' and PARTITION_NAME = '$fpart'
                        and column_name=b.column_name) num_buckets,
           b.avg_col_len, to_char(b.last_analyzed,'DD-MM-YY HH24:MI:SS') la
    from   dba_tab_columns a ,
           DBA_PART_COL_STATISTICS b
   where  
           '$ftype' = 'TABLE PARTITION' and  $A_FOWNER  $AND  a.table_name = '$ftable' 
            and b.table_name (+) = a.table_name and b.owner(+) =a.owner
            and b.column_name(+)  = a.column_name
            and b.PARTITION_NAME (+)  = upper('$fpart') and 1=$AND_1
union
select a.column_name, a.data_type||'('||a.data_length||')' dtyp, b.num_distinct,
           decode(nvl(b.num_distinct,0),0,0,(&row_num-b.num_nulls)/b.num_distinct) selectivity, b.density density,
           b.global_stats, b.num_nulls,
           b.HISTOGRAM,(select count(1) from dba_subpart_histograms where
                       $FOWNER $AND table_name = '$ftable' and SUBPARTITION_NAME = '$fpart'
                        and column_name=b.column_name) num_buckets,
           b.avg_col_len, to_char(b.last_analyzed,'DD-MM-YY HH24:MI:SS') la
    from   dba_tab_columns a ,
           DBA_SUBPART_COL_STATISTICS b
   where  
           '$ftype' = 'TABLE SUBPARTITION' and  $A_FOWNER  $AND  a.table_name = '$ftable' 
            and b.table_name = a.table_name and b.owner=a.owner
            and b.column_name = a.column_name
            and b.SUBPARTITION_NAME  = upper('$fpart') and 1=$AND_1
/
EOF

echo '********************************************************************'
echo "log file: $FOUT"
echo '********************************************************************'
echo

# ...........................................................
elif [ "$req" = "part_hv" ];then
 if [ -n "$fowner" ];then
         AND_FOWNER=" and table_owner =  '$fowner' "
 fi
sqlplus -s "$CONNECT_STRING"  <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 190 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline, 'Show partitions high values for table: $ftable' from sys.dual
/
set head off
-- this query produce a concatened, comma separated,  list of column names
select 'Part col -->  ' ||   column_name
      from (
                    select
                         listagg(column_name,',') within group (order by column_name) column_name
                    from
                          SYS.DBA_PART_KEY_COLUMNS
                    where name ='$ftable' and owner = '$fowner'
          ) ;

set serveroutput on
set lines 190 pagesize 66

declare
   tt varchar2(512);
   loc long;
   v_col varchar2(30) ;
   function ff ( ll long) return varchar2 is
    var varchar2(512);
   begin
     select ll into var from dual ;
     return var;
   end ff ;
begin
  dbms_output.put_line(rpad('Partion_name',30,' ')|| 'High_value');
  dbms_output.put_line(rpad('-',29,'-')||' '|| rpad('-',70,'-'));
  for  t in (select partition_name,high_value from dba_tab_partitions where table_name = '$ftable' $AND_FOWNER order by partition_position)
  loop
    tt:= ff(t.high_value) ;
    dbms_output.put_line(rpad(t.partition_name,30,' ') || tt );
  end loop;
end;
/
EOF
# ...........................................................
# Table metadata for tuning
# ...........................................................

elif [ "$req" = "TIS" ];then
# ...........................................................
set -v
sqlplus -s "$CONNECT_STRING"  <<EOF

ttitle skip 1 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 1
set pagesize 0 linesize 132 termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS')||chr(10),
       'Username          -  '||rpad(USER,15)  || 'Show table statistics' nline
from sys.dual
/
col db_block_size new_value fsize noprint
set head off feed off
select value db_block_size from v\$parameter where name = 'db_block_size'
/
set head on
break on partition_position on partition_name on report
COL partition_position       FORMAT  9999 heading 'Part| Pos'
COL fsize                    FORMAT  9999999   heading 'Size (m)'
COL lsize                    FORMAT  9999999   heading 'Alloc |ated(m)' justify c
COL partition_name           FORMAT  A32 head 'Partition name'
COL subpartition_name        FORMAT  A25 head 'System generated|Subpartition name'
COL table_name               FORMAT   A32 head 'Table name'
COL tablespace_name          FORMAT  A24   justify c HEAD 'Tablespace'
COL owner                    FORMAT  A16   justify c HEAD 'Owner'
COL glob                     FORMAT  A4   justify c HEAD 'Glob|stat'
col created                  format  A19  head 'Created'
col last_ddl_time            format  A19  head 'Last ddl'
col temporary                format  A10  head 'Temporary'
col row_movement head "Row|Movment" justify c
col avg_rpb format 9999999 head "Avg Row|Per blk" justify c
col max_rpb format 9999999 head "Max Row|Per blk" justify c
col empt_clocks head "Empty|Blocks"
col CHAIN_CNT head "Chain|Cnt" format 99999
col AVG_ROW_LEN head "Avg row|Len" format 9999999
col AVG_space format 999999 head "Avg|space"
col NUM_FREELIST_BLOCKS format 99999 head "Num|Frlist|block" justify c
col Empty_BLOCKS head "Empty|blocks"
col TEMPORARY head "Temp" format a5
col BUFFER_POOL format a8 head "Buffer|pool"
col GLOBAL_STATS head "Global|stats" format a5
col USER_STATS head "User|stats" format a5
col IOT_TYPE head "Iot" format a5
col SAMPLE_SIZE head "Sample| size" justify c
col degree for a3 head "Deg|ree" justify c
col dens format 990.9999 head 'Density:|eqjoin ret|% of rows'
col ini_trans head "ini|tran" format 999
col max_trans head "max|tran" format 999
col avg_sfp head "Avg space|Free list block"  format 9999 justify c
col FREELISTS head "free|list"  format 999
col FREELIST_GROUPS head "Free list| Group"  format 999
col cache format a5
col compression for a5 head 'Comp|ressed' justify c
col row_movement for a3  head 'Row|Mov'
set lines 190
prompt *********************************
prompt $ftable :
prompt *********************************
 -- heap table

col LAST_ANALYSED format  A19  head 'Last Analyzed'
SELECT table_name, a.owner,trunc(NUM_ROWS)num_rows,  a.blocks, a.BLOCKS * &fsize/1048576 fsize ,
        case nvl(a.tablespace_name,'0')
            when '0' then
                    case nvl(a.partitioned,'0')
                                when '0'  then '-- temporary --'
                                else '-- partitioned -- '
                 end
            else  a.tablespace_name
        end tablespace_name ,
        TO_CHAR(a.LAST_ANALYZED, 'YYYY-MM-DD HH24:MI:SS') LAST_ANALYSED, CHAIN_CNT, AVG_ROW_LEN,
        global_stats glob, substr(row_movement,1,3) row_movement  ,trim(a.degree) degree
     FROM DBA_TABLES a
     WHERE IOT_TYPE is null and a.tablespace_name is not null  and    a.owner = '$fowner'  and TABLE_NAME = upper('$ftable')
union -- table partition
SELECT table_name, a.owner, max(trunc(NUM_ROWS))num_rows,  max(a.blocks), max(a.BLOCKS * &fsize/1048576) fsize ,
       max(case nvl(a.tablespace_name,'0')
            when '0' then
                    case nvl(a.partitioned,'0')
                                when '0'  then '-- temporary --'
                                else '-- partitioned -- '
                 end
            else   a.tablespace_name
        end ) tablespace_name ,
        max(TO_CHAR(a.LAST_ANALYZED, 'YYYY-MM-DD HH24:MI:SS')) last_analysed, max(CHAIN_CNT), max(AVG_ROW_LEN),
        max(global_stats) glob, max(substr(row_movement,1,3)) row_movement  ,trim(a.degree) degree
     FROM DBA_TABLES a
     WHERE  IOT_TYPE is null and a.tablespace_name is null  and    a.owner = '$fowner'  and TABLE_NAME = upper('$ftable')
            group by table_name, a.owner ,trim(a.degree)
union
SELECT b.table_name, b.owner,trunc(b.NUM_ROWS)num_rows, LEAF_BLOCKS LEAF_BLOCKS ,LEAF_BLOCKS * &fsize/1048576 fsize ,
       case nvl(b.tablespace_name,'0')
            when '0' then ' -- partitioned --'
            else  b.tablespace_name
        end tablespace_name ,
       TO_CHAR(b.LAST_ANALYZED, 'YYYY-MM-DD HH24:MI:SS') last_analysed, CHAIN_CNT, AVG_ROW_LEN,
        a.global_stats glob, substr(row_movement,1,3) row_movement  ,trim(a.degree) degree
     FROM DBA_TABLES a,  dba_indexes  b
     WHERE   IOT_TYPE = 'IOT'  and    a.owner = '$fowner'  and b.TABLE_NAME = upper('$ftable')
              and b.owner = a.owner and b.table_name = a.table_name
order by 3 , last_analysed
/
break on f0 on fw skip 1 on f0 on ft on f1 on f2

column dg format A3 heading 'Par'
column f1 format a30 heading 'Index|Name'
column column_name format a22 heading 'Column|Name'
column f0 format a30 new_value the_table heading 'Table|Name'
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
prompt

select  a.index_name f1, substr(uniqueness,1,1)   f2,
       column_name  , clustering_factor cf,
       decode(a.num_rows,0,0,((CLUSTERING_FACTOR/decode(c.blocks,0,1,c.blocks))/(a.NUM_ROWS/decode(c.blocks,0,1,c.blocks)))*100) pct,
       DISTINCT_KEYS dk, a.NUM_ROWS, to_char(a.LAST_ANALYZED,'DD-MM HH24:MI') la,
       substr(a.status,1,3) st, ' '||substr(a.DEGREE,1,2) dg,
       case a.index_type
            when 'FUNCTION-BASED NORMAL' then 'Func based'
            when 'FUNCTION-BASED DOMAIN' then 'Func domain'
          else a.index_type
       end idx_type, c.tablespace_name
from dba_ind_columns b, dba_indexes a, dba_tables c
where a.table_owner     = '$fowner'   and b.table_name ='$ftable'   and
      b.index_name      = a.index_name           and
      b.table_owner (+) = a.table_owner          and
      b.table_name  (+) = a.table_name           and
      c.table_name      = a.table_name           and
      c.owner           = a.table_owner
order
   by a.table_type, a.table_name, a.index_name, column_position
/
col selectivity format 9999999999.9 head "Rows per key|(Selectivity)"
col num_buckets format 999999 head " Num  |Bucket"
col avg_col_len format 999 head "Agv|Col|Len"
col la format A18 head "Last Analysed"
col dtyp format A16 head "Data Type"
col num_rows new_value row_num noprint
col num_distinct for 9999999999 head 'Num|distinct' justify c
col global_stats for a4 head 'Glob|Stat'
col num_nulls head 'Num|Nulls' justify c
col Density head 'Density:|eqjoin ret|% of rows' for 990.999999
col Histogram head 'Histogram' for a15
col column_name format a30

select num_rows from dba_tables where owner = '$fowner'    and  table_name = '$ftable'
/
select a.column_name, a.data_type||'('||a.data_length||')' dtyp, a.num_distinct,
           decode(nvl(a.num_distinct,0),0,0,(&row_num-num_nulls)/a.num_distinct) selectivity, density density,
           a.global_stats, a.num_nulls,
           HISTOGRAM,(select count(1) from dba_tab_histograms where
                       owner = '$fowner'   and table_name = '$ftable' and column_name=a.column_name) num_buckets,
           a.avg_col_len, to_char(a.last_analyzed,'DD-MM-YY HH24:MI:SS') la
    from   dba_tab_columns a
   where
           'TABLE' = 'TABLE' and  owner = '$fowner'    and  table_name = '$ftable'
/

EOF

exit

# ...........................................................
elif [ "$req" = "part" ];then
# -p : list partitions
   if [ -n "$fowner" ];then
         AND_FOWNER=" and a.table_owner =  '$fowner' "
   fi
#cat  <<EOF
sqlplus -s "$CONNECT_STRING"  <<EOF
col db_block_size new_value fsize noprint
set head off feed off
set pagesize 66 linesize 90 termout on pause off embedded on verify off heading off
select value db_block_size from v\$parameter where name = 'db_block_size'
/
select 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID' ||chr(10),
        'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS')||chr(10),
        'Username          -  '||rpad(USER,15)  ||'Show partitions for table: $ftable' from sys.dual
/
set lines 190 pages 90
set head on
break on partition_position on partition_name on pnum on report
COL partition_position       FORMAT  9999 heading 'Part| Pos'
COL fsize                    FORMAT  9999999   heading 'Size (m)'
COL snum                     FORMAT  99999999   heading 'Subpart|Num rows'
COL pnum                     FORMAT  A12   heading 'Partition|Num rows'
COL partition_name           FORMAT  A30 head 'Partition name'
COL subpartition_name        FORMAT  A25 head 'Subpartition name'
COL tablespace_name          FORMAT  A25   justify c HEAD ' Tablespace name'
col last_analyzed            format  A17  head 'Last Analyzed'
col part_lob_size            format  9999999 head 'Partition|lob size(m)'
comp sum of fsize  part_lob_size on report
set head off
-- this query produces a concatened comma separated list of column names
select 'Part col -->  ' ||   column_name || '  ( ''+'' signal aggregate stats - stats derived from others stats)'
      from (
                    select listagg(column_name,',') within group (order by column_name) column_name
                    from
                          SYS.DBA_PART_KEY_COLUMNS
                    where name ='$ftable' and owner = '$fowner'
      ) ;
set head on
prompt
with v as (
   select /*+ no_merge */
      d.owner, d.table_name,
      a.partition_position,
      a.partition_name,
      decode(a.global_stats,'YES',to_char(a.num_rows),
            'NO', '+'||to_char(round(a.num_rows,0)),to_char(round(a.num_rows,0))) pnum
        --  ,b.subpartition_name
        --,to_char(nvl(b.last_analyzed,a.last_analyzed),'DD-MM-YY HH24:MI:SS') last_analyzed,
        ,to_char(a.last_analyzed,'DD-MM-YY HH24:MI:SS') last_analyzed,
        a.avg_row_len, a.avg_space avg_space, 
       (a.blocks*8192)/1024/1024 size_m
    from
       dba_tables d,
       dba_tab_partitions a
       --  , dba_tab_subpartitions b
   where
              d.table_name = '$ftable' $AND_FOWNER
          and d.IOT_TYPE = 'IOT'
          and a.table_name = '$ftable'  and a.table_owner =  d.owner
     --     and a.table_owner = b.table_owner (+)
     --     and a.table_name = b.table_name (+)
     --     and a.partition_name  = b.partition_name (+)
)
, v2 as (
select
        p.table_owner,p.table_name, p.partition_name, 
        trunc(sum(bytes)/1024/1024) part_lob_size
  from dba_segments s, dba_lobs l  , dba_lob_partitions p
where
           l.table_name = '$ftable'   $AND_L_OWNER
      and s.owner = l.owner and s.segment_name=l.segment_name
      and s.owner=p.table_owner  and l.table_name = p.table_name  and s.partition_name=p.lob_partition_name
 group by p.table_owner,p.table_name, p.partition_name
order by 1
)
select
      a.partition_position,
      a.partition_name,
      decode(a.global_stats,'YES',to_char(a.num_rows),
            'NO', '+'||to_char(round(a.num_rows,0)),to_char(round(a.num_rows,0))) pnum,
       --b.subpartition_name,
       --nvl(b.tablespace_name,a.tablespace_name) tablespace_name, $ALTERNATE_FIELD
       a.tablespace_name, --$ALTERNATE_FIELD
       --to_char(nvl(b.last_analyzed,a.last_analyzed),'DD-MM-YY HH24:MI:SS') last_analyzed,
       to_char(a.last_analyzed,'DD-MM-YY HH24:MI:SS') last_analyzed,
       a.avg_row_len, a.avg_space, v2.part_lob_size, round((a.blocks*8192)/1024/1024,1) size_m
   from
       dba_tables d,
       dba_tab_partitions a,
       v2
       --dba_tab_subpartitions b,
   where
          d.IOT_TYPE is null  and
        d.table_name = '$ftable'   and
        a.table_name = '$ftable' 
         -- and a.table_name = b.table_name (+) and
        --a.partition_name=b.partition_name  (+)  and
        -- a.table_owner = b.table_owner (+) 
        and d.owner=a.table_owner $AND_FOWNER
        and a.table_name=v2.table_name (+) and a.table_owner=v2.table_owner (+) and a.partition_name=v2.partition_name (+)
union
select
     v.partition_position,
     v.partition_name,
     pnum,
     --ib.subpartition_name,
     --nvl(ib.tablespace_name,ia.tablespace_name) tablespace_name, $IALTERNATE_FIELD
     ia.tablespace_name, --$IALTERNATE_FIELD
     nvl(to_char(ia.last_analyzed,'DD-MM-YY HH24:MI:SS'),v.last_analyzed)last_analyzed
     ,0 avg_row_len, 0 avg_space ,0 partition_lob, round(v.size_m,1) size_m
from
     v,
     dba_indexes i
     ,dba_ind_partitions ia
     --,dba_ind_subpartitions ib
where
              v.owner=i.owner
          and i.table_name = v.table_name
          and i.index_type = 'IOT - TOP'
          and i.owner =  ia.index_owner
          and i.index_name =  ia.index_name
          and ia.index_owner = v.owner
          and ia.partition_name = v.partition_name
         --and ia.index_name = ib.index_name (+)
         -- and ia.index_owner  = ib.index_owner (+)
         --and ia.partition_name  = ib.partition_name (+)
-- order by partition_position,a.partition_name
/

EOF

# ...........................................................
# constraints
# ...........................................................
elif [ "$req" = "constraints" ];then

   if [ -n "$fowner" ];then
       AND_OWNER=" and owner = '$fowner' "
       AND_OWNER_A=" and a.owner = '$fowner' "
       AND_OWNER_B=" and b.owner = '$fowner' "
       AND_NOT_OWNER_B=" and b.owner != '$fowner' "
   fi
sqlplus -s "$CONNECT_STRING"  <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on heading off pause off embedded off verify off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline , 'List Constraints which point to the Table $ftable' nline from sys.dual
/
prompt
set embedded on heading on feedback off linesize 190 pagesize 66
col cn       form a25 head 'Foreign Keys:'
col col1     form a48 head 'Remote |Table.Colmuns'
col col0     form a35 head 'Table Columns'
col cond     form a40 head 'Col or Condition'
col typ      form a10 head 'Type of |Constraint'
col rc       form a18 head 'Remote|Constraint name'
col rc2       form a56 head 'Remote tables with FK on $ftable'
col drule    form a12 head 'Delete|Rule'
col position form 999 head 'Pos'
col status   form a7  head 'Status'
col st   form a10  head 'Status'
col owner new_value owner noprint
break on col1
prompt
prompt CONSTRAINT_NAME                Constraint Col or Condition                          Pos Status     DEFERRABLE     DEFERRED
prompt ------------------------------ ---------- ---------------------------------------- ---- ---------- -------------- ---------

set head off
select  a.constraint_name, decode(constraint_type,'U','UNIQUE','PRIMARY') typ,
            b.column_name cond, position, status st, a.DEFERRABLE,a.DEFERRED
     from dba_constraints a, dba_cons_columns b
           where a.table_name = upper('$ftable')  $AND_OWNER_A
             and   constraint_type in ('U','P')
             and   a.constraint_name = b.constraint_name
             and   a.owner = b.owner
/
select a.constraint_name, 'Check' typ,
       search_condition cond,  1 position, status st,a.DEFERRABLE, a.DEFERRED
      from dba_constraints a, dba_cons_columns b
      where a.table_name =  '$ftable' $AND_OWNER_A
      and   constraint_type in ('C')
              and   a.constraint_name = b.constraint_name
              and   a.owner = b.owner
/
prompt
prompt Foreign Key from $ftable to remote tables:
set head on
select * from ( -- get now those constraint in the same schema
select  '(' || a.constraint_name || ')' cn, a.table_name||'.'||d.column_name col0,
         '-> '|| b.owner||'.'||b.table_name||'.'||c.column_name  col1, '('|| b.constraint_name|| ')' rc ,
     c.position,substr(a.status,1,1) status,
     decode(a.delete_rule,'CASCADE','ON CASCADE',' ') drule
     from
            dba_constraints a,
            dba_constraints b,
            all_cons_columns c,
            all_cons_columns d
     where
           a.table_name = '$ftable'  $AND_OWNER_A   --$AND_OWNER_B
       and d.owner = a.owner
       and d.table_name = a.table_name
       and d.constraint_name = a.constraint_name
       and a.r_constraint_name = b.constraint_name
       and a.r_owner = b.owner
       and c.constraint_name = b.constraint_name
       and c.owner = b.owner
       and d.position = c.position
)
order by position
/
prompt
prompt Foreign Key from remote tables to $ftable:
prompt
col col0     form a68 head 'Local |Table.Colmuns (cons name)'
col rc       form a30 head 'Remote|Constraint name'
select b.constraint_name rc, '['||b.owner||'].'||b.table_name||'.'||d.column_name  rc2,
'--> ['||a.owner||'].'||a.table_name||'.'||c.column_name ||'  ('||a.constraint_name||')' col0
 from dba_constraints a , dba_constraints b, all_cons_columns c, all_cons_columns d
where a.table_name= '$ftable'  $AND_OWNER_A
  and b.r_constraint_name = a.constraint_name
  and b.r_owner = a.owner
  and c.constraint_name = a.constraint_name
  and c.owner = a.owner
  and c.table_name = a.table_name
  and d.owner = b.owner
  and d.table_name = b.table_name
  and d.constraint_name = b.constraint_name
/
prompt
prompt List triggers:
prompt
col TRIGGERING_EVENT for a20 head 'Triggering event'
col fname for a50 head 'Trigger  name'
col COLUMN_NAME for a30
set feed on
select  owner||'.'||trigger_name fname , COLUMN_NAME, TRIGGER_TYPE, TRIGGERING_EVENT ,
        ACTION_TYPE, status
   from all_triggers where  table_name = '$ftable' $AND_OWNER ;
prompt

exit
EOF


# ...........................................................
# extract DDL
# ...........................................................
elif [ "$req" = "ddl" ];then
sqlplus -s "$CONNECT_STRING"  <<EOF
set echo  off verify off feed off
set head off
SET PAGESIZE 0 line 160
SET LONG 90000
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'CONSTRAINTS_AS_ALTER', true ) ;
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', TRUE ) ;
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'CONSTRAINTS', TRUE ) ;
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'REF_CONSTRAINTS', TRUE ) ;
execute dbms_metadata.set_transform_param(dbms_metadata.session_transform, 'TABLESPACE', true) ;
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY', true ) ;
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', true ) ;
set echo  on
set serveroutput on size 99999 format wrapped
col fline for a4000
spool $FOUT.tmp
SELECT dbms_metadata.get_ddl('TABLE', '$ftable','$fowner') fline FROM dual
/
select dbms_metadata.get_ddl('INDEX',index_name,'$fowner') fline from (
select index_name from dba_indexes where table_name = '$ftable' and table_owner = '$fowner'
)
/
EOF
cat $FOUT.tmp |sed -e 's/ *$//' -e '/^ *$/d' > $FOUT ; rm $FOUT.tmp
echo "results in $FOUT"
exit
# ...........................................................
# sLobs
# ...........................................................
elif [ "$req" = "slobs" ];then

if [ -n "$fowner" ];then
     AND_OWNER=" and us.owner = '$fowner' "
     AND_TOWNER=" and table_owner = '$fowner' "
     AND_I_OWNER=" and ui.owner='$fowner' and ui.owner = uip.index_owner "
     AND_IS_OWNER=" and ui.owner='$fowner' and ui.owner = uisp.index_owner "
fi

sqlplus -s "$CONNECT_STRING"  <<EOF

column table_name format a20 heading "Table"
column owner format a15 heading "Owner"
column tablespace_name format a18 heading "Tablespace"
column column_name format a20 heading "column Name"
column segment_name format a25 heading "Segment Name"
column partition_name format a25 heading "Partition Name"
column lob_column format a30 heading "Lob Column"
column bytes format 999990.99 head "Size(m)"
column LOB_PARTITION_NAME format a18 heading "Lob partition|name" justify c
col type format a14
set linesize 190 pagesize 66 feedback off termout on head on pause off



SELECT /*+ USE_NL(a) */
    'alter table ' ||  a.owner || '.$ftable modify lob ('|| a.lob_column||') (shrink space cascade )   -- size='  || sum(bytes/1048576)  || 'm ;'
 FROM (
          -- segment lob from table
          SELECT OWNER owner, 'table_lob' type, segment_name, '-' partition_name, '-' lob_partition_name, tablespace_name, column_name lob_column
                      FROM dba_lobs us WHERE table_name = '$ftable' $AND_OWNER
          UNION
          -- segment lob from partition table
          SELECT TABLE_OWNER owner, 'partition_rows' type,table_name segment_name, partition_name, '-'lob_partition_name, tablespace_name,'-' lob_column
                      FROM dba_tab_partitions WHERE table_name = '$ftable' $AND_TOWNER $AND_PART_NAME
          UNION
          -- segment lob from sub partition table
              (SELECT TABLE_OWNER owner, 'sub_partition' type,table_name segment_name, subpartition_name partition_name,
                       '-'lob_partition_name,tablespace_name,'-' lob_column
                       FROM dba_tab_subpartitions WHERE (table_name, partition_name) IN
                      (SELECT table_name, partition_name FROM dba_tab_partitions WHERE  table_name = '$ftable' $AND_TOWNER $AND_PART_NAME) $AND_TOWNER)
          UNION
              (SELECT /*+ FIRST_ROWS */ TABLE_OWNER owner,'lob_partition' type, lob_name segment_name, partition_name,
                                         lob_partition_name,TABLESPACE_NAME, COLUMN_NAME lob_column
                     FROM dba_lob_partitions WHERE table_name = '$ftable' $AND_TOWNER $AND_PART_NAME)
          UNION
          -- lob index
              SELECT ui.owner,'index_lob' type, ui.index_name segment_name, '-' , '-',ui.TABLESPACE_NAME,'-' lob_column
                       FROM  dba_indexes ui
                WHERE ui.table_name = '$ftable' $AND_TOWNER
                  AND ui.index_type = 'LOB'
          UNION
              (SELECT ui.owner,'idx_lob_part' type,uip.index_name segment_name, '-'partition_name,
                       uip.partition_name lob_partition_name ,uip.TABLESPACE_NAME,'-' lob_column
                       FROM  dba_indexes ui, dba_ind_partitions uip
                WHERE ui.table_name = '$ftable' $AND_I_OWNER
                  AND ui.index_type = 'LOB'
                  AND uip.index_name = ui.index_name)
          UNION
              (SELECT /*+ FIRST_ROWS */ TABLE_OWNER owner,'lob_subpart' type,lob_name segment_name,
                      lob_subpartition_name lob_partition_name,'-' partition_name,TABLESPACE_NAME,COLUMN_NAME lob_column
                 FROM dba_lob_subpartitions WHERE table_name = '$ftable' $AND_TOWNER)
          UNION
              (SELECT /*+ FIRST_ROWS */  ui.owner,'idx_lob_subpart' type, ui.index_name segment_name,
                       uisp.subpartition_name partition_name,'-'lob_partition_name, uisp.TABLESPACE_NAME,'-' lob_column
                 FROM dba_indexes ui, dba_ind_subpartitions uisp
                WHERE ui.table_name = '$ftable'
                  AND ui.index_type = 'LOB'
                  AND uisp.index_name = ui.index_name $AND_IS_OWNER)
      ) a,
      dba_segments us
  WHERE us.segment_name = a.segment_name $AND_OWNER
  and a.type != 'index_lob' and a.type !='idx_lob_part' and a.type !='idx_lob_subpart' 
  AND (1=  case
            when  us.partition_name  is null then 1
            when  us.partition_name = a.partition_name then 1
            when  us.partition_name = a.lob_partition_name then 1
            else 0  end
       )
   GROUP by  a.owner,a.type ,a.segment_name,a.partition_name,lob_partition_name,a.tablespace_name,lob_column
order by a.owner,a.partition_name
/

EOF
# ...........................................................
# Lobs
# ...........................................................
elif [ "$req" = "lobs" ];then
if [ -n "$fowner" ];then
     AND_OWNER=" and us.owner = '$fowner' "
     AND_TOWNER=" and table_owner = '$fowner' "
     AND_I_OWNER=" and ui.owner='$fowner' and ui.owner = uip.index_owner "
     AND_IS_OWNER=" and ui.owner='$fowner' and ui.owner = uisp.index_owner "
fi

sqlplus -s "$CONNECT_STRING"  <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 120
set termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline, 'List tables info : $fowner' nline from sys.dual
/
column table_name format a20 heading "Table"
column owner format a15 heading "Owner"
column tablespace_name format a18 heading "Tablespace"
column column_name format a40 heading "column Name"
column segment_name format a25 heading "Segment Name"
column partition_name format a25 heading "Partition Name"
column lob_column format a30 heading "Lob Column"
column fbytes format 99999990.9 head "Size(m)"
column LOB_PARTITION_NAME format a18 heading "Lob partition|name" justify c
col type format a14
set linesize 190 pagesize 66 feedback off termout on head on pause off

compute sum of fbytes on report
 break on owner on segment_name on partition_name on report



SELECT /*+ USE_NL(a) */
    a.owner,a.segment_name, a.partition_name, a.lob_column column_name,
    a.lob_partition_name, a.tablespace_name,
    a.type,sum(bytes/1048576) as fbytes
 FROM (
          -- segment lob from table
          SELECT OWNER owner, 'table_lob' type, segment_name, '-' partition_name, '-' lob_partition_name, tablespace_name, '-'lob_column
                      FROM dba_lobs us WHERE table_name = '$ftable' $AND_OWNER
          UNION
          -- segment lob from partition table
          SELECT TABLE_OWNER owner, 'partition_rows' type,table_name segment_name, partition_name, '-'lob_partition_name, tablespace_name,'-' lob_column
                      FROM dba_tab_partitions WHERE table_name = '$ftable' $AND_TOWNER $AND_PART_NAME
          UNION
          -- segment lob from sub partition table
              (SELECT TABLE_OWNER owner, 'sub_partition' type,table_name segment_name, subpartition_name partition_name,
                       '-'lob_partition_name,tablespace_name,'-' lob_column
                       FROM dba_tab_subpartitions WHERE (table_name, partition_name) IN
                      (SELECT table_name, partition_name FROM dba_tab_partitions WHERE  table_name = '$ftable' $AND_TOWNER $AND_PART_NAME) $AND_TOWNER)
          UNION
              (SELECT /*+ FIRST_ROWS */ TABLE_OWNER owner,'lob_partition' type, lob_name segment_name, partition_name,
                                         lob_partition_name,TABLESPACE_NAME, COLUMN_NAME lob_column
                     FROM dba_lob_partitions WHERE table_name = '$ftable' $AND_TOWNER $AND_PART_NAME)
          UNION
          -- lob index
              SELECT ui.owner,'index_lob' type, ui.index_name segment_name, '-' , '-',ui.TABLESPACE_NAME,'-' lob_column
                       FROM  dba_indexes ui
                WHERE ui.table_name = '$ftable' $AND_TOWNER
                  AND ui.index_type = 'LOB'
          UNION
              (SELECT ui.owner,'idx_lob_part' type,uip.index_name segment_name, '-'partition_name,
                       uip.partition_name lob_partition_name ,uip.TABLESPACE_NAME,'-' lob_column
                       FROM  dba_indexes ui, dba_ind_partitions uip
                WHERE ui.table_name = '$ftable' $AND_I_OWNER $AND_PART_NAME
                  AND ui.index_type = 'LOB'
                  AND uip.index_name = ui.index_name)
          UNION
              (SELECT /*+ FIRST_ROWS */ TABLE_OWNER owner,'lob_subpart' type,lob_name segment_name,
                      lob_subpartition_name lob_partition_name,'-' partition_name,TABLESPACE_NAME,COLUMN_NAME lob_column
                 FROM dba_lob_subpartitions WHERE table_name = '$ftable' $AND_TOWNER)
          UNION
              (SELECT /*+ FIRST_ROWS */  ui.owner,'idx_lob_subpart' type, ui.index_name segment_name,
                       uisp.subpartition_name partition_name,'-'lob_partition_name, uisp.TABLESPACE_NAME,'-' lob_column
                 FROM dba_indexes ui, dba_ind_subpartitions uisp
                WHERE ui.table_name = '$ftable'
                  AND ui.index_type = 'LOB'
                  AND uisp.index_name = ui.index_name $AND_IS_OWNER)
      ) a,
      dba_segments us
  WHERE us.segment_name = a.segment_name $AND_OWNER
  AND (1=  case
            when  us.partition_name  is null then 1
            when  us.partition_name = a.partition_name then 1
            when  us.partition_name = a.lob_partition_name then 1
            else 0  end
       )
   GROUP by  a.owner,a.type ,a.segment_name,a.partition_name,lob_partition_name,a.tablespace_name,lob_column
order by owner,partition_name
/
prompt
EOF

# ...........................................................
# chain rows
# ...........................................................
elif [ "$req" = "chain" ];then
  if [ -n "$FOWNER" ];then
      AND=" and"
   else
      unset AND
   fi

sqlplus -s "$CONNECT_STRING"  <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 190 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline, 'List tables with chained rows for Schema : $fowner' nline from sys.dual
/
$PROMPT
set pause off feed on verify on
column avg_row_len format 999990 heading "Average|Row len"
column pct_free format 990 heading "pct|Free"
column pct_used format 990 heading "pct|Used"
column pct format 990.99 heading "%|Chained" justify c
column chain_cnt  format 999,990 heading "Chained| Rows" justify c
column table_name format a30 heading "Table Name"
             set embedded on
             set linesize 80 pagesize 66
             set feedback on
             set termout on head on;
             select TABLE_NAME, NUM_ROWS, CHAIN_CNT,
                    decode(num_rows,0,0,(chain_cnt*100/num_rows)) pct,
                    pct_used,pct_free,avg_row_len
             from dba_tables
             where chain_cnt > 0 $AND $FOWNER
                   order by 100- (chain_cnt*100/num_rows)

/
EOF

# ...........................................................

elif [ "$req" = "HIST_GROW" ];then
cat <<EOF

                                 Table growth history

MACHINE           -  $HOST
ORACLE_SID        -  $ORACLE_SID
Date              -  `date +%a' '%d' '%B' '%Y' '%H:%M:%S`
Username          -  $S_USER
DBID              -  $DBID
Owner             -  $fowner                                Table             -  $ftable
EOF

sqlplus -s "$CONNECT_STRING"  <<EOF
set linesize 200 head on pagesize 90
column FDATE format $LENGHT_FDATE_COL
column SPACE_USAGE format 9999999999 head 'Space |Used(MB)' justify c
column SPACE_ALLOC format 9999999999 head 'Space |Allocated(MB)' justify c
column QUALITY format A14

break on QUALITY

select to_char(TIMEPOINT,'$FDATE_FORMAT') FDATE,SPACE_ALLOC/1024/1024 SPACE_ALLOC,SPACE_USAGE/1024/1024 SPACE_USAGE,QUALITY from table(dbms_space.OBJECT_GROWTH_TREND(
object_owner => '$fowner',
start_time => $TRUNC_DATE-($NUM_ROWS*$NBR_MIN)/(1440),
end_time => $TRUNC_DATE,
object_name => '$ftable',
object_type => 'TABLE',
interval => TO_DSINTERVAL('$INTERVAL'))) order by FDATE desc;

EOF

# ...........................................................
# this is the default for 'tbl -t <tab> -u <owner>
# ...........................................................

else  # default

    if [ -z "$fowner"  ];then
        unset AND
    elif [ -z "$ftable" ];then
        unset AND
    else
       AND=" and "
    fi

    if [ -n "$FOWNER" ];then
        AND_F=" and "
    fi
    if [ -n "$A_TABLE_LIKE" ];then
        AND_IOT=" and iot_name like '$ftable'"
    else
        AND_IOT=" and IOT_NAME='$ftable'"
    fi

    DEG=",degree "
    ADEG=",trim(a.degree) degree "
    GADEG=",trim(a.degree) "

    if [ "$ADDITIONAL_INFO" = "TRUE" ];then
        # avg row per block  = ( (avg free space in block/block_size)/100 ) * (max num of rows in a block)
        SQL_INFO1=" prompt
                col rmv head 'Row |movement' justify c
                col compression head 'Compression' format a11
                col PCT_FREE head 'Pct|Free' for 9999 justify c
                col PCT_USED head 'Pct|Used' for 9999 justify c
                select ROW_MOVEMENT rmv , EMPTY_BLOCKS, CHAIN_CNT, AVG_ROW_LEN,
                        round(nvl(floor(&fsize - 66 - INI_TRANS * 24)/greatest(AVG_ROW_LEN + 2, 11), 1),0) max_rpb,
                        (1-(avg_space/&fsize))* round(nvl(floor(&fsize - 66 - INI_TRANS * 24)/greatest(AVG_ROW_LEN + 2, 11), 1),0) avg_rpb,
                        num_rows/(trunc(nvl(floor(&fsize - 66 - INI_TRANS * 24)/greatest(AVG_ROW_LEN + 2, 11), 1),0))/
                        decode(blocks,0,0.00000001,blocks)  dens,
                        trunc((1+FREELIST_GROUPS+BLOCKS)*&fsize) /1048576 HWM, Nvl(compression,'NO') compression, DEPENDENCIES as depend
                        from dba_tables where table_name = '$ftable' $AND_FOWNER ;"
        SQL_INFO2="prompt
              SELECT AVG_SPACE_FREELIST_BLOCKS avg_sfp, PCT_FREE, PCT_USED, INI_TRANS, MAX_TRANS, freelists, freelist_groups,
              trim(DEGREE) degree, CACHE,  BUFFER_POOL, USER_STATS, IOT_TYPE, SAMPLE_SIZE
              from dba_tables where table_name = '$ftable' $AND_FOWNER;
         prompt
         prompt -- lobs :
         prompt
         col column_name for a22 head 'Column'
         col in_row head 'Stored|In Rows' justify c for a7
         col index_name for a26
         col PCTVERSION head 'pct|vers' for 9999
         col rete for 999999 head 'Retention'
         col Cache head 'Cache'
         col Logging head 'Logging'
         col in_tbs head 'Stored|In Tablespace' justify l for a24
         col chunk_size head 'Chunk|Size' for 99999
         col index_name head 'Index name'
         select  a.COLUMN_NAME , a.TABLESPACE_NAME in_tbs, CHUNK chunk_size, a.INDEX_NAME , a.PCTVERSION,
                 a.retention rete,CACHE, LOGGING, IN_ROW,FORMAT,a.PARTITIONED, round(b.bytes/1048576) size_mb
         from dba_lobs a , dba_segments b
            where table_name = '$ftable' $AND_A_FOWNER
              and a.owner = b.owner  (+)
              and a.index_name = b.segment_name (+) ;"
   fi

ORD_PRED=${ORD_PRED:-3}
if [ "$SHOW_ALLOCATED" = "Y" ];then
       S_ALLOCATED=" s.bytes/1048576 lsize,"
       s_ALLOCATED_NULL=" null,"
       S_SUM_ALLOC=" sum(s.bytes/1048576) lsize,"
       S_DBA_SEG=", dba_segments s "
       AND_S1=" and a.owner  = s.owner and a.table_name = segment_name and s.segment_type = 'TABLE' "
       AND_S2=" and a.owner  = s.owner and a.table_name = segment_name and s.segment_type = 'TABLE PARTITION' "
       AND_S3=" and b.owner=a.owner and b.table_name = a.table_name and b.index_type ='IOT - TOP' "
       AND_S4=" and b.owner  = b.owner and b.index_name = s.segment_name  and s.segment_type = 'INDEX' and INDEX_TYPE = 'IOT - TOP' "
fi 
sqlplus -s "$CONNECT_STRING"  <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
set pagesize 66 linesize 132 termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS')||chr(10),
       'Username          -  '||rpad(USER,15)  || 'Show partition table' nline
from sys.dual
/
col db_block_size new_value fsize noprint
set head off feed off
select value db_block_size from v\$parameter where name = 'db_block_size'
/
set head on
break on partition_position on partition_name on report
COL partition_position       FORMAT  9999 heading 'Part| Pos'
COL fsize                    FORMAT  9999999   heading 'Size (m)'
COL lsize                    FORMAT  9999999   heading 'Alloc |ated(m)' justify c
COL partition_name           FORMAT  A32 head 'Partition name'
COL subpartition_name        FORMAT  A25 head 'System generated|Subpartition name'
COL table_name               FORMAT   A32 head 'Table name'
COL tablespace_name          FORMAT  A24   justify c HEAD 'Tablespace'
COL owner                    FORMAT  A16   justify c HEAD 'Owner'
COL glob                     FORMAT  A4   justify c HEAD 'Glob|stat'
col last_analyzed            format  A19  head 'Last Analyzed'
col created                  format  A19  head 'Created'
col last_ddl_time            format  A19  head 'Last ddl'
col temporary                format  A10  head 'Temporary'
col row_movement head "Row|Movment" justify c
col avg_rpb format 9999999 head "Avg Row|Per blk" justify c
col max_rpb format 9999999 head "Max Row|Per blk" justify c
col empt_clocks head "Empty|Blocks"
col CHAIN_CNT head "Chain|Cnt" format 99999
col AVG_ROW_LEN head "Avg row|Len" format 9999999
col AVG_space format 999999 head "Avg|space"
col NUM_FREELIST_BLOCKS format 99999 head "Num|Frlist|block" justify c
col Empty_BLOCKS head "Empty|blocks"
col TEMPORARY head "Temp" format a5
col BUFFER_POOL format a8 head "Buffer|pool"
col GLOBAL_STATS head "Global|stats" format a5
col USER_STATS head "User|stats" format a5
col IOT_TYPE head "Iot" format a5
col SAMPLE_SIZE head "Sample| size" justify c
col degree for a3 head "Deg|ree" justify c
col dens format 990.9999 head 'Density:|eqjoin ret|% of rows'
col ini_trans head "ini|tran" format 999
col max_trans head "max|tran" format 999
col avg_sfp head "Avg space|Free list block"  format 9999 justify c
col FREELISTS head "free|list"  format 999
col FREELIST_GROUPS head "Free list| Group"  format 999
col cache format a5
col compression for a5 head 'Comp|ressed' justify c
col row_movement for a3  head 'Row|Mov'
comp sum of fsize on report

$PROMPT

$SQL_DDL
set lines 190
 -- heap table
SELECT table_name, a.owner,trunc(NUM_ROWS)num_rows,  a.blocks, a.BLOCKS * t.block_size/1048576 fsize , 
       $S_ALLOCATED case nvl(a.tablespace_name,'0')
            when '0' then
                    case nvl(a.partitioned,'0')
                                when '0'  then '-- temporary --'
                                else '-- partitioned -- '
                 end
            else  a.tablespace_name
        end tablespace_name , 
        TO_CHAR(a.LAST_ANALYZED, 'YYYY-MM-DD HH24:MI:SS') last_analysed, CHAIN_CNT, AVG_ROW_LEN,
        global_stats glob, substr(row_movement,1,3) row_movement  $ADEG
     FROM DBA_TABLES a, dba_tablespaces t  $S_DBA_SEG
     WHERE IOT_TYPE is null and a.tablespace_name is not null 
           and a.tablespace_name = t.tablespace_name $AND_F  $A_FOWNER $AND_TABLE $A_TABLE_LIKE $AND_S1
union -- table partition
SELECT a.table_name, a.owner, sum(p.NUM_ROWS)num_rows,  sum(p.blocks), sum(p.BLOCKS * t.block_size/1048576) fsize , $S_SUM_ALLOC
       max(case nvl(a.tablespace_name,'0')
            when '0' then
                    case nvl(a.partitioned,'0')
                                when '0'  then '-- temporary --'
                                else '-- partitioned -- '
                 end
            else   a.tablespace_name
        end ) tablespace_name ,
        max(TO_CHAR(p.LAST_ANALYZED, 'YYYY-MM-DD HH24:MI:SS')) last_analysed, sum(p.CHAIN_CNT), avg(p.AVG_ROW_LEN),
        max(a.global_stats) glob, max(substr(row_movement,1,3)) row_movement  $ADEG
     FROM DBA_TABLES a, DBA_TAB_PARTITIONS p, dba_tablespaces t $S_DBA_SEG
     WHERE
             a.IOT_TYPE is null and a.tablespace_name is null $AND_A_FOWNER $AND_A_TABLE $A_TABLE_LIKE $AND_S2
        and  a.owner = p.table_owner   and a.TABLE_NAME = p.table_name
        and p.tablespace_name = t.tablespace_name
            group by a.table_name, a.owner $GADEG
union
SELECT b.table_name, b.owner,trunc(b.NUM_ROWS)num_rows, LEAF_BLOCKS LEAF_BLOCKS ,LEAF_BLOCKS * &fsize/1048576 fsize ,  $S_ALLOCATED
       case nvl(b.tablespace_name,'0')
            when '0' then ' -- partitioned --'
            else  b.tablespace_name
        end tablespace_name ,
       TO_CHAR(b.LAST_ANALYZED, 'YYYY-MM-DD HH24:MI:SS') last_analysed, CHAIN_CNT, AVG_ROW_LEN,
        a.global_stats glob, substr(row_movement,1,3) row_movement  $ADEG
     FROM DBA_TABLES a,  dba_indexes  b  $S_DBA_SEG
     WHERE   IOT_TYPE = 'IOT' $AND_F  $A_FOWNER $AND_B_TABLE $AND_S3 $AND_S4 $A_TABLE_LIKE
              and b.owner = a.owner and b.table_name = a.table_name
order by $ORD_PRED , last_analysed
/
-- union
select  table_name, owner , null, blocks, blocks * &fsize/1048576  , $S_ALLOCATED_NULL
        '-iot_overflow-' , null, null, null, null, null  $DEG
           from  DBA_TABLES where IOT_TYPE ='IOT_OVERFLOW'  $AND_IOT $AND_FOWNER 
/
$SQL_INFO1
$SQL_INFO2
prompt
EOF

fi

