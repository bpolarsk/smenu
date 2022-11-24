#!/usr/bin/ksh
#---------------------------------------------------------------------------------
#-- Script:	smenu_latch_wait.ksh
#-- Author:	B. Polarski
#-- date  :	13 Sept 2005
#               20 Sept 2005 Added the 'buffer busy wait' to -d option
#---------------------------------------------------------------------------------
SBINS=$SBIN/scripts
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
PROMPD="prompt law -d to see details for buffer busy wait and latch children"
while getopts ftad ARG
do
  case $ARG in
   t ) PAR=$1 ;;
   d ) unset PROMPD 
       DETAIL_E=",decode(w.event, 'buffer busy waits', 
                        (select 'Hot block : '|| to_char(a.block#) || ' File ' || a.file# || ' Segment -->' || name from 
                              (select decode(bitand(t.property, 8192), 8192, 'NESTED TABLE', 'TABLE') type,
                                    t.obj#, t.file#, t.block#, t.ts# from sys.tab$ t where bitand(t.property, 1024) = 0 
                               union all
                               select 'TABLE PARTITION' type, tp.obj#, tp.file#, tp.block#, tp.ts# from sys.tabpart$ tp
                               union all
                               select 'CLUSTER' type, c.obj#, c.file#, c.block#, c.ts# from sys.clu$ c
                               union all
                               select decode(i.type#, 8, 'LOBINDEX', 'INDEX') type, i.obj#, i.file#, i.block#, i.ts# 
                                      from sys.ind$ i where i.type# in (1, 2, 3, 4, 6, 7, 8, 9)
                               union all
                               select 'INDEX PARTITION' type, ip.obj#, ip.file#, ip.block#, ip.ts# from sys.indpart$ ip
                               union all
                               select 'LOBSEGMENT' type, l.lobj#, l.file#, l.block#, l.ts# from sys.lob$ l
                               union all
                               select 'TABLE SUBPARTITION' type, tsp.obj#, tsp.file#, tsp.block#, tsp.ts# 
                                      from sys.tabsubpart$ tsp
                               union all
                               select 'INDEX SUBPARTITION' type, isp.obj#, isp.file#, isp.block#, isp.ts# 
                                      from sys.indsubpart$ isp
                               union all
                               select decode(lf.fragtype$, 'P', 'LOB PARTITION', 'LOB SUBPARTITION') type,
                                      lf.fragobj#, lf.file#, lf.block#, lf.ts# 
                                      from sys.lobfrag$ lf ) a, sys.obj$ o
                                           where a.obj# = o.obj# and  file# = p1 and block# >=p2 and block#  <= p2+1 
                       ),w.event) evt" 

       DETAIL_L=",decode(n.name, 'library cache', (select '  Address --> ' || address || ' SQL--> ' || 
                           sql_text from v\$sql, v\$session where sid = w.sid and
                           ((address = sql_address and hash_value = sql_hash_value) or 
                           (address = prev_sql_addr  and hash_value = prev_hash_value )) and rownum = 1)) spec" ;;
   f ) SPOOL="spool $FOUT" 
       FOUT=$SBIN/tmp/law_$ORACLE_SID_`date +%d%H%S`.log ;;
  esac
done
TMP=$SBIN/tmp
cd $TMP

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} 
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
PROMPT="
prompt .                                                       Number   Seconds
prompt Sid   Event name               Latch Name               Sleeps   Waiting      P1      P1RAW      P2       P2RAW
prompt----- ------------------------ ------------------------ --------- -------- ---------- -------- ---------- --------"

if [ "$PAR" = "-t" ];then

sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 80
set termout on pause off
set embedded on
set verify off
set heading off
$SPOOL

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report Latch current activity'
from sys.dual
/

set linesize 150
set heading on
column name        format a24 heading "Latch type"
column event       format a24 heading "Event name"
column waits_holding_latch   format 99999999 heading "Wait     | holding latch"
column sleeps  format 99999999 heading "Number|Sleeps"
column sw      format 999999 heading "Seconds| Waiting"
column sid     format 9999 heading "Sid"

select b.sid, event, name, sleeps , sw , address from
v\$open_cursor a,
( SELECT w.sid,  w.event,n.name, SUM(w.p3) Sleeps, SUM(w.seconds_in_wait) sw
 FROM V\$SESSION_WAIT w, V\$LATCHNAME n
WHERE w.p2 = n.latch# and latch# not in (1)
GROUP BY w.sid, n.name, w.event ) b
where b.sid = a.sid  
/
EOF

else
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 80
set termout on pause off
set embedded on
set verify off
set heading off
$SPOOL

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report Latch sleeps statistics'
from sys.dual
/
set linesize 150
set heading off
column spec        format a124 heading "Message"
column evt        format a124 heading "Message"
column name        format a24 heading "Latch Name"
column event       format a24 heading "Event name"
column waits_holding_latch   format 99999999 heading "Wait     | holding latch"
column sleeps  format 99999999 heading "Number|Sleeps"
column sw      format 999999 heading "Seconds| Waiting"
column sid     format 9999 heading "Sid"

$PROMPD
$PROMPT

SELECT w.sid ,  w.event,n.name, w.p3 Sleeps, w.seconds_in_wait sw
       , p1, p1raw, p2, p2raw $DETAIL_L $DETAIL_E
 FROM V\$SESSION_WAIT w, V\$LATCHNAME n 
WHERE  w.event not in ('rdbms ipc message') 
   and w.p2 = n.latch# and latch# not in (1)
order by w.sid
/

EOF
fi

if [ -f "$FOUT" ];then
    $SBINS/yesno.sh "To review spool file " DO N
    vi $FOUT
fi
