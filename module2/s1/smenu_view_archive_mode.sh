#!/bin/ksh 
SBINS=$SBIN/scripts
TMP=$SBIN/tmp

# .......................................................................................
do_it_by_sed()
{
#-------------------------------------------------------------------------------
# Alternated method if sys is not available
#-------------------------------------------------------------------------------
#-- Script:     instance_variables.sql
#-- Purpose:    to list the values of the instance variables
#--
#-- Copyright:  (c) 1998 Ixora Pty Ltd
#-- Author:     Steve Adams
#__ apapted to smenu by By. Polarski
#-------------------------------------------------------------------------------

TMP_FIL=$SBIN/tmp/get_var$$.txt
sqlplus -s "$CONNECT_STRING" <<EOF >/dev/null 2>&1
spool $TMP_FIL
select
  'X\$KVII' struct, kviitag  variable, kviival  value, kviidsc  description
from sys.x\$kvii
union all
select
  'X\$KVIT', kvittag, kvitval, kvitdsc
from sys.x\$kvit
union all
select
  'X\$KVIS', kvistag, kvisval, kvisdsc
from
  sys.x\$kvis
/
spool off ;
EOF
echo
OLD=TOTO
cat << EOF
MACHINE $HOST        - ORACLE_SID : $ORACLE_SID                            Page:   1

Date              -  `date +%A'  '%d'   '%B'   '%H:%M:%S`
Username          -  SYS
                  -  Show instance variables


STRUCT VARIABLE   VALUE    DESCRIPTION
------ -------- ---------- -----------------------------------------------------
EOF
sed -e '/selected\.$/d' -e '/^---.*--$/d' -e '/^STRUCT/d' $TMP_FIL | while read a b c d
   do
      a=`echo $a | awk '{ printf ("%-7.7s",$1)  }'`
      b=`echo $b | awk '{ printf ("%7.7s",  $1)  }'`
      c=`echo $c | awk '{ printf ("%10.10s",$1)  }'`
      if [ $a = $OLD ];then
         echo "       ${b}${c}   ${d}"
      else
         echo "${a}${b}${c}   ${d}"
      fi
      OLD=$a
done
echo

if [ -f $TMP_FIL ];then
   rm $TMP_FIL
fi
}
# .......................................................................................
function help {

  cat <<EOF
  

       sts -bw [-rn <n>]   : Background process event
       sts -def            : Show default database properties
       sts -dif            : Show parameter differences
       sts -pch -par parm  : Show parameter change history of parameter name <parm>
       sts -fl             : List flash logs
       sts -f              : Display flasharead stats
       sts -fp             : List restore points
       sts -hex <string>   : Convert Hexadecimal string to Decimal
       sts -l              : show system log mode
       sts -m              : show dba_outstanding_alert
       sts -log            : show system supplemental logging. User 'tbl -log' for table supplemental logging
       sts -lim            : List resource limit
       sts -opt            : List most of relevants parameters about the optimizer
       sts -nls            : List DB nls setting
       sts -rac            : Rac : list instances status
       sts -s              : List system statistics 
       sts -sar [-inst<n>] : Oracle AWR version of sar like stats
       sts -si             : show When system statistics were taken
       sts -sl             : List gather_database_stats run history
       sts -su             : Show temp usage
       sts -t  <SCN>       : Convert SCN to timestamp
       sts -td <TIMESTAMP> : Convert timestamp to SCN : format is 'YYYY-MM-DD HH24:MI:SS'
       sts -use            : Show options with licences used
       sts -urc            : List no logging operations
       sts -var            : Show instance variables
       sts -pwd            : Generate a script to preserve all users password
       sts -bq             : Show session blocking Quiesce database
       sts -fkn            : List FK with nullable target 
       sts -dest           : List archive destinations
       sts -prf <file>     : Use perl to overview event parse a 10046 trace file
       sts -tkp <file>     : Use perl to parse details from a 10046 trace file
       sts -i              : List info diag 
       sts -al [-rn <n>]   : View the contents of the alert log, limited to last <n> lines
                               -ora  : List all ORA- message
                               -id   : Show record id, usefull for -bid/-eid option
                               -cpt  : count message type
       sts -ltb            : if admin_tab_part is installed, list configured tables
       sts -llog           : if admin_tab_part is installed, list logs
       sts -vlog <Key>     : if admin_tab_part is installed, view log of given key
       sts -awlb -u <owner> : show managed_parts ( at worldline only)
       sts -al -bid <n> [-eid <n>] : view all message of alert log between 2 id.
       sts -lc             : List category counts in controlfiles
       sts -tns            : regen tnsnanes.ora from grid control. 
       sts -adv            : List advisors status

       sts -h              : this help
       sts -v              : Verbose
           
 Note:       -rn <ROWNUM>  : Limit display to <ROWNUM> first rows, default is 30

     sts -sar <nn> -val    : Show Os stats taken from AWR repository for the last <nn>  periods. Default is 1
                                   -val : gives results in absolute values rather than percentages
       
EOF
exit
}
# .......................................................................................
#                               Main
# .......................................................................................
if [ -z "$1" ];then
   help
fi
NSNAP=1
ROWNUM=30
while [ -n "$1" ]
do
  case "$1" in
    -adv  ) CHOICE=LIST_ADV;;
    -al  ) CHOICE=ALERT_LOG;;
    -cpt ) COUNT=TRUE ;;
    -id ) RECORD_ID="RECORD_ID as id," ;;
    -bid ) BID=$2 ; shift ;;
    -eid ) EID=$2 ; shift ;;
    -sar ) CHOICE=SAR;
          if [ -n "$2" ];then
             NSNAP=$2
             shift
          fi;;
   -dest ) CHOICE=DEST ;;
   -awlb ) CHOICE=MANAGED_PARTS ;;
    -ora ) MSGTYPE=" and message_type in ( 2, 3 )" ;; 
    -bw ) CHOICE=BW ;;
    -bq ) CHOICE=BQ ;;
   -dif|-vdif ) CHOICE=DIFF ;;
   -def ) CHOICE=DEFAULT ;;
    -fl ) CHOICE=FLASH_LOG;;
    -f  ) CHOICE=FLASH_STATS;;
   -fkn ) CHOICE=FK_NULL;;
     -i ) CHOICE=INFO_DIAG ; export S_USER=SYS;;
     -l ) CHOICE=STS ;;
     -lc) CHOICE=CONTROL_FILE ;;
   -lim ) CHOICE=RESOURCE_LIMIT ;;
   -log ) CHOICE=SUP_LOG;;
   -ltb ) CHOICE=LTB ;;
  -llog ) CHOICE=LLOG ;;
  -vlog ) CHOICE=VLOG ; KEY=$2; shift;;
    -fp ) CHOICE=LIST_RESTORE_POINT;;
  -inst ) INST_NUM=$2; shift ;;
   -nls ) CHOICE=NLS ;;
    -m  ) CHOICE=OUTSTANDING ;;
   -opt ) CHOICE=OPT_LIST ;;
   -pch ) CHOICE=PAR_HIST   ;;
   -par ) PAR_NAME="$2" ; shift ;;
   -pwd ) CHOICE=PSWD ; S_USER=SYS;;
   -prf ) CHOICE=PRF ; FIN=$2 ; shift;;
     -s ) CHOICE=SYSSTAT ;;
    -si ) CHOICE=SYSSTAT_INFO ;;
    -sl ) CHOICE=GDS ;;
    -su ) CHOICE=SORT_USAGE ;;
   -rac ) CHOICE=RAC_LIST ;;
     -t ) CHOICE=CVT_SCN; SCN=$2;shift;;
    -td ) CHOICE=CVT_TO_SCN; shift ; FDATE=$@; break ;;
   -tns ) CHOICE=REGEN_TNS;;
   -val ) VAL=TRUE;;
   -urc ) CHOICE=URC;;
   -hex ) CHOICE=HEX; String=$2; shift;;
   -tkp ) CHOICE=TKP ; FIN=$2 ; shift;;
   -var ) CHOICE=VAR;;
     -v ) VERBOSE=YES; set -xv ;;
   -use ) CHOICE=USE ;;
     -u ) fowner=$2 ; shift ;;
    -rn ) ROWNUM=$2 ; shift ;;
      * ) echo "invalid value : $1"; help ;;
  esac
  shift
done
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get the password of $S_USER"
   if [ "$CHOICE" = "VAR" ];then
         do_it_by_sed
   fi
   exit 0
fi

# ..................................................................
# meta for kruger manager partitions
# ..................................................................
if [ "$CHOICE" = "LIST_ADV" ];then
SQL="
SELECT client_name, status FROM dba_autotask_client;

prompt to disable run :
prompt SQL> EXEC DBMS_AUTO_TASK_ADMIN.DISABLE(client_name=>'sql tuning advisor', operation=>NULL, window_name=>NULL);
prompt SQL> EXEC DBMS_AUTO_TASK_ADMIN.DISABLE(client_name=>'auto space advisor', operation=>NULL, window_name=>NULL);
prompt SQL> EXEC DBMS_AUTO_TASK_ADMIN.DISABLE(client_name=>'auto optimizer stats collection', operation=>NULL, window_name=>NULL);
"
# ..................................................................
# meta for kruger manager partitions
# ..................................................................
elif [ "$CHOICE" = "MANAGED_PARTS" ];then
 if [ -s "$fowner" ];then
    echo "I need an owner"
    exit
 fi
SQL="

set lines 230 pages 66

col TABLE_NAME for a25
col RETENTION_PERIOD for 999999 head 'ret|period'
col PARTS_TO_PRECREATE for a6 head 'par to|create' justify c
col INTERVAL_PER_PART  for a10 head 'interval'
col EST_SIZE_DATA_PART for 999999 head 'Est data|size(m)'
col EST_SIZE_IDX_PART  for 999999 head 'Est idx|size(m)'
col CHILD_TABLES for a20 head 'child table'
col EXPORT_DIR for a20
col PARTITION_TYPE for a20 head 'partition|type' justify c
col CLUSTER_DB for a3 head 'clus|db'
col PART_NAME_PREFIX for a10 head 'part|prefix'
col EXCP_PART_KEY_VALUES for a10 head 'exp key| value'
col REF_VAL_FOR_PRECREATION  for a35 head 'ref val|for precreation'
col IDX_TABLESPACE_MGMT  for a30 head 'idx tbs'

select 
  TABLE_NAME, 
  --RETENTION_PERIOD, 
  PARTS_TO_PRECREATE, INTERVAL_PER_PART,
  EST_SIZE_DATA_PART, EST_SIZE_IDX_PART, CHILD_TABLES,
  EXPORT_DIR, PARTITION_TYPE, CLUSTER_DB, PART_NAME_PREFIX, 
  EXCP_PART_KEY_VALUES, REF_VAL_FOR_PRECREATION, IDX_TABLESPACE_MGMT
from   
  $fowner.MANAGE_PARTS ;
"
# ..................................................................
# found at : https://www.gpsos.es/2018/03/creacion-fichero-tnsnames/?lang=en
# ..................................................................
elif [ "$CHOICE" = "REGEN_TNS" ];then
SQL="
Set pages 999 lines 200 heading off
Col host for A50
Col port for A10
Col sid for A10

Spool Db_all. txt

select
    distinct mgmt\$target.host_name || ' | ' || Sid.PROPERTY_VALUE || '|' || Port. PROPERTY_VALUE
from
   sysman.mgmt_target_properties machine,
   sysman.mgmt_target_properties port,
   sysman.mgmt_target_properties sid,
   sysman.mgmt_target_properties domain,
   sysman.mgmt$target
where
    machine.target_guid = sid.target_guid
AND sid.target_guid = port.target_guid
AND port.target_guid = domain.target_guid
AND Machine.PROPERTY_NAME = 'MachineName '
AND port.PROPERTY_NAME = 'Port '
AND sid.PROPERTY_NAME = 'SID '
AND sid.PROPERTY_VALUE not like '%ASM%'
AND Machine.TARGET_GUID in (select TARGET_GUID from Sysman. mgmt_current_availability 
                                 where sysman.EM_SEVERITY.get_avail_string (current_status) = 'UP ')
AND Machine.TARGET_GUID= Mgmt\$target.TARGET_GUID
order by 1
/

spool off
"
elif [ "$CHOICE" = "VLOG" ];then
   if [ -z "$KEY" ];then
      echo "I need a key, use -k <key>"
      exit
   fi
SQL="
set long 2000000
set pages 0 lines 200
select LOG from system.admin_log where key = '$KEY' ;
/
"

# ..................................................................
elif [ "$CHOICE" = "NLS" ];then
SQL="
set lines 190 pages 66
select * from v\$nls_parameters
/
"
# ..................................................................
elif [ "$CHOICE" = "CONTROL_FILE" ];then
SQL="
set lines 190 pages 66
compute sum of RECORDS_USED on report
compute sum of RECORDS_TOTAL on report
break on report
select TYPE,RECORD_SIZE,RECORDS_TOTAL,RECORDS_USED,FIRST_INDEX,LAST_INDEX,LAST_RECID 
  from V\$CONTROLFILE_RECORD_SECTION  ;
col tmb head 'Total(m)' for 99990.99 
compute sum of tmb break on report
select type, (record_size*records_total/1024/1024) tmb from v\$controlfile_record_section order by 2 desc;
"
# ..................................................................
elif [ "$CHOICE" = "OUTSTANDING" ];then
SQL="
set lines 190 pages 66
col OBJECT_TYPE for a20
col reason for a70
col SUGGESTED_ACTION for a60
col message_level for 999 head 'Msg|lvl'
select to_Char(TIME_SUGGESTED,'YYYY-MM-DD HH24:MI:SS')ldate 
      ,object_type, message_type,message_level,reason,SUGGESTED_ACTION from dba_outstanding_alerts 
order by 1 desc
/
"
elif [ "$CHOICE" = "LLOG" ];then
SQL="
set lines 100 pages 66
select * from (
select KEY  , to_char(LOG_CREATION,'YYYY-MM-DD HH24:MI:SS') as ldate from SYSTEM.ADMIN_LOG order by LOG_CREATION desc
) where rownum <= $ROWNUM
/
"
# ..................................................................
elif [ "$CHOICE" = "LTB" ];then
SQL="
set lines 197 pages 55
col TABLE_OWNER for a16 head 'Owner'
col TABLESPACE_NAME for a20 head 'Tablespace'
col TABLE_NAME for a30 head 'Table'
col PART_TYPE head 'Type' for a4
col PART_COL for a14
col INITIAL_PART_SIZE head 'Init|size' for 99999
col NEXT_PART_SIZE head 'Next' for 9999
col IS_PARTIONNING_ACTIVE head 'Act|ive' for a3
col PARTS_TO_CREATE_PER_PERIOD  head 'Part|create|per|period'
col DROP_AFTER_N_PERIOD head 'Drop|after|period' justify c
col DROP_WHEN_N_PARTS_EXISTS head 'Drop|when|n|exits' justify c for 99999
col USE_DATE_MASK_ON_PART_COL head 'Mask' for a22
col COPY_STATS for a4 head 'copy|stat'
col DAYS_AHEAD head 'Days|ahead' for 99999
col DAYS_TO_KEEP head 'Days|keep' for 9999
col PART_NAME_RADICAL head 'Radical' for a12

select TABLESPACE_NAME,TABLE_OWNER,TABLE_NAME,PART_TYPE,PART_COL,
       INITIAL_PART_SIZE,NEXT_PART_SIZE,IS_PARTIONNING_ACTIVE,PARTS_TO_CREATE_PER_PERIOD,
       DROP_AFTER_N_PERIOD, DROP_WHEN_N_PARTS_EXISTS ,USE_DATE_MASK_ON_PART_COL,COPY_STATS,
       DAYS_AHEAD,DAYS_TO_KEEP,PART_NAME_RADICAL from system.admin_tab_partitions
/
"
# ..................................................................
elif [ "$CHOICE" = "ALERT_LOG" ];then
if [ -n "$MSGTYPE" ];then
   TITTLE="List error from alert.log limited to last $ROWNUM"
else
   TITTLE=${TITTLE:-List alert.log last $ROWNUM lines}
fi

if [ -n "$BID" ];then
   if [ -z "$EID" ];then
         EID=`expr $BID + $ROWNUM`
   fi
   AND_BID=" and record_id >= $BID and record_id <= $EID "
   ROWNUM=10000
fi

if [ "$COUNT" = "TRUE" ];then
SQL="
set head off lines 80 pages 66
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  , '$TITTLE' 
from sys.dual
/
set lines 190 pages 900
set head on
select count(*) cpt, message_type from  v\$diag_alert_ext group by message_type
/
"
else # non count access on alert.log
SQL="
set head off lines 80 pages 66
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  , '$TITTLE' 
from sys.dual
/
set lines 190 pages 900
col line for a140
select $RECORD_ID ldate, line from (
select record_id, ldate, line from (
 select  record_id,
       to_char(originating_timestamp,'MON-DD HH24:MI:SS') ldate,
       message_text line
 from v\$diag_alert_ext where 1=1 $MSGTYPE $AND_BID
 order by record_id desc
 ) 
 where rownum <= $ROWNUM
) order by record_id 
/
"
fi
# ..................................................................
elif [ "$CHOICE" = "INFO_DIAG" ];then
   SQL="
   set lines 190 pages 66
   col value format a65
   col name for a24
   select * from V\$DIAG_INFO ;
"
# ..................................................................
elif [ "$CHOICE" = "TKP" ];then
   if [ ! -f "$FIN" ];then
      echo "I do not find the input file $FIN"
      exit
   fi
   $SBINS/tkp_det.ksh $FIN
   exit
# ..................................................................
elif [ "$CHOICE" = "SORT_USAGE" ];then
SQL="
compute sum of MB on report
break on report

set lines 190 pages 66
col username for a30
SELECT
    u.inst_id
  , u.username
  , s.sid
  , u.session_num serial#
  , u.sql_id
  , u.tablespace
  , u.contents
  , u.segtype
  , ROUND( u.blocks * t.block_size / 1048576 ) MB
  , SEGFILE#  file_id
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
"
# ..................................................................
elif [ "$CHOICE" = "PRF" ];then
   if [ ! -f "$FIN" ];then
      echo "I do not find the input file $FIN"
      exit
   fi
   $SBINS/tkp.pl -t $FIN
   exit
# ..................................................................
elif [ "$CHOICE" = "DEST" ];then
# a usefull stuff from Jared still log
SQL="
set lines 190 pages 66
col name for a30
col value for a90

select name, value
from v\$parameter
where name = 'log_archive_dest'
and value is not null
union all
select p.name, p.value
from v\$parameter p where
name like 'log_archive_dest%'
and p.name not like '%state%'
and p.value is not null
and 'enable' = (
   select lower(p2.value)
   from v\$parameter p2
   where p2.name =  substr(p.name,1,instr(p.name,'_',-1)) || 'state' || substr(p.name,instr(p.name,'_',-1))
)
union all
select p.name, p.value
from v\$parameter p
where p.name like 'log_archive_dest_stat%'
and lower(p.value) = 'enable'
and (
   select p2.value
   from v\$parameter p2
   where name = substr(p.name,1,16) || substr(p.name,instr(p.name,'_',-1))
) is not null
/
"
# ..................................................................
elif [ "$CHOICE" = "FK_NULL" ];then
   if [ -n "$fowner" ];then
        fowner=`echo $fowner | awk '{print toupper($1) }'`
        AND_OWNER=" and a.owner = upper('$fowner') "
   fi
SQL="
set lines 190 pages 66
 col COLUMN_NAME for a30
 col owner for a30
 col table_name for a30
 select
    b.owner,
    b.table_name , d.column_name, t.nullable
 from all_constraints a , all_constraints b, all_cons_columns c, all_cons_columns d,
      all_tab_columns t
where
      b.r_constraint_name = a.constraint_name $AND_OWNER
  and b.r_owner = a.owner 
  and c.constraint_name = a.constraint_name
  and c.owner = a.owner
  and c.table_name = a.table_name
  and d.owner = b.owner
  and d.table_name = b.table_name
  and d.constraint_name = b.constraint_name
  and   t.owner = a.owner
  and   t.table_name=a.table_name
  and   t.column_name = c.column_name
  and   t.nullable='Y'
/
"
# ..................................................................
elif [ "$CHOICE" = "PAR_HIST" ];then
#-- parm_mods.sql   : http://kerryosborne.oracle-guy.com/scripts/parm_mods.sql
#--
#-- Shows all parameters (including hidden) that have been modified. 
#-- Uses the lag function so that a single record is returned for each change.
#-- It uses AWR data - so only snapshots still in the database will be included.
#--
#-- The script prompts for a parameter name (which can be wild carded).
#-- Leaving the parameter name blank matches any parameter (i.e. it will show all changes).
#-- Calculated hidden parameters (those that start with two underscores like "__shared_pool_size") 
#-- will not be displayed unless requested with a Y.
#--
#-- Kerry Osborne
#--
#-- Note: I got this idea from Jeff White.
#--       Adapted to Smenu by Bpa
if [ -n "$PAR_NAME" ];then
     AND_PARNAME=" and parameter_name like '%${PAR_NAME}%' "
fi
SQL="set linesize 190 pages 300 verify off 
col instance for 9999 head 'Inst'
col PARAMETER_NAME head 'parameter name' for a20
col time for a22
col parameter_name format a30
col old_value format a49
col new_value format a49
col calc_flag for a4 head 'Auto|Calc|Par.' justify c 
break on instance skip 3

select instance_number instance,  time, parameter_name, calc_flag, old_value, new_value 
     from ( select 
                   a.snap_id,to_char(end_interval_time,'YYYY-MM-DD HH24:MI') TIME, 
                   a.instance_number, parameter_name, value new_value, 
                   lag(parameter_name,1) over (partition by parameter_name, 
                   a.instance_number order by a.snap_id) old_pname,
                   lag(value,1) over (partition by parameter_name, 
                   a.instance_number  order by a.snap_id) old_value ,
                   decode(substr(parameter_name,1,2),'__','Y','N') calc_flag
            from 
                 dba_hist_parameter a, 
                 dba_Hist_snapshot b ,
                 v\$instance v
            where 
                  a.snap_id=b.snap_id 
              and a.instance_number=b.instance_number $AND_PARNAME
            ) 
      where 
            new_value != old_value 
order by 1,2
/
"
# ..................................................................
elif [ "$CHOICE" = "BQ" ];then
   TITTLE="Show session blocking Alter database Quiesce"
   SQL="
prompt
prompt  to quiesce   : ALTER SYSTEM QUIESCE RESTRICTED;;
prompt  to unquiesce : ALTER SYSTEM UNQUIESCE;;
prompt
   select bl.sid, user, osuser, type, program
          from v\$blocking_quiesce bl, v\$session se where bl.sid = se.sid;
"
# ..................................................................
elif [ "$CHOICE" = "HEX" ];then
   if [ -z "$String" ];then
      echo " I need an hexdecimal value"
      exit
   fi
# starting 8i we can also do :  select to_number('F','XXXXXXXX' ) from dual
sqlplus -s "$CONNECT_STRING" <<EOF
set serveroutput on 
declare
  V_in  varchar2(30):='$String' ;
  V_out varchar2(30);
  function to_dec ( p_str in varchar2, p_from_base in number default 16 ) return number
  is
	l_num   number default 0;
	l_hex   varchar2(16) default '0123456789ABCDEF';
   begin
	for i in 1 .. length(p_str) loop
		l_num := l_num * p_from_base + instr(l_hex,upper(substr(p_str,i,1)))-1;
	end loop;
	return l_num;
   end to_dec;
begin
  v_out:=to_dec(v_in);
  dbms_output.put_line('(Hexa to Dec)   ' || v_in || ' :--> '|| v_out ) ;
end;
/
EOF
# ..................................................................
elif [ "$CHOICE" = "PSWD" ];then
   TMP=$SBIN/tmp
   FOUT=$TMP/alter_user_passwd_$ORACLE_SID.txt
> $FOUT
echo " Create user script " 
echo " =======================" 
echo " Create user script "  >> $FOUT
echo " ======================="  >> $FOUT
echo " " >> $FOUT
vers=`$SBINS/smenu_get_ora_version.sh`
vers=${vers:-11}
if [ $vers -lt 11 ] ;then
(
sqlplus -s "$CONNECT_STRING" <<EOF
        set pages 0 feed off echo off pause off lines 250 trimspool on
        select 'create user ' ||username || ' identified by values '||''''|| password || '''' || ' default tablespace ' || 
               DEFAULT_TABLESPACE ||' temporary tablespace ' || TEMPORARY_TABLESPACE || ' ; ' from dba_users
/
EOF
) >> $FOUT
echo >> $FOUT
echo " Preserve user passwd for later use" 
echo " ==================================" 
echo " " >> $FOUT
echo " " >> $FOUT
echo " " >> $FOUT
echo " Preserve user passwd for later use"  >> $FOUT
echo " =================================="  >> $FOUT
(
sqlplus -s "$CONNECT_STRING" <<EOF
        set pages 0 feed off echo off pause off lines 500 trimspool on
        select 'alter user ' ||username || ' identified by values '||''''|| password || ''' ; ' from dba_users
        /
EOF
) >> $FOUT

else # version 11+

(
sqlplus -s "$CONNECT_STRING" <<EOF
        set pages 0 feed off echo off pause off lines 500 trimspool on
        select 'create user ' || name || ' identified by values '||''''|| password || '''' || ' default tablespace ' || 
               DEFAULT_TABLESPACE ||' temporary tablespace ' || TEMPORARY_TABLESPACE || ' ; ' 
       from (
            select u.name , t.name DEFAULT_TABLESPACE , t2.name TEMPORARY_TABLESPACE, 
                   case 
                       when u.spare4 is null  then password
                       else u.spare4||';'||password  
                   end password
            from sys.user\$ u, sys.ts$ t, sys.ts$ t2
                 where    u.type#=1
                      and u.DATATS# = t.ts#
                      and u.TEMPTS# = t2.ts#
       )
/
EOF
) >> $FOUT
echo " Preserve user passwd for later use" 
echo " ==================================" 
echo " " >> $FOUT
echo " " >> $FOUT
echo " " >> $FOUT
echo " Preserve user passwd for later use"  >> $FOUT
echo " =================================="  >> $FOUT
    
(
sqlplus -s "$CONNECT_STRING" <<EOF
        set pages 0 feed off echo off pause off lines 500 trimspool on
       select 'alter user ' || name || ' identified by values '||''''|| password || ''' ; ' 
       from (
            select u.name ,
                   case 
                       when u.spare4 is null  then password
                       else u.spare4||';'||password  
                   end password
            from sys.user\$ u where type#=1
       )
/
EOF
) >> $FOUT

fi
cd $TMP
echo " "
cat $FOUT
echo " "
exit

# ..................................................................
elif [ "$CHOICE" = "BW" ];then
#---------------------------------------------------------------------------------
#  date   : 2005 Nov 15
#  Author : Donald K. Burleson  ( derived from a script of Steve Adams  )
#                               ( but DKB seems to have a short memory  )
#  adapted to smenu by By Bernard Polarski
#---------------------------------------------------------------------------------

       TITTLE="System Backround events"
SQL="set lines 190 pages 66
column c1 heading 'System|ID'              format 9999
column c2 heading 'Background|Process'     format a10 justify l
column c3 heading 'Event name'             format a40
column c4 heading 'Total|Waits'            format 999,999,999
column c5 heading 'Time|Waited|(in secs)'  format 999,999,999
column c6 heading 'Nbr |timouts'            format 9999999 justify c
column c7 heading 'Avg|Wait|secs'          format 99990.999
column c8 heading 'Max|Wait|(in secs)'     format 99999

break on c1 on report
select c1,c2,c3,c4,c6,c6,c7,c8 from (
select
   b.sid                                     c1,
   decode(b.username,NULL,c.name,b.username) c2,
   a.event                                   c3,
   a.total_waits                             c4,
   round((a.time_waited / 100),2)            c5,
   a.total_timeouts                          c6,
   round((average_wait / 100),3)             c7,
   round((a.max_wait / 100),2)               c8,
   rank() over ( partition by decode(b.username,NULL,c.name,b.username) order by a.total_waits desc) as topr
from
   sys.v_\$session_event a,
   sys.v_\$session       b,
   sys.v_\$bgprocess     c
 where
   a.event NOT LIKE 'DFS%'
and
   a.event NOT LIKE 'KXFX%'
and
   a.sid = b.sid
and
   b.paddr = c.paddr
and
   a.event NOT IN
   (
   'lock element cleanup',
   'pmon timer',
   'rdbms ipc message',
   'smon timer',
   'SQL*Net message from client',
   'SQL*Net break/reset to client',
   'SQL*Net message to client',
   'SQL*Net more data to client',
   'dispatcher timer',
   'Null event',
   'io done',
   'parallel query dequeue wait',
   'parallel query idle wait - Slaves',
   'pipe get',
   'PL/SQL lock timer',
   'slave wait',
   'virtual circuit status',
   'WMON goes to sleep') $ORDER
) where topr <= $ROWNUM ;
"
elif [ "$CHOICE" = "URC" ];then

TITTLE="List No logging operations"
SQL="
set linesize 125 pages 66
set head on

COL fName    FORMAT A55      HEADING 'Datafile'
COL tbs  FORMAT A30      HEADING 'Tablespace'
COL uc   FORMAT 999999999999      HEADING 'Scn'
COL fd   FORMAT A20      HEADING 'Date'

SELECT a.fNAME,  a.uc, TO_CHAR (a.fdate,'DD-MON-YYYY HH:MI:SS') fd , b.name tbs
 from (
      SELECT NAME fname, UNRECOVERABLE_CHANGE# uc, UNRECOVERABLE_TIME fdate, ts#
   FROM V\$DATAFILE  where UNRECOVERABLE_CHANGE# > 0 order by fdate desc) a,
   sys.ts\$ b where  a.ts# = b.ts# and rownum <=$ROWNUM
/
"
# .................................................................................
elif [ "$CHOICE" = "VAR" ];then
TITTLE="Show instance variables"
SQL="set lines 190 pages 65
column variable format a16
column description format a60
break on struct

select
  'X\$KVII' struct,
  kviitag  variable,
  kviidsc  description,
  kviival  value
from
  sys.x\$kvii
union all
select
  'X\$KVIT',
  kvittag,
  kvitdsc,
  kvitval
from
  sys.x\$kvit
union all
select
  'X\$KVIS',
  kvistag,
  kvisdsc,
  kvisval
from
  sys.x\$kvis
/
"
# .................................................................................
elif [ "$CHOICE" = "GDS" ];then
SQL="col operation format a30
col start_time for a22
col duration format a18
break on operation on report
set lines 124 pages 66
select operation,to_char(start_time,'YYYY-MM-DD HH24:MI:SS')start_time,
       (end_time-start_time) day(1) to second(0) as duration from dba_optstat_operations
order by start_time desc;"
# ..................................................................
elif [ "$CHOICE" = "SYSSTAT" ];then
SQL="
set lines 190 pages 66
set feed off
COL statistics_name         FORMAT A30      HEADING 'Statistics'
COL system_status           FORMAT A10      HEADING 'Status'
COL statistics_view_name    FORMAT A24      heading 'Corresponding view'
COL activation_level        FORMAT A10      heading 'Activation|Level'
COL description             FORMAT A73      heading 'Description'
select statistics_name,system_status, statistics_view_name , activation_level, description from v\$statistics_level ;
prompt 
set feed on
prompt System statistics setting
select pname, pval1  value from sys.aux_stats\$ where sname = 'SYSSTATS_MAIN';
"
elif [ "$CHOICE" = "STS" ];then
   sqlplus -s $CONNECT_STRING  <<EOF
   set head off feed off
   prompt
   select 'FORCE_LOGGING                  ' ||force_logging from v\$database;
   archive log list;
   exit
EOF
   exit
# .................................................................................
elif [ "$CHOICE" = "USE" ];then
SQL="
set lines 190 pages 909
col owner format a18
col name format a55
col version format a10
col detected_usages format 999999 head 'Detected|usages' justify c
col last_usage for a22 head 'Last Usage'
col description format a93
select NAME, DETECTED_USAGES, to_char(LAST_USAGE_DATE,'DD-MM-YYYY HH24:MI:SS') last_usage,
     DESCRIPTION from SYS.DBA_FEATURE_USAGE_STATISTICS where DETECTED_USAGES > 0 order by 1;"
# try this :
# SELECT output FROM TABLE( DBMS_FEATURE_USAGE_REPORT.display_text)
# ..................................................................
elif [ "$CHOICE" = "SAR" ];then
   if  [ -z "$VAL" ];then
       PERC="/snap_len *100,2"
       TYPE=%
   else
       TYPE=s
   fi
   if [ -n "$INST_NUM" ];then
      unset SELECT_INST
      SELECT_INST="define inst='$INST_NUM'"
   else
      SELECT_INST="select instance_number inst from v\$instance;"
   fi
   SQL="
set feed off verify off lines 190 pages 66
col inst new_value inst noprint;
col id1 head 'Idle time($TYPE)' justify c
col usr1 head 'User time($TYPE)' justify c
col sys1 head 'Sys time($TYPE)' justify c
col io1 head 'Io Wait time($TYPE)' justify c
col load1 head 'Avg Load' justify c
col snap_len head 'Interval| (Secs)' justify c
col num_cpus new_value p_num_cpus  head 'Number of CPU';
col a1 new_value secs noprint;
col SNAP_BEGIN format a20 head 'Snap begin' justify c
col SNAP_END format a20 head 'Snap end' justify c

   $SELECT_INST 
   SELECT value num_cpus FROM v\$osstat WHERE stat_name = 'NUM_CPUS';
 prompt
 prompt Negatives values correspond to Shutdown:
 prompt
select  snap_id, snap_len, round(id1 $PERC) id1,  
                       round(usr1 $PERC) usr1,
                       round(sys1 $PERC) sys1, 
                       round(io1 $PERC) io1, 
                       round(load1,1) load1 , snap_begin, snap_end 
from (
     select  snap_id,  id1, usr1,sys1, io1,  load1, snap_begin, snap_end , 
             round( extract( day from diffs) *24*60*60*60+
                    extract( hour from diffs) *60*60+
                    extract( minute from diffs )* 60 +
                    extract( second from diffs )) snap_len                  -- this is the exact length of the snapshot in seconds
     from ( select /*+ at this stage, each row show the cumulative value. 
                       r1    7500  8600
                       r2    7300  8300
                       r3    7200  8110
                    we use [max(row) - lag(row)] to have the difference between [row and row-1], to obtain differentials values:
                       r1    200   300
                       r2    100   190
                       r3    0       0
                    */
        a.snap_id,
        (max(id1)    - lag( max(id1))   over (order by a.snap_id))/100        id1 ,
        (max(usr1)   - lag( max(usr1))  over (order by a.snap_id))/100        usr1,
        ( max(sys1)  - lag( max(sys1))  over (order by a.snap_id))/100        sys1,
        ( max(io1)   - lag( max(io1))   over (order by a.snap_id))/100        io1,
         max(load1)       load1,
          max(to_char(BEGIN_INTERVAL_TIME,' YYYY-MM-DD HH24:mi:ss'))          snap_begin,      -- for later display
          max(to_char(END_INTERVAL_TIME,' YYYY-MM-DD HH24:mi:ss'))            snap_end,        -- for later display
        ( max(END_INTERVAL_TIME)-max(BEGIN_INTERVAL_TIME))                    diffs            -- exact len of snap used for percentage calculation
        from ( /*+  perform a pivot table so that the 5 values selected appears on one line.
                    The case, distibute col a.value among 5 new columns, but creates a row for each.
                    We will use the group by (snap_id) to condense the 5 rows into one.
                    if you don't see the utility, just remove the group by and max function, 
                    then re-add it and you will see the what  use is max() and here is what you will see:
        Raw data :   1000     2222
                     1000     3333
                     1000     4444
                     1000     5555
                     1000     6666       
        The SELECT CASE creates populate our inline view with structure: 
                       ID    IDLE    USER   SYS   IOWAIT   NICE
                     1000    2222
                     1000             3333
                     1000                   4444
                     1000                          5555
                     1000                                  6666
         the goup by(1000) condensate the rows in one:
                       ID    IDLE    USER   SYS   IOWAIT  NICE
                      1000   2222    3333   4444   5555   6666
               */
               select a.snap_id,
                  case b.STAT_NAME
                       when 'IDLE_TIME' then a.value / &p_num_cpus
                   end  id1,
                  case b.STAT_NAME
                       when 'USER_TIME' then a.value / &p_num_cpus
                  end usr1 ,
                  case b.STAT_NAME
                       when 'SYS_TIME' then  a.value / &p_num_cpus
                  end sys1 ,
                  case b.STAT_NAME
                       when 'IOWAIT_TIME' then  a.value / &p_num_cpus
                  end io1,
                  case b.STAT_NAME
                       when 'LOAD' then  a.value
                  end load1
                  from  sys.WRH\$_OSSTAT a,  sys.WRH\$_OSSTAT_NAME b
                       where 
                            a.dbid      = b.dbid       and a.dbid = (select dbid from v\$database) and
                            a.STAT_ID   = b.stat_id    and  
                            instance_number = &inst    and
                            b.stat_name in ('IDLE_TIME','USER_TIME','SYS_TIME','IOWAIT_TIME','LOAD') and
                            a.snap_id > (( select max(snap_id) from  sys.WRH\$_OSSTAT where dbid=a.dbid) - $NSNAP  -1 )
                   order by 1 desc
              ) a,  sys.wrm\$_snapshot s
         where  a.snap_id = s.snap_id
         group by a.snap_id 
         order by snap_id desc 
        ) order by snap_id desc 
   )where rownum < ($NSNAP+1) order by snap_id desc ;
"
# ..................................................................
elif [ "$CHOICE" = "RESOURCE_LIMIT" ];then
SQL="set lines 190 pages 66
select * from v\$resource_limit ;
"
# ..................................................................
elif [ "$CHOICE" = "DEFAULT" ];then
SQL="col PROPERTY_VALUE format a40
 col DESCRIPTION format a40
select * from database_properties;
"
# ..................................................................
elif [ "$CHOICE" = "SYSSTAT_INFO" ];then
SQL="col pval1 for 9999 
col pval2 for a20
select pname, pval1, pval2 from sys.aux_stats\$ where sname  = 'SYSSTATS_INFO'; 
"
# ..................................................................
elif [ "$CHOICE" = "DIFF" ];then
SQL="SET LINESIZE 120 pages 66
COLUMN name          FORMAT A30
COLUMN current_value FORMAT A30
COLUMN sid           FORMAT A8
COLUMN spfile_value  FORMAT A30

SELECT p.name, i.instance_name AS sid, p.value AS current_value, sp.sid, sp.value AS spfile_value      
FROM   v\$spparameter sp,
       v\$parameter p,
       v\$instance i
WHERE  sp.name   = p.name
AND    sp.value != p.value; "

# ..................................................................
elif [ "$CHOICE" = "CVT_TO_SCN" ];then
SQL="
col SCN for 9999999999999
 SELECT TIMESTAMP_TO_SCN(to_timestamp('$FDATE','YYYY-MM-DD HH24:MI:SS')) SCN from dual ; "

# ..................................................................
elif [ "$CHOICE" = "CVT_SCN" ];then
SQL=" SELECT SCN_TO_TIMESTAMP($SCN) from dual ; "

# ..................................................................
elif [ "$CHOICE" = "OPT_LIST" ];then
SQL="col name format a40
col value format a40
set lines 124 pagesize 66
SELECT 
    name, value 
FROM 
    v\$parameter 
WHERE 
    name like 'optimizer%' 
 OR name like 'parallel%' 
 OR name in ('cursor_sharing', 'db_file_multiblock_read_count', 'hash_area_size', 'hash_join_enabled', 'query_rewrite_enabled',
'query_rewrite_integrity', 'sort_area_size', 'star_transformation_enabled', 'bitmap_merge_area_size', 'partition_view_enabled') 
ORDER BY name; 
"
# ..................................................................
elif [ "$CHOICE" = "RAC_LIST" ];then
#-- +----------------------------------------------------------------------------+
#-- |         Jeffrey M. Hunter  : jhunter@idevelopment.info                     |
#-- | PURPOSE  : Provide a summary report of all configured instances for the    |
#-- |            current clustered database.                                     |
#-- +----------------------------------------------------------------------------+
SQL="
SET LINESIZE  145
SET PAGESIZE  9999
SET VERIFY    off

COLUMN instance_name          FORMAT a13         HEAD 'Instance|Name / Number'
COLUMN thread#                FORMAT 99999999    HEAD 'Thread #'
COLUMN host_name              FORMAT a13         HEAD 'Host|Name'
COLUMN status                 FORMAT a6          HEAD 'Status'
COLUMN startup_time           FORMAT a20         HEAD 'Startup|Time'
COLUMN database_status        FORMAT a8          HEAD 'Database|Status'
COLUMN archiver               FORMAT a8          HEAD 'Archiver'
COLUMN logins                 FORMAT a10         HEAD 'Logins?'
COLUMN shutdown_pending       FORMAT a8          HEAD 'Shutdown|Pending?'
COLUMN active_state           FORMAT a6          HEAD 'Active|State'
COLUMN version                                   HEAD 'Version'

SELECT
    instance_name || ' (' || instance_number || ')' instance_name
  , thread# , host_name , status , TO_CHAR(startup_time, 'DD-MON-YYYY HH:MI:SS') startup_time
  , database_status , archiver , logins , shutdown_pending , active_state , version
FROM gv\$instance ORDER BY instance_number;
"
# ..................................................................
elif [ "$CHOICE" = "SUP_LOG" ];then
   SQL="set linesize 134
col SUPPLEMENTAL_LOG_DATA_MIN format  a18 head 'Minimal|Supplemental log| for logminer'
col SUPPLEMENTAL_LOG_DATA_PK format  a18 head 'Supplemental log| for primary keys'
col SUPPLEMENTAL_LOG_DATA_UI format  a18 head 'Supplemental log| for bitmap indexes '
col SUPPLEMENTAL_LOG_DATA_FK format  a18 head 'Supplemental log| for Foreign keys'
col SUPPLEMENTAL_LOG_DATA_ALL format  a18 head 'Supplemental log| for all colums'
col FORCE_LOGGING format  a18 head 'Force logging'
SELECT
  SUPPLEMENTAL_LOG_DATA_MIN ,
  SUPPLEMENTAL_LOG_DATA_PK ,
  SUPPLEMENTAL_LOG_DATA_UI ,
  SUPPLEMENTAL_LOG_DATA_FK ,
  SUPPLEMENTAL_LOG_DATA_ALL ,
  FORCE_LOGGING FORCE_LOG
  from v\$database;"
# ..................................................................
elif [ "$CHOICE" = "LIST_RESTORE_POINT" ];then
SQL="
col RPT for a19 head 'Restore point time' justify c
col Created for a19 head 'Creation time'
col Flash_size_b head 999999999 head 'Flash size|used for this RP' justify c
col GUARANTEE for a9
col SCN for 9999999999999999
col name for a30
col preserved for a9 head 'Preserved' justify c
Set lines 190
select r.name, r.preserved, 
   to_char(r.RESTORE_POINT_TIME,'YYYY-MM-DD HH24:MI:SS') RPT,
   to_char(r.TIME,'YYYY-MM-DD HH24:MI:SS') Created,
   round(r.storage_size/1048576,1) Flash_size_b,
   r.GUARANTEE_FLASHBACK_DATABASE GUARANTEE,
   r.SCN, v.SEQUENCE# archive
  from GV\$RESTORE_POINT r , v\$archived_log v
  where scn >= FIRST_CHANGE#  and scn <  NEXT_CHANGE# 
     and v.THREAD#  = r.INST_ID
/
"
# ..................................................................
elif [ "$CHOICE" = "FLASH_LOG" ];then
SQL="
col name format a70
col FIRST_CHANGE# for 99999999999999
set linesize 190 pagesize 66 head on 
select NAME,log#,THREAD#,SEQUENCE#, 
  round(bytes/1024/1024) bytes_m,FIRST_CHANGE#,to_char(FIRST_TIME,'DD-MM-YYYY HH24:MI:SS')FIRST_TIME
from  V\$FLASHBACK_DATABASE_LOGFILE order by 6 desc;"

# ..................................................................
elif [ "$CHOICE" = "FLASH_STATS" ];then
   SQL="
col name for a60
set lines 157
col space_limit for 9999999 head 'Space|Limit'
col space_used  for 9999999 head 'Space|Used'
col SPACE_RECLAIMABLE for 9999999 head 'Reclaimable|Space(mb)'
col number_of_files for 999999 head 'Files'
col REDO_DATA for 999999999 head 'Redo(mb)'
col Flash_mb  for  999999999 head 'Flash size(mb)'
col estim_flash_mb for  999999999 head 'Estimated|Flash size(mb)'
col fdata   for 99999999 head 'db data(mb)'

select 
   to_char(BEGIN_TIME,'YYYY-MM-DD HH24:MI:SS')BEGIN_TIME, 
   to_char(END_TIME,'YYYY-MM-DD HH24:MI:SS')END_TIME, 
   FLASHBACK_DATA/1048576 Flash_mb ,  DB_DATA/1048576 fdata,  REDO_DATA/1048576 REDO_DATA, 
   ESTIMATED_FLASHBACK_SIZE/1048576 estim_flash_mb 
from V\$FLASHBACK_DATABASE_STAT
/

set head off
select  line from (
select 0 as ord, ' Flashback size (G) '||to_char(round(FLASHBACK_SIZE/1073741824)) as line From V\$FLASHBACK_DATABASE_LOG
union
select 1 as ord, ' Estimated need for retention (G) '||to_char(round(ESTIMATED_FLASHBACK_SIZE/1073741824)) as line From V\$FLASHBACK_DATABASE_LOG
union
select 2 , ' db_recovery_file_dest_size (G) '||to_char(value/1073741824) from V\$PARAMETER where name='db_recovery_file_dest_size'
union
select 3,  ' retention target (minutes) '||value||' (hours : '||value/60||')' from V\$PARAMETER where name='db_flashback_retention_target'
union
select 4  , ' db_recovery_file_dest --> '||value as line  from V\$PARAMETER where name='db_recovery_file_dest'
)
order by ord
; 

set head on
select  trunc(space_limit/1048576) space_limit,
        trunc(space_used/1048576) space_used,
        trunc(SPACE_RECLAIMABLE/1048576) SPACE_RECLAIMABLE, number_of_files
    from v\$recovery_file_dest
/
col old head 'Oldest Flashback Time' for a26
select to_char(oldest_flashback_time,'YYYY-MM-DD HH24:MI:SS') old
 from v\$flashback_database_log
/
SELECT * FROM V\$FLASH_RECOVERY_AREA_USAGE;
"
fi
# ..................................................................
#       Execute the SQL
# ..................................................................
sqlplus -s "$CONNECT_STRING"   <<EOF
$SQL
EOF

