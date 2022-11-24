#!/usr/bin/ksh
#set -xv
# author  : B. Polarski
# program : smenu_object_accessed.sh
# 
function help
{
cat <<EOF

 
     This script will give info on objects accessed by a session
     If you don't give a session sid, then all obejcst/session are shown
     in fact it is worth coupling this withg option '-e' and see also the events
     associate at this moment with the session.


     sla  <sid> -e -n

        -e : show also the events associate to this session
        -n : sort objects by object name

EOF
exit
}

while [ -n "$1" ]
do
 case "$1" in
          -n ) ORDER=" order by object" ;;
          -e ) SHOW_EVENT=Y ;;
          -h ) help;;
          *  ) PAR2=" and a.sid = $1 " ;;
       esac
       shift
done

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SBINS=$SBIN/scripts
FOUT=$SBIN/tmp/sess_obj_acc_${ORACLE_SID}_`date +%m%d%H`.txt

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
      echo "could no get a the password of $S_USER"
      exit 0
fi

if [ "x-$SHOW_EVENT" = "x-Y" ];then
    EVENT_SQL="select
  event, total_waits total_waits, total_timeouts , total_timeouts,
  time_waited/100 time_waited, average_wait
from
  sys.v_\$session_event a , sys.v_\$session b
  where a.sid = b.sid $PAR2
  order by 2 desc
/
"

fi

sqlplus -s "$CONNECT_STRING" <<EOF

set linesize 80
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set termout on
set embedded on
set verify off
set heading off pause off
spool $FOUT
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Show Objects accessed(v\$access)' nline
from sys.dual
/

prompt type 'sla  <sid> for objects accessed only by <sid>
prompt type 'sla  <sid> -e to add <sid> events wait
prompt type 'sla -n to sort object by name

column sid format 9999 head "Sid"
column event format a30 head "Event type"
column origin format a30 head "User"
column total_waits head "Total  |Waits  "
column total_timeouts head "Total  | Timeouts "
column time_waited format 9999999999.9 head " Time (secs)|Waited  "
column average_wait format 99999999.9 head "Average (ms)|Wait   "
prompt
set head on pause off feed off
set linesize 124
break on sid on username on owner on type

column sid format 9999 head "Sid"
column username format A20 head "Username" truncate
column owner format A20 head "Object Owner" truncate
column type format a15 head "Type"
column object format A50 head "Object" truncate

select  s.sid , s.username, a.owner, a.type, a.object
        from v\$access a, v\$session s
        where a.sid = s.sid  $PAR2 $ORDER

/
$EVENT_SQL
EOF

