#!/bin/sh
#set -xv
cd $TMP

 while [ -n "$1" ]
 do
    case $1 in
       -g ) PAR_TYPE=DATA_GUARD ;;
       -s ) PAR_TYPE=STREAMS ;;
       -t ) PAR_TYPE=TUNNING ;;
    esac
    shift
 done
PROMPT="prompt .     parg = data guard         pars = Streams"
#S_USER=SYS
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID

if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

if [ "$PAR_TYPE" = "DATA_GUARD" ];then
sqlplus -s "$CONNECT_STRING" <<EOF1
set heading off feed off
set embedded off pause off
set verify off
set linesize 172
set pagesize 66
column nline newline

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report            -  Standby parameters' nline
from sys.dual
/
set heading on

column  name             format a28  heading "Parameter" 
column  value            format a75  heading "Value" 
column  issys_modifiable format a10   heading "Is Sys|Modifiable" justify c
$PROMPT
select name, value, issys_modifiable from v\$parameter where name in ('db_name','instance_name','compatible'
      ,'log_archive_start', 'control_file',
      'db_file_name_convert','log_file_name_convert','log_archive_format','local_listener','service_names',
      'log_archive_dest_1','log_archive_dest_state_1','log_archive_dest_2','log_archive_dest_state_2',
      'standby_file_management','standby_archive_dest','remote_archive_enable','lock_name_space','switchover_status', 'fal_server','fal_client',
      'db_unique_name','undo_retention','log_archive_config', 'connection_brokers','dg_broker_config_file1','dg_broker_config_file2','dg_broker_start','use_dedicated_broker'
)
order by name
/
exit
EOF1

elif [ "$PAR_TYPE" = "STREAMS" ];then

sqlplus -s "$CONNECT_STRING" <<EOF1
set heading off feed off
set embedded off pause off
set verify off
set linesize 172
set pagesize 66
column nline newline

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report            -  Streams parameters' nline
from sys.dual
/
set heading on

column  name             format a32  heading "Parameter" 
column  value            format a72  heading "Value" 
column  fvalue            format a12  heading "Value" 
column  description      format a72  heading "Description" 
column  issys_modifiable format a10   heading "Is Sys|Modifiable" justify c
$PROMPT
select name, value, issys_modifiable from v\$parameter where name in ('compatible','processes','parallel_max_servers',
         'global_names','job_queue_processes','log_parallelism','aq_tm_processes','logmnr_max_persistant_sessions',
         'db_name','log_archive_dest_1','log_archive_format','log_archive_start','open_links','sga_max_size',
         'shared_pool_size','sessions','archive_lag_target', 'logmnr_max_persistent_sessions'
)
order by name
/
set head off
select  x.ksppinm name ,
        v.ksppstvl fvalue,
        x.ksppdesc description
from    x\$ksppi x, x\$ksppcv v
where   translate(ksppinm,'_','#') like '#%'    and
        v.indx = x.indx                         and
        v.inst_id = x.inst_id                   and
        x.ksppinm = '_first_spare_parameter'
/
exit
EOF1

elif [ "$PAR_TYPE" = "TUNNING" ];then

sqlplus -s "$CONNECT_STRING" <<EOF1
set heading off feed off embedded off pause off verify off linesize 172 pagesize 66
column nline newline

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report            -  Most common tunning parameters' nline
from sys.dual
/
set heading on

column  name             format a30  heading "Parameter" 
column  value            format a45  heading "Value" 
column  issys_modifiable format a10   heading "Is Sys|Modifiable" justify c
$PROMPT
select name, value, issys_modifiable from v\$parameter where name in (
       'optimizer_mode','optimizer_dynamic_sampling','session_cached_cursors','plsql_optimize_level',
       'optimizer_index_cost_adj','optimizer_index_caching','disk_asynch_io','dbwr_io_slaves','query_rewrite_enabled',
       'statistics_level','dbio_expected','optimizer_secure_view_merging','workarea_size_policy'
)
order by name
/
col statistics_name format a30 head 'Statistic name'
col status format A8 head 'Status'
col activation_level format A10 head "Minimum|Stat Level"
col session_settable format A10 head "Session|Settable" justify c
col statistics_view_name format A30 head "Statistics view name" justify c

col statistics_name for a40
select statistics_name, system_status status ,
     activation_level,  session_settable,
      statistics_view_name from v\$statistics_level

/
exit
EOF1
fi
