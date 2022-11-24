#!/bin/sh
#  set -xv
# author  : B. Polarski
# program : smenu_run_dbms_repair.ksh
# date    : 9 Decembre 2005

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
# default entreprise manager grid control owner
SYSMAN=sysman
#S_USER=SYSMAN
# you can export in the local en the target repository, export TTTREP=<grid sid>
if [ -n "$TTREP" ];then
   if [ ! "$ORACLE_SID" = "$TTREP" ];then
       export ORACLE_SID=$TTREP
   fi
fi
EXECUTE=YES
ROWNUM=50
# -------------------------------------------------------------------------------------
function help 
{

  cat <<EOF

         GRID control
         (require sysman in vpas)

    gc  -e -t <target> : List errors
    gc  -lt            : List targets
    gc  -td            : restrict target list to database
    gc  -tl            : restrict target list to listnener
 
    gc -rmw -t <target> : Remove warning
    gc -rmc -t <target> : Remove critical

    gc -lb  -rn <n>      : List backup from rman (database only) - rman.bs, rman.rc_database
    gc -lba  -rn <n>     : List backup from rman (database and archive) - rman.bs, rman.rc_database
    gc -bk <SID> -rn <n> : List backup infp from cloud control



  -t    <target_name>   : use gc -td/lt/tl to list a target
  -su <S_USER>          : if you need to set S_USER to sysman. Must have sysman passwd in vpas

 example : gc -t arch.tdrdbprd.srv.bpo.be -rmw


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
       'Username          -  '||USER  nline, '$TTITLE ' nline
from sys.dual
/
set head on
col module_name format a16
col error_msg format a54
col facility format a8
col EMD_URL format a24
$BREAK
set linesize 124 pagesize 66 
prompt 
$SQL
EOF
}
# -------------------------------------------------------------------------------------
#                    Main
# -------------------------------------------------------------------------------------
if [ -z "$1" ];then 
   help; exit
fi
BK_SIZE=mega
# ............ some default values and settings: .................
while [ -n "$1" ]
do
  case "$1" in
       -bk   ) ACTION="CLOUD_BACKUP" ; BK_SID=$2; shift;;
       -e   ) ACTION="LIST_ERR" ;;
       -lb  ) ACTION=LIST_RMAN_BK ;;
      -lba  ) ACTION=LIST_RMAN_BK ; FTYPE=DA;;
       -lt  ) ACTION="LIST_TARGETS" ;;
       -rmw ) ACTION="REMOVE_MESSAGE" ; CRIT=20 ;;
       -rmc ) ACTION="REMOVE_MESSAGE" ; CRIT=25 ;;
       -su  ) export S_USER=$1; shift ;;
       -t   ) TARGET=$2 ;shift ;;
       -td  ) ACTION="LIST_TARGETS" 
              AND_TYPE="and target_type='oracle_database'" ;;
       -tl  ) ACTION="LIST_TARGETS"
              AND_TYPE="and target_type='oracle_listener'" ;;
       -rn  ) ROWNUM=$2 ; shift ;;
       -g   ) BK_SIZE=giga;;
       -v   ) SETXV="set -xv";;
       -nx  ) EXECUTE=NO;;
        * ) echo "Invalid argument $1"
            help ;;
 esac
 shift
done
. ${GET_PASSWD} $SYSMAN $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# .................................................
if [ "$ACTION" = "CLOUD_BACKUP" ];then
 if [ $BK_SIZE = "giga" ];then
    DIV=1024
 else
    DIV=1
 fi
SQL="
col DB_NAME for a20
col JOB_STARTED for a22
col RMAN_STATUS for a20
col minutes for 9999 head  'Dur.|(min)' justify c
col IN_MBYTES head 'Read(m)'
col out_MBYTES head 'size|write(m)' justify c
set lines 210 pages 90
prompt Backup : size in $BK_SIZE
select * from (
select 
 DB_NAME, 
   INCR_LVL Lvl,
   round(IN_MBYTES/$DIV) IN_MBYTES, round(OUT_MBYTES/$DIV) out_MBYTES,
   to_char(JOB_STARTED,'MM-DD/HH24:MI') fstart,
   to_char(JOB_ENDED,'DD/HH24:MI') fend,
   round((job_ended - job_started) * 24 * 60) minutes,
DATABASE_ROLE,
 RMAN_STATUS
  from 
    mgmt_view.db_backup_tbl_all 
  where 
    DB_UNIQUE_NAME='$BK_SID'  
  order by JOB_STARTED desc
) where rownum <=$ROWNUM
/
"
# .................................................
# 
# if you connect as sysman, you need grants from rman views, then run this
# select 'grant select on '|| view_name || ' to sysman ;' from user_views ;
# .................................................
elif [ "$ACTION" = "LIST_RMAN_BK" ];then
   if [ "$FTYPE" != "DA" ];then
      AND_DA=" and BCK_TYPE in ('D','I') "
   fi
   if [ -n "$TARGET" ];then
        AND_TARGET=" and rc.name = upper('$TARGET') "
   fi
SQL="
set lines 190 pages 250
col START_TIME head 'Start time'
col COMPLETION_TIME head 'End time'
col STATUS for a6 head 'Status'
col BCK_TYPE head 'Bkp|Type' for a4
col INCR_LEVEL head 'lvl' 
select name, BCK_TYPE, status, start_time, completion_time, tag,cpt_files from (
select rc.NAME,
       bs.STATUS , 
  case
    when BCK_TYPE='D' then 'Full'
    when BCK_TYPE='I' then 'INC'
    when BCK_TYPE='L' then 'Arch'
    else BCK_TYPE
  end bck_type
   , INCR_LEVEL , bs.BS_KEY, bs.BS_RECID, PIECES,
    bp.tag,
    rank() over (partition by tag order by bs.START_TIME,set_count) rnk,
    min(to_char(bs.START_TIME,'YYYY-MM-DD HH24:MI:SS')) over (partition by tag) start_time,
    max(to_char(bs.COMPLETION_TIME,'YYYY-MM-DD HH24:MI:SS')) over (partition by tag) completion_time,
    count(*) over (partition by tag ) cpt_files
from rman.bs bs, rman.rc_database rc , rman.bp bp
where 
       rc.DB_KEY = bs.DB_KEY  $AND_DA $AND_TARGET
--and rc.name='NORKOMPR'
   and bp.db_key (+) =  bs.db_key and bp.BS_KEY (+) = bs.BS_KEY 
   and bs.bs_key not in(select bs_key from rman.rc_backup_spfile)
--   and bs.bs_key not in (select bs_key from rman.rc_backup_controlfile ) -- where AUTOBACKUP_DATE is not null or AUTOBACKUP_SEQUENCE is not null)
order by START_TIME desc
) where rnk=1 and rownum <=$ROWNUM
/

"
# .................................................
#   Remove messages
# .................................................
elif [ "$ACTION" = "REMOVE_MESSAGE" ];then

if [ -z "$TARGET" ];then
   echo "I need a target, use gc -td or gc -lt "
   exit
fi
SQL="
set serveroutput on lines 200 trimspool on
declare
  cmd varchar2(500) ;
begin
 for c in ( select  t.target_guid , metric_guid , key_value 
            from   sysman.mgmt_targets t inner join sysman.mgmt_current_severity s on t.target_guid = s.target_guid
             where SEVERITY_CODE = $CRIT and 
                target_name like '$TARGET' )
 loop
     cmd:='exec em_severity.delete_current_severity(''' || c.target_guid || ''',''' || c.metric_guid || ''',''' || c.key_value || ''')'   ;
     dbms_output.put_line(cmd ) ;
     em_severity.delete_current_severity( c.target_guid, c.metric_guid , c.key_value )   ;
 end loop ;
end ;
/
"
# .................................................
#   List errors
# .................................................
elif [ "$ACTION" = "LIST_TARGETS" ];then
SQL="
set pages 900 lines 190
col TARGET_NAME for a50
col TARGET_TYPE for a20
col HOST_NAME for a40
select target_name, TARGET_TYPE, to_char(LAST_UPDATED_TIME,'YYYY-MM-DD HH24:MI:SS') Last_load , HOST_NAME 
 from sysman.mgmt_targets  
where 1=1 $AND_TYPE order by TARGET_TYPE, target_name 
/
"
# .................................................
elif [ "$ACTION" = "LIST_ERR" ];then
if [ -n "$TARGET" ];then
   AND_TARGET=" and target_name='$TARGET'"
fi
   SQL="select MODULE_NAME,to_char(OCCUR_DATE,'DD-MM-YY HH24:MI:SS')occur_date,FACILITY,EMD_URL, error_msg 
               from SYSMAN.MGMT_SYSTEM_ERROR_LOG where 1=1 $AND_TARGET
order by occur_date desc; "
fi
# .................................................
# .................................................
# .................................................
if [ "$EXECUTE" = "YES" ];then
   do_execute
else
  echo "$SQL"
fi
