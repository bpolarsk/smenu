#!/bin/ksh
# set -x
#---------------------------------------------------------------------------------
#-- Copyright:	(c) 2001 Ixora Pty Ltd
#-- Author:	Steve Adams, adapted to smenu by B. Polarski
#---------------------------------------------------------------------------------
#
function help 
{
  cat <<EOF

  spx   -a  -rac 

         -a :         # Order by address
         -dop :         # show Degree of Parallelism (DOP)
         -f :         # show Degree of Parallelism operations
         -o :         # show overview of Parallelism 
         -s :         # stat from PQ_SYSTAT
         -l :         # List QC and slaves query
         -ls :        # List QC and slaves query on short format
         -t  :        # Show parallel stats from v\$systat
         -pc :        # List dbms_parallel excute chunks status
   


EOF
exit
}
SBINS=$SBIN/scripts
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

if [ -z "$1" ];then
   help
fi

TITTLE='Report PQ slaves '
while [ -n "$1" ]
do
  case "$1" in
   -a ) ORDER="ORDER by address" ;;
   -d ) METHOD=DFO ;;
   -dop ) METHOD=DOP ;;
   -f ) METHOD=LONGOPS ;;
   -l ) METHOD=LIST_LOCAL;;
  -ls ) METHOD=LIST_LOCAL_SHORT;;
   -o ) METHOD=OVERVIEW ;;
   -pc )METHOD=PC ;;
 -rac ) METHOD=RAC ;;
   -s ) METHOD=PX_SYSTAT ;;
   -t ) METHOD=SYSTAT ;;
   -v ) set -xv ;;
   -h ) help ;;
  esac
  shift
done
TMP=$SBIN/tmp
cd $TMP

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} 
if [  -z "$CONNECT_STRING" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

if [ "$METHOD" = "PC" ];then
SQL="
set lines 190
col task_name for a40
select count(*) cpt , STATUS, TASK_NAME from dba_parallel_execute_chunks group by TASK_NAME, STATUS ;
"
elif [ "$METHOD" = "SYSTAT" ];then
SQL="
set lines 190
col name for a50
SELECT NAME, VALUE FROM GV\$SYSSTAT
 WHERE UPPER (NAME) LIKE '%PARALLEL OPERATIONS%'
OR UPPER (NAME) LIKE '%PARALLELIZED%' OR UPPER (NAME) LIKE '%PX%'
/
"
 # from metallink
elif [ "$METHOD" = "OVERVIEW" ];then
 # from metallink
SQL="
set pages 300 lines 300 
col Username for a12 
col qc head 'QC/Slave' for A8 
col Slaveset for A8 
col  sinst head 'Slave INST' for A9 
col qcs head 'QC SID' for A6 
col QCI head 'QC INST' for A6 
col operation_name for A30 
col target for A30 

select 
decode(px.qcinst_id,NULL,username,  
' - '||lower(substr(pp.SERVER_NAME, 
length(pp.SERVER_NAME)-4,4) ) )Username, 
decode(px.qcinst_id,NULL, 'QC', '(Slave)') QC , 
to_char( px.server_set) SlaveSet, 
to_char(px.inst_id) SINST, 
substr(opname,1,30)  operation_name, 
substr(target,1,30) target, 
sofar, 
totalwork, 
units, 
start_time, 
timestamp, 
decode(px.qcinst_id, NULL ,to_char(s.sid) ,px.qcsid) QCS, 
to_char(px.qcinst_id) QCI 
from gv\$px_session px, 
gv\$px_process pp, 
gv\$session_longops s  
where px.sid=s.sid  
and px.serial#=s.serial# 
and px.inst_id = s.inst_id 
and px.sid = pp.sid (+) 
and px.serial#=pp.serial#(+) 
order by 
  decode(px.QCINST_ID,  NULL, px.INST_ID,  px.QCINST_ID), 
  px.QCSID, 
  decode(px.SERVER_GROUP, NULL, 0, px.SERVER_GROUP),  
  px.SERVER_SET,  
  px.INST_ID 
/
"
elif [ "$METHOD" = "DOP" ];then
SQL="
col username for a12 
col QCS head  'QC SID' for A6 
col SID for A6 
col QCSlave head 'QC/Slave' for A8 
col rDOP head 'Req. DOP' for 9999 
col aDOP head 'Actual DOP' for 9999 
col Slaveset for A8 
col SINST head 'Slave INST' for A9 
col qci head 'QC INST' for A6 
set pages 300 lines 300 
col wait_event format a30 
select 
decode(px.qcinst_id,NULL,username,  ' - '||lower(substr(pp.SERVER_NAME, length(pp.SERVER_NAME)-4,4) ) )Username, 
decode(px.qcinst_id,NULL, 'QC', '(Slave)') QCSlave , 
to_char( px.server_set) SlaveSet, 
to_char(s.sid) SID, 
to_char(px.inst_id) SINST, 
decode(sw.state,'WAITING', 'WAIT', 'NOT WAIT' ) as STATE,      
case  sw.state WHEN 'WAITING' THEN substr(sw.event,1,30) ELSE NULL end as wait_event , 
decode(px.qcinst_id, NULL ,to_char(s.sid) ,px.qcsid) QCS, 
to_char(px.qcinst_id) QCI, 
px.req_degree RDOP, 
px.degree ADOP
from   gv\$px_session px, 
       gv\$session s , 
       gv\$px_process pp, 
       gv\$session_wait sw 
where px.sid=s.sid (+) 
and px.serial#=s.serial#(+) 
and px.inst_id = s.inst_id(+) 
and px.sid = pp.sid (+) 
and px.serial#=pp.serial#(+) 
and sw.sid = s.sid   
and sw.inst_id = s.inst_id    
order by 
  decode(px.QCINST_ID,  NULL, px.INST_ID,  px.QCINST_ID), 
  px.QCSID, 
  decode(px.SERVER_GROUP, NULL, 0, px.SERVER_GROUP),  
  px.SERVER_SET,  
  px.INST_ID 
/ 
"
elif [ "$METHOD" = "LONGOPS" ];then
SQL="
set pages 300 lines 300 
col wait_event format a30 
select  
  sw.SID as RCVSID, 
  decode(pp.server_name,  
         NULL, 'A QC',  
         pp.server_name) as RCVR, 
  sw.inst_id as RCVRINST, 
case  sw.state WHEN 'WAITING' THEN substr(sw.event,1,30) ELSE NULL end as wait_event , 
  decode(bitand(p1, 65535), 
         65535, 'QC',  
         'P'||to_char(bitand(p1, 65535),'fm000')) as SNDR, 
  bitand(p1, 16711680) - 65535 as SNDRINST, 
  decode(bitand(p1, 65535), 
         65535, ps.qcsid, 
         (select  
            sid  
          from  
            gv\$px_process  
          where  
            server_name = 'P'||to_char(bitand(sw.p1, 65535),'fm000') and 
            inst_id = bitand(sw.p1, 16711680) - 65535) 
        ) as SNDRSID, 
   decode(sw.state,'WAITING', 'WAIT', 'NOT WAIT' ) as STATE      
from  
  gv\$session_wait sw, 
  gv\$px_process pp, 
  gv\$px_session ps 
where 
  sw.sid = pp.sid (+) and 
  sw.inst_id = pp.inst_id (+) and  
  sw.sid = ps.sid (+) and 
  sw.inst_id = ps.inst_id (+) and  
  p1text  = 'sleeptime/senderid' and 
  bitand(p1, 268435456) = 268435456 
order by 
  decode(ps.QCINST_ID,  NULL, ps.INST_ID,  ps.QCINST_ID), 
  ps.QCSID, 
  decode(ps.SERVER_GROUP, NULL, 0, ps.SERVER_GROUP),  
  ps.SERVER_SET,  
  ps.INST_ID 
/ 

"
elif [ "$METHOD" = "LIST_LOCAL_SHORT" ];then
    # A nice application of sys_connect_by_path from Jacques Ferauge, DBA at AtosWorldline
SQL="
SET LINES 180 pages 66
COL qcsid  FORMAT 99999  Head 'Master| sid '
COL sidl   FORMAT A50 Head 'List of slave sid'
COL event  Format A56 Head 'Event of Master session'
COL qcount format 999 Head '  #  |slaves'
COL username format A16 head 'Oracle User'
COL sql_id format a15 head 'sql id'
COL SECONDS_IN_WAIT format 99G999 Head 'Wait| (ses)'
SELECT qcsid, sql_id, ses.username, w.event, w.SECONDS_IN_WAIT, qcount, sidl FROM
(
SELECT qcsid, max(seq) qcount, 
    max(ltrim (SYS_CONNECT_BY_PATH (sid , ','),',')) AS sidl
        FROM   (SELECT DISTINCT ps.qcsid, ps.sid
                           , DENSE_RANK () OVER (PARTITION BY ps.qcsid ORDER BY ps.sid) AS seq
                    FROM   v\$px_session ps WHERE ps.sid <> ps.qcsid
                )
        START  WITH seq = 1
         CONNECT BY PRIOR seq + 1 = seq AND PRIOR qcsid  = qcsid
       GROUP  BY qcsid 
) SQ
, v\$session_wait w
, v\$session ses
WHERE w.sid(+) = SQ.qcsid
AND SES.sid = SQ.qcsid
;
"
elif [ "$METHOD" = "RAC" ];then
  # Query attributed to Doug Burn
  TITTLE="Query Coordinator (QC) and slaves on rac"
SQL="set lines 190 pages 66
prompt QC=Query Coordinator    User 'lsof -p' on spid of QC to see actual traffic
prompt
col username for a26
col adop head 'Acttual|DOP' justify c
col rdop head 'Requested|DOP' for 9999999 justify c
col qcsid head 'QC Sid' for a7
col qcslave head 'QC or|Slave'
col server_set head 'Slave set' for a10
col inst_id for 9999 head 'Inst|id' justify l
col sid for a6
   select
      s.inst_id,
      decode(px.qcinst_id,NULL,s.username,
            ' - '||lower(substr(s.program,length(s.program)-4,4) ) ) Username,
      decode(px.qcinst_id,NULL, 'QC', '(Slave)') qcslave,
      to_char( px.server_set) server_set,
      to_char(s.sid) SID,
      decode(px.qcinst_id, NULL ,to_char(s.sid) ,px.qcsid) qcsid ,
      px.req_degree rdop ,
     px.degree adop, p.spid
   from
     gv\$px_session px, gv\$session s, gv\$process p
   where
     px.sid=s.sid (+) and
     px.serial#=s.serial# and
     px.inst_id = s.inst_id
     and p.inst_id = s.inst_id
     and p.addr=s.paddr
  order by 6,3 desc,5, 1 desc
/
"
elif [ "$METHOD" = "DFO" ];then
# this can only be run into the session, not from the exterior.
# So cut an paste the whole an run it into the SQL Sessions
#  A query from Christo Kutrovsky of Pythian group
SQL="
set lines 190 feed on
col perc head '%'
col br head 'b/r'
break on dfo_number on tq_id
select dfo_number "d", tq_id as "t", server_type, 
       num_rows,rpad('x',round(num_rows*10/nullif(max(num_rows) 
             over (partition by dfo_number, tq_id, server_type),0)),'x') as pr, 
       round(bytes/1024/1024) mb,  process, instance i,
       round(ratio_to_report (num_rows) over (partition by dfo_number, tq_id, server_type)*100) as pec, 
       open_time, avg_latency, waits, timeouts,round(bytes/nullif(num_rows,0)) asbr 
from v\$pq_tqstat 
   order by dfo_number, tq_id, server_type desc, process
/
"
elif [ "$METHOD" = "PX_SYSTAT" ];then
SQL="col statistic format a50
SELECT * FROM v\$pq_sysstat  ;
"
elif [ "$METHOD" = "LIST_LOCAL" ];then
SQL=" select x.server_name
	     , x.status as x_status
	     , x.pid as x_pid
	     , x.sid as x_sid
	     , w2.sid as p_sid
	     , v.osuser
	     , v.schemaname
	     , w1.event as child_wait
	     , w2.event as parent_wait
	from  v\$px_process x
	    , v\$lock l
	    , v\$session v
	    , v\$session_wait w1
	    , v\$session_wait w2
	where x.sid <> l.sid(+)
	-- and   to_number (substr(x.server_name,3)) = l.id2(+)
	and   x.sid = w1.sid(+)
	and   l.sid = w2.sid(+)
	and   x.sid = v.sid(+)
	and   nvl(l.type,'PS') = 'PS'
	order by 4,1,2;
"
fi
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline 
set pagesize 66 linesize 80 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER,15)|| '$TITTLE'
from sys.dual
/

set linesize 124 pagesize 66
set heading on
column name        format a24 heading "Latch type"
column child_wait  format a30 heading "child wait"
column event       format a24 heading "Event name"
column waits_holding_latch   format 99999999 heading "Wait     | holding latch"
column sleeps  format 99999999 heading "Number|Sleeps"
column sw      format 999999 heading "Seconds| Waiting"
column sid     format 9999 heading "Sid"

column child_wait  format a30
	column parent_wait format a30
	column server_name format a4  heading 'Name'
	column x_status    format a10 heading 'Status'
	column schemaname  format a14 heading 'Schema'
	column osuser  format a10 heading 'Osuser'
	column x_sid format 9990 heading 'Sid'
	column x_pid format 9990 heading 'Pid'
	column p_sid format 9990 heading 'Parent'

	break on p_sid skip 1
$SQL
EOF

