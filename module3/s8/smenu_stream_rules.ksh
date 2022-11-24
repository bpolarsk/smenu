#!/bin/sh
#  set -xv
# author  : B. Polarski
# program : smenu_stream_rules.ksh
# date    : 9 Decembre 2005
# I have assumed here that the rule owner is also the queue owner 
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
LEN=105
# -------------------------------------------------------------------------------------
function help 
{

  more <<EOF

     rul -ln -ls -lo -lst -app -len <LENGTH to display>
         -rn <RULE_NAME> -rs <RULE_SET_NAME> -u <RULE(_SET)_OWNER> -drop -add 
         -sn  <STREAM_NAME> -st <STREAM_TYPE> -remove -purge -switch -grant -s
         -create -t <TABLE_NAME> -so <SOURCE_OWNER> -src_sid <ORACLE_SID>

         -l  : show rules overview                              -lo : List rules per objects
         -ls : List rules sets                                  -lt : List rules types
         -ln : List rules name with text                       -lst : List rulset stats
        -add : Add a rule to a rule set                         -st : Stream type
        -app : list apply rule created with dbms_streams_adm   -len : Display rule with len character, default is 70
          -v : Verbose execution display the SQL to run before running it effectively
        -trf : list transformation functions                   -lsg  : List general rules set stats

     -create : create a rule or a rule set
              -cap :  Create a rule of type 'capture'
           -apl_sw :  Create a rule of type 'apply' with change table ownership
               -so :  Source (Table) owner                -to :  target (Table) owner
               -qn :  target queue name                    -t :  Table name
               -switch:  create a switch function using (-src_sid, -so, -to )

      -grant : grant usage of a <STREAM> to  table owner
       -drop : drop rules or rules set : see rl or rs     -u : Rule owner
     -remove : Remove a rule from a rule set             -sn : Stream name
    -src_sid :  Source ORACLE_SID
       -steps: Show Steps to set up a full install of stream between 2 DB.

    .........................................................................................................
    Stream administrator admin and his password can be deduced by smenu if you defined one for this instance
    in SM/3.8 ortherwise it will try to default to STRMADMIN/STRMADMIN
    .........................................................................................................

Create capture rule:   rul -create -cap -rn <RULE> -u <RULE_OWNER> -t <TABLE_NAME> -so <TABLE_OWNER> -src_sid <ORACLE_SID>
====================

Add a rule to rule_set:   rul  -add -rn <RULE>  -rs <RULE_SET_NAME> -u <RULE_OWNER>
=======================    

Create apply rule with switch owner :
======================================
  Generic Function : 

           rul -switch -so <SOURCE_OWNER> -to <TARGET_OWNER> -src_sid <SOURCE_SID>

  Table rule, one for each table :

           rul -apl_sw -t <TABLE_NAME> -so <SOURCE_OWNER> -to <TARGET_OWNER>   # if streams_name does not exits, 
               -src_sid <SOURCE_SID>   -sn <STREAMS_NAME> -qn <QUEUE_NAME>     # then it is created by first tbl rule   
               -u <rule_owner>

Grant object to streams:  rul -grant -sn <STREAM_NAME> -to <TARGET OWNER> -src_SID <SRC_SID>
=========================
     
Drop:
======
   To drop a rule     :   rul -drop -u <OWNER> -rn <RULE_NAME>
   To drop a rule set :   rul -drop -u <OWNER> -rs <RULE_SET_NAME>

REMOVE a rule:   rul -sn <STREAM_NAME> -st <STREAM_TYPE> -remove
==============


Purge all about a  rule:   rul -purge -src_sid <SRC_SID> -t <TABLE> -so <TABLE_OWNER>
==========================

EOF

exit
}
# -------------------------------------------------------------------------------------
function show_steps
{
  more <<EOF

 ON SOURCE DB
	-- Create admin user at source  (smenu/3.8)
	-- create queue at db source   	(aq)
 ON  TARGET DB
	-- create admin user at target	(smenu/3.8)
	-- create queue at db target  	(aq)
 ON SOURCE DB
        -- create ruleset		(rul)
               *rule set name
               *rule set owner
	-- Create capture         	(cap)
               *queue_name   
               *capture_name
               *rule_set_name
	-- Create RULE for capture 	(rul)  + grant all on <table> to strmamdin
               * rule name
               * object name
               * object owner
               * source DB
	-- Add capture rule to ruleset.  (rul)
               * rule name
               * rule owner
               * rule set name
	-- Create propagation between source and target (prop)
               * source queue
               * target queue
               * owener (of queues and prop)
               * propagation name
 ON  TARGET DB
	   Create apply:
		-- create generic switch data ownership function (rul)
                    * source owner
                    * target owner 
                    * source db
		-- Create a stream apply rule table that take input from generic switch funstion (rul)
                    * table
                    * source owner
                    * target owner
                    * source db
                    * stream name (invent one)
                    * target queue name
                    * target queue owner
	-- Grant execute of rule set to applied owner 	(rul)
                    * stream name
                    * target owner
                    * source DB name
 ON SOURCE DB
	-- Prepare source schema instantiation (cap)
                    * source owner
	-- prepare source table instantiation (cap)
                    * source owner
                    * table table name
                    * db link to use
 ON  TARGET DB
	-- set option disable on TARGET queue (app)
                    * stream name
                    * N or Y
	-- Start apply    (app)
                 * apply name
 ON SOURCE DB
	-- start capture  (cap)
                 * capture name
EOF
}
# -------------------------------------------------------------------------------------
function do_execute
{
LLEN=`expr 55 + $LEN`
$SETXV
echo
echo $NN "MACHINE $HOST - ORACLE_SID : $ORACLE_SID $NC"
sqlplus -s "$CONNECT_STRING" <<EOF
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER,15)||   '$TTITLE ' from sys.dual
/
set head on

$BREAK
set linesize $LLEN pagesize 30 long 500
col DECLARATIVE_TYPE format 9999 head Type
col FROM_SCHEMA_NAME format a16 head 'From schema'
col TO_SCHEMA_NAME format a16 head 'To schema'
col FROM_TABLE_NAME format a20 head 'From Table'
col TO_TABLE_NAME format a20 head 'To Table'
col step_number format 9999 head 'Step|Nbr' justify c
col table_name format A18 head "Table name"
col streams_name format a22 head "Streams Name"
col var format a12 head 'Variable msg |Type' Justify c
col tn format A30 head "Table name"
col sb format A9 head "Source|Database"
col SOURCE_DATABASE format A25 head "Source|Database"
col RULE_SET_OWNER format  a14
col RULE_OWNER format  a14
col TYPE format  a4
col st format  a8 head "Streams|Type" justify c
col RULE_SET_NAME format  a14 head "Rule set Name"
col rno format  a34 head "Rule Name"
col rnol format  a40 head "Rule Name"
col RULE_TYPE format  a4 head "Rule|Type"
col rc format  a$LEN head "Rule Name"
col RULE_SET_rule_COMMENT format A35
COL target_obj HEADING 'Target Object' FORMAT A32
COL source_obj HEADING 'Source Object' FORMAT A32
COL target_owner HEADING 'Object Owner' FORMAT A22
COL source_owner HEADING 'Source|Object Owner' FORMAT A22 justify l
COL tow HEADING 'Table Owner' FORMAT A14
col Text format a50
COL ACTION_CONTEXT_VALUE format a50
col INCLUDE_TAGGED_LCR format a3 head 'Inc|Tag|LCR'
col rule_name format a16
col streams_rule_type head 'Stream|Rule| Type' justify c
col FROM_COLUMN_NAME for a22
col TO_COLUMN_NAME for a22
col COLUMN_NAME  for a22

--prompt .       rul -l  [list rules]                 rul -lo [objets in rule]                     rul -ls [rules in ruleset] 
--prompt .       rul -ln [show rule text] -len <nn>   rul -app  rul -u <OWNER> -rn <RULE> -drop    rul -create (see rul -h) 
--prompt 
$SQL
EOF
}
# -------------------------------------------------------------------------------------
#                    Main
# -------------------------------------------------------------------------------------
if [ -z "$1" ];then 
   help; exit
fi

# ............ some default values and settings: .................
typeset -u ftable
typeset -u fsource_owner
typeset -u frule_owner
typeset -u ftarget_owner
typeset -u function_owner
typeset -u frule
typeset -u ftype
typeset -u fstream_name
typeset -u frule_set_name
typeset -u fqueue
if [ -f $SBIN/data/stream_$ORACLE_SID.txt ];then
   STRMADMIN=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep STRMADMIN=| cut -f2 -d=`
   STR_PASS=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep STR_PASS=| cut -f2 -d=`
   DEF_SID=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep DEF_SID=| cut -f2 -d=`
   DEST_QUEUE_NAME=$STRMADMIN.STREAMS_QUEUE@$DEST_DB
fi
STRMADMIN=${STRMADMIN:-STRMADMIN}
STRMADMIN_PASS=${STR_PASS:-STRMADMIN}
EXECUTE=NO
INCLUDE_DML=TRUE
INCLUDE_DDL=FALSE
SRC_DB=$ORACLE_SID
DEST_DB=$DEF_SID
QUEUE_NAME=$STRMADMIN.STREAMS_QUEUE
SRC_QUEUE_NAME=$STRMADMIN.STREAMS_QUEUE
DEST_QUEUE_NAME=${DEST_QUEUE_NAME:-STRMADMIN.STREAMS_QUEUE}


while [ -n "$1" ]
do
  case "$1" in
      -rn ) frule=$2; shift ;;
      -rs ) frule_set_name=$2; shift ;;
       -u ) frule_owner=$2; shift ;;
     -lst ) CHOICE=rul_sets_stats; TITTLE="List rule stats";EXECUTE=YES;;
     -lsg ) CHOICE=rul_stats; TITTLE="List general rule stats";EXECUTE=YES;;
      -so ) fsource_owner=$2; shift ;;
      -to ) ftarget_owner=$2; shift ;;
      -qn ) fqueue=$2; shift ;;
      -sn ) fstream_name=$2 ; shift ;;
      -st ) ftype=$2 ; shift ;;
       -t ) ftable=$2; shift ;;
       -l ) CHOICE=RULE ; TTITLE="List rules " ; EXECUTE=YES ;;
      -ln ) CHOICE=RULE_TEXT ; TTITLE="List rules " ; EXECUTE=YES ;;
      -lt ) CHOICE=RULE_TYPE ; TTITLE="List rules type" ; EXECUTE=YES ;;
     -cap ) CREATE_TYPE=CAP;;
     -trf ) CHOICE=LIST_TRF ;;
     -app ) CHOICE=RUL_APP ; TTITLE="Liste rules created with dbms_streams_adm" ; EXECUTE=YES;;
      -ls ) CHOICE=SETS_RULE ; TTITLE="Show rule set " ; EXECUTE=YES ;;
      -lo ) EXECUTE=YES ; TTITLE="List rules per object" ; CHOICE=RULE_OBJ ;;
  -create ) CHOICE=CREATE_RULE ; TTITLE="Create Rule" ;;
   -grant ) CHOICE=GRANT ; TTITEL="Grant streams usage to user" ;;
 -src_sid ) SRC_SID=$2 ; shift ;;
  -switch ) CHOICE=SWITCH ; TTITLE="Create function switch ownership" ;;
  -apl_sw ) CHOICE=SWITCH_TBL ; TTITLE="Create rule for switch table ownership" ;;
     -add ) CHOICE=ADD_RULE ; TTITLE="Add a Rule to a Rule set" ;;
    -drop ) CHOICE=DROP_RULE ;;
   -purge ) CHOICE=PURGE_RULE  ; TTITLE="Purge a rule" ;;
  -remove ) CHOICE=REMOVE_RULE ; TTITLE="Remove a rule" ;;
       -v ) SETXV="set -xv";;
       -x ) EXECUTE=YES;;
     -len ) LEN=$2; shift ;;
    -steps) show_steps ; exit ;;
        * ) echo "Invalid argument $1" ; help ;;
 esac
 shift
done
vers=$SBINS/smenu_get_ora_version.sh
if [  "$CHOICE" = "DROP_RULE" -o "$CHOICE" = "CREATE_RULE" -o "$CHOICE" = "SWITCH"  -o  "$CHOICE" = "SWITCH_TBL" ];then
   export S_USER=$frule_owner
   S_USER=${S_USER:-$STRMADMIN}
fi
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# .................................................
# List rules set stats
# .................................................
if [ "$CHOICE" = "LIST_TRF" ];then
EXECUTE=YES
SQL="set lines 190
col COLUMN_FUNCTION format a10
col column_name format a12
select RULE_NAME, DECLARATIVE_TYPE, FROM_SCHEMA_NAME, TO_SCHEMA_NAME,FROM_TABLE_NAME,TO_TABLE_NAME, TABLE_NAME, column_name,
STEP_NUMBER,COLUMN_FUNCTION from STREAMS\$_INTERNAL_TRANSFORM ;
"
# .................................................
# List rules types
# .................................................

elif [ "$CHOICE" = "RULE_TYPE" ];then
SQL="set linesize 150
select STREAMS_TYPE , STREAMS_NAME, RULE_NAME , STREAMS_RULE_TYPE, RULE_TYPE ,SOURCE_DATABASE , 
      OBJECT_NAME from SYS.DBA_STREAMS_RULES;"
elif [ "$CHOICE" = "GRANT" ];then
    SQL="DECLARE
rs_name VARCHAR2(64); -- Variable to hold rule set name
BEGIN
SELECT RULE_SET_OWNER||'.'||RULE_SET_NAME INTO rs_name FROM DBA_APPLY WHERE APPLY_NAME='$fstream_name';
DBMS_RULE_ADM.GRANT_OBJECT_PRIVILEGE( privilege => SYS.DBMS_RULE_ADM.EXECUTE_ON_RULE_SET, object_name => rs_name, grantee => '$ftarget_owner'); END;
/
prompt doing 'grant execute on ${SRC_SID}_to_${ftarget_owner} to $ftarget_owner ;'
prompt may fails if the current user has not enought privilege
grant execute on ${SRC_SID}_to_${ftarget_owner} to $ftarget_owner 
/
"

# .................................................
# List rules set stats
# .................................................

elif [ "$CHOICE" = "rul_stats" ];then
SQL="col name format a60 head 'Name'
select name, value from  V\$RULE_SET_AGGREGATE_STATS;"
elif [ "$CHOICE" = "rul_sets_stats" ];then
SQL="col name format a20 head 'rule set name'
set linesize 132
select NAME ,CPU_TIME,FIRST_LOAD_TIME,LAST_LOAD_TIME,EVALUATIONS,CONDITIONS_PROCESSED,EVALUATION_FUNCTION_CALLS 
     from V\$RULE_SET order by 1;"
# .................................................
# List rules created with dbms_streams_adm
# .................................................
elif [ "$CHOICE" = "RUL_APP" ];then
  BREAK="break on streams_name on source_obj on sb"
  SQL="select streams_name ,table_owner||'.'||table_name source_obj, SOURCE_DATABASE sb, RULE_TYPE ||' TABLE RULE' TYPE ,
       INCLUDE_TAGGED_LCR, rule_owner||'.'||rule_name rno from dba_streams_table_rules where streams_type = 'APPLY'
UNION
select streams_name ,schema_name source_obj, SOURCE_DATABASE sb, RULE_TYPE ||' SCHEMA RULE' TYPE , INCLUDE_TAGGED_LCR,
rule_owner||'.'||rule_name rno from dba_streams_schema_rules where streams_type = 'APPLY'
UNION
select streams_name ,' ' source_obj, SOURCE_DATABASE sb, RULE_TYPE ||' GLOBAL RULE' TYPE , INCLUDE_TAGGED_LCR,
rule_owner||'.'||rule_name rno from dba_streams_GLOBAL_rules where streams_type = 'APPLY' order by 1,2;"

# .................................................
# Create a rule with switch ownership
# .................................................
elif [ "$CHOICE" = "SWITCH_TBL" ];then
   SQL="DECLARE
action_ctx SYS.RE\$NV_LIST;
ac_name varchar2(30) := 'STREAMS\$_TRANSFORM_FUNCTION';
v_dmlrule VARCHAR2( 128 );
v_ddlrule VARCHAR2( 128 );
rs_name VARCHAR2(64);
BEGIN
DBMS_STREAMS_ADM.ADD_TABLE_RULES( table_name  => '${fsource_owner}.${ftable}', streams_type => 'APPLY',
streams_name => '${fstream_name}', queue_name => '${frule_owner}.${fqueue}', include_dml => true, include_ddl => false,
dml_rule_name => v_dmlrule, ddl_rule_name => v_ddlrule, source_database => '$SRC_SID');

select rule_name into v_dmlrule from dba_rules where rule_owner='${frule_owner}' and RULE_CONDITION LIKE '%${ftable}%';
select rule_action_context into action_ctx from dba_rules where rule_owner='${frule_owner}' and rule_name = v_dmlrule;

action_ctx := SYS.RE\$NV_LIST(SYS.RE\$NV_ARRAY());
action_ctx.ADD_PAIR(ac_name,SYS.ANYDATA.CONVERTVARCHAR2('$frule_owner.${SRC_SID}_to_${ftarget_owner}'));
DBMS_RULE_ADM.ALTER_RULE(rule_name => v_dmlrule,action_context => action_ctx );
END;
/
prompt *********************************************************
prompt Doing 'grant all on ${ftarget_owner}.${ftable} to $frule_owner ;'
prompt This may fail if the current user does not have enought right. You will have to do it manually then.
prompt *********************************************************
prompt
grant all on ${ftarget_owner}.${ftable} to $frule_owner 
/
"


# .................................................
# Create generic apply rule
# .................................................
elif [ "$CHOICE" = "SWITCH" ];then
   SQL="CREATE OR REPLACE FUNCTION ${SRC_SID}_to_${ftarget_owner} ( p_in_data IN SYS.ANYDATA) RETURN SYS.ANYDATA IS
out_data SYS.LCR\$_ROW_RECORD;
tc PLS_INTEGER;
typenm VARCHAR2(61);
BEGIN
typenm := p_in_data.GETTYPENAME();
IF typenm = 'SYS.LCR\$_ROW_RECORD' THEN
-- Typecast AnyData to LCR\$_ROW_RECORD
tc := p_in_data.GETOBJECT(out_data);
IF out_data.GET_OBJECT_OWNER() = '${fsource_owner}' THEN
-- Transform the in_data into out_data
out_data.SET_OBJECT_OWNER('${ftarget_owner}');
END IF;
-- Convert to AnyData
RETURN SYS.AnyData.ConvertObject(out_data);
ELSE
RETURN p_in_data;
END IF;
END;
/
"

# .................................................
# Create a rule 
# .................................................
elif [ "$CHOICE" = "CREATE_RULE" ];then
   if [ -n "$frule_set_name" ];then
   # create a ruleset
     SQL="execute DBMS_RULE_ADM.CREATE_RULE_SET(rule_set_name => '$frule_owner.$frule_set_name', evaluation_context => 'sys.streams\$_evaluation_context');"
   else
      case $CREATE_TYPE in
          CAP ) SQL=" execute DBMS_RULE_ADM.CREATE_RULE ( rule_name => '$frule',  condition => ':dml.get_object_owner() = ''$fsource_owner'' AND  '|| ':dml.get_object_name() = ''$ftable''  AND  '|| ':dml.get_source_database_name() = ''$SRC_SID'''); "
              ;;
           *  ) echo "I need the type of rule to create ie: -cap"
                exit 0 ;;
      esac
   fi

# .................................................
# Add a rule to a rule set
# .................................................
elif [ "$CHOICE" = "ADD_RULE" ];then
     SQL="execute DBMS_RULE_ADM.ADD_RULE( rule_name => '$frule_owner.$frule', rule_set_name => '$frule_owner.$frule_set_name', evaluation_context => NULL);"

# .................................................
# remove a rule
# .................................................
elif [ "$CHOICE" = "REMOVE_RULE" ];then
   if [ -n "$frule" ];then
      echo "I need a rule name, a stream name and a stream type"
   fi
   SQL="execute DBMS_STREAMS_ADM.REMOVE_RULE( rule_name => '$frule', streams_type => '$ftype', streams_name => '$fstream_name') ;"


# .................................................
# Drop a rule
# .................................................
elif [ "$CHOICE" = "DROP_RULE" ];then
   if [ $vers = 9 ];then
   if [ -n "$frule_set_name" ];then
     SQL="execute DBMS_RULE_ADM.DROP_RULE_SET( rule_set_name => '$frule_owner.$frule_set_name', delete_rules => true);"
   elif [ -n "$frule" ];then
      SQL="execute DBMS_RULE_ADM.DROP_RULE( rule_name => '$frule_owner.$frule', force => true);"
   fi
   else # 10
   if [ -n "$frule_set_name" ];then
     SQL="execute DBMS_RULE_ADM.DROP_RULE_SET( rule_set_name => '$frule_set_name', delete_rules => true);"
   elif [ -n "$frule" ];then
      SQL="execute DBMS_RULE_ADM.DROP_RULE( rule_name => '$frule', force => true);"
   fi
   fi

# .................................................
# Purge datadictionary from a rule
# .................................................
elif [ "$CHOICE" = "PURGE_RULE" ];then
     SQL="execute DBMS_STREAMS_ADM.PURGE_SOURCE_CATALOG( source_database => '$SRC_SID', source_object_name => '$fsource_owner.$ftable', source_object_type => 'TABLE');"

# .................................................
# List rule and its condition
# .................................................
elif [ "$CHOICE" = "RULE" ];then
   if [ -n "$frule" ];then
       WHERE_R=" where rule_name = '$frule' "
   fi
   BREAK="break on rule_owner on ACTION_CONTEXT_VALUE"
   SQL=" 
prompt Without a transform function, source obj name is also target obj name
prompt
select rule_owner,rule_name,
      substr(rule_condition,
              instr(rule_condition,'''',instr(rule_condition,'dml.get_object_name()')+20,1)+1,
                          (instr(rule_condition,'''',instr(rule_condition,'dml.get_object_name() =')+20,2))-
              (instr(rule_condition,'''',instr(rule_condition,'dml.get_object_name() =')+20,1))-1
                          ) source_obj,
      substr(rule_condition,
              instr(rule_condition,'''',instr(rule_condition,'dml.get_object_owner()')+21,1)+1,
                          (instr(rule_condition,'''',instr(rule_condition,'dml.get_object_owner() =')+21,2))-
              (instr(rule_condition,'''',instr(rule_condition,'dml.get_object_owner() =')+21,1))-1
                          ) source_owner,
                          rule_condition text
      from dba_rules $WHERE_R order by rule_owner,rule_name
/
-- SELECT ac.NVN_VALUE.ACCESSVARCHAR2() ACTION_CONTEXT_VALUE, r.RULE_NAME
--   FROM DBA_RULES r, TABLE(R.RULE_ACTION_CONTEXT.ACTX_LIST) ac,
--        DBA_RULE_SET_RULES s
--   WHERE 
--        ac.NVN_NAME  like  ('%TRANSFORM_FUNC%' ) and
--         r.RULE_NAME      = s.RULE_NAME AND
--         r.RULE_OWNER     = s.RULE_OWNER
--   order by 1,2;

col TRANSFORM_FUNCTION_NAME for a40
col VALUE_TYPE for a30
select RULE_OWNER, RULE_NAME, TRANSFORM_FUNCTION_NAME, CUSTOM_TYPE
       from DBA_STREAMS_TRANSFORM_FUNCTION;

prompt Steps) DECLARATIVE_TYPE=1 ->delete column ; DECLARATIVE_TYPE=2 ->rename col ; DECLARATIVE_TYPE=3 ->add col
select RULE_NAME, DECLARATIVE_TYPE, FROM_COLUMN_NAME, TO_COLUMN_NAME,COLUMN_NAME, TABLE_NAME,
STEP_NUMBER,COLUMN_FUNCTION from STREAMS\$_INTERNAL_TRANSFORM  where DECLARATIVE_TYPE < 4;
  prompt table and schema transformation
select RULE_NAME, DECLARATIVE_TYPE, FROM_SCHEMA_NAME, TO_SCHEMA_NAME,FROM_TABLE_NAME,TO_TABLE_NAME,
STEP_NUMBER from STREAMS\$_INTERNAL_TRANSFORM  where DECLARATIVE_TYPE > 3 ;
"

# .................................................
# List rule and its condition
# .................................................
elif [ "$CHOICE" = "RULE_TEXT" ];then
   if [ -n "$frule" ];then
       WHERE_R=" where rule_name = '$frule' "
   fi
   BREAK="break on rule_owner"
   SQL="select rule_owner,rule_name,substr(rule_condition,1,$LEN) rc from dba_rules $WHERE_R order by rule_owner,rule_name;"

# .................................................
# List rules sets and rule in each rule set
# .................................................
elif [ "$CHOICE" = "SETS_RULE" ];then
  BREAK="break on RULE_SET_OWNER on rule_owner on RULE_SET_NAME"
  SQL=" set lines 190  feed off
col OBJECT_NAME format a18
col schema_NAME format a18
col rule_name forma a20
col dec_type format a55 head 'Declarative transformation Function' justify c
break on STREAMS_TYPE on STREAMS_NAME on RULE_SET_NAME
select
STREAMS_TYPE, 
STREAMS_NAME , RULE_SET_NAME, 
RULE_NAME, RULE_TYPE,
substr(RULE_SET_TYPE,1,3) type, STREAMS_RULE_TYPE
,schema_name,OBJECT_NAME,INCLUDE_TAGGED_LCR, SOURCE_DATABASE
from DBA_STREAMS_RULES order by STREAMS_TYPE, STREAMS_NAME,RULE_SET_NAME, SCHEMA_NAME,OBJECT_NAME
/
prompt 
prompt Declarative transformations:
prompt 
select rule_name, case DECLARATIVE_TYPE 
        when 5 then 'Type 5 Rename owner  : ' || FROM_SCHEMA_NAME ||' --> '||TO_SCHEMA_NAME
        when 4 then 'Type 4 Rename table  : ' || FROM_TABLE_NAME ||' --> '||TO_TABLE_NAME
        when 3 then 'Type 3 Add column    : ' || COLUMN_NAME || ' type : ' || to_char(COLUMN_TYPE)
        when 2 then 'Type 2 Rename column : ' || FROM_COLUMN_NAME||' --> '||TO_COLUMN_NAME
        when 1 then 'Type 1 Delete column : ' || COLUMN_NAME
        end  as dec_type, COLUMN_FUNCTION
    from STREAMS\$_INTERNAL_TRANSFORM ;
prompt 
prompt Custom transformation functions:
prompt 
col VALUE_TYPE format a30
col TRANSFORM_FUNCTION_NAME format a30
select RULE_NAME,VALUE_TYPE,TRANSFORM_FUNCTION_NAME,CUSTOM_TYPE from SYS.DBA_STREAMS_TRANSFORM_FUNCTION
order by TRANSFORM_FUNCTION_NAME, RULE_NAME; 
prompt 
"
# .................................................
# List rules per objects
# .................................................
elif [ "$CHOICE" = "RULE_OBJ" ];then
  BREAK="break on streams_name on tn"
  SQL="SELECT streams_name,table_name tn, rule_owner||'.'||rule_name rno, rule_type, streams_type st, table_owner tow, source_database sb
        FROM DBA_STREAMS_TABLE_RULES order by source_database , table_name ,rule_type ;"
fi

if [ "$EXECUTE" = "YES" ];then
   do_execute
else
  echo "$SQL"
fi
