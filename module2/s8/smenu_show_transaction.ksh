#!/bin/ksh
# smenu_show_transaction.ksh
# Author  : bernard Polarski
# Date    : 25-April-2006
# set -x
cd $TMP
# ----------------------------------------------------------------
function help
{
cat <<EOF

        tx -s -p -n -h -purge <TRANS_ID>

        -s : List SCN instead of xid
        -n : Lists all incoming (from remote client) and outgoing (to remote server)
             in-doubt distributed transactions(DBA_2PC_NEIGHBORS)
        -h : This help
        -p : Lists all in-doubt distributed transactions (DBA_2PC_PENDING)
             You get the TRANS_ID for purge 
    -purge : To manually remove an entry from the data dictionary

  note : use 
    
      ROLLBACK/COMMIT force 'global_trans_id' before using -purge

EOF
}
# ----------------------------------------------------------------
function do_it
{

sqlplus -s "$CONNECT_STRING" <<EOF1
set heading off
set embedded off pause off
set verify off
set linesize 132
set pagesize 66
column nline newline

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report            -  $TITLE' nline
from sys.dual
/
set embedded on
set heading on
prompt         Type tx -h for help
prompt
column se_status format A8 head "Session|Status"
column tr_status format A8 head "Transact.|Status"
column strt  head "Start time"
column since  head "Running|time (s)"
column start_scn format 9999999999999 head "Start SCN"
column sid format 99999
column segment_name format A22


$SQL
exit
EOF1

}
# -----------------------------------------------------------------------
CHOICE=LIST
FIELD=XID
TITLE="Show transaction info"
while [ -n "$1" ];
do

   case "$1" in
     -s )  FIELD=START_SCN ;;
 -purge )  trans_id=$2 ;shift
           TITLE="Purge transaction $trans_id from data dictionary"
           CHOICE=PURGE
           export S_USER=SYS;;
     -p )  CHOICE=2PC
           TITLE="Lists all in-doubt distributed transactions";;
     -n )  CHOICE=NEIGHB
           TITLE="Lists all incoming and outgoing in-doubt distributed transactions." ;;
  -sid  )  SID=$2 ; shift ;;
     -h )  help ; exit ;;
    -v  )  VERBOSE=TRUE ;;
     *   ) CHOICE=LIST ;;
   esac
   shift
done
. $SBIN/scripts/passwd.env
. ${GET_PASSWD}
#. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# ......................................
# List transactions
# ......................................
if [ "$CHOICE" = "LIST" ];then
  if [ -n "$SID" ];then
      AND_SID=" and vs.sid = $SID "
  fi
 SQL=" col version new_value version noprint
col field new_value field noprint
col tx_id for a20 head tx_id
col used_urec format 9999999999 head 'Undo|Records'
col undo_size head 'Undo|size (k)' justify c
col machine for a20
set lines 210
-- select substr(version,1,instr(version,'.',1)-1) version from v\$instance;
-- select decode(&version,9,'','$FIELD,') field from dual;
Select r.segment_name,To_Char(To_Date(vt.Start_Time,'MM-DD-RR HH24:MI:SS'),'MM-DD HH24:MI:SS') "strt"
     ,  decode(vs.status,'ACTIVE',vs.last_Call_et,0) "since" , vs.sid, vs.status se_status, 
       XID, to_char(XIDUSN)||'.'||to_char(XIDSLOT)||'.'||to_char(XIDSQN) tx_id, 
       vt.status tr_status, log_io, phy_io,cr_get,cr_change, vt.used_urec, vt.used_ublk * p.value/1024 undo_size,
      vs.machine
  From dba_rollback_segs dr,
       v\$rollstat rs,
       v\$transaction vt,
       v\$session vs,
       v\$process vp,
       dba_rollback_segs r,
       v\$parameter p
  Where vs.Paddr = vp.Addr (+) AND p.name  = 'db_block_size' $AND_SID
   and vt.xidusn (+)  = r.segment_id
   And vs.UserName Is Not Null
   And vs.Taddr Is Not Null
   And vs.Taddr = vt.Addr
   And vt.xidusn = dr.segment_id
   And vt.xidusn = rs.usn
    Order By VS.OsUser, To_Date(vt.Start_Time,'MM-DD-RR HH24:MI:SS') ;"

# ......................................
# Lists all in-doubt distributed transactions
# ......................................
elif [ "$CHOICE" = "2PC" ];then
    SQL="COL LOCAL_TRAN_ID FORMAT A13
COL GLOBAL_TRAN_ID FORMAT A36
COL STATE FORMAT A14
COL MIXED FORMAT A3
COL HOST FORMAT A20
COL COMMIT# FORMAT A12
set lines 159
SELECT LOCAL_TRAN_ID trans_id, GLOBAL_TRAN_ID, STATE, MIXED, HOST, COMMIT# ,
      to_char(fail_time ,'DD:MM HH24:MI:SS')Fail_time,to_char(retry_time,'DD:MM HH24:MI:SS')retry_time
      FROM DBA_2PC_PENDING;"

# ......................................
# Lists all ingoing and outgoing distributed transactions
# ......................................
elif [ "$CHOICE" = "NEIGHB" ];then
  SQL="COL LOCAL_TRAN_ID FORMAT A13
COL IN_OUT FORMAT A6
COL DATABASE FORMAT A25
COL DBUSER_OWNER FORMAT A15
COL INTERFACE FORMAT A3
SELECT LOCAL_TRAN_ID, IN_OUT, DATABASE, DBUSER_OWNER, INTERFACE FROM DBA_2PC_NEIGHBORS;"

elif [ "$CHOICE" = "PURGE" ];then
  if [ -z "$trans_id" ];then
       echo "No transaction id provided "
       echo "get trans_id with tx -p"
       exit 1
  fi
  SQL="execute DBMS_TRANSACTION.PURGE_LOST_DB_ENTRY('$trans_id');"
fi
if [ -n "$VERBOSE" ];then 
   echo "$SQL"
fi
do_it

