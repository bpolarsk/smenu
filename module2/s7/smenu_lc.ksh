#!/bin/ksh
#set -x
# show library cache info
# date : 29-05-2006
#-------------------------------------------------------------------------------
#   Contains Script:     whence_invalidations.sql whose Purpose is to trace cursor invalidations
#                        to the changed dependencies
#-- Copyright:  (c) Ixora Pty Ltd
#-- Author:     Steve Adams
#-- Adapted to Smenu by B. Polarski 01-06-2006
#
#  Update  : bpa  03 Jul 2006
#            added -b to show which session is blocking
#            added -lb for a global view of session blocking
#            added -ses to list session library cache hit ratio
#            bpa 10 Aug 2006
#            added -lp  to show who is holing the library cache pin
#            added -lpo to show what is hold
#-------------------------------------------------------------------------------

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
cd $TMP
TITTLE="List library cache info"
# function help
function help
{

  cat <<EOF


           lc   -s  <SID> -sql -len    #  list library lock for SID, default length is 60
           lc   -b  <KGL handle>       #  show blocking session whos handle is shown in lc -s
           lc   -a <SID>               #  List object accessed in shared pool and their handle
           lc   -lb                    #  List blocking and blocked session for library cache lock
           lc   -lbo                   #  List blocking and blocked session for library cache lock and the object
           lc   -lp                    #  List blocking and blocked session for library cache pin
           lc   -li                    #  List blocking session for library cache lock
           lc   -lpo                   #  List library cache pin object
           lc   -lp_ses                #  List library cache lock with the sessions info
           lc   -lm                    #  List session holding a lock
           lc   -lmo                   #  List session holding a lock and session they block
           lc   -dml                   #  show the library cache info for the dml
           lc   -inv                   #  show invalidated objects
           lc   -ses                   #  Show session cache performances
           lc   -mx                    #  Show mutext
           lc   -purge  SQL_ID         #  Purge an SQL ID from the library cache

          Additional :

      -len <nn> : Text length
            -sql :
             -v : verbose execution
             -h : this help

EOF
exit
}
# ---------------------------------------------------------------------------------------------------------------
if [ -z "$1" ];then
   help
fi
EXECUTE=FALSE
while [ -n "$1" ]
do
case "$1" in
   -s ) ACTION=LIST ; SID=$2; shift; S_USER=SYS ;;
   -b ) ACTION=KGLH ; KGLH=$2; shift; S_USER=SYS ;;
   -a ) ACTION=KGLDP ; SID=$2 ; shift ;S_USER=SYS ;;
   -llb ) ACTION=LKGLH ;  S_USER=SYS ;;
   -lb ) ACTION=LLB ;  S_USER=SYS ;;
   -lbo ) ACTION=LKGLHO ;  S_USER=SYS ;;
   -lm ) ACTION=LCKM ;  S_USER=SYS ;;
   -lmo ) ACTION=LCKMO ;  S_USER=SYS ;;
   -llp ) ACTION=PIN ;  S_USER=SYS ;;
   -lp ) ACTION=LPIN ;  S_USER=SYS ;;
   -li ) ACTION=LIST_BLOCKING ;  S_USER=SYS ;;
   -lc ) ACTION=LIBRARY_CACHE; S_USER=SYS ;;
   -lpo ) ACTION=PIN_OBJ ;  S_USER=SYS ;;
   -lp_ses ) ACTION=PIN_SES ;  S_USER=SYS ;;
   -len ) TEXT_LEN=$2; shift ;;
   -mx ) ACTION=MUTEXT;;
   -purge ) ACTION=PURGE ; SQL_ID=$2; shift ;;
   -sql ) FSQL=TRUE ;;
   -v ) VERBOSE=TRUE ; set -x;;
   -x ) EXECUTE=TRUE ;;
  -inv ) S_USER=SYS ; ACTION=INVALIDATION ;;  #
  -ses ) ACTION=SES ;;  #
   -h ) help ;;
  -dml) ACTION=DML;;
esac
shift
done

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# ---------------------------------------------------
# Query based on Riyaj idea
# ---------------------------------------------------
if [ "$ACTION" = "PURGE" ];then
    if [ "$EXECUTE" = TRUE ];then
 echo " "
sqlplus -s "$CONNECT_STRING" <<EOF
set serveroutput on ;
declare
   v_addr raw(8) ;
   v_hash   number ;
   v_str varchar2(100);
   v_str2 varchar2(100);
begin
   select ADDRESS ,hash_value into v_addr,  v_hash
      from V\$SQLAREA where SQL_ID  = '$SQL_ID' ;
 
   v_str:='execute sys.DBMS_SHARED_POOL.PURGE ('''||v_addr||',' || v_hash || ''', ''C'')';
   dbms_output.put_line(v_str);
    begin
       sys.DBMS_SHARED_POOL.PURGE (v_addr||','||v_hash, 'C');
   exception
       when others then
            dbms_output.put_line('Error code ' || SQLCODE || ': ' || SQLERRM);
     end ;
end ;
/ 
  
EOF
exit

else
    SQL="
set line 190 pages 66
col address for a20
col HASH_VALUE for 999999999999
select ADDRESS, HASH_VALUE from V\$SQLAREA where SQL_ID  = '$SQL_ID'
/ 

set pages 0 head off
prompt
prompt do:
prompt
select 'execute sys.DBMS_SHARED_POOL.PURGE ('''||address||',' || hash_value || ''', ''C'');'
      from V\$SQLAREA where SQL_ID  = '$SQL_ID'
/
"
fi
# ---------------------------------------------------
# Query based on Riyaj idea
# ---------------------------------------------------
elif [ "$ACTION" = "MUTEXT" ];then
SQL="
set line 190 pages 66
col MUTEX_IDENTIFIER head 'Mutex Id' for 999999999999 
col SLEEP_TIMESTAMP for a28 head 'Sleep time'
col mxt head 'Mutex Type' for a14
col REQUESTING_SESSION for 99999 head 'Reqst|Sess'
col BLOCKING_SESSION for 99999 head 'Block|Sess'
col location for a20
col gets for 99999999
col slepps for 9999999A
col p1 for 999999
col p2 for 999999
col p3 for 999999
select MUTEX_IDENTIFIER, SLEEP_TIMESTAMP,  substr(mutex_type,1,14) mxt, 
       REQUESTING_SESSION, BLOCKING_SESSION,
       LOCATION, MUTEX_VALUE, GETS, SLEEPS, p1, p2, p3
  from  V\$MUTEX_SLEEP_HISTORY;
"
# ---------------------------------------------------
# Query based on Riyaj idea
# ---------------------------------------------------
elif [ "$ACTION" = "LLB" ];then

TITLE="List library cache lock"
SQL="set lines 190
col OBJ_OWNER for a16 head  'Object Owner'
col OBJ_NAME for a26 head 'Object Name'
col module for a26
col EVENT for a20
col lck_cnt for 999 head 'Lck|cnt'
col lock_req for 999 head 'Lck|req'
col lock_mode for 9999 head 'Lck|mode'
col State for a8
col seconds_in_Wait head 'Seconds|in wait'
col wait_time head 'wait|time' for 999999
select
 distinct
   ses.ksusenum sid, KSUSEMNM module,
   ob.kglnaown obj_owner, ob.kglnaobj obj_name
   ,lk.kgllkcnt lck_cnt, lk.kgllkmod lock_mode, lk.kgllkreq lock_req
   , w.state, w.event, w.wait_Time, w.seconds_in_Wait
 from
  x\$kgllk lk,  x\$kglob ob,x\$ksuse ses , v\$session_wait w 
  where lk.kgllkhdl in (select kgllkhdl from x\$kgllk where kgllkreq >0 )
and ob.kglhdadr = lk.kgllkhdl
and lk.kgllkuse = ses.addr
and w.sid = ses.indx
order by seconds_in_wait desc
/
"
# ---------------------------------------------------
# Query based on Riyaj idea
# ---------------------------------------------------
elif [ "$ACTION" = "LPIN" ];then
TITLE="List library cache pin"
SQL="set lines 190
col OBJ_OWNER for a16 head  'Object Owner'
col OBJ_NAME for a26 head 'Object Name'
col EVENT for a30
col pin_cnt for 999 head 'Pin|cnt'
col pin_req for 999 head 'Pin|req'
col pin_mode for 9999 head 'Pin|mode'
col State for a8
col seconds_in_Wait head 'Seconds|in wait'
col wait_time head 'wait|time' for 999999
select distinct
   ses.ksusenum sid, 
   ob.kglnaown obj_owner, ob.kglnaobj obj_name
   ,pn.kglpncnt pin_cnt, pn.kglpnmod pin_mode, pn.kglpnreq pin_req
   , w.state, w.event, w.wait_Time, w.seconds_in_Wait
 from
  x\$kglpn pn,  x\$kglob ob, x\$ksuse ses , v\$session_wait w
where pn.kglpnhdl in
(select kglpnhdl from x\$kglpn where kglpnreq >0 )
and ob.kglhdadr = pn.kglpnhdl
and pn.kglpnuse = ses.addr
and w.sid = ses.indx
order by seconds_in_wait desc ;
"
# ---------------------------------------------------
#
# ---------------------------------------------------
elif [ "$ACTION" = "KGLDP" ];then
SQL="set lines 190 pagesize 60
col kglnaown format a20 head 'Owner'
col kglnaobj format a30 head 'Object name'
col type format a18 head 'Object type'
col KGLLKMOD head 'Hold|Mode'
col KGLLKREQ head 'Req|Mode'
col KGLLKHDL head 'Address in|shared pool|(KGLLKHDL)'
select distinct o.kglnaown,o.kglnaobj, 
     decode(o.kglobtyp,     0, 'CURSOR',      1, 'INDEX',    2, 'TABLE' ,    3, 'CLUSTER',    4, 'VIEW',    5, 'SYNONYM',
                            6, 'SEQUENCE',    7, 'PROCEDURE',    8, 'FUNCTION',    9, 'PACKAGE',
                            10,'NON-EXISTENT',    11,'PACKAGE BODY',    12,'TRIGGER',    13,'TYPE',    
                            14,'TYPE BODY',    15,'OBJECT',    16,'USER', 17,'DBLINK',    18,'PIPE',    19,'TABLE PARTITION',    
                            20,'INDEX PARTITION',    21,'LOB',    22,'LIBRARY',    23,'DIRECTORY ',    24,'QUEUE',    
                            25,'INDEX-ORGANIZED TABLE',    26,'REPLICATION OBJECT GROUP',    27,'REPLICATION PROPAGATOR',    
                            28,'JA VA SOURCE',    29,'JAVA CLASS',    30,'JAVA RESOURCE',    31,'JAVA JAR',    'INVALID TYPE') type ,
                 l.KGLLKMOD,l.KGLLKREQ,KGLLKHDL,
       case when o.kglhdadr = d.kglhdpar then 'Parent' else 'Child' end as type
     from x\$ksuse s,
          x\$kglob o,
          x\$kgldp d,
          x\$kgllk l 
where 
     l.kgllkuse=s.addr     and 
     l.kgllkhdl=d.kglhdadr and 
     l.kglnahsh=d.kglnahsh and 
     o.kglnahsh=d.kglrfhsh and
     o.kglhdadr=d.kglrfhdl and
     s.ksusenum = $SID
;
"
# ---------------------------------------------------
#
# ---------------------------------------------------
elif [ "$ACTION" = "SES" ];then
    SQL="
Prompt   The total max for SGA and PGA do not mean they occured all at same time.
prompt   It is just an indication of the potential
promp
compute sum of uga max pga pmax on report
break on report
SELECT   --+ ordered
       a.sid, b.value count , a.value  hit,c.value uga , d.value max,e.value pga,f.value pmax from
       (select sid,value from v\$sesstat x,v\$statname y
               where x.statistic# = y.statistic# and y.name = 'session cursor cache hits')a,
       (select sid,value from v\$sesstat x,v\$statname y
               where x.statistic# = y.statistic# and y.name = 'session cursor cache count')b,
       (select sid,value from v\$sesstat x,v\$statname y
               where x.statistic# = y.statistic# and y.name = 'session uga memory')c,
       (select sid,value from v\$sesstat x,v\$statname y
               where x.statistic# = y.statistic# and y.name = 'session uga memory max')d,
       (select sid,value from v\$sesstat x,v\$statname y
               where x.statistic# = y.statistic# and y.name = 'session pga memory')e,
       (select sid,value from v\$sesstat x,v\$statname y
               where x.statistic# = y.statistic# and y.name = 'session pga memory max')f
     where a.sid=b.sid and b.sid=c.sid and c.sid=d.sid and d.sid=e.sid and e.sid=f.sid
         order by 2 desc;
prompt
prompt
set head off
SELECT  'Total memory for all sessions      : ' || to_char(SUM(VALUE)/1024/1024,'99990.99') || ' meg'
   FROM V\$SESSTAT, V\$STATNAME WHERE NAME = 'session uga memory' AND V\$SESSTAT.STATISTIC# = V\$STATNAME.STATISTIC#;

SELECT  'Total max memory for all sessions  : ' || to_char(SUM(VALUE)/1024/1024,'99990.99') || ' meg'
   FROM V\$SESSTAT, V\$STATNAME WHERE NAME = 'session uga memory max' AND V\$SESSTAT.STATISTIC# = V\$STATNAME.STATISTIC#;
"
# ---------------------------------------------------
#
# ---------------------------------------------------
elif [ "$ACTION" = "INVALIDATION" ];then
SQL=" column object_owner format a12
column object_name format a25
select /*+ ordered use_hash(d) use_hash(o) */
  o.kglnaown  object_owner,
  o.kglnaobj  object_name,
  sum(o.kglhdldc - decode(o.kglhdobj, hextoraw('00'), 0, 1))  unloads,
  sum(decode(bad_deps, 1, invalids, 0))  invalidations,
  sum(decode(bad_deps, 1, 0, invalids))  and_maybe
from
  (
    select /*+ ordered use_hash(d) use_hash(o) */
      c.kglhdadr,
      sum(c.kglhdivc)  invalids,
      count(*)  bad_deps
    from
      sys.x\$kglcursor  c,
      sys.x\$kgldp  d,
      sys.x\$kglob  o
    where
      c.inst_id = userenv('Instance') and
      d.inst_id = userenv('Instance') and
      o.inst_id = userenv('Instance') and
      c.kglhdivc > 0 and
      d.kglhdadr = c.kglhdadr and
      o.kglhdadr = d.kglrfhdl and
      o.kglhdnsp = 1 and
      (
        o.kglhdldc > 1 or
        o.kglhdobj = hextoraw('00')
      )
    group by
      c.kglhdadr
  )  c,
  sys.x\$kgldp  d,
  sys.x\$kglob  o
where
  d.inst_id = userenv('Instance') and
  o.inst_id = userenv('Instance') and
  d.kglhdadr = c.kglhdadr and
  o.kglhdadr = d.kglrfhdl and
  o.kglhdnsp = 1 and
  (
    o.kglhdldc > 1 or
    o.kglhdobj = hextoraw('00')
  )
group by
  o.kglnaown,
  o.kglnaobj
order by
  sum(invalids / bad_deps)
/
"
# ---------------------------------------------------
#
# ---------------------------------------------------
elif [ "$ACTION" = "DML" ];then
  SQL="select namespace, DLM_LOCK_REQUESTS, DLM_PIN_REQUESTS, DLM_PIN_RELEASES,
              DLM_INVALIDATION_REQUESTS, DLM_INVALIDATIONS  from sys.v_\$librarycache;"
# ---------------------------------------------------
#
# ---------------------------------------------------
elif [ "$ACTION" = "LIBRARY_CACHE" ];then

  SQL="prompt Reason for invalidation in SQL AREA:
prompt .   changing of permissions.
prompt .   changing of indexes on tables that are involved in views.
prompt .   analyzing an object.
prompt .   running out of room in the shared pool.
prompt
col pinhitratio format 0.99
  select namespace, gets  locks, gets - gethits  loads,
  pins, pinhitratio, reloads, invalidations from sys.v_\$librarycache where gets > 0 order by 2 desc; "
# ---------------------------------------------------
#
# ---------------------------------------------------
elif [ "$ACTION" = "LIST" ];then
TEXT_LEN=${TEXT_LEN:-60}
if [ -n "$FSQL" ];then
   AND_SQL=" and lock_type = 'Cursor Definition Lock' "
fi
SQL="
set lines 190 pages 66
col SESSION_ID head sid for 9999
col handle for a18 head 'Handle'
col LOCK_ID1 for a$TEXT_LEN head 'What'
col req for a6 head 'Req'
col held for a6 head 'Held'
   select SESSION_ID, LOCK_ID2 handle, MODE_REQUESTED req, MODE_HELD held,
         LOCK_TYPE, LOCK_ID1 from SYS.DBA_LOCK_INTERNAL 
    where SESSION_ID = '$SID' $AND_SQL
    order by handle;"
# ---------------------------------------------------
#
# ---------------------------------------------------
elif [ "$ACTION" = "KGLH" ];then

   SQL=" prompt KGLLKREG = 0 means it hold the lock
SELECT SID,USERNAME,PROGRAM, kgllkreq FROM V\$SESSION, x\$kgllk
         WHERE SADDR = kgllkses and  kgllkhdl = '$KGLH' ;
"
# ---------------------------------------------------
#
# ---------------------------------------------------
elif [ "$ACTION" = "LCKMO" ];then
SQL="
set lines 190
      col REQ_OBJ format a30
      col username format a18 head 'User'
      col The_handle head 'Handle'
      col kgllkmod head 'Mode|held' justify l format 9999
      col kgllkreq head 'Mode|req' justify l format 9999
      col reqsid head 'Sid|that|Req' format 99999
      col b_sid head 'Block|king|Sid' format 99999 justify c


break on    The_handle on report  
       select a1.kgllkhdl The_handle, b1.sid reqsid, b1.username , a1.kgllkreq ,
             a1.kgllksqlid req_sql_id,a1.KGLNAOBJ req_obj,
               b2.sid b_sid, b2.username , a2.kgllksqlid blocking_sql_id, a2.KGLLKMOD
       from x\$kgllk a1, v\$session b1, x\$kgllk a2,  V\$SESSION  b2
            where
                 a1.KGLLKSES = b1.saddr and a1.KGLLKMOD > 1
          and a1.kgllkhdl = a2.kgllkhdl
          and b2.SADDR = a2.kgllkses 
          and a2.KGLLKMOD=0
          order by a1.kgllkhdl
/
"
# ---------------------------------------------------
#
# ---------------------------------------------------
elif [ "$ACTION" = "LCKM" ];then
   SQL=" col KGLNAOBJ format A40
         select kgllkmod, kgllkreq,kgllksqlid,KGLNAOBJ, sid,username, kgllkhdl
         from x\$kgllk a, v\$session b
              where a.KGLLKSES = b.saddr and KGLLKMOD > 1;
"
# ---------------------------------------------------
#
# ---------------------------------------------------
elif [ "$ACTION" = "LIST_BLOCKING" ];then
SQL="set verify on feed on
SELECT SID,USERNAME,TERMINAL,PROGRAM FROM V\$SESSION
       WHERE SADDR in 
       (SELECT KGLLKSES FROM X\$KGLLK LOCK_A 
               WHERE KGLLKREQ = 0
                     AND EXISTS (SELECT LOCK_B.KGLLKHDL FROM X\$KGLLK LOCK_B
                                        WHERE LOCK_A.KGLLKHDL = LOCK_B.KGLLKHDL AND KGLLKREQ > 0 
                )
  );
"
# ---------------------------------------------------
#
# ---------------------------------------------------
elif [ "$ACTION" = "LKGLH" ];then
  SQL="select sid,KGLLkHDL,KGLLKMOD,kgllkreq , decode(kgllkreq,0,'blocking','blocked') blocking
       from x\$kgllk,v\$session where saddr = kgllkses and kgllkhdl in (
            select KGLLKHDL from x\$kgllk where KGLLKREQ > 0  );
"
# ---------------------------------------------------
#
# ---------------------------------------------------
elif [ "$ACTION" = "LKGLHO" ];then
  SQL="
col KGLFNOBJ format a30 head 'Object Name'
col type head Type
select s.INDX sid, l.KGLLKHDL, l.kgllkreq , decode( l.kgllkreq,0,'blocking','blocked') blocking,
       o.KGLFNOBJ,  o.KGLHDCLT ,
decode(o.kglobtyp,     0, 'CURSOR',      1, 'INDEX',    2, 'TABLE' ,    3, 'CLUSTER',    4, 'VIEW',    5, 'SYNONYM',
                            6, 'SEQUENCE',    7, 'PROCEDURE',    8, 'FUNCTION',    9, 'PACKAGE',
                            10,'NON-EXISTENT',    11,'PACKAGE BODY',    12,'TRIGGER',    13,'TYPE',
                            14,'TYPE BODY',    15,'OBJECT',    16,'USER', 17,'DBLINK',    18,'PIPE',    19,'TABLE PARTITION',
                            20,'INDEX PARTITION',    21,'LOB',    22,'LIBRARY',    23,'DIRECTORY ',    24,'QUEUE',
                            25,'INDEX-ORGANIZED TABLE',    26,'REPLICATION OBJECT GROUP',    27,'REPLICATION PROPAGATOR',
                            28,'JA VA SOURCE',    29,'JAVA CLASS',    30,'JAVA RESOURCE',    31,'JAVA JAR',    'INVALID TYPE') type
       from x\$kgllk l,x\$kglob o, x\$ksuse s
            where KGLLKREQ > 0  and  o.kglhdadr = l.KGLLKHDL and
           l.kgllkuse=s.addr     
;
"
# ---------------------------------------------------
#
# ---------------------------------------------------
elif [ "$ACTION" = "PIN" ];then
SQL="SELECT s.sid, kglpnmod , kglpnreq  FROM x\$kglpn p, v\$session s
     WHERE p.kglpnuse = s.saddr AND kglpnhdl   in (SELECT  p1raw
      FROM v\$session_wait WHERE event = 'library cache pin' AND state = 'WAITING');
"
# ---------------------------------------------------
#
# ---------------------------------------------------
elif [ "$ACTION" = "PIN_OBJ" ];then
SQL="SELECT kglnaown , kglnaobj FROM x\$kglob WHERE kglhdadr in (SELECT  p1raw
      FROM v\$session_wait WHERE event = 'library cache pin' AND state = 'WAITING');
"
# ---------------------------------------------------
#
# ---------------------------------------------------
elif [ "$ACTION" = "PIN_SES" ];then
# variation on a the theme by Mark Bobak : 
SQL="set feed on lines 150
col object_name format a30
select /*+ ordered use_nl(lob pn ses) */ 
decode(lob.kglobtyp, 0, 'NEXT OBJECT', 1, 'INDEX', 2, 'TABLE', 3, 'CLUSTER', 
4, 'VIEW', 5, 'SYNONYM', 6, 'SEQUENCE', 
7, 'PROCEDURE', 8, 'FUNCTION', 9, 'PACKAGE', 
11, 'PACKAGE BODY', 12, 'TRIGGER', 
13, 'TYPE', 14, 'TYPE BODY', 
19, 'TABLE PARTITION', 20, 'INDEX PARTITION', 21, 'LOB', 
22, 'LIBRARY', 23, 'DIRECTORY', 24, 'QUEUE', 
28, 'JAVA SOURCE', 29, 'JAVA CLASS', 30, 'JAVA RESOURCE', 
32, 'INDEXTYPE', 33, 'OPERATOR', 
34, 'TABLE SUBPARTITION', 35, 'INDEX SUBPARTITION', 
40, 'LOB PARTITION', 41, 'LOB SUBPARTITION', 
42, 'MATERIALIZED VIEW', 
43, 'DIMENSION', 
44, 'CONTEXT', 46, 'RULE SET', 47, 'RESOURCE PLAN', 
48, 'CONSUMER GROUP', 
51, 'SUBSCRIPTION', 52, 'LOCATION', 
55, 'XML SCHEMA', 56, 'JAVA DATA', 
57, 'SECURITY PROFILE', 59, 'RULE', 
62, 'EVALUATION CONTEXT', 
'UNDEFINED') object_type, 
lob.kglnaobj object_name, 
pn.kglpnmod lock_mode_held, 
pn.kglpnreq lock_mode_requested, 
ses.sid, 
ses.serial#, 
ses.username 
from v\$session_wait vsw, 
     x\$kglob lob, 
     x\$kglpn pn, 
     v\$session ses 
where vsw.event = 'library cache lock' 
and vsw.p1raw = lob.kglhdadr 
and lob.kglhdadr = pn.kglpnhdl 
and pn.kglpnmod != 0 
and pn.kglpnuse = ses.saddr ;
"
fi
if [ -n "$VERBOSE" ];then
   echo "$SQL"
fi
sqlplus -s "$CONNECT_STRING" <<EOF


ttitle skip 2 'MACHINE $HOST1 - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 heading off pause off embedded off verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline , '$TITTLE (help : lc -h)' nline
from sys.dual
/
prompt
set embedded on
set term off
set heading on
set feedback off
set linesize 124 pagesize 66
set echo off
Column SID         FORMAT 99999 heading "Sess|ID "
col p1raw new_value p1raw noprint ;
col  kglpnmod format 9999999
col  kglkmod format 9999999
col  kglkreq format 9999999
col  kglnaobj format a50
col  kglnaown format a22
col  username format a22
col  kglpnreq format 9999
col namespace format A18
Col count head "Total number| cursor cached"
Col hit head "Hits in|sess cache "
Col uga head "Current|sga size"
Col max head "Max|sga size"
Col pga head "Current|pga size"
Col pmax head "Max|pga size"


$SQL

EOF

