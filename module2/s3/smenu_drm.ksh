#!/bin/ksh
# B. Polarski
# Creation : 12-Jan-2008
# History  : 03-Apr-2009   Added option -s, -set. Option -l has been enhanced
#
echo "drm is too dangerous for a system production"
echo "remove the exit to use it"
#exit
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

# ----------------------------------------------------------------
function help {

cat <<EOF

 RESOURCE GROUP MANAGER (drm) usage : 
   
          drm     -lw                     #  List Maintenance plan windows
          drm     -lp                     #  List plan
          drm     -sh                     #  List plan stats history
          drm     -u                      #  List users assigned to groups
          drm     -ld                     #  List plan directive
          drm     -lg                     #  List consumer groups
          drm     -lsg  [-rac]            #  List consumer group stats
          drm     -lh                     #  List resource plan history
          drm     -ls  [-rac]             #  List stats for group sessions
          drm     -la                     #  List active resource plan manager
          drm     -lm                     #  List consumer group mapping

alter  PLAN / DIRECTIVE / GROUP:

          drm     -active  <plan> | -reset                            # Activate or deactivate a plan
          drm     -clp                                                # Clear pending area
          drm     -crp <plan>   [-co <"COMMENT">]                     # Create plan
          drm     -crg <group>  [-co <"COMMENT">]                     # Create Consumer group 
          drm     -drg <plan>                                         # Delete consumer group
          drm     -drp <plan>                                         # Delete Plan
          drm     -add -p plan -g group                               # Add group to plan
          drm     -p plan -g group  -cpu[1-7] <nn>                    # Add CPU restriction to group for level 'n'
          drm     -set <USER> -g <CONSUMER_GRP>                       # set the initial consumer group 

          -g <plan>                           # Plan name
          -g <group>                          # Group name
          -v                                  # Verbose

Example : 

      drm -p MY_PLAN -g MY_GROUP -cpu2 30      # Restrict grp MY_GROUP in MY_PLAN to max of 30% cpu in second level

Remember than constraints on resources only apply if the db as reached the level of load where the constraint could start apply.
If MY_GROUP is constrained 30% and db load is only 10% then MY_GROUP has 90% CPU potential despite the 30% constraint.

EOF
exit
}
# ----------------------------------------------------------------
if [ -z "$1" -o "$1" = "-h" ];then
   help
fi
ROWNUM=30
typeset -u fplan
typeset -u fgroup
typeset -u fdirctv

while [ -n "$1" ]
do
  case "$1" in
-active ) req=ACTIVE_PLAN; PLAN=$2; shift ;;
-reset  ) req=RESET_ACTIVE_PLAN;;
   -add ) req=ADD ;; 
   -clp ) req=CLEAR_PENDING ;EXECUTE=YES ;;
    -co ) COMMENT="$2" ;;
  -cpu1 ) CPU1=$2 ; req=ALTER ;shift ;;
  -cpu2 ) CPU2=$2 ; req=ALTER ;shift ;;
  -cpu3 ) CPU3=$2 ; req=ALTER ;shift ;;
  -cpu4 ) CPU4=$2 ; req=ALTER ;shift ;;
  -cpu5 ) CPU5=$2 ; req=ALTER ;shift ;;
  -cpu6 ) CPU6=$2 ; req=ALTER ;shift ;;
  -cpu7 ) CPU7=$2 ; req=ALTER ;shift ;;
   -crg ) req=CREATE_CONSUMER_GROUP ; fgroup=$2; shift ;;
   -crp ) req=CR_PLAN ; fplan=$2; shift  ;;
   -drp ) req=DEL_PLAN ; fplan=$2; shift  ;;
   -drg ) req=DELETE_CONSUMER_GROUP ; fgroup=$2; shift ;;
     -g ) fgroup=$2; shift ;;
    -la ) req=LIST_ACTIVE ;EXECUTE=YES ;;
    -ld ) req=LIST_DIRECTIVES ;EXECUTE=YES ;;
    -lg ) req=LIST_GRP ; EXECUTE=YES ;;
    -lh ) req=LIST_HISTORY ;EXECUTE=YES ;;
   -lsg ) req=GROUP_STAT;EXECUTE=YES;;
    -lm ) req=LIST_MAP ;EXECUTE=YES ;;
    -lp ) req=LIST_PLAN ;EXECUTE=YES ;;
    -ls ) req=SESS_STAT;EXECUTE=YES;;
    -lw ) req=LIST_WINDOWS;EXECUTE=YES;;
     -p ) fplan=$2; shift ;;
   -rac ) INST_ID="INST_ID," ; RAC=G;;
 -ratio ) RATIO=" , cpu_mth=> 'RATIO' " ;;
    -rn ) ROWNUM=$2; shift  ;;
   -set ) req=SET_GRP; F_USER=$2 ; shift ;;
    -sh ) req=STAT_HIST;EXECUTE=YES;;
     -u ) req=LIST_USER ;EXECUTE=YES ;;
     -h ) help ;;
     -x ) EXECUTE=YES ;;
     -v ) VERBOSE=TRUE;;
  esac
  shift
done

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# ............................................................
# List windows maintenance plan
# ............................................................
if [ "$req" = "LIST_WINDOWS" ];then
SQL="
set lines 157 pages 66
col window_name format a17
col RESOURCE_PLAN format a25
col LAST_START_DATE format a50
col duration format a15
col SCHEDULE_OWNER format a15
col enabled format a5
col active head 'Currently|active' justify c format a9
select SCHEDULE_OWNER, window_name, RESOURCE_PLAN,  LAST_START_DATE, DURATION, active, enabled 
 from DBA_SCHEDULER_WINDOWS;
"
# ............................................................
# Add group to plan 
# ............................................................
elif [ "$req" = "ADD" ];then
  if [ -z "$fplan" ];then
     echo "No Plan  given"
     exit
  fi
  if [ -z "$fgroup" ];then
     echo "No group or subplan given"
     exit
  fi
  if [ -n "$CPU1" ];then   C1=", new_cpu_p1=> $CPU1" ; fi
  if [ -n "$CPU2" ];then   C2=", new_cpu_p2=> $CPU2" ; fi
  if [ -n "$CPU3" ];then   C3=", new_cpu_p3=> $CPU3" ; fi
  if [ -n "$CPU4" ];then   C4=", new_cpu_p4=> $CPU4" ; fi
  if [ -n "$CPU5" ];then   C5=", new_cpu_p5=> $CPU5" ; fi
  if [ -n "$CPU6" ];then   C6=", new_cpu_p6=> $CPU6" ; fi
  if [ -n "$CPU7" ];then   C7=", new_cpu_p7=> $CPU7" ; fi
SQL="
exec DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA;
exec dbms_resource_manager.create_plan_directive( plan => '$fplan', group_or_subplan => '$fgroup' , comment => '$comment' $C1 $C2 $C3 $C4 $C5 $C6 $C7 ) ;
exec DBMS_RESOURCE_MANAGER.VALIDATE_PENDING_AREA;
exec DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA;
"

# ............................................................
# Alter plan
# ............................................................
elif [ "$req" = "ALTER" ];then

  if [ -z "$fplan" ];then
     echo "No Plan  given"
     exit
  fi
  if [ -z "$fgroup" ];then
     echo "No group or subplan given"
     exit
  fi
  if [ -n "$CPU1" ];then   C1=", new_cpu_p1=> $CPU1" ; fi
  if [ -n "$CPU2" ];then   C2=", new_cpu_p2=> $CPU2" ; fi
  if [ -n "$CPU3" ];then   C3=", new_cpu_p3=> $CPU3" ; fi
  if [ -n "$CPU4" ];then   C4=", new_cpu_p4=> $CPU4" ; fi
  if [ -n "$CPU5" ];then   C5=", new_cpu_p5=> $CPU5" ; fi
  if [ -n "$CPU6" ];then   C6=", new_cpu_p6=> $CPU6" ; fi
  if [ -n "$CPU7" ];then   C7=", new_cpu_p7=> $CPU7" ; fi
SQL="
set feed on verify on
prompt
prompt doing : exec dbms_resource_manager.update_plan_directive ( plan => '$fplan', group_or_subplan => '$fgroup'  $C1 $C2 $C3 $C4 $C5 $C6 $C7 ) ;;
exec DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA;
exec dbms_resource_manager.update_plan_directive( plan => '$fplan', group_or_subplan => '$fgroup'  $C1 $C2 $C3 $C4 $C5 $C6 $C7 ) ;
exec DBMS_RESOURCE_MANAGER.VALIDATE_PENDING_AREA;
exec DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA;
"
# ............................................................
elif [ "$req" = "CLEAR_PENDING" ];then
# ............................................................
SQL="
set feed on
execute dbms_resource_manager.clear_pending_area ;
prompt
"
# ............................................................
elif [ "$req" = "LIST_MAP" ];then
TITTLE="List consumer group mapping"
SQL="col value format a30 trunc
col attribute format a20 trunc
col consumer_group format a20 trunc
break on CONSUMER_GROUP skip 1
SELECT CONSUMER_GROUP,ATTRIBUTE, VALUE from DBA_RSRC_GROUP_MAPPINGS order by 1;
"

# ............................................................
elif [ "$req" = "STAT_HIST" ];then
TITTLE="List history stats"
SQL="
col max_seq new_value max_seq noprint ;
col REQUESTS head 'Cumulative|number of|requests'
col ACTIVE_SESS_LIMIT_HIT head 'Number|sessions|queued' justify c
col UNDO_LIMIT_HIT head '# Queries|cancelled on| undo limit' justify c
col SESSION_SWITCHES_IN head '# Sess|Switched in|Cons grp'
col SESSION_SWITCHES_out head '# Sess|Switched out|Cons grp'
col ACTIVE_SESS_KILLED head '# Sess kill|on Exceed|Switch_time'
col IDLE_SESS_KILLED head '# Sess kill|on idle exceed' justify c
col IDLE_BLKR_SESS_KILLED head '#Sess kill|on blocking|Too long' justify c
col name for a16 head 'Name'
col QUEUE_TIME_OUTS head '# Session|out due to|long queuing' justify c
col QUEUED_TIME head 'Tot Session|Queue time' justify c
col YIELDS head '#of Sess|Yield CPU'
select max(sequence#) max_seq from ${RAC}V\$RSRC_CONS_GROUP_HISTORY;
select $INST_ID  NAME, REQUESTS , CPU_WAIT_TIME, CPU_WAITS ,
                round(CONSUMED_CPU_TIME/1000,1) CONSUMED_CPU_TIME ,YIELDS ,UNDO_LIMIT_HIT ,ACTIVE_SESS_LIMIT_HIT
from ${RAC}V\$RSRC_CONS_GROUP_HISTORY where sequence#=&max_seq order by name;
prompt
select $INST_ID  name, CONSUMED_CPU_TIME
  ,SQL_CANCELED,ACTIVE_SESS_KILLED,IDLE_SESS_KILLED,IDLE_BLKR_SESS_KILLED,QUEUED_TIME,QUEUE_TIME_OUTS 
   from ${RAC}V\$RSRC_CONS_GROUP_HISTORY where sequence#=&max_seq ;
"
# ............................................................
elif [ "$req" = "GROUP_STAT" ];then
    if [ -n "$RAC" ];then  
       ORDER='order by inst_id,2'
    fi
TITTLE="List active consumer group statistics"
SQL="set feed on
col CPU_WAIT_TIME head 'Cpu Wait|Time' justify c
col Queue_length head 'Queue| Length'
col CPU_WAITS head '#Cpu| Waits' justify c
col REQUESTS head 'Cumulative|number of|requests'
col ACTIVE_SESSION_LIMIT_HIT head 'Number|sessions|queued' justify c
col ACTIVE_SESSIONS head 'Active|sessions' justify c
col UNDO_LIMIT_HIT head '# Queries|cancelled on| undo limit' justify c
col SESSION_SWITCHES_IN head '# Sess|Switched in|Cons grp'
col SESSION_SWITCHES_out head '# Sess|Switched out|Cons grp'
col ACTIVE_SESSIONS_KILLED head '#Sess kill|on Exceed|Switch_time'
col IDLE_SESSIONS_KILLED head '# Sess kill|on idle exceed' justify c
col IDLE_BLKR_SESSIONS_KILLED head '#Sess killed|on blocking|Too long' justify c
col name for a16 head 'Name'
col QUEUE_TIME_OUTS head '# Session|out due to|long queuing' justify c
col QUEUED_TIME head 'Total| Session|Queue time' justify c
col YIELDS head '#of Sess|Yield CPU'
col EXECUTION_WAITERS head 'Session Wait|for Exec'
col CONSUMED_CPU_TIME head 'Consumed|Cpu time(s)'
break on inst_id skip 1
SELECT $INST_ID name, active_sessions, queue_length,
  consumed_cpu_time, cpu_waits, cpu_wait_time,EXECUTION_WAITERS,QUEUED_TIME,QUEUE_TIME_OUTS
  FROM ${RAC}v\$rsrc_consumer_group $ORDER;
SELECT $INST_ID name
       YIELDS,ACTIVE_SESSION_LIMIT_HIT,SESSION_SWITCHES_IN,SESSION_SWITCHES_OUT,
       ACTIVE_SESSIONS_KILLED,IDLE_SESSIONS_KILLED,IDLE_BLKR_SESSIONS_KILLED
  FROM ${RAC}v\$rsrc_consumer_group $ORDER;
"
# ............................................................
elif [ "$req" = "SESS_STAT" ];then
    if [ -n "$RAC" ];then
         SE='se.' 
         AND_INST_ID=' and se.inst_id = co.inst_id '
         ORDER_INST_ID='se.inst_id,'
    fi
TITTLE="List consumer group Session statistics"
SQL="
col state for a12
break on consumer_group 
SELECT  $SE$INST_ID co.name consumer_group,  se.sid sess_id, 
 se.state, se.consumed_cpu_time cpu_time, se.cpu_wait_time, se.queued_time
 FROM ${RAC}v\$rsrc_session_info se, ${RAC}v\$rsrc_consumer_group co
 WHERE se.current_consumer_group_id = co.id $AND_INST_ID
    order by $ORDER_INST_ID cpu_time desc;
"
# ............................................................
elif [ "$req" = "SET_GRP" ];then
SQL="set head off
prompt Doing : exec DBMS_RESOURCE_MANAGER.SET_INITIAL_CONSUMER_GROUP('$F_USER','$fgroup') ;;
exec dbms_resource_manager_privs.grant_switch_consumer_group( grantee_name => '$F_USER', consumer_group => '$fgroup', grant_option => FALSE);
exec DBMS_RESOURCE_MANAGER.SET_INITIAL_CONSUMER_GROUP('$F_USER','$fgroup') ;
"
elif [ "$req" = "DELETE_CONSUMER_GROUP" ];then
SQL=" set feed on 
exec DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA;
exec DBMS_RESOURCE_MANAGER.DELETE_CONSUMER_GROUP ( consumer_group => '$fgroup' ); 
exec DBMS_RESOURCE_MANAGER.VALIDATE_PENDING_AREA;
exec DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA;
"
# ............................................................
elif [ "$req" = "CREATE_CONSUMER_GROUP" ];then
SQL=" set feed on 
exec DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA;
exec DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP ( consumer_group => '$fgroup' ,  comment =>  '$COMMENT' $CPU_MTH ); 
exec DBMS_RESOURCE_MANAGER.VALIDATE_PENDING_AREA;
exec DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA;
"

# ............................................................
elif [ "$req" = "DEL_PLAN" ];then
SQL=" 
exec DBMS_RESOURCE_MANAGER.DELETE_PLAN (plan  => '$fplan' ) ;
"
# ............................................................
elif [ "$req" = "CR_PLAN" ];then
SQL=" 
exec DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA;
exec DBMS_RESOURCE_MANAGER.CREATE_PLAN ( plan  => '$fplan', comment =>  '$COMMENT' $RATIO  ); 
# At least one directive is required to create a plan. Alter/delete later if this group is not used.
exec DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE (PLAN => '$fplan', GROUP_OR_SUBPLAN => 'OTHER_GROUPS', 
           COMMENT => 'Lowest priority sessions', CPU_P1 => 0);
exec DBMS_RESOURCE_MANAGER.VALIDATE_PENDING_AREA;
exec DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA;
"
# ............................................................
elif [ "$req" = "LIST_HISTORY" ];then
SQL="select * from (select * from  V\$RSRC_PLAN_HISTORY order by start_time desc ) where rownum <=$ROWNUM ;"

# ............................................................
elif [ "$req" = "RESET_ACTIVE_PLAN" ];then
SQL="prompt connect as sys and do :
prompt
prompt ALTER SYSTEM SET RESOURCE_MANAGER_PLAN='' scope=both sid='*';;
prompt"
elif [ "$req" = "ACTIVE_PLAN" ];then
SQL="prompt connect as sys and do :
prompt
prompt ALTER SYSTEM SET RESOURCE_MANAGER_PLAN = '$PLAN' scope=both sid='*';;
prompt"

# ............................................................
elif [ "$req" = "LIST_ACTIVE" ];then
   TITTLE="List active resource plan manager"
   SQL="col value format a30 head 'Active plan'
set feed on
prompt Use 'drm -d' to see all groups for a plan
prompt
SELECT inst_id, nvl(VALUE,'no plan active') value FROM gV\$PARAMETER 
      WHERE name = 'resource_manager_plan' order by 1;"

# ............................................................
elif [ "$req" = "LIST_USER" ];then
   TITTLE=" List users assigned resource consumer groups"
   SQL="col username for a30
col initial_group for a7 head 'Initial|Group'
col grant_option form a6 head 'Grant|Option'
SELECT initial_rsrc_consumer_group, username FROM dba_users 
ORDER BY 1,2 ;
prompt
SELECT Granted_group, grantee, grant_option, initial_group 
       FROM dba_rsrc_consumer_group_privs  $WHERE_GROUP
       ORDER BY Granted_group;
"

# ............................................................
elif [ "$req" = "LIST_DIRECTIVES" ];then
   TITTLE="List resource plan directives"
   SQL="SELECT plan ,group_or_subplan ,cpu_p1 ,cpu_p2 ,cpu_p3 ,undo_pool ,status, 
          PARALLEL_DEGREE_LIMIT_P1,SWITCH_GROUP,MAX_IDLE_TIME,
          MAX_EST_EXEC_TIME, MAX_IDLE_BLOCKER_TIME, SWITCH_TIME_IN_CALL,MANDATORY,active_sess_pool_p1
        FROM dba_rsrc_plan_directives order by 1 ,2 ;"

# ............................................................
elif [ "$req" = "LIST_PLAN" ];then
    TITTLE="List resource plan"
    SQL="set trimspool on 
set lines 190
SELECT plan ,num_plan_directives ,cpu_method ,active_sess_pool_mth ,parallel_degree_limit_mth,
       queueing_mth ,status ,mandatory FROM dba_rsrc_plans ;

break on plan  on report
prompt
Prompt Groups in Plan:
prompt
SELECT plan ,group_or_subplan from dba_rsrc_plan_directives order by plan;
"

# ............................................................
elif [ "$req" = "LIST_GRP" ];then
    TITTLE="List Resource consmner groups"
    SQL=" SELECT consumer_group ,cpu_method ,status ,mandatory ,comments FROM dba_rsrc_consumer_groups ; "
fi
# ............................................................
#   Execute the SQL
# ............................................................
if [ "$VERBOSE" = "TRUE" ];then
   echo "$SQL"
fi

if [ "$EXECUTE" = "YES" ];then
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 120 linesize 80 pause off heading off embedded off verify off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  || '  -   $TITTLE ' 
from sys.dual
/
set embedded on heading on feedback off linesize 190 pagesize 66 
COL consumer_group      FORMAT A30  HEADING 'Consumer Group'
COL cpu_method          FORMAT A14  HEADING 'CPU Method'
COL status              FORMAT A10  HEADING 'Status'
COL mandatory           FORMAT A06  HEADING 'Manda-|tory?'
COL comments            FORMAT A105  HEADING 'Comments'
COL plan                      FORMAT A28  HEADING 'Resource Plan'
COL num_plan_directives       FORMAT 9999 HEADING '# of|Plan|Dirs'
COL active_sess_pool_mth      FORMAT A32  HEADING 'Active Session Pool Method' justify c
COL parallel_degree_limit_mth FORMAT A32  HEADING 'Parallel Limit Method' justify c
COL queueing_mth              FORMAT A18  HEADING 'Queueing Method' justify c
COL group_or_subplan          FORMAT A30  HEADING 'Group or Sub Plan'
COL type                      FORMAT A15  HEADING 'Type'
COL initial_rsrc_consumer_group  FORMAT A24  HEADING 'Resource Consumer Group'
COL username                     FORMAT A12  HEADING 'User Name'
col SWITCH_GROUP   format a13          head 'Switch|group'
col PARALLEL_DEGREE_LIMIT_P1 format 99 head 'Par|deg|limit' justify c
col cpu_p1 format 999
col cpu_p2 format 999
col cpu_p3 format 999
col cpu_p4 format 999
col MAX_EST_EXEC_TIME format 9999 head 'Max exec|time(s)' justify c
col MAX_IDLE_TIME format 999999 head 'Max idle|time(s)' justify c
col MAX_IDLE_BLOCKER_TIME format 9999 head 'Max block|time(s)' justify c
col SWITCH_TIME_IN_CALL format 9999 head 'switch time|in Call (s)' justify c
col active_sess_pool_p1 format 99999 head 'activ|sess|pool'
col undo_pool for 999999999 head 'Undo|Pool(kb)' justify c
col WINDOW_NAME format a38
prompt
$SQL
exit
EOF

else

 echo "$SQL"

fi
