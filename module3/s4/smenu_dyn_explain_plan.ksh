#!/bin/sh
# set -x
# author :  B. Polarski
# 02 Sept 2005
# Modified 08 Jun 2006 : Added dbms_xplan
#          28 Jun 2006 : Added vi, vh, -sb
#          27 May 2008 : Added option -vx
#          16 Jun 2009 : Added automatic conversion from sql_id to hash_value and reverse
#          09 Dec 2010 : Added iggy Fernandez 'show execution steps plan'
#          23 Dec 2010 : renamed '-sb' to '-lb'
ROWNUM=30
# ---------------------------------------------------------------------------
# to update an outlines : update outln.ol$hints set hint_text='INDEX_RS_ASC(@"SEL$1" "TXN"@"SEL$1" ("TXN"."EXT_TXN_ID" "TXN"."END_TIME"))'
#          where ol_name = 'SYS_OUTLINE_07120313083698728' and hint#=1
# get the value of ol_name and hint# with 'sx -stl' followed by 'sx -tn <ol_name>'

# ----------------------------------------------------------------------------------------------------------------
function check_HV_or_exit
{
  if [ -z "$HASH_VALUE" ];then
       echo "corresponding hash_value is not found in memory anymore"
       exit
  fi
}
# ----------------------------------------------------------------------------------------------------------------
function get_sql_id_first_child {
   ret=`get_sql_id $1`
   var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select min(child_number) from v\\$sql where sql_id='$ret' ;
EOF`
echo "$var" | tr -d '\r'  | awk '{print $1}'
}
# ----------------------------------------------------------------------------------------------------------------
function get_sql_id
{
 if [ -z "${1%%*[a-z]*}" ];then
    # $1 is a mix
    echo "$1"
    return
 fi
 # $1 is a hash_value made of only digit
 ret=`sqlplus -s "$CONNECT_STRING" <<EOF
 set head off pagesize 0 feed off verify off
 select distinct sql_id from v\\$sql where hash_value = '$1';
EOF`
 echo "$ret" | tr -d '\r' |  awk '{print $1}'
}
# ----------------------------------------------------------------------------------------------------------------
function get_hash_value
{
 if [ -n "${1%%*[a-z]*}" ];then
    # $1 is only digit
    echo "$1"
    return
 fi
 SQL_ID=$1
 ret=`sqlplus -s "$CONNECT_STRING" <<EOF
 set head off pagesize 0 feed off verify off
 select trunc(mod(sum((instr('0123456789abcdfghjkmnpqrstuvwxyz',substr(lower(trim('$SQL_ID')),level,1))-1)
        *power(32,length(trim('$SQL_ID'))-level)),power(2,32))) hash_value
     from dual connect by level <= length(trim('$SQL_ID'));
EOF`

 echo "$ret" |  tr -d '\r'|  awk '{print $1}'
}
# ----------------------------------------------------------------------------------------------------------------
function help1
{
cat <<EOF

#   .................................................................
"         Show options for Stored outlines:
#   .................................................................

OUTLINES:
 --------
    sx -lso                                          # List sql from V\$SQL which uses an Outline
    sx -lc [-cat <CATEGORY>]                         # List stored outlines for category <CATEGORY>
    sx -cro <hash_value> -c <n> -cat <CATEGORY_NAME> # Create stored outlines for a given hash_value
    sx -crf <sql file> -cat <CATEGORY_NAME>
            [-ot <OUTLNAME>] -u <OWNER> [-outln <schema>] # Create stored outlines for SQL in file
    sx -ch <OUTLINE_NAME> -hv <HASH_VALUE>           # Set hash value for OUTLINE_NAME
    sx -ln [ OUTLINE_NAME ] [-outln <schema>]        # List hints for a given outline name. 'sx -lc' list existing outlines
                                                     # Default outln schema is OUTLN. use this if it is another schema
    sx -clone <outlname> <new_outlname> [-cat <category>]  # for cloning, default category is DEFAULT
    sx -rfo <OUTLINE_NAME>                           # Resync the outline edited with memory
    sx -tr  <SRC_OL> <TARGET_OL> ][-outln <schema>]  # Transfer all outlines hints from <SRC_OL> to <TARGET_OL>
    sx -pos  OUTLINE_NAME OLD_POS NEW_POS            # Move a hint line from one position to another
    sx -exp ][-outln <schema>]                       # Export the 3 outlines tables : OL\$ OL\$NODES OL\$HINTS in $SBIN/tmp
    sx -vs  <hash_value>                             # Add stats from average execution (v\$sql_plan_statistic  / v\$sql.executions )
    sx -opt <hash_value>                             # Add optimizer environment for the given hash_value
    sx -cl  <OUTLINE_NAME>                           # Reset used column in 'sx -lc' (dba_outlines.used) for an outline name
    sx -dr  <OUTLINE_NAME>                           # Drop an outline
    sx -drc <category>                               # Drop an outlines category

SQL PROFILES:
-------------
    sx -lprf                                         # List SQL Profiles
    sx -cr_prf <sql_id> [-cat <CATEGORY>]            # Create a stored profile from an SQL_ID. May serve to be modified later
    sx -tr_prf -so <sql_id> -pv <planhv> -st<sql_id> # Create a stored profile for -st <sql_id> using plan from -so <sql_id> 
                 -cat <CATEGORY>]                    # -p < plan hash value to use>
    sx -fprf <hinted sql file> -st <sql_id>          # Create a stored profile for -st <sql_id> using the plan of <hinted sql file>
    sx -dr_prf <SQL_PROFILE_NAME>                    # Drop an sql profile
    sx -lh <SQL_PROFILE_NAME>                        # List the hint of SQL profile (need select on SQLOBJ\$DATA)

SQL plan statbilisation -> Stored Outlines/SQL profiles:

    sx -str <STRING>  [-u <USER>]                    # List hash values which strings in the plan
    sx -stu                                          # List operations present in v\$sql_plan

Notes:   -outln --> use this only if the owner of the OL$ is not schema OUTLN

Example :
       sx -crf F.SQL -cat MYCAT -ot F_OT -u LILI # Creates stored outlines for the sql in F.SQl, that addess tables visible
                                                 # by schema LILI  the stored outline will be named F_OT and be in category
                                                 # MYCAT. if F.SQL is not in the current dir, then give full path
SQL COLORISATION:
-----------------
    sx -clr                                  # list all colored sql
    sx -clr_add  <sql_id>                    # Add colored sql
    sx -clr_drop <sql_id>                    # Remove colored sql

EOF
exit
}
# ----------------------------------------------------------------------------------------------------------------
function help
{
cat <<EOF

#   .................................................................
#      Type : 'sx -h1'   for help on Stored Outlines
#   .................................................................
 Show plan  (Note: you can use indiferently sql_id or hash_value)

List plan:

    sx <hash_value> -a -c <nn>              # Show plan
    sx -pl <PLAN_HASH_VALUE>                # list plan for given plan hash value
    sx -lpl <PLAN_HASH_VALUE>               # list hash_value, sql_id for a given plan_hash_value
    sx -l -u <OWNER>  -tim -gets -cost      # list plans per sort options  :
                                               -tim    : active time;
                                               -gets   : Per gets
                                               -cost   : Per costs
                                               -rows   : Per number of output rows
    sx -inv <sql_id>                        # list reasong for child invalidation: only column with 'Y' are marked
    sx -ld  -u <OWNER>                      # List all SQL_ID with differents plan in v\$sql
    sx -lf  -u <OWNER> -cost <nn> -card <n> # List plan with a FULL tablescan in it order by cost (default) or cardinality
    sx -lfs -u <OWNER> -cost <nn> -card <n> # Same as -lf but uses actual values from v$sql_plan_statistics rather than estimated from v$sql_plan
    sx -lfpl -u <OWNER> -cost<nn> -card <n> # Generate the plan for all sql_id, child seen in option '-lf'
    sx -lpt <TABLE> [ -u <OWNER> ]          # List all plan which refers to <table> or an index of the table.

    sx -s   <sql_id> [-o <n>] [-c <nn>]           # use dbms_xplan
    sx -po  <sql_id> [-o <n>] [-c <nn>]           # use dbms_xplan with step order marked
    sx -po1 <sql_id> [-o <n>] [-c <nn>]           # use dbms_xplan with step order marked and extended info
    sx -gr  <sql_id> [-o <n>] [-c <nn>]           #  Plan with magnitude graphs
    sx -vl  <hash_value>                    # Add stats from last execution (v\$plan_statistic )
    sx -vx  <hash_value> [-c <n> ] -p       # another mix of v\$sql_plan and v\$sql_plan_statistics.  -p : show partitions start/stop
    sx -px  <hash_value> [-c <n> ] -p       # Same as vx, but takes input from v\$sql_plan_monitor.   -p : show partitions start/stop
    sx -stp <sql_id> -c <n>                 # Show execution plan steps
    sx -lb <sql_id>                         # show bind variable sample (10g)+
    sx -purge <sql_id> -pv <plan_hash_value> # purge the plan for the given sql_id from SGA

utilities:
    sx -vh <hash_value>                     # Conversion : return sql_id    for a given hash_value
    sx -vi <sql_id>                         # Conversion : return hash_value for a given sql_id
    sx -ed <process_numm>                   # edit tracefile whose number was given by '-f'
    sx -f <file> -ev <nnn> -level <nn>      # set events (10046|53 etc..) before executing file


Notes:
   -len  : set the len of the sql_text column               -v  : Verbose : output sql text that the 'sx' command will use. Default is silent
     -f  : execute sql in file.                             -c  : SQL Child number (used in v$sql) default is 0
     -s  : Show plain with dbms_xplan.display_cursor    -level  : event level, default is 12, relevant only with -f
     -l  : List all SQL present in v\$sql_plan              -a  : List access path and filter
             -u  : restric plan to <schema>             -dup <nn>    : show sqlid with <nn> or more duplicate plan. default is 1
             -rn : Limit number or rows to display, default is 30
    -ev  : set event <nnnnn> in session  while executing sql given by -f, default is 10053
     -o  : where <n> is a choice of format
                   1 :  Basic    Displays the minimum information
                   2 :  Typical  Displays Partition pruning, parallelism and predicates if available
                   3 :  Serial   Like TYPICAL except that the parallel information is not displayed
                   4 :  All      Display all levels
                   5 :  Runstats_last  Displays the runtime statistics for the last execution of the cursor.
                        (requires init.ora statistics_level=ALL)
                   6 :  Runstats_TOT Displays the total aggregated runtime statistics for all executions (req. init.ora statistics_level=ALL)
                   7 :  Outlines  Display outlines used by the sql
                   8 :  Advanced Display all available data about this sql
                   9 :  ALLSTATS LAST : predicted row counts and actual executions stats
               default FORMAT is Typical
   -lot <sql_id> -c <n>   : list stored outlines for given sql_id [and optinal child number]

  For explain plans, 'sx' will first count the number of plans for a given SQL and display the number of the lowest child
  It will then try to display the plan for child 0, which is default. If there is no plan use the value of min to see
  the first one and query v\$sql_plan for other childs number. if there are multple childs, use sx <HV> -c <CHILD> to see each child plan

EOF
exit
}
# ---------------------------------------------------------------------------
if [  "$1" = "-h" ];then
   help
fi
if [ -z "$1" ];then
  help
fi
METHOD=PLAN
FORMAT="TYPICAL"
EV_NUM=10053
EV_LEVEL=12
CATEGORY=DEFAULT
typeset -u F_USER
FLEN=50
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
unset TITTLE
unset_presql=FALSE
OLSCHEMA=OUTLN

while [ -n "$1" ]
do
   case "$1" in
    -a ) METHOD=AC1 ;;
   -lb ) METHOD=BIND; SQL_ID=$2; shift;;
    -c ) CHILD=$2;shift;;
   -co ) CHILD_O=$2;shift;;
   -ct ) CHILD_T=$2;shift;;
  -cat ) CATEGORY=`echo $2|awk '{print toupper ($1) }'`; shift ;;          # too much compat problems with typset -u
   -cl ) METHOD=CLEAN_USED; OT_NAME=`echo $2|awk '{print toupper($1)}'`; shift; TITTLE="Clear used col for $CATEGORY" ;;
   -ch ) METHOD=CH_HV ; OT_NAME=$2 ; shift ;;
-clone ) METHOD=CLONE; OLD=$2 ; NEW=$3;shift; shift ;;
  -cro ) METHOD=CR_OUTLN; HASH_VALUE=$2; shift ;;
  -crf ) METHOD=CRF_OUTLN; SQLFILE=$2; shift ;;
-cr_prf) METHOD=CR_STORED_PROF; SQL_ID=$2 ; shift ;;
-tr_prf) METHOD=CR_STORED_PROF2;;
  -drc ) METHOD=DROPCAT ; CATEGORY=`echo $2|awk '{print toupper($1)}'`; shift ;TITTLE="drop outlines category $CATEGORY" ;;
   -dr ) METHOD=DROPOL ; OT_NAME=`echo $2|awk '{print toupper($1)}'`; shift ;TITTLE="drop outlines category $CATEGORY" ;;
-dr_prf) METHOD=DROP_PRF; PRF_NAME=$2 ; shift ;;
  -dup ) MAX_PLAN=$2 ; shift ;;
   -ed ) METHOD=TRC; TRC=$2; shift ;;
   -ev ) EV_NUM=$2; shift ;;
 -inv  ) METHOD=INVALID; SQL_ID=$2 ; shift ; S_USER=system;;
  -exp ) METHOD=EXP_STO ;;
    -f ) FFILE=$2;shift
         if [ ! -f "$FFILE" ];then
            echo "Cannot find $FFILE"
            exit
         fi
         METHOD=FILE;;
 -fprf ) METHOD=CR_PRF_FROM_FILE ; FILE=$2; shift ; unset_presql=TRUE;;
 -gets ) ORDER=gets ;;
 -card ) N_CARD=$2; shift ;;
  -tim ) ORDER=time;;
  -dsk ) ORDER=disk_reads;;
 -cost ) ORDER=cost
         if [ -n "$2" -a $2 -eq $2 2>/dev/null ];then
                 N_COST=$2; shift
         fi;;
    -h ) help ;;
   -hv ) HASH_VALUE=$2 ; shift ;;
   -gr ) METHOD=GRAPH; SQL_ID=$2 ; shift ;;
    -i ) METHOD=PLAN_SQL_ID; SQL_ID=$2; shift ;;
  -len ) FLEN=$2 ; shift ;;
    -l ) METHOD=LIST_PLAN;;
   -lc ) METHOD=LIST_OUTLN ; TITTLE="List outlines" ;;
   -ld ) METHOD=LIST_DIFF_PLAN ; TITTLE="List sql with different plans" ;;
   -lf ) METHOD=LIST_FULL ; TITTLE="List plan with full table scan"  ;;
   -lh ) METHOD=LIST_NHINT ; PRF_NAME=$2; shift; TITTLE="List hints for profle : $PRF_NAME"  ;;
  -lfs ) LFS=TRUE; METHOD=LIST_FULL ; TITTLE="List plan with full table scan"  ;;
 -lfpl ) METHOD=LIST_FULL_PL ; TITTLE="List plan of all SQL with full table scan"  ;;
-level ) EV_LEVEL=$2; shift ;;
   -ln ) METHOD=LIST_HINT; OT_NAME=$2 ; shift ;;
  -lot ) METHOD=LIST_PLAN_HINT ; sql_id=$2 ; shift ;;
  -lpl ) METHOD=LPL; PL_HV=$2; shift ;;
  -lpt ) METHOD=LPT; ftable=$2; shift ;;
  -lso ) METHOD=LIST_SQL_OUTLN  ;;
   -ot ) OT_NAME=`echo $2|awk '{print toupper($1)}'`; shift ;;
  -opt ) METHOD=OPTIM_ENV ; HASH_VALUE=$2 ; shift ;;
    -p ) PART_START_STOP=TRUE;;
   -pl ) METHOD=PL; PLAN_HASH_VALUE=$2; shift ; unset_presql=TRUE ;;
  -pos ) METHOD=CHG_POS; OT_NAME=$2; OLD_POS=$3 ; NEW_POS=$4; shift; shift;shift ;;
  -rfo ) METHOD=REFRESH_OL ; OT_NAME=$2; shift;;
 -rows ) ORDER=rows ;;
   -rn ) ROWNUM=$2; shift;;
    -s ) METHOD=DBMS; SQL_ID=$2; shift ;;
   -clr     ) METHOD=COLOR_SQL_LIST;;
   -clr_add ) METHOD=COLOR_SQL_ADD; SQL_ID=$2; shift ;;
   -clr_drop) METHOD=COLOR_SQL_REMOVE; SQL_ID=$2; shift ;;
   -so ) SQL_ID_O=$2 ; shift ;;
   -st ) SQL_ID_T=$2 ; shift ;;
 -lprf ) METHOD=SQL_PROFILE;;
  -stp ) METHOD=STEPS ; SQL_ID="$2" ; shift ;;
  -str ) METHOD=STR ; STRING="$2" ; shift ;;
 -stru ) METHOD=STRU ;;
   -tr ) METHOD=CP_OL; SOURCE=$2;TARGET=$3;shift ; shift ;;
    -v ) VERBOSE=TRUE ;;
   -vh ) METHOD=VH; HASH_VALUE=$2 ; shift;;
   -vi ) METHOD=VI; SQL_ID=$2 ;  TITTLE="List bind variable value for sql_id"; shift;;
   -vl ) METHOD=VLAST; HASH_VALUE=$2;shift;;
   -vs ) METHOD=VSTAT; HASH_VALUE=$2;shift;;
   -vx ) METHOD=XMS ;  HASH_VALUE=$2
         if [ "$3" = "-c" ];then
              if [ -n "$4" ];then
                    SQL_CHILD=$4; shift; shift ;
              fi
         fi
         shift;;
 -purge) METHOD=PURGE; SQL_ID=$2; shift ;;
   -pv ) PLAN_HASH_VALUE=$2; shift ;;
   -px ) METHOD=PXMS ;  SQL_ID=$2 ;;
    -u ) F_USER=$2; AND_OWNER=" and u.username=upper('$F_USER')"; shift;;
    -o ) VAR=$2;
          case $VAR in
              1) FORMAT=BASIC;;
              2) FORMAT=TYPICAL;;
              3) FORMAT=SERIAL;;
              4) FORMAT='ALL +PEEKED_BINDS';;
              5) FORMAT=RUNSTATS_LAST;;
              6) FORMAT=RUNSTATS_TOT;;
              7) FORMAT=OUTLINE ;;
              8) FORMAT=ADVANCED ;;
              9) FORMAT="ALLSTATS LAST" ;;
          esac
         shift ;;
   -outln) OLSCHEMA=$2 ; shift ;;
   -po ) METHOD=PLAN_ORD ; SQL_ID=$2 ; shift ;;
   -po1) METHOD=PLAN_ORD1 ; SQL_ID=$2 ; shift ;;
   -h1 ) help1; exit ;;
     * ) echo "Unknow parameter: $1" ; exit ;; 
   esac
   shift
done

# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
if [ -n "$HASH_VALUE" ];then
     HASH_VALUE=`get_hash_value $HASH_VALUE`
elif [ -n "$SQL_ID_O" ];then
        HASH_VALUE=`get_hash_value $SQL_ID_O`
fi
#----------------------------------------------------------------------------
if [ -n "$CHILD" ];then
   AND_CHILD_NUMBER=" and child_number = $CHILD"
   AND_A_CHILD_NUMBER=" and a.child_number = $CHILD"
fi
if [ -z "$TITTLE" ];then
    TITTLE="Explain plan for query hash_value"
fi
# --------------------------------------------------------------------------
# purge the plan for a given SID
# --------------------------------------------------------------------------
if [ "$METHOD" = "PURGE" ];then
set -x
  if [ -z "$SQL_ID" ];then
      echo "I need an SQL ID"
      exit
  fi
  if [  -z "$PLAN_HASH_VALUE" ];then
        echo "I need a plan hash value"
        exit
  fi
ADR=`sqlplus -s "$CONNECT_STRING" <<EOF
      set feed off pagesize 0 head off
      select address from v\\$sqlarea where sql_id='$SQL_ID';
EOF`
  if [  -z "$ADR" ];then
        echo "I did not found the address in v\$sqlarea"
        exit
  fi
  SQL="exec sys.dbms_shared_pool.purge('$ADR, $PLAN_HASH_VALUE','C');"
  echo "Do this as sys : $SQL"
  exit
# --------------------------------------------------------------------------
#     List all plan that refers to a table name or one of its index
# --------------------------------------------------------------------------
elif [ "$METHOD" = "LPT" ];then
   unset_presql=TRUE
   ftable=`echo $ftable | tr 'a-z' 'A-Z']`
   # check if the 
   if [ -n "$ftable" -a -z "$fowner" ];then
      var=`sqlplus -s "$CONNECT_STRING" <<EOF
      set feed off pagesize 0 head off
      select  trim(to_char(count(*))) cpt from dba_tables where table_name='$ftable' ;
EOF` 
      ret=`echo $var | tr -d '\n'| awk '{print $1}'`
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
         fowner=`echo $var | tr -d '\n'| awk '{print $1}'`
         FOWNER="owner = '$fowner' "
         AND_FOWNER=" and  $FOWNER"
        elif [ "$ret" -gt "0"  ];then
           if [ -z "$fowner" ];then
              echo " there are many tables for $ftable:"
              echo " Use : "
              echo
              echo " sx -lpt $ftable -u <user> "
              echo
              sqlplus -s "$CONNECT_STRING" <<EOF
                 set feed off pagesize 66 head on
                select owner, table_name , 'table' from dba_tables where table_name='$ftable' ;
EOF
              exit
           fi
        fi
    fi # end check if fowner

   TITTLE="List plan that refers to $fowner.$ftable  "
   SQL="
  set pages 0 lines 190 feed off verify off head on
  col sql_id for a13
  col child_number for 999 head 'CHD|NBR'
  col sql_text for a60
  col ms for 999990.99 head 'ms|spent|per exec' justify c
  col Arows  for 99999999 head 'Actual|rows|per exec'
  col reads for 9999999 head 'reads|per exec'
  col writes for 999999 head 'writes'
  col plan_hash_value head 'plan'
  col execs head 'execs' for 99999999
  col gets head 'gets|per exec' for 99999999
  with v as (
    select '$ftable' object_name from dual 
    union
    select index_name from dba_indexes
where owner='$fowner' and table_name='$ftable'
 ) ,
v1 as    (
 select distinct
      p.sql_id, p.child_number, plan_hash_value
      from v, v\$sql_plan p
where p.object_owner='$fowner' and p.object_name=v.object_name
) select  
      v1.sql_id, v1.child_number , v1.plan_hash_value
      ,nvl(s.EXECUTIONS,v.EXECUTIONS) execs
      ,nvl(s.ELAPSED_TIME,v.ELAPSED_TIME/decode(nvl(s.EXECUTIONS,v.EXECUTIONS),0,1,nvl(s.EXECUTIONS,v.EXECUTIONS)))/1000 ms
      , nvl(s.OUTPUT_ROWS,v.ROWS_PROCESSED/decode(nvl(s.EXECUTIONS,v.EXECUTIONS),0,1,nvl(s.EXECUTIONS,v.EXECUTIONS))) arows
      , round(nvl(s.CR_BUFFER_GETS,nvl(s.cu_BUFFER_GETS,v.BUFFER_GETS/decode(nvl(s.EXECUTIONS,v.EXECUTIONS),0,1,nvl(s.EXECUTIONS,v.EXECUTIONS))))) gets
      ,nvl(s.DISK_READS,v.DISK_READS/decode(nvl(s.EXECUTIONS,v.EXECUTIONS),0,1,nvl(s.EXECUTIONS,v.EXECUTIONS))) reads
      ,s.DISK_WRITES writes
      ,substr(v.sql_text,1,60) sql_text
  from 
        v1, v\$sql v, v\$sql_plan_statistics s
  where v1.sql_id = v.sql_id
   and v1.child_number =v.child_number
   and v1.sql_id = s.sql_id (+)
   and v1.child_number = s.child_number(+)
   and s.operation_id (+)= 1
order by v1.plan_hash_value
/
"

# --------------------------------------------------------------------------
elif [ "$METHOD" = "LIST_NHINT" ];then
   unset_presql=TRUE
SQL="
set pages 90
set lines 190
select hint as outline_hints
   from (select p.name, p.signature, p.category, row_number()
         over (partition by sd.signature, sd.category order by sd.signature) row_num,
         extractValue(value(t), '/hint') hint
   from sys.sqlobj\$data sd, dba_sql_profiles p,
        table(xmlsequence(extract(xmltype(sd.comp_data), '/outline_data/hint'))) t
   where sd.obj_type = 1
   and p.signature = sd.signature
   and p.category = sd.category
   and p.name like ('$PRF_NAME'))
   order by row_num
/
"
# --------------------------------------------------------------------------
# found on Don chio website
# --------------------------------------------------------------------------
elif [ "$METHOD" = "INVALID" ];then
  if [ -z "$SQL_ID" ];then
     echo "I need an sql id"
     exit
  fi
SQL="
set serveroutput on
set line 1090 pages 900
declare
      c         number;
      col_cnt   number;
      col_rec   dbms_sql.desc_tab;
      col_value varchar2(4000);
      ret_val    number;
begin
     dbms_output.put_line('***************************************');
     dbms_output.put_line('SQL_ID  : '|| '$SQL_ID' ) ;
     dbms_output.put_line('***************************************');
     c := dbms_sql.open_cursor;
     dbms_sql.parse(c, 'select s.* from v\$sql_shared_cursor s where s.sql_id =''$SQL_ID''', dbms_sql.native);
     dbms_sql.describe_columns(c, col_cnt, col_rec);
     for idx in 1 .. col_cnt loop
       dbms_sql.define_column(c, idx, col_value, 4000);
     end loop;
     ret_val := dbms_sql.execute(c);
     while(dbms_sql.fetch_rows(c) > 0) loop
       for idx in 1 .. col_cnt loop
         dbms_sql.column_value(c, idx, col_value);
         if col_rec(idx).col_name in ('CHILD_NUMBER' ) then
           dbms_output.put_line(rpad(col_rec(idx).col_name, 30) || ' = ' || col_value);
         elsif col_value = 'Y' then
           dbms_output.put_line(rpad(col_rec(idx).col_name, 30) || ' = ' || col_value);
         end if;
       end loop;
       dbms_output.put_line('--------------------------------------------------');
      end loop;
     dbms_sql.close_cursor(c);
end;
/
"
# --------------------------------------------------------------------------
#       SQLPLAN with order : R. Geist variation using model
# --------------------------------------------------------------------------
elif [ "$METHOD" = "GRAPH" ];then

# Found at : http://dboptimizer.com/2011/09/20/display_cursor/

SQL_ID=`get_sql_id $SQL_ID`
if  [ -z "$CHILD" ];then
    CHILD=`get_sql_id_first_child $SQL_ID`
fi
SQL="

col cn format 99
col ratio format 99
col ratio1 format A6
--set pagesize 1000
set linesize 190
break on sql_id on cn
col lio_rw format 999
col "operation" format a60
col a_rows for 999,999,999
col e_rows for 999,999,999
col elapsed for 999,999,999
col TCF_GRAPH for a7

Def v_sql_id=$SQL_ID

select
       id,
       parent_id,
       -- sql_id,
       --hv,
       -- ptime, stime,
       nvl(lio,0) lio,
       case when stime - nvl(ptime ,0) > 0 then
          stime - nvl(ptime ,0)
        else 0 end as elapsed,
       nvl(trunc((lio-nvl(plio,0))/nullif(a_rows,0)),0) lio_ratio,
       --starts,
       --nvl(ratio,0)                                    TCF_ratio,
       ' '||case when ratio > 0 then
                rpad('-',ratio,'-')
             else
               rpad('+',ratio*-1 ,'+')
       end as                                           TCF_GRAPH,
       starts*cardinality                              e_rows,
                                                       a_rows,
       --nvl(lio,0) lio, nvl(plio,0)                      parent_lio,
       case
          when oid=0 then operation ||'(' ||sql_id||','||to_char(childn)||')'
          else operation
       end                                                   operation
from (
  SELECT
      stats.LAST_ELAPSED_TIME                             stime,
      p.elapsed                                  ptime,
      stats.sql_id                                        sql_id
    , stats.HASH_VALUE                                    hv
    , stats.id  oid
    , stats.CHILD_NUMBER                                  childn
    , to_char(stats.id,'990')
      ||decode(stats.access_predicates,null,null,'A')
      ||decode(stats.filter_predicates,null,null,'F')     id
    , stats.parent_id
    , stats.CARDINALITY                                    cardinality
    , LPAD(' ',depth)||stats.OPERATION||' '||
      stats.OPTIONS||' '||
      stats.OBJECT_NAME||
      DECODE(stats.PARTITION_START,NULL,' ',':')||
      TRANSLATE(stats.PARTITION_START,'(NRUMBE','(NR')||
      DECODE(stats.PARTITION_STOP,NULL,' ','-')||
      TRANSLATE(stats.PARTITION_STOP,'(NRUMBE','(NR')      "operation",
      stats.last_starts                                     starts,
      stats.last_output_rows                                a_rows,
      (stats.last_cu_buffer_gets+stats.last_cr_buffer_gets) lio,
      p.lio                                                 plio,
      trunc(log(10,nullif
         (stats.last_starts*stats.cardinality/
          nullif(stats.last_output_rows,0),0)))             ratio
  FROM
       v\$sql_plan_statistics_all stats
       , (select sum(last_cu_buffer_gets + last_cr_buffer_gets) lio,
                 sum(LAST_ELAPSED_TIME) elapsed,
                 child_number,
                 parent_id,
                 sql_id
         from v\$sql_plan_statistics_all
         group by child_number,sql_id, parent_id) p
  WHERE
    stats.sql_id='&v_sql_id'  and
    p.sql_id(+) = stats.sql_id and
    p.child_number(+) = stats.child_number and
    p.parent_id(+)=stats.id
)
order by sql_id, childn , id
/

"
# --------------------------------------------------------------------------
#       SQLPLAN with order : R. Geist variation using model
# --------------------------------------------------------------------------
elif [ "$METHOD" = "PLAN_ORD" ];then

SQL_ID=`get_sql_id $SQL_ID`
if  [ -z "$CHILD" ];then
    CHILD=`get_sql_id_first_child $SQL_ID`
fi
FORMAT=${FORMAT:-ALLSTATS LAST}



SQL="
set termout on lines 150 pages 1000
col plan_table_output format a150

/* ALLSTATS LAST is assumed as the default formatting option for DBMS_XPLAN.DISPLAY_CURSOR */
define v_xc_format = '$FORMAT'
define  v_xc_sql_id = '$SQL_ID'
defin v_xc_child_no = '$CHILD'

with sql_plan_data as (
        select  id, parent_id
        from    gv\$sql_plan
        where   inst_id = sys_context('userenv','instance')
        and     sql_id = '&v_xc_sql_id'
        and     child_number = to_number('&v_xc_child_no')
        )
,    hierarchy_data as (
        select  id, parent_id
        from    sql_plan_data
        start   with id = 0
        connect by prior id = parent_id
        order   siblings by id desc
        )
,    ordered_hierarchy_data as (
        select id
        ,      parent_id as pid
        ,      row_number() over (order by rownum desc) as oid
        ,      max(id) over () as maxid
        from   hierarchy_data
        )
,    xplan_data as (
        select /*+ ordered use_nl(o) */
               rownum as r
        ,      x.plan_table_output as plan_table_output
        ,      o.id
        ,      o.pid
        ,      o.oid
        ,      o.maxid 
        ,      count(*) over () as rc
        from   table(dbms_xplan.display_cursor('&v_xc_sql_id',to_number('&v_xc_child_no'),'&v_xc_format')) x
               left outer join
               ordered_hierarchy_data o
               on (o.id = case
                             when regexp_like(x.plan_table_output, '^\|[\* 0-9]+\|')
                             then to_number(regexp_substr(x.plan_table_output, '[0-9]+'))
                          end)
        )
select plan_table_output
from   xplan_data
model
   dimension by (rownum as r)
   measures (plan_table_output,
             id,
             maxid,
             pid,
             oid,
             greatest(max(length(maxid)) over () + 3, 6) as csize,
             cast(null as varchar2(128)) as inject,
             rc)
   rules sequential order (
          inject[r] = case
                         when id[cv()+1] = 0
                         or   id[cv()+3] = 0
                         or   id[cv()-1] = maxid[cv()-1]
                         then rpad('-', csize[cv()]*2, '-')
                         when id[cv()+2] = 0
                         then '|' || lpad('Pid |', csize[cv()]) || lpad('Ord |', csize[cv()])
                         when id[cv()] is not null
                         then '|' || lpad(pid[cv()] || ' |', csize[cv()]) || lpad(oid[cv()] || ' |', csize[cv()]) 
                      end, 
          plan_table_output[r] = case
                                    when inject[cv()] like '---%'
                                    then inject[cv()] || plan_table_output[cv()]
                                    when inject[cv()] is not null
                                    then regexp_replace(plan_table_output[cv()], '\|', inject[cv()], 1, 2)
                                    else plan_table_output[cv()]
                                 end ||
                                 case
                                    when cv(r) = rc[cv()]
                                    then  chr(10) ||
                                         'About'  || chr(10) || 
                                         '------' 
                                 end 
         )
order  by r
/
"
# --------------------------------------------------------------------------
#       SQLPLAN with order : R. Geist variation using model
# --------------------------------------------------------------------------
elif [ "$METHOD" = "PLAN_ORD1" ];then


#-- Script:       xplan_extended_display_cursor.sql
#-- Version:      0.9
#--               December 2011
#-- Author:       Randolf Geist
#--               oracle-randolf.blogspot.com
#-- Description:  A free-standing SQL wrapper over DBMS_XPLAN. Provides access to the
#--               DBMS_XPLAN.DISPLAY_CURSOR pipelined function for a given SQL_ID and CHILD_NUMBER
#--
#--               This is a prototype for an extended analysis of the data provided by the
#--               Runtime Profile (aka. Rowsource Statistics enabled via
#--               SQL_TRACE = TRUE, STATISTICS_LEVEL = ALL or GATHER_PLAN_STATISTICS hint)
#--               and reported via the ALLSTATS/MEMSTATS/IOSTATS formatting option of
#--               DBMS_XPLAN.DISPLAY_CURSOR
#--
#-- Versions:     This utility will work for all versions of 10g and upwards.
#--
#-- Required:     The same access as DBMS_XPLAN.DISPLAY_CURSOR requires. See the documentation
#--               of DISPLAY_CURSOR for your Oracle version for more information
#--
#--               The script directly queries
#--               1) V$SESSION
#--               2) V$SQL_PLAN_STATISTICS_ALL
#--
#-- Credits:      Based on the original XPLAN implementation by Adrian Billington (http://www.oracle-developer.net/utilities.php
#--               resp. http://www.oracle-developer.net/content/utilities/xplan.zip)
#--               and inspired by Kyle Hailey's TCF query (http://dboptimizer.com/2011/09/20/display_cursor/)
#--
#-- Features:     In addition to the PID (The PARENT_ID) and ORD (The order of execution, note that this doesn't account 
#--                for the special cases so it might be wrong)
#--               columns added by Adrian's wrapper the following additional columns over ALLSTATS are provided:
#--
#--               A_TIME_SELF        : The time taken by the operation itself 
#-- this is the operation's cumulative time minus the direct descendants operation's cumulative time
#--               LIO_SELF           : The LIOs done by the operation itself 
#--                                    this is the operation's cumulative LIOs minus the direct descendants operation's cumulative LIOs
#--               READS_SELF         : The reads performed the operation itself 
#--                                    this is the operation's cumulative reads minus the direct descendants operation's cumulative reads
#--               WRITES_SELF        : The writes performed the operation itself 
#--                                     this is the operation's cumulative writes minus the direct descendants operation's cumulative writes
#--               A_TIME_SELF_GRAPH  : A graphical representation of A_TIME_SELF relative to the total A_TIME
#--               LIO_SELF_GRAPH     : A graphical representation of LIO_SELF relative to the total LIO
#--               READS_SELF_GRAPH   : A graphical representation of READS_SELF relative to the total READS
#--               WRITES_SELF_GRAPH  : A graphical representation of WRITES_SELF relative to the total WRITES
#--               LIO_RATIO          : Ratio of LIOs per row generated by the row source 
#--                                      the higher this ratio the more likely there could be a more efficient way 
#--                                      to generate those rows (be aware of aggregation steps though)
#--               TCF_GRAPH          : Each +/- sign represents one order of magnitude based on ratio 
#                        between E_ROWS_TIMES_START and A-ROWS. Note that this will be misleading with Parallel Execution (see E_ROWS_TIMES_START)
#--               E_ROWS_TIMES_START : The E_ROWS multiplied by STARTS - this is useful for understanding the actual cardinality estimate 
#                 for related combine child operations getting executed multiple times. Note that this will be misleading with Parallel Execution
#--
#--
#-- Usage:        @xplan_extended_display_cursor.sql [sql_id] [cursor_child_number] [format_option]
#--
#--               If both the SQL_ID and CHILD_NUMBER are omitted the previously executed SQL_ID and CHILD_NUMBER of the session will be used
#--               If the SQL_ID is specified but the CHILD_NUMBER is omitted then CHILD_NUMBER 0 is assumed
#--
#--               This prototype does not support processing multiple child cursors like DISPLAY_CURSOR is capable of
#--               when passing NULL as CHILD_NUMBER to DISPLAY_CURSOR. Hence a CHILD_NUMBER is mandatory, either
#--               implicitly generated (see above) or explicitly passed
#--
#--               The default formatting option for the call to DBMS_XPLAN.DISPLAY_CURSOR is ALLSTATS LAST - extending this output is the primary purpose of this script
#--
#-- Note:         You need a veeery wide terminal setting for this prototype, something like linesize 400 should suffice
#--
##--               This tool is free but comes with no warranty at all - use at your own risk
#--

SQL_ID=`get_sql_id $SQL_ID`
if  [ -z "$CHILD" ];then
    CHILD=`get_sql_id_first_child $SQL_ID`
fi
FORMAT=${FORMAT:-ALLSTATS LAST}

SQL="
set echo off verify off termout off
set doc off
col plan_table_output format a400
set linesize 400 pagesize 0 tab off

/* ALLSTATS LAST is assumed as the default formatting option for DBMS_XPLAN.DISPLAY_CURSOR */
define fo = '$FORMAT'
define  si = '$SQL_ID'
defin cn = '$CHILD'

column last new_value last

/* Last or all execution */
select
       case
       when instr('&fo', 'LAST') > 0
       then 'last_'
       end  as last
from
       dual
;

set termout on

with
-- The next three queries are based on the original XPLAN wrapper by Adrian Billington
-- to determine the PID and ORD information, only slightly modified to deal with
-- the 10g special case that V$SQL_PLAN_STATISTICS_ALL doesn't include the ID = 0 operation
-- and starts with 1 instead for Rowsource Statistics
sql_plan_data as
(
  select id , parent_id
  from
          v\$sql_plan_statistics_all
  where
          sql_id = '&si'
  and     child_number = &cn
),
hierarchy_data as
(
  select
          id
        , parent_id
  from
          sql_plan_data
  start with
          id in
          (
            select
                    id
            from
                    sql_plan_data p1
            where
                    not exists
                    (
                      select
                              null
                      from
                              sql_plan_data p2
                      where
                              p2.id = p1.parent_id
                    )
          )
  connect by
          prior id = parent_id
  order siblings by
          id desc
),
ordered_hierarchy_data as
(
  select
          id
        , parent_id                                as pid
        , row_number() over (order by rownum desc) as oid
        , max(id) over ()                          as maxid
        , min(id) over ()                          as minid
  from
          hierarchy_data
),
-- The following query uses the MAX values
-- rather than taking the values of PLAN OPERATION_ID = 0 (or 1 for 10g V$SQL_PLAN_STATISTICS_ALL)
-- for determining the grand totals
--
-- This is because queries that get cancelled do not
-- necessarily have yet sensible values in the root plan operation
--
-- Furthermore with Parallel Execution the elapsed time accumulated
-- with the ALLSTATS option for operations performed in parallel
-- will be greater than the wallclock elapsed time shown for the Query Coordinator
--
-- Note that if you use GATHER_PLAN_STATISTICS with the default
-- row sampling frequency the (LAST_)ELAPSED_TIME will be very likely
-- wrong and hence the time-based graphs and self-statistics will be misleading
--
-- Similar things might happen when cancelling queries
--
-- For queries running with STATISTICS_LEVEL = ALL (or sample frequency set to 1)
-- the A-TIME is pretty reliable
totals as
(
  select
          max(&last.cu_buffer_gets + &last.cr_buffer_gets) as total_lio
        , max(&last.elapsed_time)                          as total_elapsed
        , max(&last.disk_reads)                            as total_reads
        , max(&last.disk_writes)                           as total_writes
  from
          v\$sql_plan_statistics_all
  where
          sql_id = '&si'
  and     child_number = &cn
),
-- The totals for the direct descendants of an operation
-- These are required for calculating the work performed
-- by a (parent) operation itself
-- Basically this is the SUM grouped by PARENT_ID
direct_desc_totals as
(
  select
          sum(&last.cu_buffer_gets + &last.cr_buffer_gets) as lio
        , sum(&last.elapsed_time)                          as elapsed
        , sum(&last.disk_reads)                            as reads
        , sum(&last.disk_writes)                           as writes
        , parent_id
  from
          v\$sql_plan_statistics_all
  where
          sql_id = '&si'
  and     child_number = &cn
  group by
          parent_id
),
-- Putting the three together
-- The statistics, direct descendant totals plus totals
extended_stats as
(
  select
          stats.id
        , stats.parent_id
        , stats.&last.elapsed_time                                  as elapsed
        , (stats.&last.cu_buffer_gets + stats.&last.cr_buffer_gets) as lio
        , stats.&last.starts                                        as starts
        , stats.&last.output_rows                                   as a_rows
        , stats.cardinality                                         as e_rows
        , stats.&last.disk_reads                                    as reads
        , stats.&last.disk_writes                                   as writes
        , ddt.elapsed                                               as ddt_elapsed
        , ddt.lio                                                   as ddt_lio
        , ddt.reads                                                 as ddt_reads
        , ddt.writes                                                as ddt_writes
        , t.total_elapsed
        , t.total_lio
        , t.total_reads
        , t.total_writes
  from
          v\$sql_plan_statistics_all stats
        , direct_desc_totals ddt
        , totals t
  where
          stats.sql_id='&si'
  and     stats.child_number = &cn
  and     ddt.parent_id (+) = stats.id
),
-- Further information derived from above
derived_stats as
(
  select
          id
        , greatest(elapsed - nvl(ddt_elapsed , 0), 0)                              as elapsed_self
        , greatest(lio - nvl(ddt_lio, 0), 0)                                       as lio_self
        , trunc((greatest(lio - nvl(ddt_lio, 0), 0)) / nullif(a_rows, 0))          as lio_ratio
        , greatest(reads - nvl(ddt_reads, 0), 0)                                   as reads_self
        , greatest(writes - nvl(ddt_writes,0) ,0)                                  as writes_self
        , total_elapsed
        , total_lio
        , total_reads
        , total_writes
        , trunc(log(10, nullif(starts * e_rows / nullif(a_rows, 0), 0)))           as tcf_ratio
        , starts * e_rows                                                          as e_rows_times_start
  from
          extended_stats
),
/* Format the data as required */
formatted_data1 as
(
  select
          id
        , lio_ratio
        , total_elapsed
        , total_lio
        , total_reads
        , total_writes
        , to_char(numtodsinterval(round(elapsed_self / 10000) * 10000 / 1000000, 'SECOND'))                         as e_time_interval
          /* Imitate the DBMS_XPLAN number formatting */
        , case
          when lio_self >= 18000000000000000000 then to_char(18000000000000000000/1000000000000000000, 'FM99999') || 'E'
          when lio_self >= 10000000000000000000 then to_char(lio_self/1000000000000000000, 'FM99999') || 'E'
          when lio_self >= 10000000000000000 then to_char(lio_self/1000000000000000, 'FM99999') || 'P'
          when lio_self >= 10000000000000 then to_char(lio_self/1000000000000, 'FM99999') || 'T'
          when lio_self >= 10000000000 then to_char(lio_self/1000000000, 'FM99999') || 'G'
          when lio_self >= 10000000 then to_char(lio_self/1000000, 'FM99999') || 'M'
          when lio_self >= 100000 then to_char(lio_self/1000, 'FM99999') || 'K'
          else to_char(lio_self, 'FM99999') || ' '
          end                                                                                                       as lio_self_format
        , case
          when reads_self >= 18000000000000000000 then to_char(18000000000000000000/1000000000000000000, 'FM99999') || 'E'
          when reads_self >= 10000000000000000000 then to_char(reads_self/1000000000000000000, 'FM99999') || 'E'
          when reads_self >= 10000000000000000 then to_char(reads_self/1000000000000000, 'FM99999') || 'P'
          when reads_self >= 10000000000000 then to_char(reads_self/1000000000000, 'FM99999') || 'T'
          when reads_self >= 10000000000 then to_char(reads_self/1000000000, 'FM99999') || 'G'
          when reads_self >= 10000000 then to_char(reads_self/1000000, 'FM99999') || 'M'
          when reads_self >= 100000 then to_char(reads_self/1000, 'FM99999') || 'K'
          else to_char(reads_self, 'FM99999') || ' '
          end                                                                                                       as reads_self_format
        , case
          when writes_self >= 18000000000000000000 then to_char(18000000000000000000/1000000000000000000, 'FM99999') || 'E'
          when writes_self >= 10000000000000000000 then to_char(writes_self/1000000000000000000, 'FM99999') || 'E'
          when writes_self >= 10000000000000000 then to_char(writes_self/1000000000000000, 'FM99999') || 'P'
          when writes_self >= 10000000000000 then to_char(writes_self/1000000000000, 'FM99999') || 'T'
          when writes_self >= 10000000000 then to_char(writes_self/1000000000, 'FM99999') || 'G'
          when writes_self >= 10000000 then to_char(writes_self/1000000, 'FM99999') || 'M'
          when writes_self >= 100000 then to_char(writes_self/1000, 'FM99999') || 'K'
          else to_char(writes_self, 'FM99999') || ' '
          end                                                                                                       as writes_self_format
        , case
          when e_rows_times_start >= 18000000000000000000 then to_char(18000000000000000000/1000000000000000000, 'FM99999') || 'E'
          when e_rows_times_start >= 10000000000000000000 then to_char(e_rows_times_start/1000000000000000000, 'FM99999') || 'E'
          when e_rows_times_start >= 10000000000000000 then to_char(e_rows_times_start/1000000000000000, 'FM99999') || 'P'
          when e_rows_times_start >= 10000000000000 then to_char(e_rows_times_start/1000000000000, 'FM99999') || 'T'
          when e_rows_times_start >= 10000000000 then to_char(e_rows_times_start/1000000000, 'FM99999') || 'G'
          when e_rows_times_start >= 10000000 then to_char(e_rows_times_start/1000000, 'FM99999') || 'M'
          when e_rows_times_start >= 100000 then to_char(e_rows_times_start/1000, 'FM99999') || 'K'
          else to_char(e_rows_times_start, 'FM99999') || ' '
          end                                                                                                       as e_rows_times_start_format
        , rpad(' ', nvl(round(elapsed_self / nullif(total_elapsed, 0) * 12), 0) + 1, '@')                           as elapsed_self_graph
        , rpad(' ', nvl(round(lio_self / nullif(total_lio, 0) * 12), 0) + 1, '@')                                   as lio_self_graph
        , rpad(' ', nvl(round(reads_self / nullif(total_reads, 0) * 12), 0) + 1, '@')                               as reads_self_graph
        , rpad(' ', nvl(round(writes_self / nullif(total_writes, 0) * 12), 0) + 1, '@')                             as writes_self_graph
        , ' ' ||
          case
          when tcf_ratio > 0
          then rpad('-', tcf_ratio, '-')
          else rpad('+', tcf_ratio * -1, '+')
          end                                                                                                       as tcf_graph
  from
          derived_stats
),
/* The final formatted data */
formatted_data as
(
  select
          /*+ Convert the INTERVAL representation to the A-TIME representation used by DBMS_XPLAN
              by turning the days into hours */
          to_char(to_number(substr(e_time_interval, 2, 9)) * 24 + to_number(substr(e_time_interval, 12, 2)), 'FM900') ||
          substr(e_time_interval, 14, 9)
          as a_time_self
        , a.*
  from
          formatted_data1 a
),
/* Combine the information with the original DBMS_XPLAN output */
xplan_data as (
  select
          x.plan_table_output
        , o.id
        , o.pid
        , o.oid
        , o.maxid
        , o.minid
        , a.a_time_self
        , a.lio_self_format
        , a.reads_self_format
        , a.writes_self_format
        , a.elapsed_self_graph
        , a.lio_self_graph
        , a.reads_self_graph
        , a.writes_self_graph
        , a.lio_ratio
        , a.tcf_graph
        , a.total_elapsed
        , a.total_lio
        , a.total_reads
        , a.total_writes
        , a.e_rows_times_start_format
        , x.rn
  from
          (
            select  /* Take advantage of 11g table function dynamic sampling */
                    /*+ dynamic_sampling(dc, 2) */
                    /* This ROWNUM determines the order of the output/processing */
                    rownum as rn
                  , plan_table_output
            from
                    table(dbms_xplan.display_cursor('&si',&cn, '&fo')) dc
          ) x
        , ordered_hierarchy_data o
        , formatted_data a
  where
          o.id (+) = case
                     when regexp_like(x.plan_table_output, '^\|[\* 0-9]+\|')
                     then to_number(regexp_substr(x.plan_table_output, '[0-9]+'))
                     end
  and     a.id (+) = case
                     when regexp_like(x.plan_table_output, '^\|[\* 0-9]+\|')
                     then to_number(regexp_substr(x.plan_table_output, '[0-9]+'))
                     end
)
/* Inject the additional data into the original DBMS_XPLAN output by using the MODEL clause */
select
        plan_table_output
from
        xplan_data
model
        dimension by (rn as r)
        measures
        (
          cast(plan_table_output as varchar2(4000)) as plan_table_output
        , id
        , maxid
        , minid
        , pid
        , oid
        , a_time_self
        , lio_self_format
        , reads_self_format
        , writes_self_format
        , e_rows_times_start_format
        , elapsed_self_graph
        , lio_self_graph
        , reads_self_graph
        , writes_self_graph
        , lio_ratio
        , tcf_graph
        , total_elapsed
        , total_lio
        , total_reads
        , total_writes
        , greatest(max(length(maxid)) over () + 3, 6) as csize
        , cast(null as varchar2(128)) as inject
        , cast(null as varchar2(4000)) as inject2
        )
        rules sequential order
        (
          /* Prepare the injection of the OID / PID info */
          inject[r]  = case
                               /* MINID/MAXID are the same for all rows
                                  so it doesn't really matter
                                  which offset we refer to */
                       when    id[cv(r)+1] = minid[cv(r)+1]
                            or id[cv(r)+3] = minid[cv(r)+3]
                            or id[cv(r)-1] = maxid[cv(r)-1]
                       then rpad('-', csize[cv()]*2, '-')
                       when id[cv(r)+2] = minid[cv(r)+2]
                       then '|' || lpad('Pid |', csize[cv()]) || lpad('Ord |', csize[cv()])
                       when id[cv()] is not null
                       then '|' || lpad(pid[cv()] || ' |', csize[cv()]) || lpad(oid[cv()] || ' |', csize[cv()])
                       end
          /* Prepare the injection of the remaining info */
        , inject2[r] = case
                       when    id[cv(r)+1] = minid[cv(r)+1]
                            or id[cv(r)+3] = minid[cv(r)+3]
                            or id[cv(r)-1] = maxid[cv(r)-1]
                       then rpad('-',
                            case when coalesce(total_elapsed[cv(r)+1], total_elapsed[cv(r)+3], total_elapsed[cv(r)-1]) > 0 then
                            14 else 0 end /* A_TIME_SELF */       +
                            case when coalesce(total_lio[cv(r)+1], total_lio[cv(r)+3], total_lio[cv(r)-1]) > 0 then
                            11 else 0 end /* LIO_SELF */          +
                            case when coalesce(total_reads[cv(r)+1], total_reads[cv(r)+3], total_reads[cv(r)-1]) > 0 then
                            11 else 0 end /* READS_SELF */        +
                            case when coalesce(total_writes[cv(r)+1], total_writes[cv(r)+3], total_writes[cv(r)-1]) > 0 then
                            11 else 0 end /* WRITES_SELF */       +
                            case when coalesce(total_elapsed[cv(r)+1], total_elapsed[cv(r)+3], total_elapsed[cv(r)-1]) > 0 then
                            14 else 0 end /* A_TIME_SELF_GRAPH */ +
                            case when coalesce(total_lio[cv(r)+1], total_lio[cv(r)+3], total_lio[cv(r)-1]) > 0 then
                            14 else 0 end /* LIO_SELF_GRAPH */    +
                            case when coalesce(total_reads[cv(r)+1], total_reads[cv(r)+3], total_reads[cv(r)-1]) > 0 then
                            14 else 0 end /* READS_SELF_GRAPH */  +
                            case when coalesce(total_writes[cv(r)+1], total_writes[cv(r)+3], total_writes[cv(r)-1]) > 0 then
                            14 else 0 end /* WRITES_SELF_GRAPH */ +
                            case when coalesce(total_lio[cv(r)+1], total_lio[cv(r)+3], total_lio[cv(r)-1]) > 0 then
                            11 else 0 end /* LIO_RATIO */         +
                            case when coalesce(total_elapsed[cv(r)+1], total_elapsed[cv(r)+3], total_elapsed[cv(r)-1]) > 0 then
                            11 else 0 end /* TCF_GRAPH */         +
                            case when coalesce(total_elapsed[cv(r)+1], total_elapsed[cv(r)+3], total_elapsed[cv(r)-1]) > 0 then
                            11 else 0 end /* E_ROWS_TIMES_START */
                            , '-')
                       when id[cv(r)+2] = minid[cv(r)+2]
                       then case when total_elapsed[cv(r)+2] > 0 then
                            lpad('A-Time Self |' , 14) end ||
                            case when total_lio[cv(r)+2] > 0 then
                            lpad('Bufs Self |'   , 11) end ||
                            case when total_reads[cv(r)+2] > 0 then
                            lpad('Reads Self|'   , 11) end ||
                            case when total_writes[cv(r)+2] > 0 then
                            lpad('Write Self|'   , 11) end ||
                            case when total_elapsed[cv(r)+2] > 0 then
                            lpad('A-Ti S-Graph |', 14) end ||
                            case when total_lio[cv(r)+2] > 0 then
                            lpad('Bufs S-Graph |', 14) end ||
                            case when total_reads[cv(r)+2] > 0 then
                            lpad('Reads S-Graph|', 14) end ||
                            case when total_writes[cv(r)+2] > 0 then
                            lpad('Write S-Graph|', 14) end ||
                            case when total_lio[cv(r)+2] > 0 then
                            lpad('LIO Ratio |'   , 11) end ||
                            case when total_elapsed[cv(r)+2] > 0 then
                            lpad('TCF Graph |'   , 11) end ||
                            case when total_elapsed[cv(r)+2] > 0 then
                            lpad('E-Rows*Sta|'   , 11) end
                       when id[cv()] is not null
                       then case when total_elapsed[cv()] > 0 then
                            lpad(a_time_self[cv()]               || ' |', 14) end ||
                            case when total_lio[cv()] > 0 then
                            lpad(lio_self_format[cv()]           ||  '|', 11) end ||
                            case when total_reads[cv()] > 0 then
                            lpad(reads_self_format[cv()]         ||  '|', 11) end ||
                            case when total_writes[cv()] > 0 then
                            lpad(writes_self_format[cv()]        ||  '|', 11) end ||
                            case when total_elapsed[cv()] > 0 then
                            rpad(elapsed_self_graph[cv()], 13)   ||  '|'      end ||
                            case when total_lio[cv()] > 0 then
                            rpad(lio_self_graph[cv()], 13)       ||  '|'      end ||
                            case when total_reads[cv()] > 0 then
                            rpad(reads_self_graph[cv()], 13)     ||  '|'      end ||
                            case when total_writes[cv()] > 0 then
                            rpad(writes_self_graph[cv()], 13)    ||  '|'      end ||
                            case when total_lio[cv()] > 0 then
                            lpad(lio_ratio[cv()]                 || ' |', 11) end ||
                            case when total_elapsed[cv()] > 0 then
                            rpad(tcf_graph[cv()], 9)             || ' |'      end ||
                            case when total_elapsed[cv()] > 0 then
                            lpad(e_rows_times_start_format[cv()] ||  '|', 11) end
                       end
          /* Putting it all together */
        , plan_table_output[r] = case
                                 when inject[cv()] like '---%'
                                 then inject[cv()] || plan_table_output[cv()] || inject2[cv()]
                                 when inject[cv()] is present
                                 then regexp_replace(plan_table_output[cv()], '\|', inject[cv()], 1, 2) || inject2[cv()]
                                 else plan_table_output[cv()]
                                 end
        )
order by
        r
/
"
# --------------------------------------------------------------------------
#       Drop sql profile
# --------------------------------------------------------------------------
elif [ "$METHOD" = "LIST_PLAN_HINT" ];then
   TITTLE="List plan hint for sql_id : $sql_id"
   if [ -z "${HASH_VALUE%%*[a-z]*}" ];then
     HASH_VALUE=`get_hash_value $sql_id`
   fi
SQL="
set lines 150
col outline_hints for a140
 select extractvalue(value(d), '/hint') as outline_hints
   from xmltable('/*/outline_data/hint'
               passing (
                         select xmltype(other_xml) as xmlval
                                from v\$sql_plan
                         where sql_id = '$sql_id'  $AND_CHILD_NUMBER
                           and other_xml is not null and rownum=1)) d
/
"
# --------------------------------------------------------------------------
#       Drop sql profile
# --------------------------------------------------------------------------
elif [ "$METHOD" = "CR_PRF_FROM_FILE" ];then
   if [ ! -f "$FILE" ];then
      echo "I do not find the hinted SQL file "
      exit
   fi
   if [  -z "$SQL_ID_T" ];then
      echo
      echo "  I need the sql_id you want to apply new plan on"
      echo
      echo "  -----> Use:  -st <sql_id> "
      echo
      exit
   fi
SQL="
  --
    -- -------------------------------------------------------------------
    --  Transfert the plan of the hinted sql file to the non-hinted sql_id
    -- -------------------------------------------------------------------
    --
    -- WARNING:
    --
    --       This script will work well only on the INSTANCE
    --       where exists the sqlid '$SQL_ID_T'
    --
    -- This procedure may not work if there a columns of type BLOB, LONG or ANYDATA
    -- for you can't use SQL*PLUS to select those type of columns
    --

    set serveroutput on
"
    VAR=`cat $FILE`
#SQL="$SQL
SQL="
col prev_sql_id new_value prev_sql_id ;
col prev_child_number new_value prev_child_number ;
$VAR


with v as (select sid from v\$mystat  where rownum=1 )
select s.prev_sql_id, s.PREV_CHILD_NUMBER from v, v\$session s where s.sid=v.sid
/
    -- from the plan we extract the SQL_SID
    set feed off verify off
declare
   type t_line is table of varchar2(4000) index by binary_integer ;
   lines t_line ;
   v_sql_id varchar2(30) := '&prev_sql_id';
   ar_profile_hints sys.sqlprof_attr;
   cl_sql_text clob;
begin
   -- capture the plan
   -- select * bulk collect into lines from table ( dbms_xplan.display_cursor )    ;
   -- for line in lines.first..lines.last
   -- loop
   --  if substr(lines(line),1,6) = 'SQL_ID' then
   --     v_sql_id:=trim(substr(lines(line), 7, instr(lines(line) ,',') - 7 )) ;
        dbms_output.put_line('Hinted sql_id : ' || v_sql_id ) ;
   --return;
   --      GOTO end_loop ;
   --  end if ;
   --  end loop ;
   --  <<end_loop>>

   -- The bind :b_sql_id contains the sql_id of the hinted SQL
   -- We we will transfer the hinted execution plan to the original SQL

   -- First extract the plan of the hinted SQL:
   select extractvalue(value(d), '/hint') as outline_hints
          bulk collect into ar_profile_hints
   from xmltable('/*/outline_data/hint'
               passing (
                         select xmltype(other_xml) as xmlval
                                from v\$sql_plan where
                          sql_id = v_sql_id and other_xml is not null and CHILD_NUMBER=&prev_child_number and rownum=1)) d;

   -- the original text
   select sql_fulltext into cl_sql_text from v\$sql where sql_id = '$SQL_ID_T' and rownum=1  ;

   -- We transfert the execution path and create the SQL profile
   dbms_sqltune.import_sql_profile(
            sql_text     =>  cl_sql_text ,
            profile      =>  ar_profile_hints ,
            category     => 'DEFAULT',
            name         => 'PROFILE_$SQL_ID_T',
            force_match  =>  true );
end;
/
"
# --------------------------------------------------------------------------
#       Drop sql profile
# --------------------------------------------------------------------------
elif [ "$METHOD" = "DROP_PRF" ];then
 unset_presql=TRUE
 TITTLE="Drop sql profile $PRF_NAME"
 SQL=" execute dbms_sqltune.drop_sql_profile('$PRF_NAME',TRUE) ;"

# --------------------------------------------------------------------------
#   Create stored profile from v$sql using the profile of another SQL_ID
# --------------------------------------------------------------------------
elif [ "$METHOD" = "CR_STORED_PROF2" ];then
set -x
 TITTLE="Transfer execution plan from $SQL_ID_O to $SQL_ID_T"
 unset_presql=TRUE
 if [ -z "$SQL_ID_O" ];then
     echo "I need a source SQL_ID : use -so <SQL_ID> "
     exit
 fi
 SQL_ID_O=`get_sql_id $SQL_ID_O`
 if [ -z "$SQL_ID_T" ];then
     echo "I need a target SQL_ID : use -st <SQL_ID> "
     exit
 fi
 SQL_ID_T=`get_sql_id $SQL_ID_T`

  if [ -z "$PLAN_HASH_VALUE" ];then
     echo "I need a plan value : -pv <plan hash value to set>"
     echo "It is the one used by -so <sql_id> "
     exit
  fi
 if [ -n "$CHILD_O" ]; then
     SQL_ID_O=`get_sql_id $SQL_ID_O`
     if [ -z "$CHILD_O" ];then
        CHILD_O=`get_sql_id_first_child $SQL_ID_O`
     fi
     AND_CHILD_O=" and child_number = $CHILD_O " 
 fi
# if [ -n "$CHILD_T" ]; then
#     SQL_ID_T=`get_sql_id $SQL_ID_T`
#     if [ -z "$CHILD_T" ];then
#            CHILD_T=`get_sql_id_first_child $SQL_ID_T`
#     fi
#     AND_CHILD_T=" and child_number = $CHILD_T " 
# fi
     SQL=" declare
    ar_profile_hints sys.sqlprof_attr;
    cl_sql_text clob;
begin

   select extractvalue(value(d), '/hint') as outline_hints
          bulk collect into ar_profile_hints
   from xmltable('/*/outline_data/hint' passing(
                 select xmltype(other_xml) as xmlval
                 from v\$sql_plan where sql_id = '$SQL_ID_O' $AND_CHILD_O
                 and plan_hash_value=${PLAN_HASH_VALUE} and other_xml is not null and rownum = 1
            ) ) d;

   select sql_fulltext into cl_sql_text from
          v\$sql where sql_id = '$SQL_ID_T' $AND_CHILD_T and rownum=1  ;

   dbms_sqltune.import_sql_profile(
            sql_text     =>  cl_sql_text ,
            profile      =>  ar_profile_hints ,
            category     => '$CATEGORY',
            name         => 'PROFILE_$SQL_ID_T',
            force_match  =>  true );
end;
/
"

# --------------------------------------------------------------------------
#
#            Create stored profile from v$sql
#
# -- all this is based on Randolf Geist original blog. it is now found
# -- all over the net under various form
# --------------------------------------------------------------------------
elif [ "$METHOD" = "CR_STORED_PROF" ];then
     SQL_ID=`get_sql_id $SQL_ID`
     if [ -z "$CHILD" ];then
            CHILD=`get_sql_id_first_child $SQL_ID`
     fi
     AND_CHILD=" and child_number = $CHILD"
     SQL="
declare
    ar_profile_hints sys.sqlprof_attr;
    cl_sql_text clob;
begin

   select extractvalue(value(d), '/hint') as outline_hints
          bulk collect into ar_profile_hints
   from xmltable('/*/outline_data/hint' passing (
           select xmltype(other_xml) as xmlval
           from v\$sql_plan where
           sql_id = '$SQL_ID' $AND_CHILD and other_xml is not null)) d;

   select sql_fulltext into cl_sql_text from
          v\$sql where sql_id = '$SQL_ID' and rownum=1  ;

   dbms_sqltune.import_sql_profile(
            sql_text     =>  cl_sql_text ,
            profile      =>  ar_profile_hints ,
            category     => '$CATEGORY',
            name         => 'PROFILE_$SQL_ID',
            force_match  =>  true );
end;
/
"
# --------------------------------------------------------------------------
#  List SQL with differents plans
# --------------------------------------------------------------------------
elif [ "$METHOD" = "LIST_DIFF_PLAN" ];then
unset_presql=TRUE
SQL="
col PARSING_SCHEMA_NAME for a24
col child_number for 9999 head 'chld'
col executions head 'Execs'
col elapsed_per_exec head 'Elapsed|per exec'
col buffer_gets head gets
break on sql_id on plan_hash_value on report

select distinct a.PARSING_SCHEMA_NAME, a.sql_id, a.child_number,
       a.plan_hash_value, a.executions,
       a.buffer_gets,
       round(a.elapsed_time/1000000,2) "elapsed_sec",
       round((a.elapsed_time/1000000)/a.executions,2) "elapsed_per_exec",
       a.OPTIMIZER_COST cost
from v\$sql a, v\$sql b
    where a.executions> 0 and a.sql_id = b.sql_id and a.plan_hash_value != b.plan_hash_value
    order by a.sql_id, a.child_number
/
"
# --------------------------------------------------------------------------
# Show SQL optimizer enviromentment
# --------------------------------------------------------------------------
elif [ "$METHOD" = "STEPS" ];then

# a very interresting attempt to demonstrate executions steps. this takes in a account
# the last discussion on bushy tree plan whichd do not follow the deep left trees rule.
# Copyright 2010 Iggy Fernandez : http://iggyfernandez.wordpress.com/2010/11/26/explaining-the-explain-plan-using-pictures/
SQL_ID=`get_sql_id $SQL_ID`
if [ -z "$CHILD" ];then
   echo "No child given, retrieving from DB first child"
   RET=`get_sql_id_first_child $SQL_ID`
   CHILD=`echo "$RET" | tr -d '\n' | tr -d '\r' | awk '{print $1}'`
fi
CHILD=${CHILD:-0}
SQL="
SET linesize 1000 pagesize 0 echo off feedback off  verify off
SET time off timing off sqlblanklines on
col EXECUTION_SEQUENCE#  for 999 head 'Step'
col FID form a5 head 'Id in|plan' justify c
col line form a140
--------------------------------------------------------------------------------
-- First retrieve the basic data from V$SQL_PLAN_STATISTICS_ALL.
-- Modify this subquery if you want data from a different source.
--------------------------------------------------------------------------------
WITH plan_table AS
(
  SELECT
    id, parent_id, object_name, operation, options, last_starts,
    last_elapsed_time / 1000000 AS last_elapsed_time, cardinality,
    last_output_rows, last_cr_buffer_gets + last_cu_buffer_gets AS last_buffer_gets,
    last_disk_reads
  FROM
    v\$sql_plan_statistics_all
  WHERE
    sql_id = '$SQL_ID'
    AND child_number = '$CHILD'
),
--------------------------------------------------------------------------------
-- Determine the order in which steps are actually executed
--------------------------------------------------------------------------------
execution_sequence AS
(
  SELECT
    id,
    ROWNUM AS execution_sequence#
  FROM
    plan_table pt1
  START WITH
    -- Start with the leaf nodes
    NOT EXISTS (
      SELECT *
      FROM plan_table pt2
      WHERE pt2.parent_id = pt1.id
    )
  CONNECT BY
    -- Connect to the parent node
    pt1.id = PRIOR pt1.parent_id
    -- if the prior node was the oldest sibling
    AND PRIOR pt1.id >= ALL(
      SELECT pt2.id
      FROM plan_table pt2
      WHERE pt2.parent_id = pt1.id
    )
  -- Process the leaf nodes from left to right
  ORDER SIBLINGS BY pt1.id
),
--------------------------------------------------------------------------------
-- Calculate deltas for elapsed time, buffer gets, and disk reads
--------------------------------------------------------------------------------
deltas AS
(
  SELECT
    t1.id,
    t1.last_elapsed_time - NVL(SUM(t2.last_elapsed_time),0) AS delta_elapsed_time,
    t1.last_buffer_gets - NVL(SUM(t2.last_buffer_gets),0) AS delta_buffer_gets,
    t1.last_disk_reads - NVL(SUM(t2.last_disk_reads),0) AS delta_disk_reads
  FROM
    plan_table t1
    LEFT OUTER JOIN plan_table t2
    ON t1.id = t2.parent_id
  GROUP BY
    t1.id,
    t1.last_elapsed_time,
    t1.last_buffer_gets,
    t1.last_disk_reads
),
--------------------------------------------------------------------------------
-- Join the results of the previous subqueries
--------------------------------------------------------------------------------
enhanced_plan_table AS
(
  SELECT -- Items from the plan_table subquery
    plan_table.id,
    plan_table.parent_id,
    plan_table.object_name,
    plan_table.operation,
    plan_table.options,
    plan_table.last_starts,
    plan_table.last_elapsed_time,
    plan_table.cardinality,
    plan_table.last_output_rows,
    plan_table.last_buffer_gets,
    plan_table.last_disk_reads,
    -- Items from the execution_sequence subquery
    execution_sequence.execution_sequence#,
    -- Items from the deltas subquery
    deltas.delta_elapsed_time,
    deltas.delta_buffer_gets,
    deltas.delta_disk_reads,
    -- Computed percentages
    CASE
      WHEN (SUM(deltas.delta_elapsed_time) OVER () = 0)
      THEN (100)
      ELSE (100 * deltas.delta_elapsed_time / SUM(deltas.delta_elapsed_time) OVER ())
    END AS delta_percentage_elapsed_time,
    CASE
      WHEN (SUM(deltas.delta_buffer_gets) OVER () = 0)
      THEN (100)
      ELSE (100 * deltas.delta_buffer_gets / SUM(deltas.delta_buffer_gets) OVER ())
    END AS delta_percentage_buffer_gets,
    CASE
      WHEN (SUM(deltas.delta_disk_reads) OVER () = 0)
      THEN (100)
      ELSE (100 * deltas.delta_disk_reads / SUM(deltas.delta_disk_reads) OVER ())
    END AS delta_percentage_disk_reads,
    CASE
      WHEN (SUM(deltas.delta_elapsed_time) OVER () = 0)
      THEN (100)
      ELSE (100 * plan_table.last_elapsed_time / SUM(deltas.delta_elapsed_time) OVER ())
    END AS last_percentage_elapsed_time,
    CASE
      WHEN (SUM(deltas.delta_buffer_gets) OVER () = 0)
      THEN (100)
      ELSE (100 * plan_table.last_buffer_gets / SUM(deltas.delta_buffer_gets) OVER ())
    END AS last_percentage_buffer_gets,
    CASE
      WHEN (SUM(deltas.delta_disk_reads) OVER () = 0)
      THEN (100)
      ELSE (100 * plan_table.last_disk_reads / SUM(deltas.delta_disk_reads) OVER ())
    END AS last_percentage_disk_reads
  FROM
    plan_table,
    execution_sequence,
    deltas
  WHERE
    plan_table.id = execution_sequence.id
    AND plan_table.id = deltas.id
  -- Order the results for cosmetic purposes
  ORDER BY plan_table.id
)
--------------------------------------------------------------------------------
-- Begin THE graph
--------------------------------------------------------------------------------
SELECT distinct
   execution_sequence#,'('||id||')' fid, ' '
  -- Line 2: Operations, options, object name, and starts
  || operation
  || CASE
       WHEN (options IS NULL)
       THEN ('')
       ELSE (' ' || options)
     END
  || CASE
       WHEN (object_name IS NULL)
       THEN ('')
       ELSE (' ' || object_name)
     END
  || CASE
       WHEN (last_starts > 1)
       THEN (' (Starts= ' || last_starts || ')')
       ELSE ('')
     END
  -- Line 3: Delta elapsed time and cumulative elapsed time
  || ' Ela= '
  || CASE
       WHEN (delta_elapsed_time IS NULL)
       THEN ('0')
       ELSE (TRIM(TO_CHAR(delta_elapsed_time, '999,999,990.00')) || 's')
     END
  || ' ('
  || CASE
       WHEN (delta_percentage_elapsed_time IS NULL)
       THEN ('0')
       ELSE (TRIM(TO_CHAR(delta_percentage_elapsed_time, '990')) || '%')
     END
  || ')'
  || ' C.Ela='
  || CASE
       WHEN (last_elapsed_time IS NULL)
       THEN ('0')
       ELSE (TRIM(TO_CHAR(last_elapsed_time, '999,999,990.00')) || 's')
     END
  || ' ('
  || CASE
       WHEN (last_percentage_elapsed_time IS NULL)
       THEN ('0')
       ELSE (TRIM(TO_CHAR(last_percentage_elapsed_time, '990')) || '%')
     END
  || ')'
  -- Line 4: Delta buffer gets and cumulative buffer gets
  || ' Gets='
  || CASE
       WHEN (delta_buffer_gets IS NULL)
       THEN ('0')
       ELSE (TRIM(TO_CHAR(delta_buffer_gets, '999,999,999,999,990')))
     END
  || ' ('
  || CASE
       WHEN (delta_percentage_buffer_gets IS NULL)
       THEN ('0')
       ELSE (TRIM(TO_CHAR(delta_percentage_buffer_gets, '990')) || '%')
     END
  || ')'
  || ' C.Gets='
  || CASE
       WHEN (last_buffer_gets IS NULL)
       THEN ('0')
       ELSE (TRIM(TO_CHAR(last_buffer_gets, '999,999,999,999,990')))
     END
  || ' ('
  || CASE
       WHEN (last_percentage_buffer_gets IS NULL)
       THEN ('0')
       ELSE (TRIM(TO_CHAR(last_percentage_buffer_gets, '990')) || '%')
     END
  || ')'
  -- Line 5: Delta disk reads and cumulative disk reads
  || ' Dsk Reads='
  || CASE
       WHEN (delta_disk_reads IS NULL)
       THEN ('0')
       ELSE (TRIM(TO_CHAR(delta_disk_reads, '999,999,999,999,990')))
     END
  || ' ('
  || CASE
       WHEN (delta_percentage_disk_reads IS NULL)
       THEN ('0')
       ELSE (TRIM(TO_CHAR(delta_percentage_disk_reads, '990')) || '%')
     END
  || ')'
  || ' C.Dsk Reads='
  || CASE
       WHEN (last_disk_reads IS NULL)
       THEN ('0')
       ELSE (TRIM(TO_CHAR(last_disk_reads, '999,999,999,999,990')))
      END
  || ' ('
  || CASE
       WHEN (last_percentage_disk_reads IS NULL)
        THEN ('0')
       ELSE (TRIM(TO_CHAR(last_percentage_disk_reads, '990')) || '%')
     END
  || ')'
  -- Line 6: Estimated rows and actual rows
  || 'E Rows='
  || CASE
       WHEN (cardinality IS NULL)
       THEN '0'
       ELSE (TRIM(TO_CHAR(cardinality, '999,999,999,999,990')))
     END
  || ' A Rows='
  || CASE
       WHEN (last_output_rows IS NULL)
       THEN '0'
       ELSE (TRIM(TO_CHAR(last_output_rows, '999,999,999,999,990')))
     END
   AS line
FROM enhanced_plan_table
-- START WITH parent_id = 0
-- CONNECT BY parent_id = PRIOR id
order  by execution_sequence#
/
"
# --------------------------------------------------------------------------
# Show SQL optimizer enviromentment
# --------------------------------------------------------------------------
elif [ "$METHOD" = "OPTIM_ENV" ];then
unset_presql=TRUE
SQL_ID=`get_sql_id $HASH_VALUE`
SQL="COLUMN CN FORMAT 99
col name for a45
col value for a25
SET PAGESIZE 1000 lines 190
break on sql_id on report

SELECT
  SQL_ID, CHILD_NUMBER CN, SUBSTR(NAME,1,45) NAME, SUBSTR(VALUE,1,25) VALUE, ISDEFAULT DEF
FROM
  V\$SQL_OPTIMIZER_ENV
WHERE
  SQL_ID='$SQL_ID' AND CHILD_NUMBER=0
ORDER BY
  NAME;
"
# --------------------------------------------------------------------------
# Explain a SQL statements  with execution profile from library cache
# --------------------------------------------------------------------------
elif [ "$METHOD" = "XMS" ];then
   if  [ -z "$SQL_CHILD" ];then
       SQL_CHILD=%
   fi
   if [ "$SQL_CHILD" = "%" ];then
      AND_SQL_CHILD="  and to_char(p.child_number) like '%' "
   else
      AND_SQL_CHILD="  and p.child_number = $SQL_CHILD "
   fi
   if [ "$PART_START_STOP" = "TRUE" ];then
       P_START="p.PARTITION_START, p.partition_stop"
   else
      P_COST="p.io_cost io_cost,
             case
                  when ps.last_disk_writes > 1048576 then lpad(to_char(round(ps.last_disk_writes/1048576,1)),6,' ')||'m'
                  else lpad(to_char(ps.last_disk_writes),7,' ')
             end  last_disk_writes"
   fi
#-------------------------------------------------------------------------------------
#-- File name:   xmsh (eXplain from Memory with Statistics lookup by Hash value)
#-- Author:      Tanel Poder
# Copyright of Mr. Tanel suppressed for this query is identical to Breitling's one
# found in this is same script but comes 3 years later (see sx -vl) .
# The output is though more candy.  adapted to smenu by bpa
#-------------------------------------------------------------------------------------

SQL="
set verify off heading off feedback off linesize 190 pagesize 5000 tab off heading on
column child_number     heading 'Ch|ld' format 99

column id           heading Op|ID format 999
column pred         heading Pr|ed format a2
column optimizer        heading Optimizer|Mode format a10
column plan_step        heading Operation for a43
column object_name      heading Object|Name for a28
column object_alias      heading Object|Alias for a14
column opt_cost     heading Optim|Cost for 999999
column opt_card     heading 'Estim.|rows' for a8 justify c
column cpu_cost             heading CPU|Cost for 999999
column io_cost              heading IO|Cost for 999999
column last_output_rows     heading ' Last exec|#rows|returned' for a10 justify c
column last_cr_buffer_gets  heading 'Consist|  gets' for a8
column last_cu_buffer_gets  heading 'Current|  gets' for a8
column last_disk_reads      heading 'Physic| reads' for a8
column last_disk_writes     heading ' Physic| writes' for a8
column last_elapsed_time_ms heading 'ms |spent' for 99990.99 justify c
col partition_stop head 'Part|Stop' for a5
col partition_start head 'Part|Start' for a5

break on child_number   skip 1
select  --+ ordered use_nl(p ps)
    p.child_number      child_number,
    case when p.access_predicates is not null then 'A' else ' ' end ||
    case when p.filter_predicates is not null then 'F' else ' ' end pred,
    p.id        id,
    lpad(' ',p.depth*1,' ')|| p.operation || ' ' || p.options plan_step,
    p.object_name   object_name, object_alias,
    round(ps.last_elapsed_time/1000,2) last_elapsed_time_ms,
    p.cost  opt_cost,
    case
        when  p.cardinality > 1048576 then lpad(to_char(round(p.cardinality/1048576,1)),6,' ')||'m'
        else lpad(to_char(p.cardinality),7,' ')
        end opt_card,
    case
        when  ps.last_output_rows > 1048576 then lpad(to_char(round(ps.last_output_rows/1048576,1)),6,' ')||'m'
        else lpad(to_char(ps.last_output_rows),7,' ')
        end last_output_rows,
    case
        when ps.last_cr_buffer_gets > 1048576 then lpad(to_char(round(ps.last_cr_buffer_gets/1048576,1)),6,' ')||'m'
        else lpad(to_char(ps.last_cr_buffer_gets),7,' ')
    end last_cr_buffer_gets,
    case
        when ps.last_cu_buffer_gets > 1048576 then lpad(to_char(round(ps.last_cu_buffer_gets/1048576,1)),6,' ')||'m'
        else lpad(to_char(ps.last_cu_buffer_gets),7,' ')
    end last_cu_buffer_gets,
    case
        when ps.last_disk_reads > 1048576 then lpad(to_char(round(ps.last_disk_reads/1048576,1)),6,' ')||'m'
        else lpad(to_char(ps.last_disk_reads),7,' ')
    end  last_disk_reads , $P_COST $P_START
from
    v\$sql_plan p,
    v\$sql_plan_statistics ps
where
    p.address     = ps.address(+)
and p.hash_value  = ps.hash_value(+)
and p.id          = ps.operation_id(+)
and p.hash_value  = $HASH_VALUE $AND_SQL_CHILD
and p.child_number= ps.child_number (+)
order by
    p.child_number asc,
    p.id asc
/
prompt
set feedback on
"
# --------------------------------------------------------------------------
# --------------------------------------------------------------------------
# Explain a SQL statements  with execution profile from library cache
# --------------------------------------------------------------------------
elif [ "$METHOD" = "PXMS" ];then
SQL="
column id           heading Op|ID format 999
column output_rows     heading 'Actual|#rows|returned' for a10 justify c
column pred         heading Pr|ed format a2
column object_name      heading Object|Name for a30
column opt_cost     heading Optim|Cost for 999999
column opt_card     heading 'Estim.|rows' for a8 justify c
column disk_reads      heading 'Physic| reads' for a8
column last_disk_writes     heading ' Physic| writes' for a8
column estim_time heading 'estimated|time(ms)' for 9999990.99
col plan_partition_stop head 'Part|Stop' for a5
col plan_partition_start head 'Part|Start' for a5
column plan_step        heading Operation for a39

select  
    p.plan_line_id        id,
    lpad(' ',p.plan_depth*1,' ')|| p.plan_operation || ' ' || p.plan_options plan_step,
    p.plan_object_name   object_name,
    round(p.plan_time/10,2) estim_time,
    p.plan_cost  opt_cost, starts,
    case
        when  p.plan_cardinality > 1048576 then lpad(to_char(round(p.plan_cardinality/1048576,1)),6,' ')||'m'
        else lpad(to_char(p.plan_cardinality),7,' ')
        end opt_card,
    case
        when  p.output_rows > 1048576 then lpad(to_char(round(p.output_rows/1048576,1)),6,' ')||'m'
        else lpad(to_char(p.output_rows),7,' ')
        end output_rows,
    case
        when p.PHYSICAL_READ_REQUESTS > 1048576 then lpad(to_char(round(p.PHYSICAL_READ_REQUESTS/1048576,1)),6,' ')||'m'
        else lpad(to_char(p.PHYSICAL_READ_REQUESTS),7,' ')
    end  disk_reads , PLAN_PARTITION_START, PLAN_PARTITION_STOP
from
    v\$sql_plan_monitor p
where p.SQL_ID  = '$SQL_ID'
order by p.sql_id, p.SQL_EXEC_ID, p.plan_line_id ;
"
# --------------------------------------------------------------------------
# List type of operation in v$sql_plan
# --------------------------------------------------------------------------

elif [ "$METHOD" = "STRU" ];then
unset_presql=TRUE
SQL="
col ops format a40
select distinct ops, count(*) cpt from (select operation||' '||options ops
       from v\$sql_plan) group by ops ; "

# --------------------------------------------------------------------------
# List hash_value with $STRING in plan
# --------------------------------------------------------------------------

elif [ "$METHOD" = "STR" ];then
unset_presql=TRUE
SQL="
col operation format a40
set pagesize 66
select distinct a.hash_value, c.cost final_cost,a.id,
       a.operation ||' '|| a.options operation , b.id, b.operation||' '|| b.options operation
  from v\$sql_plan a , v\$sql_plan b, v\$sql_plan c
    where a.operation||' '||a.options like upper('%$STRING%') and
    a.hash_value=b.hash_value and
       a.child_number = b.child_number and
    c.hash_value=b.hash_value and
       c.child_number = b.child_number
       and c.id=0 and
       b.id = (a.id + 1)
;
"
# --------------------------------------------------------------------------
#  change HASH_VALUE for a given OT
# --------------------------------------------------------------------------
elif [ "$METHOD" = "CH_HV" ];then
unset_presql=TRUE
SQL="prompt Doing update outln.ol\$ set HASH_VALUE=$HASH_VALUE where ol_name = upper('$OT_NAME');;
update outln.ol\$ set HASH_VALUE=$HASH_VALUE where ol_name = upper('$OT_NAME');"

# --------------------------------------------------------------------------
# Display plan for given hash value and child numb
# --------------------------------------------------------------------------

elif [ "$METHOD" = "PL" ];then
SQL="
set verify off heading off feedback off linesize 210 pagesize 0 tab off heading on
column child_number     heading 'Ch|ld' format 99

column id           heading Op|ID format 999
column pred         heading Pr|ed format a2
column plan_step        heading Operation for a68
column object_name      heading Object|Name for a30
column opt_cost     heading Optim|Cost for 999999
column opt_card     heading 'Estim.|rows' for a8 justify c
column cpu_cost             heading CPU|Cost for 99999
column io_cost              heading IO|Cost for 99999
column last_output_rows     heading ' Last exec|#rows|returned' for a10 justify c
column last_cr_buffer_gets  heading 'Consist|  gets' for a8
column last_cu_buffer_gets  heading 'Current|  gets' for a8
column last_disk_reads      heading 'Physic| reads' for a8
column last_disk_writes     heading ' Physic| writes' for a8
column last_elapsed_time_ms heading 'ms spent' for 9999990.99
col partition_stop head 'Part|Stop' for a5
col partition_start head 'Part|Start' for a5
col sql_id noprint
break on sql_id  skip 1  on child_number on report
select  --+ ordered use_nl(p ps)
    p.sql_id, p.child_number ,
    case when p.access_predicates is not null then 'A' else ' ' end ||
    case when p.filter_predicates is not null then 'F' else ' ' end pred,
    p.id        id,
    lpad(' ',p.depth*1,' ')|| p.operation || ' ' || p.options plan_step,
       case when
        p.id=0 then
         '( sqlid => '||p.sql_id||' )'
    else
    p.object_name
    end  object_name,
    round(ps.last_elapsed_time/1000,2) last_elapsed_time_ms,
    p.cost  opt_cost,
    case
        when  p.cardinality > 1048576 then lpad(to_char(round(p.cardinality/1048576,1)),6,' ')||'m'
        else lpad(to_char(p.cardinality),7,' ')
        end opt_card,
    case
        when  ps.last_output_rows > 1048576 then lpad(to_char(round(ps.last_output_rows/1048576,1)),6,' ')||'m'
        else lpad(to_char(ps.last_output_rows),7,' ')
        end last_output_rows,
    case
        when ps.last_cr_buffer_gets > 1048576 then lpad(to_char(round(ps.last_cr_buffer_gets/1048576,1)),6,' ')||'m'
        else lpad(to_char(ps.last_cr_buffer_gets),7,' ')
    end last_cr_buffer_gets,
    case
        when ps.last_cu_buffer_gets > 1048576 then lpad(to_char(round(ps.last_cu_buffer_gets/1048576,1)),6,' ')||'m'
        else lpad(to_char(ps.last_cu_buffer_gets),7,' ')
    end last_cu_buffer_gets,
    case
        when ps.last_disk_reads > 1048576 then lpad(to_char(round(ps.last_disk_reads/1048576,1)),6,' ')||'m'
        else lpad(to_char(ps.last_disk_reads),7,' ')
    end  last_disk_reads,
    p.io_cost io_cost,
    ps.executions
    -- , case
    --     when ps.last_disk_writes > 1048576 then lpad(to_char(round(ps.last_disk_writes/1048576,1)),6,' ')||'m'
    --     else lpad(to_char(ps.last_disk_writes),7,' ')
    -- end last_disk_writes
from
    v\$sql_plan p,
    v\$sql_plan_statistics ps
where
    p.plan_hash_value  = $PLAN_HASH_VALUE
and p.address     = ps.address(+)
and p.hash_value  = ps.hash_value(+)
and p.id          = ps.operation_id(+)
and p.child_number= ps.child_number (+)
order by p.sql_id,
    p.child_number asc,
    p.id asc
/
prompt
set feedback on
"
  #-- $AND_SQL_CHILD -- $P_START
# --------------------------------------------------------------------------
# List type of operation in v$sql_plan
# --------------------------------------------------------------------------

elif [ "$METHOD" = "STRU" ];then
unset_presql=TRUE
SQL="
col ops format a40
select distinct ops, count(*) cpt from (select operation||' '||options ops
       from v\$sql_plan) group by ops ; "
# --------------------------------------------------------------------------
# List hash_value when a plan_hash_value is given
# --------------------------------------------------------------------------

elif [ "$METHOD" = "LPL" ];then
unset_presql=TRUE
SQL="col sql_text format a80
select a.hash_value, a.child_number, sql_id ,
   (select executions from v\$sql where hash_value=a.hash_value and child_number=a.child_number) executions,
   (select sql_text from v\$sql where hash_value=a.hash_value and child_number=a.child_number) sql_text
    from v\$sql_plan a where a.plan_hash_value = $PL_HV and id = 0;
"
# --------------------------------------------------------------------------
# List SQL from v$sql using outlines
# --------------------------------------------------------------------------

elif [ "$METHOD" = "CRF_OUTLN" ];then
   if [ ! -f "$SQLFILE" ];then
         echo " I need an sql file"
         exit
   fi
   if [ -n "$CATEGORY" ];then
      AND_CAT=" for category $CATEGORY "
   fi
   FTMP=$SBIN/tmp/cr_outln_$$.sql
   echo "create or replace outline $OT_NAME $AND_CAT on " > $FTMP
   cat $SQLFILE |sed '/^$/d' >> $FTMP
   tail -2 $FTMP | grep '/'
   if [ $? -eq 1 ];then
      echo "/" >> $FTMP
   fi
   echo "exit" >> $FTMP
   if [ -n "$F_USER" ];then
   S_USER=`echo $F_USER| tr '[a-z]' '[A-Z]'`
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
   fi

   sqlplus -s "$CONNECT_STRING" @$FTMP
   rm -f $FTMP
   exit


# --------------------------------------------------------------------------
# List SQL from v$sql using outlines
# --------------------------------------------------------------------------

elif [ "$METHOD" = "LIST_SQL_OUTLN" ];then
unset_presql=TRUE
SQL="col SQL_TEXT format a40
col OPTIMIZER_COST format 999999 head 'Opt|Cost'
col EXECUTIONS  head 'Execs'
col old_hash_value head 'Old hash|Value' justify c
col plan_hash_value head 'Plan hash|Value' justify c
select a.sql_id,a.hash_value,a.child_number,a.plan_hash_value, a.old_hash_value,
          a.EXECUTIONS,OPTIMIZER_COST,a.LAST_ACTIVE_TIME,substr(a.SQL_TEXT,1,40) sql_text
from v\$sql a
 where outline_category is not null ;
"

# --------------------------------------------------------------------------
# Change outlines position
# --------------------------------------------------------------------------

elif [ "$METHOD" = "CHG_POS" ];then
unset_presql=TRUE
SQL="
prompt doing : DBMS_OUTLN_EDIT.CHANGE_JOIN_POS ( '$OT_NAME', $OLD_POS , $NEW_POS);
exec DBMS_OUTLN_EDIT.CHANGE_JOIN_POS( '$OT_NAME', $OLD_POS , $NEW_POS);
"


# --------------------------------------------------------------------------
# Transfer outlines hints from one OTL to another
# --------------------------------------------------------------------------

elif [ "$METHOD" = "CP_OL" ];then
unset_presql=TRUE
    if [ -z "$SOURCE" ];then
       echo "I need a source outline name"
       exit
    else
       var=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off feed off pause off
select count(*) from $OLSCHEMA.OL\\$ where OL_NAME='$SOURCE';
exit
EOF`
       ret=`echo $var|tr -d '\r' |awk '{print $1}'`
       if [ ! $ret -eq 1 ];then
           echo "I do not find Source $SOURCE in $OLSCHEMA.OL\$"
           exit
       fi
    fi
    if [ -z "$TARGET" ];then
       echo "I need a target outline name"
       exit
    else
       var=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off feed off pause off
select count(*) from $OLSCHEMA.OL\\$ where OL_NAME='$TARGET';
exit
EOF`
       ret=`echo $var|tr -d '\r' |awk '{print $1}'`
       if [ ! $ret -eq 1 ];then
           echo "I do not find Target $TARGET in $OLSCHEMA.OL\$"
           exit
       fi
    fi
# a exchange of OL name is simpler but this destroy our source
# we want to transfer our source onto the target witout destroying the source
    sqlplus -s "$CONNECT_STRING" <<EOF
    set serveroutput on
    declare
     rec $OLSCHEMA.ol\$hints%rowtype ;
     cat varchar2(30);
    begin
       select CATEGORY into cat from $OLSCHEMA.OL\$ where OL_NAME='$SOURCE';
       --dbms_output.put_line('cat=' || rec.category);
       delete from $OLSCHEMA.ol\$hints where ol_name = '$TARGET' ;
       for r in (select * from $OLSCHEMA.OL\$HINTS where OL_NAME='$SOURCE')
       loop
          null ;
          rec:=r ;
          rec.ol_name:='$TARGET' ;
          rec.category:=cat ;
 dbms_output.put_line('ol_name='||rec.ol_name ||'   cat=' || rec.category);

          insert into $OLSCHEMA.ol\$hints values rec ;
       end loop ;
       commit ;
    end;
/

EOF
exit

# --------------------------------------------------------------------------
# Clear used outlines column in DBA_OUTLINES
# --------------------------------------------------------------------------

elif [ "$METHOD" = "CLEAN_USED" ];then
unset_presql=TRUE
   if [ -z "$OT_NAME" ];then
      echo "I need an outline name"
      exit
   fi
if $SBINS/yesno.sh "to clean USED column in DBA_OUTLINES for Outline $OT_NAME"
then
SQL="prompt doing exec dbms_outln.clear_used('$OT_NAME');
exec dbms_outln.clear_used('$OT_NAME');"
else
SQL='prompt clean cancelled'
fi

# --------------------------------------------------------------------------
# export outlines
# --------------------------------------------------------------------------

elif [ "$METHOD" = "EXP_STO" ];then
unset_presql=TRUE
SQL="exp / file=$SBIN/tmp/OL.dmp tables=('$OLSCHEMA.OL\$HINTS','$OLSCHEMA.OL\$NODES' ,'$OLSCHEMA.OL\$')"
$SQL
exit

# --------------------------------------------------------------------------
# Refresh outlines after changing a hints
# --------------------------------------------------------------------------

elif [ "$METHOD" = "REFRESH_OL" ];then
unset_presql=TRUE
SQL="
Prompt Doing : exec DBMS_OUTLN_EDIT.REFRESH_PRIVATE_OUTLINE ('$OT_NAME');
exec DBMS_OUTLN_EDIT.REFRESH_PRIVATE_OUTLINE ('$OT_NAME');
"

# --------------------------------------------------------------------------
# Clone outlines
# --------------------------------------------------------------------------

elif [ "$METHOD" = "CLONE" ];then
unset_presql=TRUE
  if [ -z "$OLD" ];then
       echo "I need the outlines names to clone"
       exit
  fi
  if [ -z "$NEW" ];then
       echo "I need a new outlines names for the  clone"
       exit
  fi
  if [ -n "$CATEGORY" ];then
       CAT=" alter session set create_stored_outlines = '$CATEGORY' "
  else
       unset CAT
  fi
  OLD=`echo $OLD | awk '{print toupper($1)}'`   # More porable than typset -u as this work also on cygwin
  NEW=`echo $NEW | awk '{print toupper($1)}'`   # More porable than typset -u as this work also on cygwin
SQL="$CAT
create or replace outline $NEW from $OLD ;
"

# --------------------------------------------------------------------------
# Drop one outline
# --------------------------------------------------------------------------

elif [ "$METHOD" = "DROPOL" ];then
unset_presql=TRUE
SQL="prompt doing drop outline $OT_NAME ;
drop outline $OT_NAME ;
"

# --------------------------------------------------------------------------
# Delete outlines category
# --------------------------------------------------------------------------

elif [ "$METHOD" = "DROPCAT" ];then
unset_presql=TRUE
echo
if $SBINS/yesno.sh "to drop all outlines for category : $CATEGORY"
then
SQL="
prompt exec dbms_outln.drop_by_cat('$CATEGORY');
exec dbms_outln.drop_by_cat('$CATEGORY');
"
else
SQL="prompt drop cancelled"
fi

# --------------------------------------------------------------------------
# List sql profiles
# --------------------------------------------------------------------------

elif [ "$METHOD" = "SQL_PROFILE" ];then
unset_presql=TRUE
TITTLE="List all sql profiles"
SQL="set long $FLEN
col LAST_MODIFIED for a28
col Name for a40
select NAME, LAST_MODIFIED,TYPE, STATUS, FORCE_MATCHING, SQL_TEXT from dba_sql_profiles order by LAST_MODIFIED desc;
"

# --------------------------------------------------------------------------
# List stored outlines hints
# --------------------------------------------------------------------------

elif [ "$METHOD" = "LIST_HINT" ];then
unset_presql=TRUE
  if [ -z "$OT_NAME" ];then
       echo "I need an Outlines name. Use sx -stl [-cat <CATEGORY> ] "
       exit
  fi
SQL="
 set linesize 190
 col hint_text format a50
col hint# format 9999
col stage# format 9999
col Table_pos format 9999 head 'Table|pos' justify c
col table_name format a24
 set long 32000
 select   HINT#, HINT_TEXT, STAGE# ,TABLE_NAME, TABLE_POS,round(COST,2) cost,CARDINALITY,bytes
           from $OLSCHEMA.ol\$HINTS where OL_NAME = '$OT_NAME' ;

"

# --------------------------------------------------------------------------
# List stored outlines
# --------------------------------------------------------------------------

elif [ "$METHOD" = "LIST_OUTLN" ];then
unset_presql=TRUE
  if [ -n "$CATEGORY" ];then
     AND_CAT=" AND a.category = upper('$CATEGORY') "
  fi
SQL="COLUMN name FORMAT A30
COLUMN category FORMAT A20
col owner format a14
set long 32000 linesize 150
set long 40
SELECT a.owner,a.name, a.category, a.enabled,a.used,b.hash_value, a.sql_text FROM dba_outlines a , $OLSCHEMA.ol\$ b
 where a.name = b.ol_name $AND_CAT;
"
# --------------------------------------------------------------------------
# Create stored outlines
# --------------------------------------------------------------------------

elif [ "$METHOD" = "CR_OUTLN" ];then
unset_presql=TRUE
SQL="
prompt exec  DBMS_OUTLN.create_outline( hash_value => $HASH_VALUE, child_number  => $CHILD, category => '$CATEGORY');

exec DBMS_OUTLN.create_outline( hash_value => $HASH_VALUE, child_number  => $CHILD, category => '$CATEGORY');
"

# --------------------------------------------------------------------------
# Performance v$sql_plan_statistics
# --------------------------------------------------------------------------

elif [ "$METHOD" = "VSTAT" ];then
var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off head off pagesize 0 termout off
select count(*) from v\\$sql where hash_value=$HASH_VALUE;
EOF`
ret=`echo "$var" | tr -d '\r' | awk '{print $1}'`
ret=`echo "$ret" |sed 's/[^0-9]*//g'`
echo "CHILD=$CHILD"
if [ -z "$ret" ];then
  echo "Currently, there is no entry in v\$sql for $HASH_VALUE"
  exit
elif [ "$ret" -eq "0" ];then
  echo "Currently, there is no entry in v\$sql for $HASH_VALUE"
  exit
elif [ "$ret" -eq "1" ];then
   #  there is only one child, we retrieve its number
   CHILD=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select min(child_number) from v\\$sql where hash_value=$HASH_VALUE ;
EOF`
elif [ "$ret" -gt "0"  -a -z "$CHILD" ];then
        echo " there are many sql child for this hash_values:"
        echo " Use  'sx -vs $HASH_VALUE -c <nn>'  to view stats and plan for one child\n"
        sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 66 head on
select child_number, executions from v\$sql where hash_value=$HASH_VALUE ;
EOF
        exit
fi
TITTLE="Explain plan and stats for $HASH_VALUE child:$CHILD"
    SQL="
set verify off echo off feed off
set linesize 190 pagesize 3000
col operation format a50
col card for 999,999,990 head 'Estimated|Card from|sql_plan'
col FROWS for 99,999,990 head '|Real avg|rows/exec|gotten '
col ELAPSED for 99,990.999
col CPU for 99990.999
col CR_GETS for 99,999,990
col CU_GETS for 99,999,990
col READS for 9,999,990
col WRITES for 99,990
col starts format 999
col fexecs new_value execs  noprint
-- whenever  sqlerror exit 1
select executions fexecs from v\$sql where hash_value = $HASH_VALUE and child_number=$CHILD;
prompt
-- at this stage exes may be null. we will use decode to avoid zero divisions
SELECT
        to_char(p.id,'990')||decode(access_predicates,null,null,'A') ||decode(filter_predicates,null,null,'F') id
       , P.COST cost
       , LPAD(' ',depth)||P.OPERATION||' '|| P.OPTIONS||' '|| P.OBJECT_NAME|| DECODE(P.PARTITION_START,NULL,' ',':')||
         TRANSLATE(P.PARTITION_START,'(NRUMBE','(NR')|| DECODE(P.PARTITION_STOP,NULL,' ','-')|| TRANSLATE(P.PARTITION_STOP,'(NRUMBE','(NR') operation
       , ( SELECT decode(&execs,0,0,(S.STARTS/&execs))
                  FROM V\$SQL_PLAN_STATISTICS S WHERE S.ADDRESS=P.ADDRESS and s.hash_value=p.hash_value
                        and s.child_number=p.child_number AND S.OPERATION_ID=P.ID) Starts
       , P.CARDINALITY card
       , ( SELECT S.OUTPUT_ROWS/&execs FROM V\$SQL_PLAN_STATISTICS S
                      WHERE S.ADDRESS=P.ADDRESS and s.hash_value=p.hash_value and s.child_number=p.child_number AND S.OPERATION_ID=P.ID) FROWS
       , ( SELECT decode(&execs,0,0,ROUND(S.ELAPSED_TIME/&execs/1000000,2)) FROM V\$SQL_PLAN_STATISTICS S
           WHERE S.ADDRESS=P.ADDRESS and s.hash_value=p.hash_value and s.child_number=p.child_number AND S.OPERATION_ID=P.ID) ELAPSED
       , (SELECT S.CR_BUFFER_GETS/&execs FROM V\$SQL_PLAN_STATISTICS S WHERE S.ADDRESS=P.ADDRESS and s.hash_value=p.hash_value
                 and s.child_number=p.child_number AND S.OPERATION_ID=P.ID) CR_GETS
       , (SELECT decode(&execs,0,0,S.CU_BUFFER_GETS/&execs) FROM V\$SQL_PLAN_STATISTICS S WHERE S.ADDRESS=P.ADDRESS and s.hash_value=p.hash_value
                and s.child_number=p.child_number AND S.OPERATION_ID=P.ID) CU_GETS
       , (SELECT decode(&execs,0,0,S.DISK_READS/&execs) FROM V\$SQL_PLAN_STATISTICS S WHERE S.ADDRESS=P.ADDRESS and s.hash_value=p.hash_value
          and s.child_number=p.child_number AND S.OPERATION_ID=P.ID) READS
       , (SELECT decode(&execs,0,0,S.DISK_WRITES/&execs) FROM V\$SQL_PLAN_STATISTICS S WHERE S.ADDRESS=P.ADDRESS and s.hash_value=p.hash_value
                 and s.child_number=p.child_number AND S.OPERATION_ID=P.ID) WRITES
FROM
    V\$SQL_PLAN P
where p.hash_value = $HASH_VALUE and p.child_number=$CHILD order by p.id
/
"
elif [ "$METHOD" = "VLAST" ];then
     check_HV_or_exit
#-------------------------------------------------------------------------------
#-- Purpose: format the plan and execution statistics from the dynamic
#-- performance views v$sql_plan and v$sql_plan_statistics
#--
#-- Copyright: (c)1996-2006 Centrex Consulting Corporation
#-- Author: Wolfgang Breitling
#--
#-- Usage One parameter: sql_hash_value
#--
#-------------------------------------------------------------------------------
     sqlplus -s "$CONNECT_STRING" <<EOF
set verify off echo off feed off
set linesize 190 pagesize 3000
col "cn" for 90 print
col operation format a50
col "card" for 999,999,990
col "ROWS" for 99,999,990
col "ELAPSED" for 99,990.999
col "CPU" for 99990.999
col CR_GETS for 99,999,990
col CU_GETS for 99,999,990
col READS for 9,999,990
col WRITES for 99,990
col pos format 999
break on "cn" skip 0
SELECT
        P.CHILD_NUMBER "cn"
       , to_char(p.id,'990')||decode(access_predicates,null,null,'A') ||decode(filter_predicates,null,null,'F') id
       , P.COST "cost"
       , P.CARDINALITY "card"
       , LPAD(' ',depth)||P.OPERATION||' '|| P.OPTIONS||' '|| P.OBJECT_NAME|| DECODE(P.PARTITION_START,NULL,' ',':')||
         TRANSLATE(P.PARTITION_START,'(NRUMBE','(NR')|| DECODE(P.PARTITION_STOP,NULL,' ','-')|| TRANSLATE(P.PARTITION_STOP,'(NRUMBE','(NR') "operation"
       , P.POSITION "pos"
       , ( SELECT S.LAST_OUTPUT_ROWS FROM V\$SQL_PLAN_STATISTICS S
                  WHERE S.ADDRESS=P.ADDRESS and s.hash_value=p.hash_value
                        and s.child_number=p.child_number AND S.OPERATION_ID=P.ID) "ROWS"
       , ( SELECT ROUND(S.LAST_ELAPSED_TIME/1000000,2) FROM V\$SQL_PLAN_STATISTICS S
           WHERE S.ADDRESS=P.ADDRESS and s.hash_value=p.hash_value and s.child_number=p.child_number AND S.OPERATION_ID=P.ID) "ELAPSED"
       , (SELECT S.LAST_CR_BUFFER_GETS FROM V\$SQL_PLAN_STATISTICS S WHERE S.ADDRESS=P.ADDRESS and s.hash_value=p.hash_value
                 and s.child_number=p.child_number AND S.OPERATION_ID=P.ID) "CR_GETS"
       , (SELECT S.LAST_CU_BUFFER_GETS FROM V\$SQL_PLAN_STATISTICS S WHERE S.ADDRESS=P.ADDRESS and s.hash_value=p.hash_value
                and s.child_number=p.child_number AND S.OPERATION_ID=P.ID) "CU_GETS"
       , (SELECT S.LAST_DISK_READS FROM V\$SQL_PLAN_STATISTICS S WHERE S.ADDRESS=P.ADDRESS and s.hash_value=p.hash_value
          and s.child_number=p.child_number AND S.OPERATION_ID=P.ID) "READS"
       , (SELECT S.LAST_DISK_WRITES FROM V\$SQL_PLAN_STATISTICS S WHERE S.ADDRESS=P.ADDRESS and s.hash_value=p.hash_value
                 and s.child_number=p.child_number AND S.OPERATION_ID=P.ID) "WRITES"
FROM
    V\$SQL_PLAN P
where p.hash_value = $HASH_VALUE
order by P.CHILD_NUMBER, p.id
/
EOF
exit
# --------------------------------------------------------------------------
# getting trace file
# --------------------------------------------------------------------------

elif [ "$METHOD" = "TRC" ];then
     var=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off feed off pause off
select value from v\\$parameter where name='user_dump_dest' ;
exit
EOF`
     FILE=$var/${ORACLE_SID}_ora_${TRC}.trc
     vi $FILE

# --------------------------------------------------------------------------
# set event and execute the file
# --------------------------------------------------------------------------

elif [ "$METHOD" = "FILE" ];then
     unset_presql=TRUE
     EV_ON="alter session set events '$EV_NUM trace name context forever, level $EV_LEVEL';"
     EV_OFF="alter session set events '$EV_NUM trace name context off';"
     SQL="$EV_ON
@$FFILE ;
$EV_OFF
-- set head off
-- select 'Session process is : ' ||b.spid from v\$session a, v\$process b
--        where a.sid =  sys_context('USERENV','SID') and a.paddr = b.addr;
"

# --------------------------------------------------------------------------
# Return the hash_value for a given sql_id
# --------------------------------------------------------------------------

elif [ "$METHOD" = "VI" ];then
   SQL="select hash_Value,child_number child from v\$sql where sql_id = '$SQL_ID';"

# --------------------------------------------------------------------------
# Return the sql_id for a given hash_value
# --------------------------------------------------------------------------

elif [ "$METHOD" = "VH" ];then
   TITTLE="List bind variable value for hash_value $HASH_VALUE";
   SQL="select sql_id, hash_Value,child_number child from v\$sql where hash_value = $HASH_VALUE;"

# --------------------------------------------------------------------------
# Return the binds associated to a given sql_id
# --------------------------------------------------------------------------

elif [ "$METHOD" = "BIND" ];then
  if [ -z "$SQL_ID" ];then
     SQL_ID=`get_sql_id $HASH_VALUE`
  fi
  SQL="col value_string format a30
      col name format A25 head 'Bind name'
      select child_number child,name, position, datatype, value_string,
             to_char(last_captured,'DD-MM HH24:MI:SS') capture_date
      from v\$sql_bind_capture
      where SQL_ID = '$SQL_ID' order by child_number,position
/
"

# --------------------------------------------------------------------------
# Explain plan using 10g dbms_xplan
# --------------------------------------------------------------------------

elif [ "$METHOD" = "DBMS" ];then
  if [ -n "${SQL_ID%%*[a-z]*}" ];then
     SQL_ID=`get_sql_id $SQL_ID`
  fi
  if [ -z "$CHILD" ];then
      echo "no child given, Retrieving first one"
      CHILD=`get_sql_id_first_child $SQL_ID`
      if [ -z "$CHILD" ];then
           CHILD=0
      fi
  fi
  SQL="SELECT * FROM table(DBMS_XPLAN.DISPLAY_CURSOR('$SQL_ID',$CHILD,'$FORMAT'));"
# --------------------------------------------------------------------------
# List plans with full
# --------------------------------------------------------------------------

elif [ "$METHOD" = "LIST_FULL_PL" ];then

  unset_presql=TRUE
  if [ -n "$F_USER" ];then
    AND_A_OWNER=" and a.object_owner = upper('$F_USER') "
  fi
  N_COST=${N_COST:-150}
  ORDER_VAR=${ORDER_VAR:-a.cost}
  if [ -n "$N_CARD" ];then
     ORDER_VAR=a.cardinality
     COST_OR_CARD=" a.cardinality > $N_CARD "
  else
     COST_OR_CARD=" a.cost > $N_COST "
  fi
  V_PLAN="v\$sql_plan"
  if [ "$LFS" = "TRUE" ]; then
       V_PLAN="v\$sql_plan_statistics_all"
       if [ -n "$N_CARD" ];then
          COST_OR_CARD=" a.output_rows > $N_CARD "
          ORDER_VAR=a.output_rows
       fi
  fi
  FORMAT=${FORMAT:-TYPICAL}
SQL="
set serveroutput on
set long 32000 trimspool on line 1024 longchunksize 32000
  set head off
declare
  type tt is table of varchar2(250) index by binary_integer;
  ret tt;
  cmd varchar2(100);
  format varchar2(60):='$FORMAT';
begin
  for c in ( select distinct * from (
                    select  a.sql_id, a.CHILD_NUMBER
                           from
                             $V_PLAN a,
                             v\$sql_plan_statistics_all b ,
                             v\$sql_plan_statistics_all c
                          where
                                 a.PLAN_HASH_VALUE =  b.PLAN_HASH_VALUE
                             and a.sql_id = b.sql_id
                             and a.child_number = b.child_number
                             and a.id = b.id
                             and a.PLAN_HASH_VALUE=  c.PLAN_HASH_VALUE (+)
                             and a.sql_id = c.sql_id and a.child_number = c.child_number
                             and c.id=0 $AND_A_OWNER
                             and a.options like  '%FULL%' and $COST_OR_CARD
                         order by $ORDER_VAR desc, sql_id, a.PLAN_HASH_VALUE
                         ) where rownum <= $ROWNUM )
  loop
    cmd:='SELECT * FROM table(DBMS_XPLAN.DISPLAY_CURSOR('''||c.sql_id||''', '''||to_char(c.child_number)||''','''||format||'''))' ;
    execute immediate cmd bulk collect into ret;
    for i in ret.first..ret.last
    loop
       dbms_output.put_line(ret(i)) ;
    end loop ;
       dbms_output.put_line(chr(10)||chr(10));
  end loop;
end;
/
"
# --------------------------------------------------------------------------
# List plans with full
# --------------------------------------------------------------------------

elif [ "$METHOD" = "LIST_FULL" ];then
  if [ -n "$F_USER" ];then
    AND_A_OWNER=" and a.object_owner = upper('$F_USER') "
  fi
  unset_presql=TRUE
  N_COST=${N_COST:-150}
  ORDER_VAR=${ORDER_VAR:-cost}
  if [ -n "$N_CARD" ];then
     ORDER_VAR=a.cardinality
     COST_OR_CARD=" a.cardinality > $N_CARD "
  else
     COST_OR_CARD=" a.cost > $N_COST "
  fi
  V_PLAN="v\$sql_plan"
  if [ "$LFS" = "TRUE" ]; then
       V_PLAN="v\$sql_plan_statistics_all"
       if [ -n "$N_CARD" ];then
          COST_OR_CARD=" a.output_rows > $N_CARD "
          ORDER_VAR=a.output_rows
       fi
  fi
  ROWNUM=${ROWNUM:-30}
  SQL="set lines 190 pages 66
     col PLAN_HASH_VALUE for 99999999999 head 'Plan hash |value' justify c
     col id for 999 head 'Id'
     col child for 99 head 'Ch|ld'
     col cost for 999999 head 'Oper|Cost'
     col tot_cost for 999999 head 'Plan|cost' justify c
     col est_car for 999999999 head 'Estimed| card' justify c
     col cur_car for 999999999 head 'Avg Curr| card' justify c
     col ACC for A3 head 'Acc|ess'
     col FIL for A3 head 'Fil|ter'
     col OTHER for A3 head 'Oth|er'
     col ope for a27 head 'Operation'
     col exec for 999999 head 'Execs'
     col OBJECT_NAME for a30 head 'Name'
     break on PLAN_HASH_VALUE on sql_id on child
    select * from (
     select
       a.PLAN_HASH_VALUE, a.id , a.sql_id, a.CHILD_NUMBER child , a.cost, c.cost tot_cost,
       a.cardinality est_car,  b.output_rows/decode(b.EXECUTIONS,0,1,b.EXECUTIONS) cur_car,
       b.EXECUTIONS exec,
       case when length(a.ACCESS_PREDICATES) > 0 then ' Y' else ' N' end ACC,
       case when length(a.FILTER_PREDICATES) > 0 then ' Y' else ' N' end FIL,
       case when length(a.projection) > 0 then ' Y' else ' N' end OTHER,
        a.operation||' '|| a.options ope, a.OBJECT_NAME
 from
    $V_PLAN a,
    v\$sql_plan_statistics_all b ,
    v\$sql_plan_statistics_all c
 where
        a.PLAN_HASH_VALUE =  b.PLAN_HASH_VALUE
    and a.sql_id = b.sql_id
    and a.child_number = b.child_number
    and a.id = b.id
    and a.PLAN_HASH_VALUE=  c.PLAN_HASH_VALUE (+)
    and a.sql_id = c.sql_id and a.child_number = c.child_number
    and c.id=0 $AND_A_OWNER
    and a.options like  '%FULL%' and $COST_OR_CARD
order by $ORDER_VAR desc, sql_id, PLAN_HASH_VALUE, id
) where rownum <= $ROWNUM
/
"
# --------------------------------------------------------------------------
# List plans
# --------------------------------------------------------------------------

elif [ "$METHOD" = "LIST_PLAN" ];then
    unset_presql=TRUE
    MAX_PLAN=${MAX_PLAN:-0}
    if [ -n "$AND_OWNER" ];then
        unset VAR_FIELD1
        VAR_FIELD2="s.rows_processed,s.elapsed_time/1000 elt,"
        FLEN=70
   else
        VAR_FIELD1="u.username, "
        FLEN=${FLEN:-50}
   fi
   if [ "$ORDER" = "time" ];then
       ORDER="  llt desc,"
       TITTLE="List plan by Last active query"
   elif [ "$ORDER" = "cost" ];then
       ORDER=" cost desc,"
       AND_COST=" and cost is not null"
       TITTLE="List plan by Cost"
   elif [ "$ORDER" = "disk_reads" ];then
       ORDER=" disk_reads desc ,"
       VAR_FIELD2="round(decode(s.executions,0,s.rows_processed,s.rows_processed/s.executions)) rows_processed,
                   round(decode(s.disk_reads,0,s.disk_reads,s.disk_reads/decode(s.executions,0,1,s.executions))) disk_reads,"
       FLEN=50
       if [ -z "$AND_OWNER" ];then
          FLEN=40
       fi
   elif [ "$ORDER" = "rows" ];then
       ORDER=" rows_processed desc ,"
       VAR_FIELD2="round(decode(s.executions,0,s.rows_processed,s.rows_processed/s.executions)) rows_processed,
                   round(decode(s.fetches,0,s.fetches,s.fetches/s.executions)) fetches,"
       FLEN=50
       if [ -z "$AND_OWNER" ];then
          FLEN=40
       fi
   elif [ "$ORDER" = "gets" ];then
       ORDER=" buffer_gets desc,"
       TITTLE="List plan by Buffer gets"
   fi
   SQL="set lines 190 pages 66
       break on username on phv on report
       col child head Ch for 99
       col cost for 99999 head 'Cost'
       col plan# head 'Nbr|plan' for 9999
       col phv head 'Plan | hash value' justify c for 9999999999
       col exec for 999999
       col buffer_gets head 'gets' for 999999990
       col rows_processed head 'rows per|Exec' for 999999990
       col fetches head 'Fetches|per Exec' for 999999990
       col disk_reads head 'Disk reads|per Exec' for 999999990
       col exc head 'Execs' for 9999990
       col elt head 'elapsed|time(ms)' for 9999990
       col llt head 'last time|active' justify c for a11
       col txt head 'Sql Text' for a${FLEN}

  select * from (
      select $VAR_FIELD1
             p.plan_hash_value phv ,
             substr(last_LOAD_TIME,6,11) llt,p.sql_id, p.child_number child,
            p.cost, s.executions exc, s.buffer_gets, $VAR_FIELD2
            count(p.sql_id) over ( partition by p.sql_id ) plan#,
             substr(sql_text,1,$FLEN) txt
       from v\$sql_plan p,v\$sql s,dba_users u
       where p.sql_id = s.sql_id and p.child_number = s.child_number
             and p.id=0
             and s.parsing_user_id = u.user_id $AND_OWNER  $AND_COST
     order by $ORDER p.sql_id, p.child_number
   )
    where plan# > $MAX_PLAN and rownum <$ROWNUM  ;"
# --------------------------------------------------------------------------
# plan
# --------------------------------------------------------------------------
elif [ "$METHOD" = "PLAN" ];then

SQL="col child_number noprint
SELECT    distinct id, parent_id, LPAD (' ', LEVEL - 1) || operation || ' ' ||
           options operation, cost ,cardinality,search_columns,object_node,object_name, child_number
FROM       (
           SELECT id, parent_id, operation, options, a.cost, cardinality,
                  search_columns, object_node, object_name, child_number
           FROM   v\$sql_plan a
           WHERE  a.HASH_VALUE = '$HASH_VALUE' $AND_A_CHILD_NUMBER)
START WITH id = 0
CONNECT BY PRIOR id = parent_id
order by child_number,id;
"
# --------------------------------------------------------------------------
elif [ "$METHOD" = "PLAN_SQL_ID" ];then
  if [ -n "${SQL_ID%%*[a-z]*}" ];then
     SQL_ID=`get_sql_id $SQL_ID`
  fi
SQL="SELECT   distinct  id, parent_id, LPAD (' ', LEVEL - 1) || operation || ' ' ||
           options operation, cost ,cardinality,search_columns,object_node,object_name
FROM       (
           SELECT id, parent_id, operation, options, cost, cardinality,search_columns, object_node,object_name
           FROM   v\$sql_plan
           WHERE  SQL_ID = '$SQL_ID' $AND_CHILD_NUMBER)
START WITH id = 0
CONNECT BY PRIOR id = parent_id
order by child_number;
"
# --------------------------------------------------------------------------
#  List Historical COlORED SQL_ID (and statements from dba_hist_sql_text)
# --------------------------------------------------------------------------
elif [ "$METHOD" = "COLOR_SQL_LIST" ];then
unset_presql=TRUE
TITTLE="list Colored SQL in AWR"
SQL="
col sql_id  for a14
col create_time head 'created'
col sql_text for a80  head 'Execs'

break on sql_id report

select c.create_time,c.sql_id, s.sql_text
  from dba_hist_colored_sql c, dba_hist_sqltext s
 where s.sql_id =c.sql_id
   and c.dbid = (select dbid from v\$database);
"

# --------------------------------------------------------------------------
#  ADD COLOR to  SQL_ID
# --------------------------------------------------------------------------
elif [ "$METHOD" = "COLOR_SQL_ADD" ];then
unset_presql=TRUE
TITTLE="Add Color from SQL in AWR"
SQL="
exec dbms_workload_repository.add_colored_sql('$SQL_ID');
col sql_id  for a14
col create_time head 'created'
col sql_text for a80  head 'Execs'

break on sql_id report

select c.create_time,c.sql_id, s.sql_text
  from dba_hist_colored_sql c, dba_hist_sqltext s
where s.sql_id=c.sql_id and s.sql_id='$SQL_ID' and c.sql_id='$SQL_ID'
  and c.create_time > sysdate - 1/24
  and c.dbid = (select dbid from v\$database);
"

# --------------------------------------------------------------------------
#  REMOVE COLOR from  SQL_ID
# --------------------------------------------------------------------------
elif [ "$METHOD" = "COLOR_SQL_REMOVE" ];then
unset_presql=TRUE
TITTLE="Remove Color from SQL in AWR"
SQL="
exec dbms_workload_repository.remove_colored_sql('$SQL_ID');
col sql_id  for a14
col create_time head 'created'
col sql_text for a80  head 'Execs'

break on sql_id report

select c.create_time,c.sql_id, s.sql_text
  from dba_hist_colored_sql c, dba_hist_sqltext s
 where s.sql_id=c.sql_id
   and s.sql_id='$SQL_ID'
   and c.sql_id='$SQL_ID'
   and c.dbid = (select dbid from v\$database);
"
# --------------------------------------------------------------------------
# predicates values
# --------------------------------------------------------------------------

elif [ "$METHOD" = "AC1" ];then
  SQL="select id,  object_name, operation ops,  'Access' type ,ACCESS_PREDICATES condition,cardinality,cost
            from v\$sql_plan
            where access_predicates is not null and object_name is not null and hash_value = $HASH_VALUE
    union
     select id, object_name, operation ops , 'Filter' type, FILTER_PREDICATES condition, cardinality, cost
            from v\$sql_plan
            where filter_predicates is not null and object_name is not null and hash_value = $HASH_VALUE $AND_CHILD_NUMBER
   order by id desc; "

fi
# --------------------------------------------------------------------------
#   End of if $METHOD
# --------------------------------------------------------------------------
if [ -n "$VERBOSE" ];then
   echo "$SQL"
fi
if [ "$unset_presql" = "FALSE" ];then
   if [ -z "${HASH_VALUE%%*[a-z]*}" ];then
     HASH_VALUE=`get_hash_value $SQL_ID`
   fi
   PRESQL="set head off
   select 'Total plans among childs: '|| count(1)|| '  First child with plan: '
             ||min(child_number) from v\$sql_plan where hash_value=$HASH_VALUE and id=0;
   set head on"
fi
sqlplus -s "$CONNECT_STRING" <<EOF
set pagesize 66 linesize 132 termout on pause off embedded on verify off heading off
select 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   ||chr(10) ||
'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER,15)  || '$TITTLE ' from sys.dual
/

break on task_name on command
set head on
COL task_name       FORMAT  A20 heading 'Task'
COL command         FORMAT  A19 heading 'Command'
COL tt              FORMAT  A80   HEADING 'Type'
COL rank noprint
COL id          FORMAT 999
COL parent_id   FORMAT 999 HEADING "PARENT"
COL operation   FORMAT a45 heading "Type of |Operations"
COL username   FORMAT a18 heading "Username"
COL SQL_Text   FORMAT a50 heading "Sql Text"
COL ops   FORMAT a12 head "Operation"
COL object_name FORMAT a22
COL ACCESS_PREDICATES FORMAT a35
COL FILTER_PREDICATES FORMAT a35
COL condition FORMAT a35
COL child_number FORMAT 99 heading "C|h|i|l|d"
COL object_node FORMAT a16
COL search_columns FORMAT 9999 head "Search| Cols"
col FIRST_LOAD_TIME format a19
col txt format a60
set pagesize 0 line 190
$PRESQL
$SQL
EOF
echo
#echo "ret=$?"

