#!/bin/sh
#set -xv
# author  : B. Polarski
# program : smenu_show_logical_dg.ksh
# date    : 28 Mars 2006

ROWNUM=30
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

# -------------------------------------------------------------------------------------
function help
{
   cat <<EOF

Dataguard both sites:

          dg -s                 : Site status in dataguard
          dg -l                 : Log standby status
          dg -m                 : monitor log apply and log transport services
          dg -a                 : Logstandby apply status
          dg -o                 : List destination options
          dg -c                 : Log standby Coordinator Status
          dg -d                 : Logical standby archive destination status
          dg -t                 : List targets archive destinations
          dg -r                 : Active apply rate (On Stby only)

          dg -err               : Errors messages
          dg -lerr              : log ship error to standby



Primary site only:

          -p : Logical standby SCN progress


Misc:
         -rn <n> : Limit display to first <n> rows
              -h : This help


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
       'Username          -  '||USER  nline, '$TTITLE (dg -h for help)' nline
from sys.dual
/
set head on
COLUMN STATUS FORMAT A50
COLUMN TYPE FORMAT A12
COLUMN NAME FORMAT A30
COLUMN VALUE FORMAT A30
COLUMN SEQUENCE# FORMAT 9999999 head "SEQ#"
COLUMN DICT_BEGIN format A5 head "Dict|Begin"
col guard_status head "Guard|Status"
col SUPPLEMENTAL_LOG_DATA_MIN format A8 head "Suplement|Log" justify c
col SUPPLEMENTAL_LOG_DATA_PK format A8 head "PK in|Sup Log" justify c
col SUPPLEMENTAL_LOG_DATA_FK format A8 head "FK in|Sup Log" justify c
col SUPPLEMENTAL_LOG_DATA_ALL format A10 head "Fixed|Length in|Sup Log"
col FLASHBACK_ON format A9 head "Flash|Back on" justify c
$BREAK
set linesize 125
prompt
$SQL
EOF
}
# -------------------------------------------------------------------------------------
#                    Main
# -------------------------------------------------------------------------------------

if [ -z "$1" ];then
   help
fi

while [ -n "$1" ]
do
  case "$1" in
       -a ) ACTION=APPLY ; EXECUTE=YES ; TTITLE="Logstandby apply status" ;;
       -c ) ACTION=COORD ; EXECUTE=YES ; TTITLE="Logstandby Coordinator Status" ;;
       -d ) ACTION=ARCH_STAT ; EXECUTE=YES ; TTITLE="Show Logical standby archive " ;;
     -err ) ACTION=ERROR ; EXECUTE=YES ; TTITLE="Error message on the logical apply" ;;
       -l ) ACTION=LGBY ; EXECUTE=YES ; TTITLE="Logstandby status" ;;
    -lerr ) ACTION=LOG_SHIP_ERROR ;  EXECUTE=YES ; TTITLE="log ship error to standby" ;;
       -m ) ACTION=MANAGED ; EXECUTE=YES ; TTITLE="monitor log apply and log transport services" ;;
       -o ) ACTION=DEST_OPTION ; EXECUTE=YES ; TTITLE="List destination options" ;;
       -s ) ACTION=PARAM ; EXECUTE=YES ; TTITLE="Logical dataguard parameters" ;;
       -t ) ACTION=TARGET_DEST ; EXECUTE=YES ; TTITLE=" List target service and archive dir" ;;
       -p ) ACTION=PROG ; EXECUTE=YES ; TTITLE="Show Logical standby SCN progress " ;;
       -r ) ACTION=ACTIVE_RATE ; TITTEL="Show active apply rate" ;EXECUTE=YES  ;;
       -v ) SETXV="set -xv";;
       -h ) help ;;
       -x ) EXECUTE=YES;;
       -r ) ROWNUM=$2 ; shift ;;
        * ) echo "What is $1 ? "; help ;;
  esac
  shift
done

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# -------------------------------------------------------------------------------------
if [ "$ACTION" = "ACTIVE_RATE" ];then
SQL="
set lines 190 pages 66 feed off
col type for a15
col item for a30
col units for a15
col COMMENTS format a50
select * from v\$recovery_progress 
/
prompt
prompt
select to_char(start_time, 'DD-MON-RR HH24:MI:SS') start_time,
item, sofar, units
from v\$recovery_progress 
where 
  item='Active Apply Rate' or 
  item='Average Apply Rate' or 
  item='Redo Applied'
/
"
# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "DEST_OPTION" ];then
SQL="
set lines 190
set numwidth 8 lines 100
column id format 99
select  dest_id id
,       archiver
,       transmit_mode
,       affirm
,       async_blocks async
,       net_timeout net_time
,       delay_mins delay
,       reopen_secs reopen
,       register,binding
from    v\$archive_dest
order by
        dest_id
/

"
# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "TARGET_DEST" ];then
SQL="
set lines 190
set numwidth 15
column ID format 99
column "SRLs" format 99
column active format 99
col type format a4
col status for a20

select  ds.dest_id id
,       ad.status
,       ds.database_mode db_mode
,       ad.archiver type
,       ds.recovery_mode
,       ds.protection_mode
,       ds.standby_logfile_count "SRLs"
,       ds.standby_logfile_active active
,       ds.archived_seq#
from    gv\$archive_dest_status   ds
,       gv\$archive_dest          ad
where   ds.dest_id = ad.dest_id
and     ad.status != 'INACTIVE'
order by
        ds.dest_id
/

"
# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "LOG_SHIP_ERROR" ];then

   SQL="
column  Status    format a10      heading "Status"
column  destination    format a35      heading "Destination"
prompt
 SELECT DEST_ID "ID",
   STATUS "DB_status",
   DESTINATION ,
   ERROR "Error"
   FROM V\$ARCHIVE_DEST
/
Prompt
prompt Check for archive log gaps:
Prompt ===========================
prompt
select * from v\$archive_gap
/
column  Status    format a20      heading "Status"
Prompt Check Managed standby processes:
Prompt ================================
prompt
select process,status from v\$managed_standby
/
"

# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "LGBY" ];then
   SQL="SELECT TYPE, HIGH_SCN, STATUS FROM V\$LOGSTDBY;

column  Status    format a10      heading 'Status'
column  Message    format a80      heading 'Message'
column  error_code    format 999999      heading 'Error| Code'
set lines 190
prompt Type 'dg -l -rn 50' to see 50 lines, default is 30
prompt
select   facility, severity,The_date, message,error_code from (
select facility, severity, to_char(timestamp,'DD/MM/YYYY HH24:MI:SS') The_date, message,
       error_code from v\$dataguard_status order by message_num desc
) where ROWNUM <= $ROWNUM;
"
# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "COORD" ];then
   SQL="SELECT NAME, VALUE FROM V\$LOGSTDBY_STATS WHERE NAME = 'coordinator state';"
# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "MANAGED" ];then
   SQL="col status format A20
        col delay_mins head 'Delay|minutes' justify c
        col client_process head 'Client|process' justify c
        SELECT PROCESS, STATUS, client_process, THREAD#, SEQUENCE#,
               BLOCK#, BLOCKS , delay_mins
      FROM V\$MANAGED_STANDBY;"

# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "PARAM" ];then
     SQL="select GUARD_STATUS, DATABASE_ROLE, PROTECTION_MODE, SWITCHOVER_STATUS,
          SUPPLEMENTAL_LOG_DATA_MIN, SUPPLEMENTAL_LOG_DATA_PK,
          SUPPLEMENTAL_LOG_DATA_FK, SUPPLEMENTAL_LOG_DATA_ALL,
          FLASHBACK_ON  from v\$database ;"

# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "ERROR" ];then
    SQL="COLUMN EVENT FORMAT A20
   COLUMN STATUS FORMAT A60
   COLUMN fdate FORMAT A19 head "Date"
   SELECT to_char(EVENT_TIME,'DD-MM-YYYY HH24:MI:SS') fdate,
          STATUS, EVENT FROM DBA_LOGSTDBY_EVENTS ORDER BY EVENT_TIME, COMMIT_SCN;"

# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "PROG" ];then
   SQL="SELECT APPLIED_SCN, NEWEST_SCN FROM DBA_LOGSTDBY_PROGRESS;"

# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "ARCH_STAT" ];then
   SQL="col DESTINATION format a40
     col status format A20
     SELECT DESTINATION, STATUS, ARCHIVED_THREAD#, ARCHIVED_SEQ# FROM V\$ARCHIVE_DEST_STATUS
     where STATUS <> 'INACTIVE';"

# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "APPLY" ];then
     SQL="COLUMN DICT_BEGIN FORMAT A10;
         COLUMN FILE_NAME FORMAT A60;
         SELECT FILE_NAME, SEQUENCE#, FIRST_CHANGE#, NEXT_CHANGE#,
                TIMESTAMP, DICT_BEGIN, DICT_END FROM DBA_LOGSTDBY_LOG ORDER BY SEQUENCE#;"
fi

if [ "$EXECUTE" = "YES" ];then
   do_execute
else
  echo "$SQL"
fi

