#!/usr/bin/ksh 
S=

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SBINS=$SBIN/scripts
FOUT=$SBIN/tmp/system_event_${ORACLE_SID}_`date +%m%d%H`.txt

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
      echo "could no get a the password of $S_USER"
      exit 0
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
 
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Show System latch per sessions ' nline
from sys.dual
/   
set head on pause off feed off
set linesize 80
break on name

Column name format a30
Column sw format 99999999 head 'Seconds|waited'
SELECT n.name, w.sid, SUM(w.p3) Sleeps, SUM(w.seconds_in_wait) sw
 FROM V\$SESSION_WAIT w, V\$LATCHNAME n
WHERE w.p2 = n.latch#
GROUP BY n.name,w.sid  
order by n.name, sw desc
/
prompt
EOF

