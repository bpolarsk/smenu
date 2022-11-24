#!/bin/ksh
# program : smenu_system_event.sh
# author  : B. Polarski
# date    : January 2008
#           2009-04-01 : Added option    -start -stop -delete -parm  -ft  -fm
#           2009-11-26 : Added option    -sti

function help
{
cat <<EOF


            Show System events figures (v\$system_event)

             srv:
                srv -a                     : List active services
                srv -e  <SERVICE_NAME>     : List services events stats
                srv -l                     : List services defined in dba_services
                srv -lba                   : List ervices Configured to Use Load Balancing Advisory (LBA) Features
                srv -ls                    : List services  from v\$service
                srv -parm                  : List all services relevant init.ora parameters within a rac
                srv -c [-u][-rac]          : List Session count per services. -u give also repartion per user
                srv -st                    : List Services stats
                srv -sti                   : List Services stats per instance
                srv -dis <SERVICE_NAME>    : Disconnect all session for given service

                srv -start  <SERVICE_NAME> [ -inst <INSTANCE_NAME> ]     : Start service SERVICE_NAME on given instance_name
                srv -stop   <SERVICE_NAME> [ -inst <INSTANCE_NAME> ]     : Start service SERVICE_NAME on given instance_name
                srv -delete <SERVICE_NAME>                               : Delete service SERVICE_NAME on given instance_name or all isnt
                srv -s      <SERVICE_NAME> -fg <NONE|SERVICE_TIME|THROUGHPUT> : Set Service goal
                srv -s      <SERVICE_NAME> -fm <NONE|BASIC>                   : Set service fail over method
                srv -s      <SERVICE_NAME> -ft <NONE|SESSION|SELECT>          : Set service fail over type
                srv -s      <SERVICE_NAME> -clb <NONE|LONG|SHORT>             : Set Connection Load Balancing

       Note :
              -inst <INSTANCE_NAME>  -- does not seems to work as described in the doc (10.2.0.3). Work only on its instance, not on remote
              -v    : Verbose


EOF
exit
}
if [ "$1" = "-h" -o -z "$1" ];then
   help
fi
while [ -n "$1" ]
do
  case "$1" in
        -a ) CHOICE=LIST_ACTV ;;
        -c ) CHOICE=COUNT ;;
      -clb ) CHOICE=CLB_METHOD ; CLB_TYPE=$2 ; shift ;;
   -delete ) CHOICE=DELETE ; SERVICE_NAME=$2;  shift ;;
      -dis ) CHOICE=DISALL_SESS ; SERVICE_NAME=$2;  shift;;
        -e ) CHOICE=LIST_EVENTS
             if [ -n "$2" ];then
                WHERE=" where  SERVICE_NAME=upper('$2') "
                shift
             fi;;
       -fm ) CHOICE=FAL_METHOD ; METHOD_VALUE=$2 ; shift ;;
       -ft ) CHOICE=FAL_TYPE ; TYPE_VALUE=$2 ; shift ;;
       -fg ) CHOICE=FAL_GOAL ; TYPE_VALUE=$2 ; shift ;;
     -inst ) INSTANCE_NAME=$2; shift ;;
        -l ) CHOICE=LIST_DBA ;;
      -lba ) CHOICE=LBA ;;
       -ls ) CHOICE=LIST_SRV ;;
     -parm ) CHOICE=LIST_PARM ;;
        -p ) CHOICE=LIST_ACTV ;;
      -rac ) RAC=G;;
    -start ) CHOICE=START ; SERVICE_NAME=$2;  shift ;;
     -stop ) CHOICE=STOP ; SERVICE_NAME=$2;  shift ;;
        -s ) SERVICE_NAME=$2; shift ;;
       -st ) CHOICE=STATS;;
      -sti ) CHOICE=STATS_SID;;
        -u ) REP_USER=TRUE;;
        -v ) VERBOSE=TRUE;;
       * ) help ;;
  esac
  shift
done

HOST=`hostname`
HOST=`echo $HOST | awk '{printf ("%-+15.15s",$1)}'`
SBINS=$SBIN/scripts

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
      echo "could no get a the password of $S_USER"
      exit 0
fi


# ....................................................................................................
#  List service stat per instances
# ....................................................................................................
if [ "$CHOICE" = "STATS_SID" ];then
# another way to view service stats
# *********************************************************** 
#
#	File: service_stats.sql 
#	Description: Report on service workload by instance 
#	From 'Oracle Performance Survival Guide' by Guy Harrison Chapter 23 Page 689
#
# ********************************************************* 
TITTLE="Report on service workload by instance"
SQL="
col instance_name format a8 heading 'Instance|Name'
col service_name format a30 heading 'Service|Name'
col cpu_time format 99,999,999 heading 'Cpu|secs'
col pct_instance format 999.99 heading 'Pct Of|Instance'
col pct_service format 999.99 heading 'Pct of|Service'
set lines 90  pages 1000 

BREAK ON instance_name skip 1
COMPUTE SUM OF cpu_time ON instance_name

WITH service_cpu AS (SELECT instance_name, service_name,
                            round(SUM(VALUE)/1000000,2) cpu_time
                     FROM     gv\$service_stats
                          JOIN
                              gv\$instance
                          USING (inst_id)
                     WHERE stat_name IN ('DB CPU', 'background cpu time')
                     GROUP BY  instance_name, service_name )
SELECT instance_name, service_name, cpu_time,
       ROUND(cpu_time * 100 / SUM(cpu_time) 
             OVER (PARTITION BY instance_name), 2) pct_instance,
       ROUND(  cpu_time
             * 100
             / SUM(cpu_time) OVER (PARTITION BY service_name), 2)
           pct_service
FROM service_cpu
WHERE cpu_time > 0
ORDER BY instance_name, service_name; 
"
# ....................................................................................................
#  List session count per service
# ....................................................................................................
elif [ "$CHOICE" = "COUNT" ];then
   if [ -n "$RAC" ];then
      INST_ID="inst_id,"
   fi
   if [ -n "$REP_USER" ];then
      REP_USER=",username"
   fi
TITTLE="List session count per services"
SQL="
  select $INST_ID Service_name $REP_USER,  count(*) from ${RAC}v\$session group by $INST_ID service_name $REP_USER
  order by $INST_ID service_name;

SELECT $INST_ID USERNAME , FAILOVER_TYPE , FAILOVER_METHOD , FAILED_OVER , COUNT(*)
FROM ${RAC}V\$SESSION
WHERE
USERNAME IS NOT NULL
GROUP BY $INST_ID USERNAME , FAILOVER_TYPE , FAILOVER_METHOD , FAILED_OVER
ORDER BY COUNT(*) DESC, FAILOVER_TYPE
/
"
# ....................................................................................................
#  Disconnect all session for a service
# ....................................................................................................
elif [ "$CHOICE" = "DISALL_SESS" ];then
   if $SBIN/scripts/yesno.sh "All sessions for service $SERVICE_NAME"
   then
TITTLE='Disconnect all sessions'
SQL="prompt Doing exec dbms_service.disconnect_session('$SERVICE_NAME');;
exec dbms_service.disconnect_session('$SERVICE_NAME');
"
   fi
# ....................................................................................................
#  Services Configured to Use Load Balancing Advisory (LBA) Features
# ....................................................................................................
# Author: Jim Czuprynski   http://www.dbasupport.com/img/LBA_features_Listing.html#List05
# ....................................................................................................
elif [ "$CHOICE" = "LBA" ];then
TITTLE='Services Configured to Use Load Balancing Advisory (LBA) Features (From DBA_SERVICES)'
SQL="COL name            FORMAT A40     HEADING 'Service Name' WRAP
COL created_on      FORMAT A20      HEADING 'Created On' WRAP
COL goal            FORMAT A12      HEADING 'Service|Workload|Management|Goal'
COL clb_goal        FORMAT A12      HEADING 'Connection|Load|Balancing|Goal'
COL aq_ha_notifications FORMAT A16  HEADING 'Advanced|Queueing|High-|Availability|Notification'
SELECT
     name
    ,TO_CHAR(creation_date, 'mm-dd-yyyy hh24:mi:ss') created_on
    ,goal
    ,clb_goal
    ,aq_ha_notifications
  FROM dba_services
 WHERE goal IS NOT NULL
   AND name NOT LIKE 'SYS%'
 ORDER BY name ;
"
# ....................................................................................................
#  List Services stats
# ....................................................................................................
# Author: Jim Czuprynski   http://www.dbasupport.com/img/LBA_features_Listing.html#List05
# ....................................................................................................
elif [ "$CHOICE" = "STATS" ];then
   if [ -n "$SERVICE_NAME" ];then
        WHERE_SERVICE=" where service_name = upper('$SERVICE_NAME') "
   fi
TITTLE='Current Service-Level Metrics|(From GV$SERVICEMETRIC)'
SQL="BREAK ON service_name NODUPLICATES
COL service_name    FORMAT A30          HEADING 'Service|Name' WRAP
COL inst_id         FORMAT 9999         HEADING 'Inst|ID'
COL beg_hist        FORMAT A10          HEADING 'Start Time' WRAP
COL end_hist        FORMAT A10          HEADING 'End Time' WRAP
COL intsize_csec    FORMAT 9999         HEADING 'Intvl|Size|(cs)'
COL goodness        FORMAT 999999       HEADING 'Good|ness'
COL delta           FORMAT 999999       HEADING 'Pred-|icted|Good-|ness|Incr'
COL cpupercall      FORMAT 99999999     HEADING 'CPU|Time|Per|Call|(mus)'
COL dbtimepercall   FORMAT 99999999     HEADING 'Elpsd|Time|Per|Call|(mus)'
COL callspersec     FORMAT 99999999     HEADING '# 0f|User|Calls|Per|Second'
COL dbtimepersec    FORMAT 99999999     HEADING 'DBTime|Per|Second'
COL flags           FORMAT 999999       HEADING 'Flags'
SELECT
     service_name
    ,TO_CHAR(begin_time,'hh24:mi:ss') beg_hist
    ,TO_CHAR(end_time,'hh24:mi:ss') end_hist
    ,inst_id
    ,goodness
    ,delta
    ,flags
    ,cpupercall
    ,dbtimepercall
    ,callspersec
    ,dbtimepersec
  FROM gv\$servicemetric $WHERE_SERVICE
 ORDER BY service_name, begin_time DESC, inst_id
;
"
# ....................................................................................................
#  Modify goal type
# ....................................................................................................
elif [ "$CHOICE" = "FAL_GOAL" ];then
TITTLE="Alter service $SERVICE_NAME set Service Goal to $TYPE_VALUE"
SQL="set head off
prompt doing exec DBMS_SERVICE.MODIFY_SERVICE('$SERVICE_NAME',failover_type=>DBMS_SERVICE.GOAL_$TYPE_VALUE);;
exec DBMS_SERVICE.MODIFY_SERVICE('$SERVICE_NAME',goal=>DBMS_SERVICE.GOAL_$TYPE_VALUE);
"

# ....................................................................................................
#  Modify fail over type
# ....................................................................................................
elif [ "$CHOICE" = "FAL_TYPE" ];then
TITTLE="Alter service $SERVICE_NAME set Fail over type to $TYPE_VALUE"
SQL="set head off
prompt doing exec DBMS_SERVICE.MODIFY_SERVICE('$SERVICE_NAME',failover_type=>'$TYPE_VALUE');;
exec DBMS_SERVICE.MODIFY_SERVICE('$SERVICE_NAME', failover_type=>'$TYPE_VALUE');
"

# ....................................................................................................
#  Modify fail over method
# ....................................................................................................
elif [ "$CHOICE" = "FAL_METHOD" ];then
TITTLE="Alter service $SERVICE_NAME set Fail over method to $METHOD_VALUE"
SQL="set head off
prompt doing exec DBMS_SERVICE.MODIFY_SERVICE('$SERVICE_NAME',failover_method=>'$METHOD_VALUE');;
exec DBMS_SERVICE.MODIFY_SERVICE('$SERVICE_NAME', failover_method=>'$METHOD_VALUE');
"

# ....................................................................................................
#  Set Connection Load Balancing option
# ....................................................................................................
elif [ "$CHOICE" = "CLB_METHOD" ];then
   if [ ! "$CLB_TYPE" = "SHORT" -a !  "$CLB_TYPE" = "LONG" ];then
      echo "CLB Type must be either SHORT or LONG"
      echo "Use -clb SHORT or -clb LONG"
      exit
   fi
TITTLE="Set Connection Load Balancing option to $CLB_TYPE"
SQL="set head off feed on
prompt Use srv -lba  To list effects
prompt doing exec DBMS_SERVICE.MODIFY_SERVICE('$SERVICE_NAME', clb_goal=>DBMS_SERVICE.CLB_GOAL_$CLB_TYPE);;
exec DBMS_SERVICE.MODIFY_SERVICE('$SERVICE_NAME', clb_goal=>DBMS_SERVICE.CLB_GOAL_$CLB_TYPE);
"

# ....................................................................................................
#   Delete service
# ....................................................................................................
elif [ "$CHOICE" = "DELETE" ];then
     if $SBINS/yesno.sh "To delete service $SERVICE_NAME "
     then
       SQL="set head off
prompt doing: exec DBMS_SERVICE.DELETE_SERVICE( '$SERVICE_NAME'   );;
exec DBMS_SERVICE.DELETE_SERVICE( '$SERVICE_NAME'   );
/
"
    fi

# ....................................................................................................
#   Stop service
# ....................................................................................................
elif [ "$CHOICE" = "STOP" ];then
   TITTLE="Stop service $SERVICE_NAME. check srv -a  service should not list anymore"
   if [ -n "$SERVICE_NAME" ];then
         ARG_INST=", instance_name => '$INSTANCE_NAME'"
   fi
SQL="set head off
prompt  doing : exec DBMS_SERVICE.STOP_SERVICE( service_name  => '$SERVICE_NAME' $ARG_INST  );;
exec DBMS_SERVICE.STOP_SERVICE( service_name  => '$SERVICE_NAME' $ARG_INST );
"

# ....................................................................................................
#   Start service
# ....................................................................................................
elif [ "$CHOICE" = "START" ];then
   TITTLE="Start service $SERVICE_NAME. check srv -a active service"
   if [ -n "$SERVICE_NAME" ];then
         $ARG_INST=", instance_name => '$INSTANCE_NAME'"
   fi

SQL="set head off
prompt  doing : exec DBMS_SERVICE.START_SERVICE( service_name  => '$SERVICE_NAME' $ARG_INST  );;
exec DBMS_SERVICE.START_SERVICE( service_name  => '$SERVICE_NAME' $ARG_INST  );
"

# ....................................................................................................
#  List parameter from gv\$parameter related to services
# ....................................................................................................
elif [ "$CHOICE" = "LIST_PARM" ];then
TITTLE="List parameter from gv\$parameter"
SQL="set lines 190 pagesize 66
  column name format a20 tru
  column value format a110 wra
  select inst_id, name, value from gv\$parameter
  where name in ('service_names','local_listener','remote_listener', 'db_name','db_domain','instance_name') order by 1,2,3;"

# ....................................................................................................
#   List service from data dictionary (static definition)
# ....................................................................................................
elif [ "$CHOICE" = "LIST_DBA" ];then
TITTLE="List service from data dictionary (static definition)"
SQL="set lines 190 pagesize 66
select NAME tag , NETWORK_NAME, CREATION_DATE, ENABLED, FAILOVER_METHOD, FAILOVER_TYPE, GOAL
from dba_services;
"

# ....................................................................................................
#   List active service
# ....................................................................................................
elif [ "$CHOICE" = "LIST_ACTV" ];then
TITTLE="List active service (from gv\$active_service)"
SQL="col NAME format a35 head 'Service name'
col NETWORK_NAME  format a30
col goal head 'Work|load|goal' for a5
col CLB_GOAL head 'Conn|Load|Balanc' for a6
col AQ_HA_NOTIFICATION head 'AQ|Notif' for a5
set lines 190 pagesize 66
select SERVICE_ID, NAME tag, INST_ID, NETWORK_NAME, CREATION_DATE , BLOCKED , goal,  AQ_HA_NOTIFICATION , CLB_GOAL
        from  GV\$ACTIVE_SERVICES  order by 3,1;"


# ....................................................................................................
#   List services defined in v\$service
# ....................................................................................................
elif [ "$CHOICE" = "LIST_SRV" ];then
TITTLE="List services defined in v\$service"
SQL="set lines 150 pagesize 66
col NETWORK_NAME format a40
col NAME format a34
col goal format a5
col SERVICE_ID head id format 999
select SERVICE_ID, NAME tag, NETWORK_NAME, CREATION_DATE, GOAL ,DTP,AQ_HA_NOTIFICATION,CLB_GOAL from v\$services;"

fi


# we do the work here

if [ -n "$VERBOSE" ];then
  echo "$SQL"
fi

sqlplus -s "$CONNECT_STRING" <<EOF
set linesize 120
column nline newline
prompt MACHINE $HOST - ORACLE_SID : $ORACLE_SID
set pagesize 66 termout on embedded off verify off heading off pause off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  || '     - $TITTLE' from sys.dual
/

set head on pause off feed on  linesize 130
col FAILOVER_METHOD format a10 head 'Failover|Method'
col FAILOVER_Type format a10 head 'Failover|type'
col name format a35 head 'Service name'
col network_name format a60 head 'Real service name'
col tag format a35 head 'Tag service name'
col service_name format a35 head 'Service name'
column average_wait format 9999990.00
column event format a45 head "Event type"
column total_waits head "Total number|of waits  "
column max_waits head "Max waits"
column total_timeouts head "Total number |of timeouts "
column time_waited head " Time waited  | (secs)" justify c
column average_wait format 9990.99 head "Average wait |(sec)" justify c
col pct format 990.99 head "% of| Waits"
col enabled for a8 head "Enabled"
$SQL
prompt
EOF

