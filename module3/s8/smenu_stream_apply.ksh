#!/bin/sh
#  set -xv
# author  : B. Polarski
# program : smenu_stream_apply.ksh
# date    : 9 Decembre 2005
#         : 15 October 2009    Added view/re-execute errors by type (error_number)

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
# -------------------------------------------------------------------------------------
function help
{

  cat <<EOF

     app  -an <APPLY_NAME>  -dis_err <Y|N> -sn <STREAM NAME> -l -lr -lat -c -o -p -r -s -i -dmlh -li -lo -cmp -cf
          -stop  <APPLY_NAME>  [-u <APPLY OWNER>]
          -start <APPLY_NAME>  [-u <APPLY OWNER>]
          -drop  <APPLY_NAME>  [-u <APPLY OWNER>]
          -xerr  <APPLY_NAME> | -xerr -tx <TRANSACTION ID> | -xerr -erno <nn> | -delerr <APPLY_NAME> |  -err | -erc
          -ti -to <TABLE_OWNER> -t <table> -src_sid <SID> -scn <nnnnn>
          -si -so <OWNER>  -src_sid <SID> -scn <nnnnn>
          -par <nn> | -trh <nn> -dis <Y|N> -cms <Y|N> | -trace <127|0> -an <APPLY_NAME>

          -l : List apply process                                       -p : Show apply processes progresses
         -as : List apply process                                     -prm : Show parameter for apply processes
        -cms : set commit_serialization to Y or N                       -r : Show reader process
         -lr : List apply process with full rule                        -s : Show apply server process
         -lo : List instantiated schema                                 -t : Table name
        -dis : set disable on error                                    -to : Table owner name
       -dmlh : List dml apply handler                                  -so : source Owner of the table
         -an : Apply name                                              -qn : queue name
        -err : List errors                                             -sn : stream name
        -erc : count errors                                            -tx : transaction id
     -delerr : Delete errors for apply process <APPLY_NAME>           -scn : scn number
       -xerr : re-execute errors for apply name                         -v : Verbose : show sql text
        -lat : Show measured latency between source and apply     -dis_err : Disable apply stream on error
          -c : Show coordinator process                             -trace : Set trace on a apply, 127 to trace, 0 to trace off
          -i : Show instanciated objects                              -trh : set TXN_LCR_SPILL_THRESHOLD to given value (default is 10 000)
          -o : List objects with apply on them                        -rec : set Recursive=TRUE when applicable
         -li : List object in local streams data dictionary & scn     -cmp : List compare old/new fields in LCR
         -cf : List prebuilt update conflict handler


   Delete all err msg for a queue  : app -delerr <APPLY_NAME>
   Change queue option             : app -dis_on_err <Y|N> -sn <STREAM_NAME>
   Start apply                     : app -start -an <APPLY_NAME>
   Force to instantiate scn        : app -ti -so <OWNER> -t <TABLE> -scn <nnn>  -src_sid <SID>
   Force table instantia. scn      : app -ti -so <OWNER> -t <TABLE> -src_sid <SID>
   Force schema instantia. scn     : app -si -so <OWNER>  -src_sid <SID>  -scn
   Show applied scn                : app -as
   List dml apply handlers         : app -dmlh
   To set parallism apply          : app -par <nn> -an <APPLY_NAME>
   To set TXN_LCR_SPILL_THRESHOLD  : app -trh <nn> -an <APPLY_NAME>
   To set commit_serialization     : app -cms <FULL|NONE> -an <APPLY_NAME>
   To set disable_on_error         : app -dis <Y|N> -an <APPLY_NAME>
   Set trace                       : app -trace 127 -an <APPLY_NAME>

INTANTIATION:      Remove apply schema instantiated SCN   :  app -si -so <OWNER> -src_sid <SID> -scn null -x [-recursive]
============       Remove apply table instantiated SCN    :  app -ti -t <TABLE>  -so <OWNERW> -src_sid <SID>  -scn null  -x

EXEC ERRORS:       view all errors                 : app -err [ERROR_NUMBER] [-rn <n>]      # -rn : Limit error list to first (nn) rows
                   re-execute all errors           : app -xerr <APPLY_NAME>
===========        re-execute on transaction       : app -xerr -tx <LOCAL_TRANSACTION_ID>   # Local_transaction id is in dba_apply_error (app -err)
                   re-execute all errors of type nn: app -xerr -ern <nn>                    # nn is col ERROR_NUMBER in dba_apply_error (app -err)

EOF

exit
}
# -------------------------------------------------------------------------------------
function do_execute
{
$SETXV
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER,22) || '$TTITLE (app -h for help)' nline
from sys.dual
/
set linesize 132 pagesize 66
set head on
col uappn format A30 head "Apply name"
col appn format A22 head "Apply name"
col rsn format A24 head "Rule Set name"
col rn format A30 head "Rule name"
col queue_name format A30 head "Queue name"
col server_sid format 99999 head "Server|Sid" justify c
col rt format A64 head "Rule text"
col sts format A8 head "Apply|Process|Status"
col apply_captured format A14 head "Type of|Applied Events" justify c
col hwt format A15 head "Last message"
col rsid format 99999 head "Reader|Sid" justify c
col startup format A15 head "Startup"
col deqt format A15 head "Last|Dequeue Time" justify c
col dmct format A12 head "Dequeue msg|create time" justify c
col ast format A12 head "Apply Srv| time" justify c
col eat format 999999999 head "Toal Apply|time(s)" justify c
col amsg format A12 head "Applied msg|create time" justify c
col applt format A15 head "Last|apply Time" justify c
col amct format A15 head "Last creation|at source DB" justify c
col state format A16 head "Status"
col st1 format A22 head "Status"
col apply# format 9999 head "Apl#"
col message_number format 9999 head "msg|nbr"
col terr format 9999999 head "Total|Errors"
col tap format 9999999 head "Total|Applied"
col tad format 9999999 head "Total|Admin"
col tas format 9999999 head "Total|Assigned"
col twd format 9999999 head "Total|Wait"
col TOTAL_ROLLBACKS format 9999999 head "Total|Rollback"
col twc format 9999999 head "Total|Wait|Commits"
col ms format 9999999 head "Message|Sequence"
col message_count format 9999999 head "Message|Count"
col tmdeq format 999999999999 head "Total Messages|Dequeued" Justify c
col totr format 999999999 head "Total|Received"
col edt format 999999999 head "Time(s)|process|messages" justify c
col est format 999999999 head "Time(s)|Dequeuing" justify c
col HWM_MSG_NBR  format 999999999999 head "HWM_MSG_NBR" justify c
col SCN  format 999999999999 head "Msg SCN" justify c
col LWM_MSG_NBR  format 999999999999 head "LWM_MSG_NBR" justify c
col PARAMETER HEADING 'Parameter' FORMAT A25
col VALUE HEADING 'Value' FORMAT A20
col SET_BY_USER HEADING 'Set by User?' FORMAT A20
COL SOURCE_DATABASE HEADING 'Source Database' FORMAT A8
COL SOURCE_OBJECT_OWNER HEADING 'Object Owner' FORMAT A22
COL SOURCE_OBJECT_NAME HEADING 'Object Name' FORMAT A30
COL own_obj HEADING 'Object Name' FORMAT A45
COL objt HEADING 'Object| Type' FORMAT A9
COL INSTANTIATION_SCN HEADING 'Instantiation| SCN' FORMAT 999999999999 justify c
COL IGNORE_SCN HEADING 'Ignore| SCN' FORMAT 999999999999 justify c
COL commitSCN HEADING 'Commit|applied scn' FORMAT 999999999999 justify c
COLUMN LATENCY HEADING 'Latency|in|Seconds' FORMAT 9999999
COLUMN CREATION HEADING 'Message|Creation time' FORMAT A17 justify c
COLUMN DEQUEUED_MESSAGE_NUMBER HEADING 'Last dequeued|scn ' FORMAT 999999999999 justify c
COLUMN LOCAL_TRANSACTION_ID HEADING 'ID Local|Transaction' FORMAT A11
COLUMN lnk HEADING 'Using|Dblink' format A18
COLUMN ERROR_MESSAGE HEADING 'Error Message' FORMAT A60
COLUMN SID format 99999 head 'SID'

$BREAK
$SQL
EOF
}
#To trace streams apply error to see what is going on:
#alter session set events=.10308 trace name context forever, level 8. ;
#alter session set events=.26700 trace name context forever, level 15999.;
#alter session set events=.1403 trace name errorstack level 1.;
# -------------------------------------------------------------------------------------
#                    Main
# -------------------------------------------------------------------------------------
if [ -z "$1" ];then
   help; exit
fi

# ............ some default values and settings: .................
typeset -u ftable
typeset -u fapply
typeset -u fsource_owner
typeset -u fowner
typeset -u ftype
typeset -u faction
typeset -u fqueue
typeset -u fstream_name
STRMADMIN=${STRMADMIN:-STRMADMIN}
EXECUTE=NO
ROWNUM=30
while [ -n "$1" ]
do
  case "$1" in
      -an ) fapply=$2 ; shift ;;
      -as ) EXECUTE=YES ; TTITLE="Show applied scn" ; CHOICE=SHOW_SCN ;;
       -c ) CHOICE=COORD ; TTITLE="Show coordinator process" ; EXECUTE=YES ;;
     -cf )  CHOICE=PREBUILD_CONFLICT; EXECUTE=YES;;
     -cmp ) CHOICE=CMP_ON; EXECUTE=YES;;
     -cms ) TTITLE="Set commit_serialization" ; PAR=commit_serialization ; value="'"$2"'" ; shift ;  CHOICE=SET_PAR ;;
 -dis_err ) DIS_ON_ERROR=$2 ; shift  ; CHOICE=DIS_ON_ERROR;;
  -delerr ) CHOICE=DEL_ERR ; TTITLE="delete error for dba_apply_errors" ; fapply=$2 ; shift ;;
     -dis ) TTITLE="Set Disable apply on error " ; PAR=disable_on_error ; value="'"$2"'" ; shift ;  CHOICE=SET_PAR ;;
    -dmlh ) CHOICE=DMLH ; TTITLE="List dml apply handlers" ; EXECUTE=YES ;;
    -drop ) ACTION=DROP ; CHOICE=START_STOP_DROP ; fapply=$2 ; shift  ;;
     -err ) CHOICE=ERROR ; TTITLE="Show error for apply process" ; EXECUTE=YES
           if [ -n "$2"  -a ! "$2" = "-v" -a ! "$2" = "-rn" ];then
                  ERRNO=$2 ; shift;
            fi ;;
     -erc ) CHOICE=COUNT_ERROR ; TTITLE="Count error for apply process" ; EXECUTE=YES ;;
    -erno ) ERRNO=$2 ; shift ;;
       -l ) EXECUTE=YES ; TTITLE="List apply process" ; CHOICE=LIST_APPLY ;;
     -lat ) CHOICE=LATENCY ; TTITLE="Show elapse time between creation and apply" ; EXECUTE=YES ;;
      -li ) CHOICE=LIST_SI ; TTITLE="List object in streams data dictionary and their SCN" ; EXECUTE=YES;;
      -lo ) CHOICE=LIST_SO ; TTITLE="List instantiated schema" ; EXECUTE=YES;;
       -i ) CHOICE=INSTANTIATE ; TTITLE="Show instantiated objects" ; EXECUTE=YES ;;
      -lr ) EXECUTE=YES ; TTITLE="List apply process with rule" ; CHOICE=LIST_APPLY_R ;;
       -o ) CHOICE=OBJ ; TTITLE="List objects with apply" ; EXECUTE=YES ;;
       -p ) CHOICE=PROGRESS ; TTITLE="Show apply process progress" ; EXECUTE=YES ;;
     -par ) TTITLE="Set parallel apply " ; PAR=parallelism ; value=$2 ; shift ;  CHOICE=SET_PAR ;;
     -prm ) CHOICE=PARAMETER ; TTITLE="Show apply process parameters" ; EXECUTE=YES ;;
      -qn ) fqueue=$2 ;shift ;;
       -r ) CHOICE=READER ; TTITLE="Show reader process" ; EXECUTE=YES ;;
      -rn ) ROWNUM=$2 ; shift ;;
       -t ) ftable=$2 ; shift ;;
     -rec ) RECURSIVE=TRUE ;;
       -s ) CHOICE=APPL_SERVER ; TTITLE="Show aplly server processes" ; EXECUTE=YES ;;
      -si ) CHOICE=SCHEMA_INSTANTIATE ; TTITLE="Force SCN to instantiate objects" ;;
      -so ) fsource_owner=$2; shift ;;
     -scn ) SCN=$2;shift  ;;
      -sn ) fstream_name=$2;shift  ;;
   -start ) CHOICE=START_STOP_DROP ; fapply=$2 ; shift ; ACTION=START ;;
    -stop ) ACTION=STOP ; CHOICE=START_STOP_DROP ; fapply=$2 ; shift  ;;
 -src_sid ) src_sid=$2; shift ;;
      -ti ) CHOICE=SET_INSTANTIATE ; TTITLE="Force SCN to instantiate objects" ;;
   -trace ) TTITLE="Set trace level " ; trace_level=$2 ; shift ; CHOICE=TRACE ;;
     -trh ) TTITLE="Set TXN_LCR_SPILL_THRESHOLD apply " ; value=$2 ; PAR=TXN_LCR_SPILL_THRESHOLD ; shift; CHOICE=SET_PAR ;;
      -tx ) TXN_ID=$2; shift;;
       -u ) fowner=$2 ;shift ;;
    -xerr ) CHOICE=XERROR ; TTITLE="Re-execute a queue for an apply process" ;
            if [ -n "$2" -a ! "$2" = "-tx" -a ! "$2" = "-erno" ];then
                 fapply=$2; shift
            fi ;;
       -v ) SETXV="set -xv";;
       -x ) EXECUTE=YES;;
        * ) echo "Invalid argument $1"
            help ;;
 esac
 shift
done
$SETXV
if [ "$CHOICE" = "START_STOP_DROP" -o "$CHOICE" = "SET_INSTANTIATE" -o "$CHOICE" = "SCHEMA_INSTANTIATE" -o "$CHOICE" = "XERROR" ];then
  if [ -z "$fowner" ];then
      . $SBIN/scripts/passwd.env
      . ${GET_PASSWD} $S_USER $ORACLE_SID
      if [  "x-$CONNECT_STRING" = "x-" ];then
         echo "could no get a the password of $S_USER"
         exit 0
      fi
      echo "No queue owner given, fetching first username from dba_streams_administrator"
      var=`sqlplus -s "$CONNECT_STRING"<<EOF
      set head off pagesize 0 feed off verify off
      select username from dba_streams_administrator where rownum = 1;
EOF`
      STRMADMIN=`echo $var | tr -d '\n' | awk '{print $1}'`
      S_USER=$STRMADMIN
      fowner=${STRMADMIN:-STRMADMIN}
   else
      S_USER=$fowner
   fi
   . $SBIN/scripts/passwd.env
   . ${GET_PASSWD} $S_USER $ORACLE_SID
   if [  "x-$CONNECT_STRING" = "x-" ];then
      echo "could no get a the password of $S_USER"
      echo "Trying to complete request defaulting password to match username $STRMADMIN"
      Q_PASSWD=${Q_PASSWD:-$STRMADMIN}
      CONNECT_STRING="$fowner/$Q_PASSWD"
   fi
else
   . $SBIN/scripts/passwd.env
   . ${GET_PASSWD} SYS $ORACLE_SID
fi
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

vers=`$SBINS/smenu_get_ora_version.sh`

# ......................................
# List compare old/new in LCR for update and delete
# ......................................

# ......................................
# List prebuilt update conflict handler
# ......................................

if [ "$CHOICE" = "PREBUILD_CONFLICT" ];then
    TTITLE="List prebuilt update conflict handler"
    SQL="
COLUMN OBJECT_OWNER HEADING 'Table|Owner' FORMAT A5
COLUMN OBJECT_NAME HEADING 'Table Name' FORMAT A12
COLUMN METHOD_NAME HEADING 'Method' FORMAT A12
COLUMN RESOLUTION_COLUMN HEADING 'Resolution|Column' FORMAT A13
COLUMN COLUMN_NAME HEADING 'Column Name' FORMAT A30

SELECT OBJECT_OWNER,
       OBJECT_NAME,
       METHOD_NAME,
       RESOLUTION_COLUMN,
       COLUMN_NAME
  FROM DBA_APPLY_CONFLICT_COLUMNS
  ORDER BY OBJECT_OWNER, OBJECT_NAME, RESOLUTION_COLUMN;
"
# ......................................
# List compare old/new in LCR for update and delete
# ......................................

elif [ "$CHOICE" = "CMP_ON" ];then
    TTITLE="List compare old/new in LCR for update and delete"
    SQL="
COLUMN OBJECT_OWNER HEADING 'Table Owner' FORMAT A15
COLUMN OBJECT_NAME HEADING 'Table Name' FORMAT A20
COLUMN COLUMN_NAME HEADING 'Column Name' FORMAT A20
COLUMN COMPARE_OLD_ON_DELETE HEADING 'Compare|Old On|Delete' FORMAT A7
COLUMN COMPARE_OLD_ON_UPDATE HEADING 'Compare|Old On|Update' FORMAT A7

SELECT OBJECT_OWNER,
       OBJECT_NAME,
       COLUMN_NAME,
       COMPARE_OLD_ON_DELETE,
       COMPARE_OLD_ON_UPDATE
  FROM DBA_APPLY_TABLE_COLUMNS
  WHERE APPLY_DATABASE_LINK IS NULL;
"

# ......................................
# List dml handler
# ......................................
elif [ "$CHOICE" = "DMLH" ];then
if [ -n "$ftable" ];then
   WHERE_TABLE=" where OBJECT_NAME = upper('$ftable') "
fi
SQL="col USER_PROCEDURE format a40
col OBJECT_OWNER format a18 head 'Object owner'
col OPERATION_NAME format a9 head 'Operation|Name' justify c
col ERROR_HANDLER format a4 head 'Err|hdl'
col lobs format a4
set linesize 136
break on appn on OBJECT_OWNER on OBJECT_NAME on report
select APPLY_NAME appn, OBJECT_OWNER, OBJECT_NAME,OPERATION_NAME, USER_PROCEDURE,ERROR_HANDLER
from DBA_APPLY_DML_HANDLERS $WHERE_TABLE order by 1,2,3;
"
# ......................................
# set trace
# ......................................
elif [ "$CHOICE" = "TRACE" ];then
# ......................................
# ......................................
   SQL="execute dbms_apply_adm.set_parameter(apply_name=> '$fapply' , parameter=> 'trace_level', value => $trace_level); "
# set parallelism
# ......................................
elif [ "$CHOICE" = "SET_PAR" ];then
   SQL="execute dbms_apply_adm.set_parameter(apply_name=> '$fapply' , parameter=> '$PAR', value => $value); "

# Force scn
# ................................................
elif [ "$CHOICE" = "SHOW_SCN" ];then
SQL="set lines 190
SELECT  s.apply_name appn, s.SID server_sid, to_char(r.dequeue_time,'DD/HH24:MI:SS') deqt, s.MESSAGE_SEQUENCE seq,
                to_char(s.applied_message_create_time,'DD/HH24:MI:SS') amsg,
                to_char(s.apply_time,'DD/HH24:MI:SS') dmct,
                to_char(s.apply_time,'DD/HH24:MI:SS') ast,
                s.commitscn,
                r.SID rsid,
                s.ELAPSED_DEQUEUE_TIME edt, ELAPSED_APPLY_TIME eat
       FROM  v\$streams_apply_server s, v\$streams_apply_reader r WHERE s.apply_name  = r.apply_name ;"

# ................................................
# Show apply process progresses
# ................................................
elif [ "$CHOICE" = "PROGRESS" ];then
# ................................................
SQL="
col apply_name for a30
col source_database for a30
col applied_message_number for 9999999999999 head 'Last applied SCN'
col oldest_message_number for 9999999999999 head 'Oldest applied SCN'
col applied_message_create_time head 'Applied msg|Create time'
col apply_time head 'Apply time'

select apply_name,source_database,applied_message_number,oldest_message_number,
      to_char(applied_message_create_time,'DD/HH24:MI:SS') applied_message_create_time,
      to_char(apply_time,'DD/HH24:MI:SS') apply_time
 from dba_apply_progress;"
# Force or erase table scn
# ................................................
elif [ "$CHOICE" = "SET_INSTANTIATE" ];then
   if [ "$RECURSIVE" = "TRUE" ];then
        DO_RECURSIVE=", recursive=>true "
   fi
   SCN=${SCN:-NULL}
   SQL="execute DBMS_APPLY_ADM.SET_TABLE_INSTANTIATION_SCN(  source_object_name=> '$fsource_owner.$ftable', source_database_name => '$src_sid' ,  instantiation_scn => $SCN $DO_RECURSIVE); "
# ................................................
# Force orerase schema scn
# ................................................
elif [ "$CHOICE" = "SCHEMA_INSTANTIATE" ];then
   SCN=${SCN:-NULL}
   if [ $vers = 9 ];then
      SQL="execute DBMS_APPLY_ADM.SET_SCHEMA_INSTANTIATION_SCN( source_schema_name => '$fsource_owner' , source_database_name => '$src_sid' ,  instantiation_scn => $SCN );"
   else # 10g and above
       SQL="execute DBMS_APPLY_ADM.SET_SCHEMA_INSTANTIATION_SCN( source_schema_name => '$fsource_owner' , source_database_name => '$src_sid' ,  instantiation_scn => $SCN , recursive => true);"
   fi
# ................................................
# Delete all errors
# ................................................
elif [ "$CHOICE" = "DIS_ON_ERROR" ];then
    SQL="execute DBMS_APPLY_ADM.SET_PARAMETER(apply_name =>'$fstream_name', parameter => 'disable_on_error', value => 'n');"

# ................................................
# Delete all errors
# ................................................
elif [ "$CHOICE" = "DEL_ERR" ];then
   if [ -z "$fapply" ];then
       echo "No Apply name name given, use '-an <apply name'>"
       exit
   fi
   SQL="execute DBMS_APPLY_ADM.DELETE_ALL_ERRORS( '$fapply') ;"
# ................................................
# execute a queue in error
# ................................................
elif [ "$CHOICE" = "XERROR" ];then
set -x
   # Apply a single error
   if [ -n "$TXN_ID" ];then
     SQL="execute DBMS_APPLY_ADM.EXECUTE_ERROR( local_transaction_id => '$TXN_ID');"

   # apply a set of error_number
   elif [ -n "$ERRNO" ];then
SQL="set serveroutput on size unlimited
declare
begin
  for c in (select local_transaction_id from dba_apply_error where error_number = $ERRNO )
  loop
    begin
    execute immediate 'begin  dbms_apply_adm.execute_error(local_transaction_id => :1); end; ' using c.local_transaction_id ;
    exception
      when others then null ;
    end ;
  end loop;
end;
/
"
   else
      if [ -z "$fapply" ];then
          echo "No Aplly name given"
          exit
      fi
      SQL="prompt doing execute DBMS_APPLY_ADM.EXECUTE_ALL_ERRORS( '$fapply') ;;
      execute DBMS_APPLY_ADM.EXECUTE_ALL_ERRORS( '$fapply') ;"
  fi

# ................................................
# list instantiated schema
# ................................................
elif [ "$CHOICE" = "LIST_SO" ];then
SQL="
col APPLY_DATABASE_LINK format a40
col SOURCE_DATABASE format a30
select SOURCE_DATABASE , SOURCE_SCHEMA , INSTANTIATION_SCN , APPLY_DATABASE_LINK from DBA_APPLY_INSTANTIATED_SCHEMAS ; "
# ................................................
# list instantiated objects scn
# ................................................
elif [ "$CHOICE" = "LIST_SI" ];then
if [ -n "$ftable" ];then
   AND1=" and lvl0name=upper('$ftable')"
fi
if [ -n "$fowner" ];then
   AND2=" and OWNERNAME=upper('$fowner')"
fi
SQL="
break on OWNERNAME on table_name on report
col global_name format a25
col OWNERNAME format a20
select OWNERNAME, lvl0name table_name , start_scn,global_name,baseobj#, INTCOLS,PROPERTY
      from system.logmnrc_gtlo o, system.logmnrc_dbname_uid_map m where m.logmnr_uid=o.logmnr_uid $AND1 $AND2 order by 1,2;
"
# ................................................
# list instantiated objects
# ................................................
elif [ "$CHOICE" = "INSTANTIATE" ];then
  if [ -n "$fowner" ];then
       WHERE=" where SOURCE_OBJECT_OWNER=upper('$fowner') "
  fi
    SQL="col SOURCE_DATABASE format a30
set linesize 150
select distinct SOURCE_DATABASE,
       source_object_owner||'.'||source_object_name own_obj,
       SOURCE_OBJECT_TYPE objt, instantiation_scn, IGNORE_SCN,
       apply_database_link lnk
from  DBA_APPLY_INSTANTIATED_OBJECTS   $WHERE
order by 1,2;"

# ................................................
# show count error
# ................................................
elif [ "$CHOICE" = "COUNT_ERROR" ];then
    SQL="SELECT count(1) Error_count, queue_name, ERROR_MESSAGE , error_number
          FROM DBA_APPLY_ERROR group by queue_name, error_message, error_number;"

# ................................................
# List errors
# ................................................
elif [ "$CHOICE" = "ERROR" ];then
    if [ -n "$ERRNO" ];then
        AND_ERRNO=" and error_number = $ERRNO "
SQL="
set serveroutput  on
declare
   errno NUMBER;
   ltxn  VARCHAR2(30);
   Inany   SYS.ANYDATA;
   a number ;
   l_varchar2    varchar2(4000);
   lcr           SYS.LCR\$_ROW_RECORD;
   rc            PLS_INTEGER;
   command       VARCHAR2(20);
   cmdtype       varchar2(64);
   colLen        NUMBER(3) :=30;
   valLen        NUMBER(3):= 45;
   oldColList    SYS.LCR\$_ROW_LIST;
   newColList    SYS.LCR\$_ROW_LIST;
   OldCols       VARCHAR2(2000):='';
   NewCols       VARCHAR2(2000):='';
   strOut        VARCHAR2(2000);
   str           VARCHAR2(2000);
   ddl_lcr       SYS.LCR\$_DDL_RECORD;
   proc_lcr SYS.LCR\$_PROCEDURE_RECORD;
   DDLTxt        CLOB;
   header_to_display boolean:=TRUE;

  FUNCTION retStr(InData sys.anydata) RETURN VARCHAR2 IS
     ColType   VARCHAR2(20);
     RetVal    VARCHAR2(2000);
  BEGIN
     IF InData IS NULL THEN
        RetVal:= 'ERR! EMPTY ';
     ELSE
     ColType:=InData.GETTYPENAME();
     IF ColType='SYS.NUMBER' THEN
       RetVal:=InData.AccessNumber;
     ELSIF ColType='SYS.CHAR' THEN
       RetVal:=InData.AccessChar;
     ELSIF ColType='SYS.NCHAR' THEN
       RetVal:=InData.AccessNchar;
     ELSIF ColType='SYS.VARCHAR' THEN
       RetVal:=InData.AccessVarchar;
     ELSIF ColType='SYS.VARCHAR2' THEN
       RetVal:=InData.AccessVarchar2;
     ELSIF ColType='SYS.NVARCHAR2' THEN
       RetVal:=InData.AccessNVarchar2;
     ELSIF ColType='SYS.DATE' THEN
       RetVal:=InData.AccessDate;
     ELSIF ColType='SYS.TIMESTAMP' THEN
       RetVal:=InData.AccessTimestamp;
     ELSIF ColType='SYS.TIMESTAMP WITH TIME ZONE' THEN
       RetVal:=InData.AccessTimestampTZ;
     ELSIF ColType='SYS.TIMESTAMP WITH LOCAL TIME ZONE' THEN
       RetVal:=InData.AccessTimestampLTZ;
     ELSIF ColType='SYS.INTERVAL DAY TO SECOND' THEN
       RetVal:=InData.AccessIntervalDS;
     ELSIF ColType='SYS.INTERVAL YEAR TO MONTH' THEN
       RetVal:=InData.AccessIntervalYM;
     ELSE
           RetVal:='-'||ColType||'-';
        END IF;
     END IF;
     return RetVal;
  END retStr;

function print_lcr  (InAny IN SYS.ANYDATA) return number IS
    typenm VARCHAR2(61);
    ddllcr SYS.LCR\$_DDL_RECORD;
    proclcr SYS.LCR\$_PROCEDURE_RECORD;
    rowlcr SYS.LCR\$_ROW_RECORD;
    res NUMBER;
    newlist SYS.LCR\$_ROW_LIST;
    oldlist SYS.LCR\$_ROW_LIST;
    ddl_text CLOB;
 BEGIN
    typenm := InAny.GETTYPENAME();
    dbms_output.put_line('LCR type:         ' || typenm);
    IF (typenm = 'SYS.LCR\$_DDL_RECORD') THEN
        res := InAny.GETOBJECT(ddllcr);
        dbms_output.put_line('--source database:   ' || ddllcr.GET_SOURCE_DATABASE_NAME);
        dbms_output.put_line('--is tag null:   ' || ddllcr.IS_NULL_TAG);
        DBMS_LOB.CREATETEMPORARY(ddl_text, TRUE);
        ddllcr.GET_DDL_TEXT(ddl_text);
        dbms_output.put_line('ddl: ' || ddl_text);
        DBMS_LOB.FREETEMPORARY(ddl_text);
    ELSIF (typenm = 'SYS.LCR\$_ROW_RECORD') THEN
        res := InAny.GETOBJECT(rowlcr);
        if ( header_to_display ) then
                header_to_display:=FALSE;
                dbms_output.put_line('-- source database:  :  '|| rowlcr.GET_SOURCE_DATABASE_NAME);
                dbms_output.put_line('-- is tag null:      :  '|| rowlcr.IS_NULL_TAG);
                dbms_output.put_line('-- Object            :  '|| rowlcr.get_object_owner||'.'||rowlcr.get_object_name);
                dbms_output.put_line('-- Command           :  '|| Ltrim(rowlcr.get_command_type));
                dbms_output.put_line('-- lcr creation time :  '|| to_char(rowlcr.get_source_time,'YYYY-MM-DD HH24:MI:SS'));
                dbms_output.put_line('-- Txn-ID / SCN      :  '|| rowlcr.get_transaction_id ||' / '||rowlcr.get_scn||chr(10));
        end if;
        oldColList:= rowlcr.get_values('OLD');
        newColList:= rowlcr.get_values('NEW','Y');
        strOut:= RPAD(' Column',colLen)||RPAD(' Old Value',valLen) ||RPAD(' New Value',valLen);
        dbms_output.put_line('   ');
        strOut:= RPAD('-',colLen,'-')||RPAD(' -',valLen,'-') ||RPAD(' -',valLen,'-');
        dbms_output.put_line(strOut);

        -- this old trick is derived from the old pick-a-month-pos-in-list-of-all-months-in-year

        FOR i IN 1..oldColList.Count LOOP
             OldCols:= OldCols||oldColList(i).column_name||',';
        END LOOP;

        FOR i IN 1..newColList.Count LOOP
              NewCols:= NewCols||newColList(i).column_name||',';
        END LOOP;

        -- Now, with the function INSTR, we check that the proposed column exists at least in one of the 2 lists
       FOR Col IN (SELECT column_name Name FROM all_tab_columns
              WHERE owner = rowlcr.get_object_owner
                    AND table_name = rowlcr.get_object_name
                    AND (INSTR(OldCols,column_name||',') > 0 OR INSTR(NewCols,column_name||',') > 0)
              ORDER BY column_id)
         LOOP
             strOut:= RPAD(Col.Name,colLen)||' ';
             str:= '-';
             IF INSTR(OldCols, Col.Name||',') > 0 THEN
                str:= '"'||retStr(rowlcr.Get_Value('OLD',Col.Name))||'"';
                IF str IS NULL OR str = '""' THEN
                   str:='NULL';
                ELSIF INSTR(str,'ERR!') > 0 THEN
                   str:='-';
                END IF;
             END IF;
             str:= RPAD(str,valLen); strOut:= strOut||str;
             str:= '-';
             IF INSTR(NewCols, Col.Name||',') > 0 THEN
                str:= '"'||retStr(lcr.Get_Value('NEW',Col.Name,'N'))||'"';
                IF str IS NULL OR str = '""' THEN
                   str:='NULL';
                ELSIF INSTR(str,'ERR!') > 0 THEN
                   str:='-';
                END IF;
             END IF;
             str:= RPAD(str,valLen); strOut:= strOut||str;
             dbms_output.put_line(strOut);
          END LOOP;
    ELSE
       dbms_output.put_line('Non-LCR Message with type ' || typenm);
    END IF;
    return 1;
END print_lcr;

BEGIN
    select LOCAL_TRANSACTION_ID into ltxn
           from dba_apply_error
              where ERROR_NUMBER = $ERRNO ;
    InAny := DBMS_APPLY_ADM.GET_ERROR_MESSAGE($ERRNO, ltxn);
    dbms_output.put_line('Local Transaction ID: ' || ltxn);
    a:=print_lcr(InAny);
end;
/
"
    do_execute
        exit
    fi
    SQL="col queue_name format a20
col source_database head 'Source|Database'
col SOURCE_TRANSACTION_ID head 'Source|Tx Id' for a14
col SOURCE_COMMIT_SCN for 9999999999999 head 'Source scn'
col ERROR_NUMBER for 99999999 head 'Error|Number' justify c
set lines 190 pages 66
select * from (
SELECT queue_name, message_count,
       source_database,LOCAL_TRANSACTION_ID,ERROR_NUMBER, SOURCE_TRANSACTION_ID, SOURCE_COMMIT_SCN,
     ERROR_MESSAGE FROM DBA_APPLY_ERROR where 1=1 $AND_ERRNO order by message_count desc
 ) where rownum <=$ROWNUM ;"

# ................................................
# show latency between source and target
# ................................................
elif [ "$CHOICE" = "LATENCY" ];then
    SQL="SELECT apply_name, (DEQUEUE_TIME-DEQUEUED_MESSAGE_CREATE_TIME)*86400 LATENCY, TO_CHAR(DEQUEUED_MESSAGE_CREATE_TIME,'DD-MM HH24:MI:SS') CREATION, TO_CHAR(DEQUEUE_TIME,'DD-MM HH24:MI:SS') deqt, DEQUEUED_MESSAGE_NUMBER  FROM V\$STREAMS_APPLY_READER ;"

# ................................................
#
# ................................................
elif [ "$CHOICE" = "OBJ" ];then
    BREAK="break on SOURCE_DATABASE on SOURCE_OBJECT_OWNER"
    SQL="SELECT SOURCE_DATABASE, SOURCE_OBJECT_OWNER, SOURCE_OBJECT_NAME, INSTANTIATION_SCN FROM DBA_APPLY_INSTANTIATED_OBJECTS order by SOURCE_DATABASE,SOURCE_OBJECT_OWNER;"

# ................................................
# List parameters
# ................................................
elif [ "$CHOICE" = "PARAMETER" ];then
    BREAK="break on APPLY_NAME"
    SQL="SELECT APPLY_NAME, PARAMETER, VALUE, SET_BY_USER  FROM DBA_APPLY_PARAMETERS ORDER BY APPLY_NAME ;"

# ................................................
# List applying server
# ................................................
elif [ "$CHOICE" = "APPL_SERVER" ];then
   SQL="select sid, apply_name appn, server_id, state st1, MESSAGE_SEQUENCE ms, TOTAL_MESSAGES_APPLIED tap ,
        to_char(APPLIED_MESSAGE_CREATE_TIME,'DD-MM HH24:MI:SS') amct,
        to_char(APPLY_TIME,'DD-MM HH24:MI:SS') applt ,
        TOTAL_ADMIN tad, TOTAL_ASSIGNED  tas from v\$streams_apply_server order by apply_name,server_id;"

# ................................................
# list queue readers
# ................................................
elif [ "$CHOICE" = "READER" ];then
  SQL="SELECT ap.APPLY_NAME, DECODE(ap.APPLY_CAPTURED,'YES','Captured LCRS', 'NO','User-Enqueued','UNKNOWN') APPLY_CAPTURED,
       SUBSTR(s.PROGRAM,INSTR(S.PROGRAM,'(')+1,4) PROCESS_NAME, r.STATE, r.TOTAL_MESSAGES_DEQUEUED, r.sga_used
       FROM V\$STREAMS_APPLY_READER r, V\$SESSION s, DBA_APPLY ap
       WHERE r.SID = s.SID AND
             r.SERIAL# = s.SERIAL# AND
             r.APPLY_NAME = ap.APPLY_NAME;

SELECT APPLY_NAME, sid rsid , (DEQUEUE_TIME-DEQUEUED_MESSAGE_CREATE_TIME)*86400 LATENCY,
        TO_CHAR(DEQUEUED_MESSAGE_CREATE_TIME,'HH24:MI:SS MM/DD') CREATION, TO_CHAR(DEQUEUE_TIME,'HH24:MI:SS MM/DD') deqt,
        DEQUEUED_MESSAGE_NUMBER  FROM V\$STREAMS_APPLY_READER;
"

# ................................................
# Show coordinator process
# ................................................
elif [ "$CHOICE" = "COORD" ];then
  SQL="
COLUMN APPLY_PROC FORMAT A12
COLUMN LAT_SEC FORMAT 999999999
COLUMN Message_Creation FORMAT A19 head 'Msg|Creation time' justify c
COLUMN Apply_Time FORMAT A19 head 'Msg|Apply time' justify c
COLUMN MSG_NO FORMAT 9999999999999
select apply_name appn, apply#,sid,state, total_received totr, total_applied tap, total_wait_deps twd, TOTAL_ROLLBACKS,
      total_wait_commits twc, total_errors terr, to_char(hwm_time,'DD-MM HH24:MI:SS')hwt
from v\$streams_apply_coordinator order by apply_name;

SELECT APPLY_NAME APPLY_PROC,
      (HWM_TIME-HWM_MESSAGE_CREATE_TIME)*86400 LAT_SEC,
      TO_CHAR(HWM_MESSAGE_CREATE_TIME,'HH24:MI:SS MM/DD/YY') Message_Creation,
      TO_CHAR(HWM_TIME,'HH24:MI:SS MM/DD/YY') Apply_Time,
      HWM_MESSAGE_NUMBER MSG_NO, LWM_TIME, to_char(startup_time,'DD-MM HH24:MI:SS') Startup
FROM GV\$STREAMS_APPLY_COORDINATOR;
"


# ................................................
# start stop drop
# ................................................
elif [ "$CHOICE" = "START_STOP_DROP" ];then
   SQL=" execute  DBMS_APPLY_ADM.${ACTION}_APPLY( apply_name => '$fapply');"

# ................................................
# List apply process
# ................................................
elif [ "$CHOICE" = "LIST_APPLY" ];then
  SQL="
col apply_tag format a8 head 'Apply| Tag'

col QUEUE_NAME format a24
col DDL_HANDLER format a20
col MESSAGE_HANDLER format a20
col NEGATIVE_RULE_SET_NAME format a20 head 'Negative|rule set'
col apply_user format a20
set linesize 150

  select apply_name uappn, queue_owner, DECODE(APPLY_CAPTURED, 'YES', 'Captured', 'NO',  'User-Enqueued') APPLY_CAPTURED,
       RULE_SET_NAME rsn , apply_tag, STATUS sts  from dba_apply;

  select QUEUE_NAME,DDL_HANDLER,MESSAGE_HANDLER, NEGATIVE_RULE_SET_NAME, APPLY_USER, ERROR_NUMBER,
         to_char(STATUS_CHANGE_TIME,'DD-MM-YYYY HH24:MI:SS')STATUS_CHANGE_TIME
  from dba_apply ;

set head off
select  ERROR_MESSAGE from  dba_apply;
"

# ................................................
# List apply process with rule
# ................................................
elif [ "$CHOICE" = "LIST_APPLY_R" ];then
     SQL="set long 4000
select rsr.rule_set_owner||'.'||rsr.rule_set_name rsn ,rsr.rule_owner||'.'||rsr.rule_name rn,
r.rule_condition rt from dba_rule_set_rules rsr, dba_rules r where rsr.rule_name = r.rule_name and rsr.rule_owner = r.rule_owner and rule_set_name in (select rule_set_name from dba_apply) order by rsr.rule_set_owner,rsr.rule_set_name;"

# ................... END if  ..............
fi

if [ -n "$ftable" ];then
        AND_FTABLE=" a.table_name='$ftable' and "
fi
if [ -n "$WHERE0" ];then
    SQL="$SQL $WHERE0"
fi
if [ -n "$ORDER0" ];then
    SQL="$SQL $ORDER0"
fi

if [ "$EXECUTE" = "YES" ];then
   do_execute
else
  echo "$SQL"
fi

