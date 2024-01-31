#!/bin/ksh
# set -x
# Program  :  smenu_get_heavy_figures.ksh
# author   :  B. Polarski
# date     :  09 September 2005
# Modified :  21 September 2005 : Added join to V$process to enforce display of only active SQL with option -x
#             25 september 2006 : added -load option extracted from some work of Tim Gorman
#             04 October   2006 : added option -sp to load and the notion of family sql for sql without bind variables
#             28 May       2009 : Added option -n
#             29 November  2010 : add GV, -x renamed to -ses, help revisited. addded sqlid_to_hv
# default conditional fields
ROWNUM="where rownum <31"
ELP="ELAPSED_TIME/1000000 elp, "
ELP0="elp,"
ORDER=" "
TITLE='SQL Work area Usefull figures (Help: sq -h)'
HASH_OR_TEXT="sql_id,child_number,parsing_schema_name"
HT_PARSING=",parsing_schema_name"
HT_HEADER="sql_id,child_number"

F_TIME=" substr(LAST_LOAD_TIME,9) ltl"
#F_TIME=" LAST_LOAD_TIME ltl"
F_TIME_TITLE="Last time| Loaded"
# ----------------------------------------------------------------------------------------------------------------
function get_dbid {
  if [ -z "$AND_DBID" ];then
    ret=`sqlplus -s "$CONNECT_STRING" <<EOF
    set head off pagesize 0 feed off verify off
    select dbid from v\\$database ;
EOF`
  fi
 echo "$ret"
}
# ----------------------------------------------------------------------------------------------------------------
function sqlid_to_hv
{
. $SBIN/scripts/passwd.env
. ${GET_PASSWD}
if [  -z "$CONNECT_STRING"  ];then
      echo "could no get a the password of $S_USER"
      exit 0
fi
 ret=`sqlplus -s "$CONNECT_STRING" <<EOF
 set head off pagesize 0 feed off verify off
 select trunc(mod(sum((instr('0123456789abcdfghjkmnpqrstuvwxyz',substr(lower(trim('$SQL_ID')),level,1))-1)
        *power(32,length(trim('$SQL_ID'))-level)),power(2,32))) hash_value
     from dual connect by level <= length(trim('$SQL_ID'));
EOF`
 echo "$ret"
}
# ----------------------------------------------------------------------------------------------------------------
function get_sql_id
{
 if [ -z "$1" ] ;then
     # if sql_id is empty then try hash_value
     if [ -z "$HASH_VALUE" ];then
         VAR=$HASH_VALUE
     else
         echo "I need an SQL_ID or HASH_VALUE"
         exit
     fi
 else
   VAR="$1"
 fi
 if [ -z "${VAR%%*[a-z]*}" ];then
    # $1 is a mix
    echo "$1"
    return
 fi
 # $1 is a hash_value made of only digit
 ret=`sqlplus -s "$CONNECT_STRING" <<EOF
 set head off pagesize 0 feed off verify off
 select distinct sql_id from v\\$sql where hash_value = '$VAR';
EOF`
 echo "$ret"
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
 ret=`sqlid_to_hv $SQL_ID`
 echo "$ret"
}
# ----------------------------------------------------------------------------------------------------------------
function help
{
  cat <<EOF

    Miscelaneous SQL stats :


            sq -m [seconds] [-u <owner>]             #  list SQL that were active within last <seconds> on V\$SQL
            sq -d [seconds]                          #  Take a snapshot off all SQL run during <seconds> on V\$SQLSTATS
            sq -lm                                   #  list SQL  from v\$sql_monitor
            sq -lsb                                  #  List bind from v$\sql_monitor for the given session, default takes first session with this seql
            sq -lse                                   #  list sql_execute id
            sq -s <SQL_ID>                           #  Show stats for given sql_id
            sq -ex  <EXEC_ID>  -sid <sid> -col <var> #  report on sql exec id, use 'sq -lse' to display exec_id
            sq -si  <SQL_ID>                         #  list all data from v\$sql_monitor of a SQL_ID
            sq -fm                                   #  List queries with same force_matching_signature
            sq -top <nn> [-ngets <nn>]               #  List top active sql for the last <nn> secs, default sort, gets &  ngets=100
            sq -ses                                  #  List SQL that can be joined to sessions

            sq -hv <SQL_HASH_VALUE>                  #  see only stat for this sql, usefull if you are given only HV

            sq -pl                                   #  show sql with difference execution time
            sq -pv  [ -day <nn>]                     #  Show sql with execution speed variations, limit to last nn days, default is 1

            sq -eh <sqlid> [-d <DBID>]               #  List SQL Execution history correlated with DB events & waits  
            sq -ph <sqlid> [-d <DBID>]               #  List sql history executions plan and perfs  
            sq -pe <sqlid> [-d <DBID>]               #  List sql history events 
            sq -pb <sqlid> [-d <DBID>]               #  List binds mismatch reason for SQL
            sq -cmis        [-d <DBID>]              #  List SQL id with more thant 5 bind mismatch
            sq -mcount                               # List count of bind mistmatch and the reason

            sq -hd                                   #  List sql load sort by disk reads   :   Sql load from Ixora
            sq -hg                                   #  List sql load sort by disk gets    :   Sql load from Ixora
            sq -load -sp len <nn> -rn <nn>           #  SQL summary stats from v\$sqlarea 
                                                          -sp  : display a sample of this family hash_value 
                                                          -len : length of text used to build family
            sq -lprf                                 # List queries using SQL PROFILE
            sq -cpar                                 # List parallel chunk status from dbms_execute_parallel
            sq -bl_sid <SQL_ID> -b <snap> -e <snap>     # list sql_id into new base line, return the baseline
            sq -blp                                  # show baseline meta parameters
            sq -lbs -p <plan_name>                   # List baselines plan
             

           

                                             -------------------
                                             |      sq -l      |
                                             -------------------

   sort by :      -ob  : buffer_gets         -oc  : cpu               -or : disk_reads    -oe  : elapsed     -inv : invalidations
                 -pars :  parse calls        -ot  : last time loaded  -ox : executions    -ow  : rows   

    -g   : figures for all execs, not per execution                 -rn : Limit display to <nn> rows                      
    -ses : Limit to SQL that may be linked to active sessions        -v : Verbose
    -pk  : list session running PL/SQL package                    -text : Show sql_text rather than hash value
   -min  : limit to <nnn> disk reads/gets, default is 10 000       -len : <len text> 

                               example : sq -l | sq -l -ses   | sq -t -ses |  sq -d  |  sq -l -g
                                         sq -top -x -ngets 1000   # top sql with at least 1000 gets sorted by executions


EOF
exit
}
# ----------------------------------------------------------------------------------------------------------------
VARFIELD=SQL_TEXT
LEN_TEXT=50
if [ -z "$1" ];then
   help
fi
ACTION=DEFAULT
typeset -u fowner
while [ -n "$1" ]
do
      case $1 in
         -ob ) ORDER=" ORDER by buff desc"  ;;
         -oc ) ORDER=" ORDER by cpu desc" ; SORT_COL=elapsed;;
       -cpar ) ACTION=CPAR ;;
        -blp ) ACTION=BLP ;;
        -lbs ) ACTION=LIST_PLAN ;;
          -d ) ACTION=DIF_SEC ; SECONDS=$2 ; shift ;;
         -or ) ORDER=" ORDER by disk_reads desc" ; SORT_COL=reads ;;
         -ox ) ORDER=" ORDER by executions desc" ; SORT_COL=execs;;
         -col) COLNBR=$2; shift ;;
       -cmis ) ACTION=COUNT_MIS_BIND ;;
         -oe ) ORDER=" ORDER by elapsed_time desc" ; SORT_COL=elapsed;;
       -dbid ) DBID=$2 ; shift  ; AND_DBID=" and s.dbid='$DBID' " ;;
        -day ) days_ago=$2 ; shift ;;
         -ex ) ACTION=REPORT_EXEC_ID ; EXEC_ID=$2 shift ;;
         -fm ) ACTION=FORCE_MATCHING ;;
          -g ) TOT_G=TRUE ;;
         -hd ) ACTION=HEAVY ; FIELD=disk_reads; FIELD1=buffer_gets;;
         -hg ) ACTION=HEAVY ; FIELD=buffer_gets ; FIELD1=disk_reads;;
         -hv ) WHERE=" where 1=1 " ; HV=`get_hash_value $2`
               FILTER1="  and hash_value = $HV " ; unset ELP ; unset ELP0 ;;
        -inv ) ORDER=" ORDER by invalidations desc" ; unset ELP ; unset ELP0;;
          -l ) ACTION=DEFAULT ;;
        -len ) LEN_TEXT=$2; shift ; GROUP_BY="substr(sql_text, 1, $LEN_TEXT)" ;;
         -lb ) ACTION=LOAD_SQID ;;
        -lsb ) ACTION=MONITOR_BIND ;;
         -bl_sid ) ACTION=LOAD_BASELINE ;;
        -lse ) ACTION=MONITOR_OVERVIEW; LIST_EXEC_ID=TRUE ;;
         -lm ) ACTION=MONITOR_OVERVIEW ;;
       -load ) ACTION=LOAD ; GROUP_BY="substr(sql_text, 1, $LEN_TEXT)" ;;
       -lprf ) ACTION=LPRF ;;
        -min ) MIN_PRES=$2;shift;;
          -m ) ACTION=LAST_SQL;
               if [ -n "$2" -a "$2" = ${2#-} ];then
                    LAST_SEC=$2; shift
                fi;;
       -mcount) ACTION=MCOUNT ;;
       -ngets) NGETS=$2; shift ;;
         -p  ) PLAN_NAME=$2; shift ;;
       -pars ) ORDER=" ORDER by parse_calls desc" ; unset ELP ; unset ELP0;;
         -pl ) ACTION=UNSTABLE ;;
         -pv ) ACTION=EXEC_VAR_SPEED ;;
         -pb ) ACTION=MIS_BIND;
               if [ -z "$2" ];then
                   echo "I need an sql id"
                   exit
               fi
               SQL_ID=$2; shift ;;
         -pe ) ACTION=PLE ;
               if [ -z "$2" ];then
                   echo "I need an sql id"
                   exit
               fi
               SQL_ID=$2; shift;;
         -ph ) ACTION=PLH ;
               if [ -z "$2" ];then
                   echo "I need an sql id"
                   exit
               fi
               SQL_ID=$2; shift;;
          -eh ) ACTION=ELH ;
               if [ -z "$2" ];then
                   echo "I need an sql id"
                   exit
               fi
               SQL_ID=$2; shift;;
         -pk ) ACTION=PLSQL ;;
         -rac) G=g; INST_ID=inst_id, ;;
         -rn ) ROWNUM="where rownum <=$2" ; NROWNUM=$2 ; shift ;;
       -text ) HASH_OR_TEXT=sql_text ; HT_HEADER=SQL_TEXT; unset HT_PARSING;;
         -ot ) ORDER=" ORDER by last_load_time desc" ; FILTER=" and LAST_LOAD_TIME is not null" 
               WHERE=" where 1=1 " ; TITLE="Sort by last time loaded" ;;
        -top ) ACTION=TOP ; NBR_SECS=$2; shift ;;
        -ses ) JOIN_TO_SESS=TRUE;;
        -ss  ) WHERE=" where sql_id='$2' " 
                HASH_OR_TEXT="sql_id,child_number,parsing_schema_name"
                shift;;
         -si ) ACTION=MONITOR_SI ; SQL_ID=$2 ; shift ;;
        -sid ) SID=$2 : shift ;;
         -sp ) FAMILLY=TRUE;;
          -ow ) ORDER=" ORDER by rows_processed desc" ;;
          -u ) fowner=$2 ; FILTERN=" and PARSING_SCHEMA_NAME = upper('$2') " 
               shift ; WHERE=" where 1=1 " ;;
          -h ) help ;;
          -b ) SNAP_BEG=$2; shift ;;
          -e ) SNAP_END=$2; shift ;;
          -v ) SETXV="set -xv";;
            *) SINGLE_SID=" and s.sid = '$1' " ;;
        esac
        shift
done
if [ -z "$ACTION" ];then
      ACTION="DEFAULT"
fi
if [ "$JOIN_TO_SESS" = "TRUE" ];then
         JOIN_TO_SESS="  , sys.${G}v_\$session b, sys.${G}v_\$process c " ; WHERE=" where 1=1 " ;
         HASH_OR_TEXT="b.sql_id,child_number,parsing_schema_name"
         FILTER1=" and (hash_value = sql_hash_value or hash_value = prev_hash_value) and b.paddr = c.addr" ; SID="sid,"
fi
if [ "$HASH_OR_TEXT" = "sql_text" ];then
      HASH_OR_TEXT="substr(sql_text, 1, $LEN_TEXT) sql_text"
fi
if [ "$FAMILLY" = "TRUE" ];then
     VARFIELD="upper(substr(replace(replace(replace(replace(sql_text,' ',''),',',''),'\"',''),'*',''),1,$LEN_TEXT)) family,family_hv"
     GROUP_BY="upper(substr(replace(replace(replace(replace(sql_text,' ',''),',',''),'\"',''),'*',''),1,$LEN_TEXT)),substr(sql_text,1,$LEN_TEXT)"
fi
if [ -n "$WHERE" ];then
   if [ -n "$FILTER" -a -n "$FILTER1" ];then
      if [ -n "$JOIN_TO_SESS" ];then
         # if we linked -x and -t then we want the sql active and use last_call_et from v$session
         F_TIME="to_char(b.last_call_et) ltl"
         F_TIME_TITLE="Sql run|Since(sec) "
      fi
   fi
   ADD_WHERE="${WHERE}$FILTER$FILTERN"
fi
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SBINS=$SBIN/scripts

if [ "$TOT_G" = TRUE ];then
        TITLE="sum gets and rows for all executions"
        BUF_GET="BUFFER_GETS buff, "
        ROW_PROC="ROWS_PROCESSED rp,"
        ROW_PROC_TITLE="Total |Rows"
        BUF_GET_TITLE=" Total|Buff Gets"
else
        TITLE="Sql stats per execution"
        BUF_GET="BUFFER_GETS/decode(executions,0,1,executions) buff, "
        ROW_PROC="ROWS_PROCESSED/decode(executions,0,1,executions) rp,"
        ROW_PROC_TITLE="Rows per|Exec"
        BUF_GET_TITLE="Buff Gets|Per Exec"
fi

. $SBIN/scripts/passwd.env
. ${GET_PASSWD}
if [  -z "$CONNECT_STRING"  ];then
      echo "could no get a the password of $S_USER"
      exit 0
fi

# ----------------------------------------------------------------------------
if [ "$ACTION" = "LIST_PLAN" ];then
  if [ -n "$PLAN_NAME" ];then
     AND_LIKE=" and SQL_HANDLE like upper('%$PLAN_NAME%') "
  fi
SQL="
set feed on
COLUMN sql_handle FORMAT A20
COLUMN plan_name FORMAT A30

SELECT sql_handle, plan_name, enabled, accepted 
FROM   dba_sql_plan_baselines
WHERE   1=1 $AND_LIKE
order by 1
/
"
# ----------------------------------------------------------------------------
elif [ "$ACTION" = "BLP" ];then
SQL="
COLUMN parameter_name FORMAT A25
COLUMN parameter_value FORMAT a15

SELECT parameter_name, parameter_value
FROM   dba_advisor_parameters
WHERE  task_name = 'SYS_AUTO_SPM_EVOLVE_TASK'
AND    parameter_value != 'UNUSED'
ORDER BY parameter_name;
"
# ----------------------------------------------------------------------------
elif [ "$ACTION" = "LOAD_BASELINE" ];then
  if  [ -z "$SQL_ID" ];then
       echo "I need an SQL_ID"
  fi
  if [ -z "$SNAP_BEG" ];then
      echo "I need a begin snap "
      exit
  fi
  if [ -z "$SNAP_END" ];then
      SNAP_END=`expr $SNAP_BEG + 1`
  fi

SQL="
set serveroutput on 
declare
  rs pls_integer;
begin
  rs := dbms_spm.load_plans_from_awr('$SNAP_BEG', '$SNAP_END', basic_filter=>q'# sql_id='$SQL_ID'#');
  dbms_output.put_line('New baseline : ' || to_char(rs));
end;
/
"
# ----------------------------------------------------------------------------
# found this at : https://carlos-sierra.net/category/high-version-count/
# ----------------------------------------------------------------------------
elif [ "$ACTION" = "MCOUNT" ];then
SQL="

set serveroutput on maxsize unlimited
declare
  rs pls_integer;
begin
  rs := dbms_spm.load_plans_from_awr('$BEG_SNAP', '$END_SNAP', basic_filter=>q'# sql_id='6g4j0944pj3hj'#');
  dbms_output.put_line(to_char(rs));
end;
/
SELECT COUNT(*) cursors, COUNT(DISTINCT sql_id) sql_ids, reason_not_shared
FROM v\$sql_shared_cursor UNPIVOT
( value FOR reason_not_shared IN
( LOCK_USER_SCHEMA_FAILED
, REMOTE_MAPPING_MISMATCH
, LOAD_RUNTIME_HEAP_FAILED
, HASH_MATCH_FAILED
, PURGED_CURSOR
, BIND_LENGTH_UPGRADEABLE
, USE_FEEDBACK_STATS
, UNBOUND_CURSOR
, SQL_TYPE_MISMATCH
, OPTIMIZER_MISMATCH
, OUTLINE_MISMATCH
, STATS_ROW_MISMATCH
, LITERAL_MISMATCH
, FORCE_HARD_PARSE
, EXPLAIN_PLAN_CURSOR
, BUFFERED_DML_MISMATCH
, PDML_ENV_MISMATCH
, INST_DRTLD_MISMATCH
, SLAVE_QC_MISMATCH
, TYPECHECK_MISMATCH
, AUTH_CHECK_MISMATCH
, BIND_MISMATCH
, DESCRIBE_MISMATCH
, LANGUAGE_MISMATCH
, TRANSLATION_MISMATCH
, BIND_EQUIV_FAILURE
, INSUFF_PRIVS
, INSUFF_PRIVS_REM
, REMOTE_TRANS_MISMATCH
, LOGMINER_SESSION_MISMATCH
, INCOMP_LTRL_MISMATCH
, OVERLAP_TIME_MISMATCH
, EDITION_MISMATCH
, MV_QUERY_GEN_MISMATCH
, USER_BIND_PEEK_MISMATCH
, TYPCHK_DEP_MISMATCH
, NO_TRIGGER_MISMATCH
, FLASHBACK_CURSOR
, ANYDATA_TRANSFORMATION
, PDDL_ENV_MISMATCH
, TOP_LEVEL_RPI_CURSOR
, DIFFERENT_LONG_LENGTH
, LOGICAL_STANDBY_APPLY
, DIFF_CALL_DURN
, BIND_UACS_DIFF
, PLSQL_CMP_SWITCHS_DIFF
, CURSOR_PARTS_MISMATCH
, STB_OBJECT_MISMATCH
, CROSSEDITION_TRIGGER_MISMATCH
, PQ_SLAVE_MISMATCH
, TOP_LEVEL_DDL_MISMATCH
, MULTI_PX_MISMATCH
, BIND_PEEKED_PQ_MISMATCH
, MV_REWRITE_MISMATCH
, ROLL_INVALID_MISMATCH
, OPTIMIZER_MODE_MISMATCH
, PX_MISMATCH
, MV_STALEOBJ_MISMATCH
, FLASHBACK_TABLE_MISMATCH
, LITREP_COMP_MISMATCH
, PLSQL_DEBUG
, LOAD_OPTIMIZER_STATS
, ACL_MISMATCH
, FLASHBACK_ARCHIVE_MISMATCH
)
)
WHERE value = 'Y'
GROUP BY reason_not_shared
ORDER BY cursors DESC, sql_ids DESC, reason_not_shared
/
"
# .........................
# List sql with same force_matching signature
# .........................
elif [ "$ACTION" = "FORCE_MATCHING" ];then
   if [ -n "$SQL_ID" ];then
      SQL="
    set pages 90 lines 190
    set wrap off
    col cpt for 99999
    col PARSING_SCHEMA_NAME for a12
    col sql_text for a100 head 'Text'
    col buffer_gets head 'gets/execs' format 9999999999 justify c
    col disk_reads head 'Disk reads|per execs' format 9999999999 justify c
    col force_matching_signature format 999999999999999999999
    col exact_matching_signature format 999999999999999999999

    select sql_id, force_matching_signature, EXACT_MATCHING_SIGNATURE , executions execs
           ,round(buffer_gets/decode(executions,0,1,executions),0) buffers_gets
           ,round(DISK_READS/decode(executions,0,1,executions),0) DISK_READS
           ,a.PARSING_SCHEMA_NAME, sql_text 
    from v\$sql a where  a.sql_id = '$SQL_ID'
/
"
 # no SQL ID given
else
SQL="
set pages 90 lines 190
set wrap off
col cpt for 99999
col PARSING_SCHEMA_NAME for a12
col sql_text for a100 head 'Text'
col buffer_gets head 'gets/execs' format 9999999999 justify c
col disk_reads head 'Disk reads|per execs' format 9999999999 justify c

with v as ( select cpt,force_matching_signature from (
select count(*) cpt, force_matching_signature from v\$sql group by force_matching_signature )
 where  cpt > 1 and force_matching_signature  > 0
)
select v.cpt, sql_id, executions execs
    ,round(buffer_gets/decode(executions,0,1,executions),0) buffers_gets
    ,round(DISK_READS/decode(executions,0,1,executions),0) DISK_READS
    , a.PARSING_SCHEMA_NAME, sql_text 
from v\$sql a, v where  a.force_matching_signature = v.force_matching_signature
and a.PARSING_SCHEMA_NAME not like 'SYS%'
and a.PARSING_SCHEMA_NAME not like 'DBSNMP%'
/

"
fi
# .........................
# Plan from SQL monitor 
# .........................
elif [ "$ACTION" = "REPORT_EXEC_ID" ];then
  if [ -z "$SQL_ID" ];then
      ret=`sqlplus -s "$CONNECT_STRING" <<EOF
 set head off pagesize 0 feed off verify off
 select distinct sid, sql_id from v\\$sql_monitor where sql_exec_id=$EXEC_ID ;
EOF`
      var=`echo "$ret" | tr  '\n' ' ' | wc -w`
      if [ ! "$var" -eq 2 ];then
         echo "I need an sql_d:"
         echo "$ret" 
         exit
      else
         SQL_ID=`echo $ret | awk '{print $2}'`
         if [ -z "$SID" ];then
            SID=`echo "$ret" | awk '{print $1}'`
         fi
      fi
  fi
  if [ -z "$SID" ];then
       ret=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off pagesize 0 feed off verify off
select sid from v\\$sql_monitor where sql_exec_id=$EXEC_ID and SQL_ID='$SQL_ID' and PX_SERVER# is null ;
EOF`
    SID=`echo "$ret" | head -1 | awk '{print $1}'`
  fi
SQL="
 set long 999999999
set lines 231
col report for a230
set pages 900
select
DBMS_SQLTUNE.REPORT_SQL_MONITOR(
   session_id=>nvl('$SID',sys_context('userenv','sid')),
   session_serial=>decode('$SID',null,null, sys_context('userenv','sid'),
        (select serial# from v\$session where audsid = sys_context('userenv','sessionid')), null),
   sql_id=>'$SQL_ID',
   sql_exec_id=>'$EXEC_ID',
   report_level=>'TYPICAL-ACTIVITY-SESSIONS') as report from dual;
"
# .........................
elif [ "$ACTION" = "MONITOR_BIND" ];then
   #if [ -n "$SQL_ID" ];then   # get the first session running this
   #      AND_SQL_ID="and sql_id='$SQL_ID'" 
   #fi
TITEL="Show bind active in a session"
SQL="
with v as (
select fsid from ( select sid as fsid from v\$sql_monitor where STATUS='EXECUTING' and PX_SERVER# is null $AND_SQL_ID) where rownum=1 )
select fsid, xmltype(binds_xml)  
   from v\$sql_monitor, v 
where 
   sid = fsid and status = 'EXECUTING'
   and binds_xml is not null
order by fsid
/
"
# .........................
#   Differential activity on V$SQLSTATS
# .........................
elif [ "$ACTION" = "DIF_SEC" ];then
TITEL="Show SQL executed during $SECONDS seconds: show only sql executed > 1 or 100 DISKREAD"
SLEEP_TIME=${SECONDS:-1}
SQL="
  set linesize 190 pagesize 0 feed off head off
set serveroutput on size 999999
declare
  type  tofar   is table of  number INDEX BY  varchar2(13) ;
  type  ttsql    is table of  varchar2(85) INDEX BY  varchar2(13) ;
 
  texec1 tofar ;
  tdskr1 tofar ; 
  tbufg1 tofar ; 
  trow1  tofar ; 
  tfetch1 tofar ; 
  tconc1 tofar ; 
  tio1 tofar ; 
  tela1 tofar ; 

  texec2 tofar ;
  tdskr2 tofar ; 
  tbufg2 tofar ; 
  trow2  tofar ; 
  tfetch2 tofar ; 
  tconc2 tofar ; 
  tio2 tofar ; 
  tela2 tofar ; 

  tsql  ttsql ;
  tsp1 timestamp ;
  v_sub varchar2(13) ;

  begin

      for c in (  
                   select sql_id, EXECUTIONS,DISK_READS, BUFFER_GETS, ROWS_PROCESSED, FETCHES,
                          CONCURRENCY_WAIT_TIME, USER_IO_WAIT_TIME, ELAPSED_TIME
                   from v\$sqlstats 
                       where
                                EXECUTIONS > 1 order by sql_id 
               )
      loop
         texec1(c.sql_id):=c.EXECUTIONS ;
         tdskr1(c.sql_id):=c.DISK_READS ;
         tbufg1(c.sql_id):=c.BUFFER_GETS ;
         trow1(c.sql_id):=c.ROWS_PROCESSED ;
         tfetch1(c.sql_id):=c.FETCHES ;
         tconc1(c.sql_id):=c.CONCURRENCY_WAIT_TIME ;
         tio1(c.sql_id):=c.USER_IO_WAIT_TIME ;
         tela1(c.sql_id):=c.ELAPSED_TIME ;
      end loop ;

     -- sleep
     tsp1:=systimestamp ;
     dbms_lock.sleep($SLEEP_TIME); 

     for g in (  
                   select sql_id, EXECUTIONS,DISK_READS, BUFFER_GETS , ROWS_PROCESSED, FETCHES ,
                          CONCURRENCY_WAIT_TIME, USER_IO_WAIT_TIME, ELAPSED_TIME,
                          substr(SQL_TEXT,1,65) sql_text from v\$sqlstats 
                       where
                                EXECUTIONS > 1 order by sql_id 
               )
      loop
         texec2(g.sql_id):=g.EXECUTIONS ;
         tdskr2(g.sql_id):=g.DISK_READS ;
         tbufg2(g.sql_id):=g.BUFFER_GETS ;
         trow2(g.sql_id):=g.ROWS_PROCESSED ;
         tfetch2(g.sql_id):=g.FETCHES ;
         tconc2(g.sql_id):=g.CONCURRENCY_WAIT_TIME ;
         tio2(g.sql_id):=g.USER_IO_WAIT_TIME ;
         tela2(g.sql_id):=g.ELAPSED_TIME ;
         tsql(g.sql_id):=g.sql_text ;
      end loop ;

     dbms_output.put_line(chr(10)||'Sample duration : ' || to_char(tsp1-systimestamp,'SS')|| chr(10) ); 

     dbms_output.put_line('.                            Buffer      Disk                       Concur.    io');
     dbms_output.put_line('Sql id         Executions     gets      reads      Rows    Fetches  wait(ms)  wait(ms)  Ela(ms)  SQL');
     dbms_output.put_line('------------- ------------ ---------- ---------- --------- ------- --------- --------- --------- --------------------------------------------------------------') ;
     v_sub:=texec2.first ; 
     while v_sub IS NOT NULL 
     LOOP
         if (texec1.exists(v_sub)  ) then
             if ( (texec2(v_sub) - texec1(v_sub)) > 0  ) then
                 dbms_output.put_line(v_sub || ' ' || 
                                      lpad(texec2(v_sub) - texec1(v_sub),12) || ' ' || 
                                      lpad(tbufg2(v_sub) - tbufg1(v_sub),10) || ' ' ||
                                      lpad(tdskr2(v_sub) - tdskr1(v_sub),10) || ' ' ||
                                      lpad(trow2(v_sub)  - trow1(v_sub),9)  || ' ' ||
                                      lpad(round((tconc2(v_sub) - tconc1(v_sub))/1000),8)  || ' ' ||
                                      lpad(round((tio2(v_sub)  - tio1(v_sub))/1000),8)  || ' ' ||
                                      lpad(round((tela2(v_sub) - tela2(v_sub))/1000),8)  || ' ' ||
                                      lpad(tfetch2(v_sub)- tfetch1(v_sub),10)  || ' ' || tsql(v_sub)
                  ) ;
             end if ;
         end if ;
         v_sub := texec1.NEXT(v_sub); 
     end loop ;
    
  end  ;
/
"
# .........................
#  sql monitor single
# .........................
elif [ "$ACTION" = "MONITOR_SI" ];then
   if [  -z "$SQL_ID" ];then
          echo "I need an SQL ID" 
          exit
   fi
COL_LEN=${COLNBR:-300}
SQL="
SET lines 300
SET pages 0
set longchunksize $COL_LEN trimspool on
set LONG 99999 
SELECT dbms_sqltune.report_sql_monitor(sql_id=>'$SQL_ID') from dual 
/
"
# .........................
#  sql monitor overview
# .........................
elif [ "$ACTION" = "MONITOR_OVERVIEW" ];then

 if [ -n "$fowner" ];then
    AND_FOWNER=" and username=upper('$fowner')"
 fi
 if [ "$LIST_EXEC_ID" = "TRUE" ];then
    EXEC_ID1=",to_char(SQL_EXEC_ID) as exec_id"
    EXEC_ID2=",'-' as exec_id"
    A_EXEC_ID=",exec_id"
 fi
NROWNUM=${NROWNUM:-45}
TITLE="Sql in parallel or that lasted > 5s"
SQL="
set lines 200 pages 66
col exec_id for a12 
col BUFFER_GETS head 'Gets' for 99999999999
col FETCHES head 'Fetches' for 999999999
col DISK_READS head 'Disk|reads' for 99999999
col cpu for 99999999 head 'Cpu(ms)' justify c
col ela for 99999999 head 'Elapsed|Time(ms)' justify c
col io for 9999999999 head 'Io wait|Time(ms)' justify c
col conc for 9999999 head 'Concur| wait|Time(ms)' justify c
col fstart head 'Start'
col lrefresh head 'Last Refresh'
col cpt head 'nbr|ses' for 999 justify c
col machine head 'Host' for a18
col username for a18 head 'Username'
col executions for 999999999
col err for a30
select /*+ no_monitor */ username,a.sid, a.sql_id $A_EXEC_ID, fstart, lrefresh, a.ela, 
       nvl(io,USER_IO_WAIT_TIME/decode(c.executions,0,1,c.executions) )io , 
       nvl(a.cpu,cpu_time/decode(c.executions,0,1,c.executions)) cpu , 
       nvl(conc,c.CONCURRENCY_WAIT_TIME/decode(c.executions,0,1,c.executions) ) conc, 
       nvl(a.fetches,c.FETCHES/decode(c.executions,0,1,c.executions) )fetches,
       nvl(a.BUFFER_GETS,c.BUFFER_GETS/decode(c.executions,0,1,c.executions) )BUFFER_GETS, a.DISK_READS,  cpt, c.executions,
       --LOCKED_TOTAL lck
       err --, rnk
from (
select username,
    sid, sql_id $EXEC_ID1,  
    to_char(sql_exec_start ,'HH24:Mi:SS') fstart,
    to_char(LAST_REFRESH_TIME ,'MM-DD HH24:Mi:SS') lrefresh,
    sum(ELAPSED_TIME/1000) over (partition by sql_id, SQL_EXEC_ID, SQL_EXEC_START)    ela, 
    sum(USER_IO_WAIT_TIME/1000) over (partition by sql_id, SQL_EXEC_ID, SQL_EXEC_START) io,
    sum(CPU_TIME/1000)  over (partition by sql_id, SQL_EXEC_ID, SQL_EXEC_START) cpu, 
    sum(CONCURRENCY_WAIT_TIME/1000) over (partition by sql_id, SQL_EXEC_ID, SQL_EXEC_START) conc,
    sum(FETCHES) over (partition by sql_id, SQL_EXEC_ID, SQL_EXEC_START) fetches, 
    sum(BUFFER_GETS ) over (partition by sql_id, SQL_EXEC_ID, SQL_EXEC_START)BUFFER_GETS, 
    sum(DISK_READS )  over (partition by sql_id, SQL_EXEC_ID, SQL_EXEC_START) DISK_READS,
    count(sid) over  (partition by sql_id, SQL_EXEC_ID, SQL_EXEC_START order by sql_exec_start) cpt,
    row_number() over  (partition by sql_id, SQL_EXEC_ID, SQL_EXEC_START order by sql_exec_start, PX_SERVER# desc ) rnk, 
    ERROR_FACILITY || '--'||to_char(ERROR_NUMBER) || ' ' || ERROR_MESSAGE err
from v\$sql_monitor 
union 
select s.username, s.sid, s.sql_id $EXEC_ID2, to_char(s.sql_exec_start ,'HH24:Mi:SS') fstart, 
       to_char(s.sql_exec_start ,'MM-DD HH24:Mi:SS') lrefresh , 
       round((sysdate - SQL_EXEC_START ) * 84400000 ) ela,
       null io, null cpu , null conc , null fetches ,
       round(q.BUFFER_GETS/decode(q.executions,0,1,q.executions)) buffer_gets, 
       round(q.DISK_READS/decode(q.executions,0,1,q.executions)) DISK_READS,
       null cpt, 1 rnk, '-' err
from v\$session s , v\$sql q
where 
      username is not null and s.sql_exec_start is not null and s.status = 'ACTIVE'
      and s.sql_id = q.sql_id and s.sql_child_number = q.child_number
      and not exists (select null from v\$sql_monitor m where m.sql_id=s.sql_id)
order by lrefresh desc
) a,  v\$sqlarea c
where  rnk=1  and
      a.sql_id = c.sql_id
      and ROWNUM <= $NROWNUM  $AND_FOWNER
--order by lrefresh desc
/
"
# .........................
# List active sql profile
# .........................
elif [ "$ACTION" = "CPAR" ];then
NROWNUM=${NROWNUM:-30}
SQL="
col task_name for a25
col lhour head 'Start'
col ehour head 'End'
select
     row_number() over ( partition by task_name order by START_TS nulls last ) rank,
     CHUNK_ID, TASK_NAME, STATUS , 
     to_char(START_TS,'MM-DD HH24:MI') LHOUR, to_char(END_TS, 'MM-DD HH24:MI') EHOUR ,
     ERROR_CODE, substr(ERROR_MESSAGE,1,40) ERR
     from SYS.DBA_PARALLEL_EXECUTE_CHUNKS 
where rownum < $NROWNUM order by TASK_NAME, START_TS;
"
# .........................
# List active sql profile
# .........................
elif [ "$ACTION" = "LPRF" ];then
NROWNUM=${NROWNUM:-45}
SQL="
col PARSING_SCHEMA_NAME for a24
col child_number for 9999 head 'chld'
col executions head 'Execs'
col elapsed_per_exec head 'Elapsed|per exec'
col buffer_gets head gets
col sql_profile for a30
col last_active_time for a14
break on last_active_time on sql_profile on sql_id on plan_hash_value on report

select * from (
select to_char(last_active_time,'MM/DD HH24:MI:SS') last_active_time, sql_profile, 
      PARSING_SCHEMA_NAME, sql_id, child_number,
       plan_hash_value, executions,
       buffer_gets,
       round(elapsed_time/1000000,2) "elapsed_sec",
       round((elapsed_time/1000000)/executions,2) "elapsed_per_exec",
       round(buffer_gets/executions,2) "gets_per_exec",
       OPTIMIZER_COST cost
from v\$sql 
where sql_profile is not null  and executions is not null and executions > 0
order by last_active_time desc, buffer_gets
) where rownum <= $NROWNUM
/
"
# .........................
# Top sql for last n seconds
# default sorting on gets
# .........................
elif [ "$ACTION" = "TOP" ];then
FSQL_LEN=${LEN_TEXT:-50}
NBR_SECS=${NBR_SECS:-1}
SORT_COL=${SORT_COL:-gets}
NROWNUM=${NROWNUM:-24}
NGETS=${NGETS:-100}
TITLE=" Top $NROWNUM sql sampled $NBR_SECS seconds, sort by $SORT_COL"
SQL="
   set linesize 190 pagesize 333 feed off head off
   set serveroutput on size 999999

declare

   type  rec_type is record (
         name       varchar2(18),
         sql_id     varchar(15),
         child      number ,  
         execs      number,
         gets       number,
         reads      number,
         writes     number,
         elapsed    number,
         app_wait   number,
         io_wait    number,
         conc_wait  number,
         fsql        varchar2($FSQL_LEN)
    );
   type  rec_sort is record (
         hash_key varchar2(30),
         value   number ) ;

    type TC is table of REC_TYPE index by  varchar2(30);
    type TC_sort is table of REC_SORT index by  binary_integer ;

    thv1 TC ; 
    thv2 TC ; 
    th_sort TC_sort;
    th_res  TC;
    v_var   varchar2(30);
    v_int   number ;
    t_execs    number ;
    t_gets     number ;
    t_reads    number ;
    t_writes   number ;
    v_res   rec_type ; 
    v       rec_type ; 
    v0      rec_sort;
    cpt     number:=0;
    rownum  number:=0;
    ------------------------------------------------------------------------------------------------------
    procedure load_data (p_thv IN OUT tc) is
       v_rec   rec_type ; 
    begin
       for c1 in ( select substr(parsing_schema_name,1,18) name,sql_id, child_number,
                          executions, buffer_gets, disk_reads, direct_writes, 
                          round(decode(elapsed_time,0,0,elapsed_time/1000)) elapsed_time,
                          round(decode(application_wait_time,0,0,application_wait_time/1000)) application_wait_time, 
                          round(decode(user_io_wait_time,0,0,user_io_wait_time/1000)) user_io_wait_time, 
                          round(decode(concurrency_wait_time,0,0,concurrency_wait_time/1000))concurrency_wait_time, 
                          substr(sql_text,1,$FSQL_LEN) fsql
                  from sys.${G}v_\$sql where buffer_gets > $NGETS )
      loop
          -- dbms_output.put_line('sql_id=' ||c1.sql_id|| ' c=' 
          --      ||to_char(c1.child_number) || ' execs=' ||to_char(c1.executions)  );
          v_rec.name:=c1.name;
          v_rec.sql_id:=c1.sql_id ;
          v_rec.child:=c1.child_number ;
          v_rec.execs:=c1.executions ;
          v_rec.gets:=c1.buffer_gets;
          v_rec.reads:=c1.disk_reads;
          v_rec.writes:=c1.direct_writes;
          v_rec.elapsed:=c1.elapsed_time;
          v_rec.app_wait:=c1.application_wait_time;
          v_rec.io_wait:=c1.user_io_wait_time;
          v_rec.conc_wait:=c1.concurrency_wait_time;
          v_rec.fsql:=c1.fsql;
          p_thv(c1.sql_id||'_'||to_char(c1.child_number) ):=v_rec;
       end loop ;
    end ;
    ------------------------------------------------------------------------------------------------------
    FUNCTION  transfer_delta(p1 IN rec_type, p2 IN rec_type )   RETURN rec_type IS
            res rec_type;
    BEGIN
            res.sql_id:=p2.sql_id;
            res.child:=p2.child;
            res.name:=p2.name;
            res.fsql:=p2.fsql;
          if p2.execs is not null and p1.execs is not null  and p2.execs > p1.execs then
             res.execs:=p2.execs - p1.execs ;
          else
             res.execs:=0;
          end if;
          if p2.gets is not null   and p1.gets is not null   and p2.gets > p1.gets then
             res.gets:=p2.gets - p1.gets ;
          else
             res.gets:=0;
          end if;
          if p2.reads is not null   and p1.reads is not null   and p2.reads > p1.reads then
             res.reads:=p2.reads - p1.reads ;
          else
             res.reads:=0;
          end if;
          if p2.writes is not null   and p1.writes is not null   and p2.writes > p1.writes then
             res.writes:=p2.writes - p1.writes ;
          else
             res.writes:=0;
          end if;
          if p2.elapsed is not null   and p1.elapsed is not null   and p2.elapsed > p1.elapsed then
             res.elapsed:=p2.elapsed - p1.elapsed ;
          else
             res.elapsed:=0;
          end if;
          if p2.app_wait is not null   and p1.app_wait is not null   and p2.app_wait > p1.app_wait then
             res.app_wait:=p2.app_wait - p1.app_wait ;
          else
             res.app_wait:=0;
          end if;
          if p2.io_wait is not null   and p1.io_wait is not null   and p2.io_wait > p1.io_wait then
             res.io_wait:=p2.io_wait - p1.io_wait ;
          else
             res.io_wait:=0;
          end if;
          if p2.conc_wait is not null   and p1.conc_wait is not null   and p2.conc_wait > p1.conc_wait then
             res.conc_wait:=p2.conc_wait - p1.conc_wait ;
          else
             res.conc_wait:=0;
          end if;
          return res;
    END ;
    ------------------------------------------------------------------------------------------------------

begin
   load_data(thv1);
   dbms_lock.sleep($NBR_SECS);
   load_data(thv2);

   -- read and compare the 2 datasets. At first cpt is still :=0
   v_var:=thv2.FIRST ; 
   if  thv1.exists(v_var) then
        v:=transfer_delta(thv1(v_var), thv2(v_var) );
        if v.gets > 0  then
           th_sort(cpt).hash_key:=v_var ;
           th_sort(cpt).value:=v.$SORT_COL ;
           th_res(v_var):=v;                           -- we store the delta
        end if;
   else
        dbms_output.put_line( 'Did not find :=' ||v_var ||'  in thv1 ! ') ; 
   end if;
   while v_var is not null
   LOOP
        v_var:=thv2.next(v_var) ;  
        if v_var is not null then 
           if thv1.exists(v_var) then
              -- dbms_output.put_line( 'sql_id exists in thv1 : ' ||v_var) ; 
              v:=transfer_delta(thv1(v_var), thv2(v_var) );
              if v.gets > 0  then
                 cpt:=cpt+1;
                 th_sort(cpt).hash_key:=v_var ;
                 th_sort(cpt).value:=v.$SORT_COL ;           -- this will define the sort order 
                 th_res(v_var):=v;                           -- we store the delta
             end if;
          else
              dbms_output.put_line( 'Did not find ' ||v_var ||'  in thv1 ! ') ; 
          end if;
       end if ;
   end loop;
   dbms_output.put_line('Total number of SQL considered : ' ||to_char(thv1.count)  || ' --> actives : ' ||to_char(th_res.count) );
   v_int:=th_sort.count ;
   if v_int > 0 then
      -- dbms_output.put_line('there is ' || to_Char(v_int) || ' elements in th_sort' );
      -- good old buble. one day should be less lazy an improve this
      for i in 0..th_sort.last
      loop
        if th_sort.exists(i) then
           for j in 1..th_sort.last
           loop
              if th_sort.exists(j) then
                 if th_sort(j).value < th_sort(i).value then
                    v0:=th_sort(i);
                    th_sort(i):=th_sort(j);
                    th_sort(j):=v0;
                  end if;
               end if;
               rownum:=rownum+1;
               exit when rownum = $NROWNUM;
            end loop;
        end if;
      end loop;
   else
      dbms_output.put_line('No relevant activity found in the elapsed time.' );
   end if;
   DBMS_OUTPUT.PUT_LINE('.                                                                      Elapse App/w   IO/w   Conc/w');
   DBMS_OUTPUT.PUT_LINE(' Owner               SQL_ID       C#   execs    Gets    reads   d.Writes  (ms)   (ms)   (ms)    (ms)   SQL text');
   DBMS_OUTPUT.PUT_LINE(' ------------------- ------------- ---  ------ -------- -------- -------- ------ ------ ------- ------'||rpad(' ',$FSQL_LEN+1,'-') );

   t_execs:=0;t_reads:=0; t_gets:=0 ; t_writes:=0 ;
   v_int:=th_sort.FIRST ; 
   if  th_sort.exists(v_int) then
       v_var:=th_sort(v_int).hash_key ;
        v:=th_res(v_var) ;
        t_execs:=t_execs+v.execs; 
        t_gets:=t_gets+v.gets; 
        t_reads:=t_reads+v.reads; 
        t_writes:=t_writes+v.writes; 
        dbms_output.put_line( rpad(v.name,19)|| ' '|| to_char(rpad(v.sql_id,13))|| ' '|| to_char(rpad(v.child,3))|| ' ' || 
            to_char(lpad(v.execs,6))|| ' ' || to_char(lpad(v.gets,8) ) || ' ' || to_char(lpad(v.reads,8)) || ' '
            || to_char(lpad(v.writes,8))|| to_char(lpad(v.elapsed,7))||
            to_char(lpad(v.app_wait,7))|| ' ' || to_char(lpad(v.io_wait,7))|| to_char(lpad(v.conc_wait,7))||' '|| v.fsql );
   end if ;
   while v_int is not null
   loop
      v_int:=th_sort.next(v_int);
      if (v_int) is not null then
          v_var:=th_sort(v_int).hash_key ;
          v:=th_res(v_var) ;
          t_execs:=t_execs+v.execs; 
          t_gets:=t_gets+v.gets; 
          t_reads:=t_reads+v.reads; 
          t_writes:=t_writes+v.writes; 
          dbms_output.put_line( rpad(v.name,19)|| ' '|| to_char(rpad(v.sql_id,13))|| ' '|| to_char(rpad(v.child,3))|| ' ' || 
            to_char(lpad(v.execs,6))|| ' ' || to_char(lpad(v.gets,8) ) || ' ' || to_char(lpad(v.reads,8)) || ' '
            || to_char(lpad(v.writes,8))|| to_char(lpad(v.elapsed,7))||
            to_char(lpad(v.app_wait,7))|| ' ' || to_char(lpad(v.io_wait,7))|| to_char(lpad(v.conc_wait,7))||' '|| v.fsql );
      end if; 
   end loop;
   DBMS_OUTPUT.PUT_LINE(' ------------------- ------------- ---  ------ -------- -------- -------- ------ ------ ------- ------' );
   DBMS_OUTPUT.PUT_LINE(' Total                              ' || to_char(lpad(t_execs,8))  || ' ' || to_char(lpad(t_gets,8) ) || ' ' 
               || to_char(lpad(t_reads,8)) || ' ' || to_char(lpad(t_writes,8)));
end;
/
"
#EOF

# .........................
# last run sql
# .........................
elif [ "$ACTION" = "LAST_SQL" ];then
   if [ -n "$fowner" ];then
       AND_OWNER=" and PARSING_SCHEMA_NAME = '$fowner' "
   fi
   LAST_SEC=${LAST_SEC:-60}
  # if [ -n "$SHOW_IO" ];then
      FIELDS="executions to_execs,
                                  decode (nvl(executions,0),0,0,BUFFER_GETS/executions) avg_gets, 
                                  decode(nvl(executions,0),0,0,DISK_READS/executions) DISK_READS, 
                                  round(decode (nvl(executions,0),0,0,USER_IO_WAIT_TIME/executions/1000),1) IO_WAIT,
                                  decode(nvl(executions,0),0,0,CONCURRENCY_WAIT_TIME/executions/1000) Conc_wait "
      FLEN=75
  # else
  #    FIELDS="executions to_execs, decode (nvl(executions,0),0,0,BUFFER_GETS/executions)  avg_gets,"
  #    FLEN=75
  # fi

if [  "$LEN_TEXT" -gt $FLEN ];then
       FLEN=$LEN_TEXT
fi
TITLE=" List  SQL run during the last $LAST_SEC seconds"
SQL="set lines 220 pages 66
col sql_text for a$FLEN
col hash_value justify c
col owner for a16 justify c head 'Owner'
col avg_gets head 'Avg|gets' for 999999990.9 justify c
col last_active_time for a22 justify c
col DISK_READS for 999999 head 'Avg|disk| reads' justify c
col USER_IO_WAIT_TIME for 999999999 head 'User Io|Wait time' justify c
col last_active_time for a12 head 'Last active| time' justify c
col IO_WAIT head 'io wait|avg(ms)|per exec' justify c
col Conc_wait head 'Concurent|wait avg(ms)|per exec' justify c
col to_execs head 'Total|execs' justify c
col application_wait_time head 'WAIT 4 APP' justify c
break on last_active_time on report
 select $INST_ID to_char(last_active_time,'HH24:MI:SS')last_active_time,application_wait_time, sql_id, child_number chld,
        executions to_execs,
        decode (nvl(executions,0),0,0,BUFFER_GETS/executions) avg_gets,
        decode(nvl(executions,0),0,0,DISK_READS/executions) DISK_READS,
        round(decode (nvl(executions,0),0,0,USER_IO_WAIT_TIME/executions/1000),1) IO_WAIT,
        round(decode(nvl(executions,0),0,0,CONCURRENCY_WAIT_TIME/executions/1000),1) Conc_wait,
        PARSING_SCHEMA_NAME owner,
          substr(SQL_TEXT,1,$FLEN) sql_text
        from sys.${G}v_\$sql where last_active_time > sysdate-$LAST_SEC/86400 $AND_OWNER order by last_active_time desc;
"

# .........................
#  Count SQL bind mistmatch
# .........................
elif [ "$ACTION" = "COUNT_MIS_BIND" ];then
   TITLE=" Count SQL bind mistmatch for SQL_ID with more than 5 mismatch"
SQL="
   select cpt,sql_id from (
   select count(*) cpt, s.sql_id from sys.${G}v_\$sql_shared_cursor s
          where BIND_EQUIV_FAILURE = 'Y'
         group by s.sql_id order by 1 desc ) where cpt >=5 $AND_DBID ;
"
elif [ "$ACTION" = "MIS_BIND" ];then

# .........................
#  SQL bind mistmatch
# .........................
#- Modified version of Dion Cho's script - http://dioncho.wordpress.com/?s=v%24sql_shared_cursor
#--
#-- Modified by Kerry Osborne
#-- I just changed the output columns (got rid of sql_text and address columns and added last_load_time)
#-- I also ordered the output by last_load_time.
SQL_ID=`get_sql_id $SQL_ID`
TITLE=" Show bind mismmatch reason"
SQL="
set serveroutput on 
declare
  c         number;
  col_cnt   number;
  col_rec   dbms_sql.desc_tab;
  col_value varchar2(4000);
  ret_val    number;
begin
  c := dbms_sql.open_cursor;
  dbms_sql.parse(c,
      'select q.sql_text, q.last_load_time, s.*
      from sys.${G}v_\$sql_shared_cursor s, sys.${G}v_\$sql q
      where s.sql_id = q.sql_id
          and s.child_number = q.child_number
          and q.sql_id like ''$SQL_ID''
      order by last_load_time',
      dbms_sql.native);
  dbms_sql.describe_columns(c, col_cnt, col_rec);

  for idx in 1 .. col_cnt loop
    dbms_sql.define_column(c, idx, col_value, 4000);
  end loop;

  ret_val := dbms_sql.execute(c);

  while(dbms_sql.fetch_rows(c) > 0) loop
    for idx in 1 .. col_cnt loop
      dbms_sql.column_value(c, idx, col_value);
      if col_rec(idx).col_name in ('SQL_ID', 'CHILD_NUMBER','LAST_LOAD_TIME') then
        dbms_output.put_line(rpad(col_rec(idx).col_name, 30) || ' = ' || col_value);
      elsif col_value = 'Y' then
        dbms_output.put_line(rpad(col_rec(idx).col_name, 30) || ' = ' || col_value);
      end if;
      -- if col_rec(idx).col_name = 'REASON' then
      --    dbms_output.put_line(rpad(col_rec(idx).col_name, 30) || ' = ' || col_value);
      -- end if ;
    end loop;
    dbms_output.put_line('--------------------------------------------------');
   end loop;
  dbms_sql.close_cursor(c);
end;
/
"

# .........................
#  SQL_ID History of event
# .........................
elif [ "$ACTION" = "PLE" ];then

SQL_ID=`get_sql_id $SQL_ID`
   if [ -z "$SQL_ID" ];then
        echo "I need an sql id"
        exit
   fi
NROWNUM=${NROWNUM:-50}
SQL="
set lines 210
col session for a20
col wait_class for a20
col event for a40
col total for 999,999
col read_io_mb for 999,999.9
col snap_begin for a26
break on sql_id on report
with v as ( select min(snap_id) snap_id from (
     select snap_id from sys.wrm\$_snapshot s, v\$database d
  where s.instance_number   = 1 and s.dbid = d.dbid order by   snap_id desc)
  where rownum <= $NROWNUM
)
select b.snap_id, 
       to_char(BEGIN_INTERVAL_TIME,' dd Mon YYYY HH24:mi:ss')    snap_begin,
       sql_id, sql_plan_hash_value plan_id, session_state, wait_class, event,  total,  read_io_mb
from  (
   select
        a.snap_id,  sql_id, sql_plan_hash_value ,
        session_state, wait_class, event, count(*) total,
        sum(delta_read_io_bytes)/(1024*1024) read_io_mb
    from 
        DBA_HIST_ACTIVE_SESS_HISTORY a, v, v\$database c
    where
               sql_id='$SQL_ID'
         and a.DBID = c.DBID
         and a.snap_id >= v.snap_id
    group by a.snap_id,sql_id, sql_plan_hash_value, session_state, wait_class, event
    ) b
    , sys.wrm\$_snapshot s
where
         b.snap_id = s.snap_id
     order by snap_id desc;
"
# .........................
#  History of plan performances
# .........................

elif [ "$ACTION" = "PLH" ];then
#----------------------------------------------------------------------------------------
#-- Author:      Kerry Osborne
#----------------------------------------------------------------------------------------
SQL_ID=`get_sql_id $SQL_ID`
   if [ -z "$SQL_ID" ];then
        echo "I need an sql id"
        exit
   fi
   if [ -z "$AND_DBID" ];then
      var=`get_dbid`
      AND_DBID=" and s.dbid=$var "
   fi

NROWNUM=${NROWNUM:-45}
SQL="
set lines 155
col execs for 999999999
col avg_etime for 99999999.9 head 'Average|exec|Time(ms)' justify c
col etime for 999999999.9 head 'Total exec|Time(s)' justify c
col avg_lio for 999999999 head 'Avg Gets'
col begin_interval_time for a22 head 'Begin interval| time' justify c
col snap_id form 9999999 head 'Snap'
col node for 9999 head 'Inst'
col plan_hash_value head 'Plan hash| Value'
col Execs for 99999999 head 'Execs'
col OPTIMIZER_COST head 'Cost' for 9999999
col dreads head 'Average|Disk|Reads' format 99999999 justify c
col frows head 'Average|Rows' format 9999999999 justify c
col twaits head 'Wait|time(ms)|per exec' format 999999999 justify c

break on plan_hash_value on startup_time skip 1
select * from (
select
      ss.snap_id, ss.instance_number node, to_char(begin_interval_time,'YYYY-MM-DD HH24:MI:SS') begin_interval_time,
      sql_id, plan_hash_value, OPTIMIZER_COST,
        nvl(executions_delta,0) execs, 
      round( elapsed_time_delta/1000000,1) etime,
      case  executions_delta
        when null then round(elapsed_time_delta/1000)
        when 0    then round(elapsed_time_delta/1000)
        else round((elapsed_time_delta/executions_delta)/1000)
      end avg_etime,
      case  executions_delta
        when null then buffer_gets_delta
        when 0    then buffer_gets_delta
        else buffer_gets_delta/executions_delta
      end avg_lio,
      case  executions_delta
        when null then DISK_READS_DELTA
        when 0    then DISK_READS_DELTA
        else DISK_READS_DELTA/executions_delta
      end dreads,
      case  executions_delta
        when null then ROWS_PROCESSED_TOTAL
        when 0    then ROWS_PROCESSED_TOTAL
        else ROWS_PROCESSED_TOTAL/executions_delta
      end frows,
      case  executions_delta
        when null then round((IOWAIT_DELTA+CLWAIT_DELTA+APWAIT_DELTA+CCWAIT_DELTA)/1000)
        when 0    then round((IOWAIT_DELTA+CLWAIT_DELTA+APWAIT_DELTA+CCWAIT_DELTA)/1000)
        else round((IOWAIT_DELTA+CLWAIT_DELTA+APWAIT_DELTA+CCWAIT_DELTA)/1000)/executions_delta
      end twaits
from
     DBA_HIST_SQLSTAT S,
     DBA_HIST_SNAPSHOT SS
where sql_id = '$SQL_ID'  and S.dbid=SS.dbid $AND_DBID
  and ss.snap_id = S.snap_id
  and ss.instance_number = S.instance_number
  -- and executions_delta > 0
order by 3 desc, 1 , 2 
) where rownum <= $NROWNUM;
prompt 
prompt     Rowset limited to first $NROWNUM rows
"

# .........................
#  Attempts to find SQL statements with plan instability
# .........................

elif [ "$ACTION" = "ELH" ];then
#----------------------------------------------------------------------------------------
#-- Author:   Oskars Stabulnieks
#----------------------------------------------------------------------------------------
SQL_ID=`get_sql_id $SQL_ID`
   if [ -z "$SQL_ID" ];then
        echo "I need an sql id"
        exit
   fi
   if [ -z "$AND_DBID" ];then
      var=`get_dbid`
      AND_DBID=" and s.dbid=$var "
   fi

SQL="
set lines 310
col execs for 999999999
col avg_etime for 999D99  head 'Average|exec|Time(ms)' justify c
col etime for 999999999.9999 head 'Total exec|Time(s)' justify c
col avg_lio for 999999999 head 'Avg Gets'
col begin_interval_time for a15 head 'Begin interval| time' justify c
col snap_id form 9999999999 head 'Snap'
col node for 9999 head 'Inst'
col plan_hash_value head 'Plan hash| Value'
col Execs for 99999999 head 'Execs'
col OPTIMIZER_COST head 'Cost' for 9999999
col dreads head 'Average|Disk|Reads' format 99999999 justify c
col twaits head 'Wait|time(ms)|per exec' format 999999999 justify c
col apwait_total for 9999999999999999.9999 head 'App Wait' justify c
col event head 'Event' for a18
col wait_class for a10 head 'Class'
col SESSION_ID head 'SID' format 99999999 justify c
col WAIT_TIME head 'WAIT' format 99999999 justify c
col TIME_WAITED head 'WAITED' format 99999999 justify c
col BLOCKING_SESSION_SERIAL# head 'BSID' format 99999999 justify c

break on startup_time skip 1
SELECT
  ss.snap_id,
  ss.instance_number node,
  TO_CHAR(ss.begin_interval_time, 'DD-MM HH24:MI:SS') begin_interval_time,
  s.sql_id,
  s.APWAIT_TOTAL,
  s.OPTIMIZER_COST,
  NVL(s.executions_delta, 0) execs,
  ROUND(s.elapsed_time_delta / 1000000, 3) etime,
  CASE
    WHEN s.executions_delta IS NULL THEN ROUND(s.elapsed_time_delta / 1000, 3)
    WHEN s.executions_delta = 0 THEN ROUND(s.elapsed_time_delta / 1000, 3)
    ELSE ROUND((s.elapsed_time_delta / s.executions_delta) / 1000, 3)
  END avg_etime,
  CASE
    WHEN s.executions_delta IS NULL THEN s.buffer_gets_delta
    WHEN s.executions_delta = 0 THEN s.buffer_gets_delta
    ELSE s.buffer_gets_delta / s.executions_delta
  END avg_lio,
  CASE
    WHEN s.executions_delta IS NULL THEN s.DISK_READS_DELTA
    WHEN s.executions_delta = 0 THEN s.DISK_READS_DELTA
    ELSE s.DISK_READS_DELTA / s.executions_delta
  END dreads,
 CASE
    WHEN s.executions_delta IS NULL THEN ROUND((s.IOWAIT_DELTA + s.CLWAIT_DELTA + s.APWAIT_DELTA + s.CCWAIT_DELTA) / 1000, 3)
    WHEN s.executions_delta = 0 THEN ROUND((s.IOWAIT_DELTA + s.CLWAIT_DELTA + s.APWAIT_DELTA + s.CCWAIT_DELTA) / 1000, 3)
    ELSE ROUND((s.IOWAIT_DELTA + s.CLWAIT_DELTA + s.APWAIT_DELTA + s.CCWAIT_DELTA) / (1000 * s.executions_delta), 3)
  END twaits,
  ash.EVENT,
  ash.WAIT_CLASS,
  ash.SESSION_ID,
  ash.USER_ID,
  ash.WAIT_TIME / 1000 as TWAIT_MS,
  ash.TIME_WAITED / 1000 as WAITED_MS,
  ash.BLOCKING_SESSION_SERIAL#
FROM
  DBA_HIST_SQLSTAT s
JOIN
  DBA_HIST_SNAPSHOT ss
  ON s.dbid = ss.dbid
  AND ss.snap_id = s.snap_id
  AND ss.instance_number = s.instance_number
LEFT JOIN
  DBA_HIST_ACTIVE_SESS_HISTORY ash
  ON ash.SQL_ID = s.sql_id
  AND ash.SNAP_ID = ss.snap_id
WHERE
  s.sql_id = '$SQL_ID'
  AND s.dbid = ss.dbid $AND_DBID
ORDER BY
  3 DESC, 1, 2;
"

elif [ "$ACTION" = "EXEC_VAR_SPEED" ];then
#----------------------------------------------------------------------------------------
#-- File name:   whats_changed.sql
#-- Purpose:     Find statements that have significantly different elapsed time than before.
#-- Author:      Kerry Osborne
#-- Usage:       This scripts prompts for four values.
#--
#--              days_ago: how long ago was the change made that you wish to evaluate
#--                        (this could easily be changed to a snap_id for more precision)
#--              min_stddev: the minimum "normalized" standard deviation between plans
#--                          (the default is 2 - which means twice as fast/slow)
#--              min_etime:  only include statements that have an avg. etime > this value
#--                          (the default is .1 second)
#--              faster_slower: a flag to indicate if you want only Faster or Slower SQL
#--                             (the default is both - use S% for slower and F% for faster)
#--
#-- Description: This scripts attempts to find statements with significantly different
#--              average elapsed times per execution. It uses AWR data and computes a
#--              normalized standard deviation between the average elapsed time per
#--              execution before and after the date specified by the days_ago parameter.
#--              The ouput includes the following:
#--              SQL_ID - the sql_id of a statement that is in the shared pool (v$sqlarea)
#--              EXECS - the total number of executions in the AWR tables
#--              AVG_ETIME_BEFORE - the average elapsed time per execution before the REFERENCE_TIME
#--              AVG_ETIME_AFTER - the average elapsed time per execution after  the REFERENCE_TIME
#--              NORM_STDDEV - this is a normalized standard deviation (i.e. how many times slower/faster is it now)
#-- See http://kerryosborne.oracleguy.com for additional information.
#----------------------------------------------------------------------------------------
DAYS=${days_ago:-1}
TITLE="Show SQL with execution speed variations"
SQL="
-- accept days_ago -
--        prompt 'Enter Days ago: ' -
--        default '1'
alter session set NLS_NUMERIC_CHARACTERS='.,' ;
define days_ago=$DAYS ;
define min_stddev=2;
define min_etime=0.1;
define faster_slower='%';
set lines 155
col execs for 999,999,999
col before_etime for 999,990.99
col after_etime for 999,990.99
col before_avg_etime for 999,990.99 head AVG_ETIME_BEFORE
col after_avg_etime for 999,990.99 head AVG_ETIME_AFTER
col min_etime for 999,990.99
col max_etime for 999,990.99
col avg_etime for 999,990.999
col avg_lio for 999,999,990.9
col norm_stddev for 999,990.9999
col begin_interval_time for a30
col node for 99999
break on plan_hash_value on startup_time skip 1
select * from (
select sql_id, execs, before_avg_etime, after_avg_etime, norm_stddev,
       case when to_number(before_avg_etime) < to_number(after_avg_etime) then 'Slower' else 'Faster' end result
-- select *
from (
select sql_id, sum(execs) execs, sum(before_execs) before_execs, sum(after_execs) after_execs,
       sum(before_avg_etime) before_avg_etime, sum(after_avg_etime) after_avg_etime,
       min(avg_etime) min_etime, max(avg_etime) max_etime, stddev_etime/min(avg_etime) norm_stddev,
       case when sum(before_avg_etime) > sum(after_avg_etime) then 'Slower' else 'Faster' end better_or_worse
from (
select sql_id,
       period_flag,
       execs,
       avg_etime,
       stddev_etime,
       case when period_flag = 'Before' then execs else 0 end before_execs,
       case when period_flag = 'Before' then avg_etime else 0 end before_avg_etime,
       case when period_flag = 'After' then execs else 0 end after_execs,
       case when period_flag = 'After' then avg_etime else 0 end after_avg_etime
from ( select
        sql_id, period_flag, execs, avg_etime,
        stddev(avg_etime) over (partition by sql_id) stddev_etime
     from (
           select sql_id, period_flag, sum(execs) execs, sum(etime)/sum(decode(execs,0,1,execs)) avg_etime from (
              select sql_id, 'Before' period_flag,
              nvl(executions_delta,0) execs,
             (elapsed_time_delta)/1000000 etime -- sum((buffer_gets_delta/decode(nvl(buffer_gets_delta,0),0,1,executions_delta))) avg_lio
             from 
                DBA_HIST_SQLSTAT S, DBA_HIST_SNAPSHOT SS
             where 
                 ss.snap_id = S.snap_id and s.dbid = ss.dbid $AND_DBID
             and ss.instance_number = S.instance_number
             and executions_delta > 0
             and elapsed_time_delta > 0
             and ss.begin_interval_time <= sysdate-&&days_ago
           union
           select 
                sql_id, 'After' period_flag, nvl(executions_delta,0) execs, (elapsed_time_delta)/1000000 etime
                -- (elapsed_time_delta)/decode(nvl(executions_delta,0),0,1,executions_delta)/1000000 avg_etime
                -- sum((buffer_gets_delta/decode(nvl(buffer_gets_delta,0),0,1,executions_delta))) avg_lio
               from 
                   DBA_HIST_SQLSTAT S, DBA_HIST_SNAPSHOT SS
               where   
                    ss.snap_id = S.snap_id and s.dbid = ss.dbid $AND_DBID
                and ss.instance_number = S.instance_number
                and executions_delta > 0
                and elapsed_time_delta > 0
                and ss.begin_interval_time > sysdate-&&days_ago
              )
         group by sql_id, period_flag
      )
    )
    )
   group by sql_id, stddev_etime
   )
     where 
            norm_stddev > nvl(to_number('&min_stddev'),2)
        and max_etime > nvl(to_number('&min_etime'),0.1)
)
where result like nvl('&Faster_Slower',result)
order by norm_stddev
/
"
elif [ "$ACTION" = "UNSTABLE" ];then
#----------------------------------------------------------------------------------------
#-- Purpose:     Attempts to find SQL statements with plan instability.
#-- Author:      Kerry Osborne
#-- Usage:       This scripts prompts for two values, both of which can be left blank.
#--              min_stddev: the minimum "normalized" standard deviation between plans
#--                          (the default is 2)
#--              min_etime:  only include statements that have an avg. etime > this value
#--                          (the default is .1 second)
#-- See http://kerryosborne.oracle-guy.com/2008/10/unstable-plans/ for more info.
#---------------------------------------------------------------------------------------
SQL="
set lines 155
col execs for 999,999,999
col min_etime for 999,999.99 head 'Min execution|Time' justify c
col max_etime for 999,999.99 head 'Max execution|Time' justify c
col avg_etime for 999,999.999
col avg_lio for 999,999,999.9
col norm_stddev for 999,999.9999
col begin_interval_time for a30
col node for 99999
break on plan_hash_value on startup_time skip 1
prompt
prompt Use 'sx' and 'aw' to further research
select * from (
                select sql_id, sum(execs) execs, min(avg_etime) min_etime, max(avg_etime) max_etime, stddev_etime/min(avg_etime) norm_stddev
                       from (
                               select
                                       sql_id, plan_hash_value, execs, avg_etime,
                                       stddev(avg_etime) over (partition by sql_id) stddev_etime
                                from (
                                         select
                                            sql_id, plan_hash_value, sum(nvl(executions_delta,0)) execs,
                                            (sum(elapsed_time_delta)/decode(sum(nvl(executions_delta,0)),0,1,sum(executions_delta))/1000000) avg_etime,
                                             sum((buffer_gets_delta/decode(nvl(buffer_gets_delta,0),0,1,executions_delta))) avg_lio
                                        from
                                            DBA_HIST_SQLSTAT S,
                                            DBA_HIST_SNAPSHOT SS
                                        where
                                             ss.snap_id = S.snap_id and s.dbid = ss.dbid $AND_DBID
                                         and ss.instance_number = S.instance_number
                                         and executions_delta > 0
                                         group by sql_id, plan_hash_value
                                      )
                             ) group by sql_id, stddev_etime
               )
         where
                norm_stddev > 2
            and max_etime > 0.1
        order by norm_stddev ;
"

# .........................
#  PL/SQL
# .........................

elif [ "$ACTION" = "PLSQL" ];then
SQL="set feed on
col type format a15
col owner format a25
col name format a24
col sid format 9999
col serial format 999999
set linesize 124 pagesize 33
   SELECT
      substr(DECODE(o.kglobtyp, 7, 'PROCEDURE', 8, 'FUNCTION', 9, 'PACKAGE', 12, 'TRIGGER', 13, 'CLASS'),1,15)  "TYPE",
      substr(o.kglnaown,1,30)  "OWNER",
      substr(o.kglnaobj,1,30)  "NAME",
      s.indx  "SID",
     s.ksuseser  "SERIAL"
   FROM
     sys.X\$KGLOB  o, sys.X\$KGLPN  p, sys.X\$KSUSE  s
   WHERE
     o.inst_id = USERENV('Instance') AND
     p.inst_id = USERENV('Instance') AND
     s.inst_id = USERENV('Instance') AND
     o.kglhdpmd = 2 AND
     o.kglobtyp IN (7, 8, 9, 12, 13) AND
     p.kglpnhdl = o.kglhdadr AND
     s.addr = p.kglpnses
  ORDER BY 1, 2, 3;"

# .........................
#   expensive sql
# .........................

elif [ "$ACTION" = "HEAVY" ];then

#-------------------------------------------------------------------------------
#--
#-- Script:     expensive_sql.sql
#-- Purpose:    to find expensive sql that may need tuning
#-- For:                8.1.6 and above
#--
#-- Copyright:  (c) Ixora Pty Ltd
#-- Author:     Steve Adams
#-- Adapted to smenu by B. Polarski
#-------------------------------------------------------------------------------
NROWNUM=${NROWNUM:-5}
SQL="set linesize 190 pagesize 66
column load format a6 justify right
column executes format 9999999 head 'Execs'
column sql_text format a65 head 'Sql Text'
column child_number head 'c#' for 999
colum buffer_gets head 'gets'

break on load on $FIELD on $FIELD1 on executes on sql_id on child_number on report

select
  substr(to_char(s.pct, '99.00'), 2) || '%'  load, $FIELD,
  s.executions  executes, $FIELD1,
  p.sql_id, s.child_number,
  p.sql_text|| chr(10) sql_text
from
  (
    select
      address,
      $FIELD, $FIELD1,
      executions, sql_id, child_number,
      pct,
      rank() over (order by $FIELD desc)  ranking
    from
      (
        select address, $FIELD, executions, $FIELD1, 100 * ratio_to_report($FIELD) over ()  pct,
               sql_id, child_number
        from sys.${G}v_\$sql where command_type != 47
      )
    where
      $FIELD > 15 * executions
  )  s,
  sys.${G}v_\$sqltext  p
where
  s.ranking <= $NROWNUM and
  p.address = s.address
order by
  1 desc, s.address, p.piece;
"
 # ...............................................................................
elif [ "$ACTION" = "LOAD" ];then
    MIN_PRES=${MIN_PRES:-10000}

SQL="col cnt format 99999
col family format a52
col load head 'relative|load|on system' for 999999999
col cpu head 'cpu(ms)' for 99999999
select sql_id,$VARFIELD, cpu,disk_reads,buffer_gets buff,sorts,executions,loads,cnt, load from (
select           sql_id,
                 substr(sql_text, 1, $LEN_TEXT) sql_text,
                 sum(abs(disk_reads)) disk_reads,
                 sum(abs(buffer_gets)) buffer_gets,
                 sum(abs(sorts)) sorts,
                 sum(abs(executions)) executions,
                 sum(abs(loads)) loads,
                 sum(abs(cpu_time/1000)) cpu,
                 max(hash_value) family_hv,
                 count(*) cnt,
                 ((sum(abs(disk_reads))*100)+sum(abs(buffer_gets)))/1000 load
        from     sys.${G}v_\$sqlarea
        group by $GROUP_BY,sql_id
        having   sum(abs(disk_reads)) > $MIN_PRES
        and      sum(abs(buffer_gets)) > $MIN_PRES
        order by  load desc) $ROWNUM;
"
 # ...............................................................................
 #     default
 # ...............................................................................
elif [ "$ACTION" = "DEFAULT" ];then
SQL="
col PARSING_SCHEMA_NAME head 'Parsing|Schema name' for a22
col child_number form 99 head 'c#'
SELECT $SID executions, loads, invalidations, parse_calls,
         DISK_READS, buff, rp, cpu, $ELP0 ltl, $HT_HEADER $HT_PARSING
from (
SELECT  $SID invalidations, parse_calls, executions, loads, 
         DISK_READS, $BUF_GET $ROW_PROC CPU_TIME/1000000 cpu, $ELP $F_TIME
         , $HASH_OR_TEXT from sys.${G}v_\$sql $JOIN_TO_SESS $ADD_WHERE $FILTER1 $ORDER
  ) $ROWNUM ;"
fi
if [ -n "$SETXV" ];then
   echo "$SQL"
fi
echo $NN "MACHINE $HOST - ORACLE_SID : $ORACLE_SID $NC"
sqlplus -s "$CONNECT_STRING" <<EOF

set linesize 80
column nline newline
set pagesize 66 termout on embedded off verify off heading off pause off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  || '       $TITLE' from sys.dual
/
set head on pause off feed off linesize 190
column buff format 99999999 head "$BUF_GET_TITLE" justify c
column disk_reads format 99999999 head "Disk|reads" justify c
column User_opening format 9999 head "Nbr of|Users" justify c
column rp format 99999990 head "$ROW_PROC_TITLE" justify c
column cpu format 99999 head "cpu |Time(s)" justify c
column elp format 99999 head "elapse |Time(s)" justify c
column invalidations format 99999999 head "invali-|dations" justify c
column parse_calls format 99999999 head "parse|calls" justify c
column loads format 99999 head "loads" justify c
column executions format 99999999 head "Execs"
column sid format 9999 head "Sid"
column hasv_value format 999999999 head "  SQL|Hash_value"  justify c
column ltl format A11 head "$F_TIME_TITLE" justify c
column sqltype format 9999 head "SQL|Type" justify c
column sorts format 99999 head "Sorts" justify c
col cnt head "nbr|in|area" format 9999 justify c
col sql_text format a$LEN_TEXT

$SQL
prompt
EOF

