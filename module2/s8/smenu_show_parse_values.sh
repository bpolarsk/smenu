#!/usr/bin/ksh
#---------------------------------------------------------------------------------
# view v$sysstat values, specificaly related to parsing
# this is a subset of 'sys' and 'ses' for a specific domain
#---------------------------------------------------------------------------------
SBINS=$SBIN/scripts
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
function help
{
  cat <<EOF

   Parsing figures

       par     : System wide statistics
       par -s  : show figures per session
       par -d  : show system detail parsing ditribution

EOF
exit
}
TMP=$SBIN/tmp
cd $TMP
FOUT=$SBIN/tmp/v_sesstat_${ORACLE_SID}.txt
while [ -n "$1" ]
  do
    case "$1" in
    -h ) help ;;
    -s ) ACTION=SESSION ;;
    -d ) ACTION=DETAIL ;;
  esac
  shift
done


. $SBIN/scripts/passwd.env
. ${GET_PASSWD}
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi


if [ "$ACTION" = "DETAIL" ];then
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 80
set termout on pause off
set embedded on
set verify off
set heading off
spool $FOUT

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report system parsing details from v\$sysstat' nline
from sys.dual
/

set linesize 124
set heading on
prompt
column name format A30
select a.*,sysdate-b.startup_time days_old from v\$sysstat a, v\$instance b
where name like 'parse%';
EOF

elif [ "$ACTION" = "SESSION" ];then

sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 80
set termout on pause off
set embedded on
set verify off
set heading off
spool $FOUT

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report parsing performences from v\$sysstat' nline
from sys.dual
/

set linesize 124
set heading on
prompt
column ptc heading "Parse time| cpu   "
column pte heading "Parse time| elapsed  "
column pc heading "Parse count|  (total)" justify c
column ph heading "Parse count|  (hard)" justify c
column perc  format A6 heading "Perc|(hard)" justify c
column tpt heading " Total parse | time  "
column apt format 90.9999 heading " Avg parse| time  "
column exc heading "Execute |count  "

set timing on
SELECT   --+ ordered
     c.sid,
    c.value pc,
    e.value ph,
    a.value ptc,
    b.value pte,
    d.value exc,
    b.value - a.value tpt,
    decode(c.value,0,0,(b.value - a.value)/c.value) apt
    ,decode(c.value,0,0,substr((e.value/c.value) * 100,1,3)) || ' %' perc
  FROM
   (select sid,value from V\$SESSTAT s, v\$statname  n where s.statistic# = n.statistic# and name = 'parse time cpu' ) a
  , (select sid,value from V\$SESSTAT s, v\$statname  n where s.statistic# = n.statistic# and name = 'parse time elapsed' ) b
  , (select sid,value from  V\$SESSTAT s, v\$statname n where s.statistic# = n.statistic# and name = 'parse count (total)') c
  , (select sid,value from  V\$SESSTAT s, v\$statname n where s.statistic# = n.statistic# and name = 'execute count') d
  , (select sid,value from V\$SESSTAT s, v\$statname  n where s.statistic# = n.statistic# and name = 'parse count (hard)' ) e
  where
    a.sid = b.sid
and b.sid =  c.sid
and c.sid = d.sid
and d.sid = e.sid
order by  d.value desc
/
EOF

else  # system wide


sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 80
set termout on pause off
set embedded on
set verify off
set heading off
spool $FOUT

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report parsing performences from v\$sysstat' nline
from sys.dual
/

set linesize 124
set heading on


prompt
Prompt Average wait parsing time should be near 0,
prompt if not you have general contention in your DB

prompt
column ptc heading "Parse time| cpu   "
column pte heading "Parse time| elapsed  "
column pc heading "Parse count|  (total)" justify c
column ph heading "Parse count|  (hard)" justify c
column pp  format A6 heading "Perc|(hard)" justify c
column twt heading " Total parse |wait time  "
column awt heading " Average parse|wait time  "
column exc_cpt heading "Execute |count  "
column rep format 990.99 heading "Ratio   | Parse/Exec"


SELECT
    a.value ptc ,
    b.value pte ,
    c.value pc,
    e.value  ph,
    substr((e.value/c.value) * 100,1,4) || ' %'pp,
    b.value - a.value twt,
    (b.value - a.value)/c.value awt,
    d.value exc_cpt,
    c.value/d.value*100 rep
  FROM
    V\$SYSSTAT a, V\$SYSSTAT b, V\$SYSSTAT c, V\$SYSSTAT d,V\$SYSSTAT e
WHERE
    a.NAME =  'parse time cpu' and
    b.NAME =  'parse time elapsed' and
    c.NAME =  'parse count (total)' and
    e.NAME =  'parse count (hard)' and
    d.NAME =  'execute count'
/
EOF
fi

