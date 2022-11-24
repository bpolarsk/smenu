#!/bin/ksh
S=
US=','

function help
{

cat <<EOF

  Show session events :

       sle -i   :  sort by SID
       sle -w   :  sort by Waits
       sle -t   :  sort by Time waited
       sle -m   :  show stats in  minutes(instead of seconds)
       sle -u <SID>  show sid related wait info
       sle -e <event name>  : show values for all sessions with this event

EOF
exit
}
while [ -n "$1" ]
do
  case "$1" in
        -i ) ORDER='order by SID ' ;;
        -w ) ORDER='order by total_waits desc' ;;
        -t ) ORDER='order by time_waited desc' ;;
        -m ) S='/60' ;;
        -e ) AND_EVENT=" and a.event= '$2' ";shift;;
        -u ) US=",decode(b.type,'BACKGROUND',b.program,b.username) origin," ;;
        -s ) ORDER=" and a.sid = '$2' order by a.total_waits desc"
             if [ -z "$2" ];then
                unset ORDER
             fi
             shift ;;
       -h ) help ;;
       -v ) set -xv ;;
        * )  AND=" and a.sid = '$1' " ;;
 esac
 shift
done

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SBINS=$SBIN/scripts
FOUT=$SBIN/tmp/session_event_${ORACLE_SID}_`date +%m%d%H`.txt

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
      echo "could no get a the password of $S_USER"
      exit 0
fi


sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '          '     Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on embedded on verify off heading off pause off
spool $FOUT

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Show Session events figures (v\$session_event)' nline
from sys.dual
/
set head on pause off feed off
set linesize 120


prompt
column sid format 9999 head "Sid"
column average_wait format 9999990.00
column event format a30 head "Event type"
column origin format a30 head "User"
column total_waits head "Total  |Waits  "
column total_timeouts head "Total  | Timeouts "
column time_waited format 9999999999.9 head " Time (secs)|Waited  "
column average_wait format 99999999.9 head "Average (ms)|Wait   "
col wait_class format a20
select
  a.sid $US
  a.event, total_waits $S total_waits, total_timeouts $S total_timeouts,
  time_waited/100 $S time_waited, average_wait $S average_wait, a.wait_class, a.wait_class#
from
  sys.v_\$session_event a , sys.v_\$session b
  where a.sid = b.sid
  $AND $AND_EVENT $ORDER
/
spool off
prompt
EOF

echo "Result in  $FOUT"
