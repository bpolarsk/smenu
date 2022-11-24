#!/bin/ksh
#set -xv
# This scripts contains also:
#---------------------------------------------------------------------------------
#-- Script:     latch_spins.sql, latch_sleeps.sql
#-- Purpose:    shows latch spin statistics
#-- Copyright:  (c) 1998 Ixora Pty Ltd
#-- Author:     Steve Adams, adapted to smenu by B. Polarski
# ----------------------------------------------------------------------
#
# B. Polarski : I added SQL extracted from the excellent Oracle wait interface
# from Shee, Deshpande, Gopalakrishanan - Oracle Press

function help
{
cat <<EOF

   All about latches:

    lat -s                 # show session latch activity
    lat -l                 # latch statistics when there are misses
    lat -d <n>             # show lat difference between <n> seconds
    lat -a                 # latch statistics including latches without misses
    lat -ll [nn]           # latch name and number, eventually for only one
    lat -m                 # latch misses from v\$latch_misses
    lat -sp                # latch spining
    lat -o                 # Show latch location
    lat -cbc               # List Cache buffer chain latches sorted by sleeps count
    lat -bh <RAW latch addr> # Show objects and touch count covered by latch raw addr
    lat -mis <latch name>  # show location of latch misses (use lat -n to exact get name)

    lat -c                 # children latch count and stats
    lat -e                 # children latch sleeping
    lat -i                 # children latch sleeping impact

    lat -p                 # Show number of latch sub pool
    lat -la  <sid>          # lock held on library cache objects (v\$access)
    lat -t                 # report current latch activity
    lat -w                 # Report Latch sleeps

    lat -x [-sid <n>] [-ln "latch name"][-n <nloop> ]  # latx by T.Poder
    lat -sx                # Report on all latch for a short duration
EOF
exit
}
# ----------------------------------------------------------------------
ACTION=DEFAULT
TITTLE="Show Latch statistics"
WHERE=" where a.misses <> 0 "
if [ -z "$1" ];then
   help
fi
while [ -n "$1" ]
do
  case "$1" in
     -a ) unset WHERE ;;
    -bh ) ACTION=BH ;       TITTLE="List object and touch count protected by latch $2" ; LATCH_RAW_NR=$2 ; shift  ;;
     -c ) ACTION=CHILDREN ; TITTLE="Report latch types with child counts and distribution" ;;
   -cbc ) ACTION=CBC ;      TITTLE="List Cache buffer chain latches sorted by sleeps count";;
   -cpt ) ACTION=CPT ;      TITTLE="Count between cold LRU and hot MRU" ;;
     -d ) ACTION=DIFF ;    SLEEP_TIME=$2 ;shift;;
     -e ) ACTION=SLEEP ;    TITTLE="Report children latch sleeping";;
     -i ) ACTION=IMPACT ;   TITTLE="Latch sleeps impact";;
     -l ) ACTION=DEFAULT ;;
    -la ) ACTION=LIB ;      TITTLE="lock held on library cache objects" ; FSID=$2; shift;;
    -ll ) ACTION=NAME
          if [ -n "$2" ] ;then
              WHERE="where latch# = '$2'"
              shift
          else
              unset WHERE
          fi
          TITTLE="Report latch name and id" ;;
    -ln ) LATCH_NAME="$2" ; shift ;;
     -m ) ACTION=MISS ;     TITTLE="latch misses from v\\\$latch_misses";;
   -mis ) ACTION=MIS ; TITTLE="show location of latch misses" ; shift; LATCH_NAME=$@ ; break;;
     -n ) NLOOP=$2; shift ;;
     -o ) ACTION=LOCATION ; TITTLE="latch location";;
     -p ) ACTION=SUBPOOL ;  TITTLE="Show number of sub pool in shared_pool" ; S_USER=SYS ;;
    -sx ) ACTION=LATCH_SESSION; TITTLE="Show session latch activity" ;;
   -sid ) SID=$2 ; shift ;;
    -sp ) ACTION=SPIN ;     TITTLE="Report spin gets";;
     -t ) ACTION=ACTIVITY ; TITTLE="report current latch activity"  ;;
     -w ) ACTION=LATW ; TITTLE="Report Latch sleeps"  ;;
     -x ) ACTION=LATX;;
     -v ) VERBOSE=YES;;
     -h ) help ;;
     *  ) echo "Unknown parameters $1" ; echo ; help ;;
  esac
  shift
done

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# ...............................................................................................

if [ "$ACTION" = "LATCH_SESSION" ];then
#-- Author:      Tanel Poder
#-- Copyright:   (c) http://www.tanelpoder.com

SQL=" set lines 190 pages 66

COL name FOR A35 TRUNCATE
COL latchprof_total_ms HEAD 'Held ms' FOR 999999.999
COL latchprof_pct_total_samples head 'Held %' format 999.99
COL latchprof_avg_ms HEAD 'Avg hold ms' FOR 999999.999
COL dist_samples HEAD Gets
COL total_samples HEAD Held
COL ksllwnam FOR A40 TRUNCATE
COL ksllwlbl FOR A20 TRUNCATE
COL objtype  FOR A20 TRUNCATE
COL object   FOR A17 WRAP JUST RIGHT
COL hmode    FOR A12 TRUNCATE
COL what     FOR A17 WRAP
COL func     FOR A30 TRUNCATE
col TOTAL_SAMPLES_PCT for 990.99999 head 'Total| Sampl%'
col sid for 99999 head 'Sid'
col dist_events for a30

BREAK ON lhp_name SKIP 1

WITH 
    t1 AS (SELECT hsecs FROM v\$timer),
    samples AS (
        SELECT /*+ ORDERED USE_NL(l.x\$ksuprlat) USE_NL(s.x\$ksuse) NO_TRANSFORM_DISTINCT_AGG */
            sid,name,func,
            COUNT(DISTINCT gets)        dist_samples
          , COUNT(*)                    total_samples
          , COUNT(*) / 1000000    total_samples_pct
        FROM 
            (SELECT /*+ NO_MERGE */ 1 FROM DUAL CONNECT BY LEVEL <= 100000) s,
            (SELECT ksuprpid PID, ksuprsid SID, ksuprlnm NAME, ksuprlat LADDR, ksulawhr, 
                    TO_CHAR(ksulawhy,'XXXXXXXXXXXXXXXX') object,
                    ksulagts GETS,
                    lower(ksuprlmd) HMODE
             FROM x\$ksuprlat) l,
            (SELECT
                    indx
                  , ksusesqh     sqlhash
                  , ksusesql     sqladdr ,
                   ksusesph planhash,
                   ksusesch sqlchild,
                   ksusesqi sqlid
             FROM x\$ksuse) s,
            (SELECT indx, 
                    ksllwnam func, ksllwnam,
                    ksllwlbl objtype, ksllwlbl 
             FROM x\$ksllw) w
        WHERE
            l.ksulawhr = w.indx (+)
        AND l.sid = s.indx
        GROUP BY
            sid,name,func
        ORDER BY
            total_samples DESC
    ),
    t2 AS (SELECT hsecs FROM v\$timer)
SELECT /*+ ORDERED */
    sid,name, func , s.total_samples , s.dist_samples
  , s.total_samples_pct
  , s.total_samples / 100000 * 100 latchprof_pct_total_samples
  , (t2.hsecs - t1.hsecs) * 10 * s.total_samples / 100000 latchprof_total_ms
  , (t2.hsecs - t1.hsecs) * 10 * s.total_samples / dist_samples / 100000 latchprof_avg_ms
  FROM
    t1,
    samples s,
    t2
  WHERE ROWNUM <= 20
/
"
# ------------------------------
# Latchx
# ------------------------------
elif [ "$ACTION" = "LATX" ];then
#-------------------------------------------------------------------------------
#-
#- File name:   latchprofx.sql ( Latch Holder Profiler eXtended )
#- Purpose:     Perform high-frequency sampling on V$LATCHHOLDER
#-              and present a profile of latches held by sessions
#-              including extended statistics about in which kernel
#-              function the latch held was taken
#-
#- Author:      Tanel Poder
#- Copyright:   (c) http://www.tanelpoder.com
#-
# Adpated to smenu by Bpa, August 2009
#-------------------------------------------------------------------------------

NLOOP=${NLOOP:-1000}
LATX_WHAT=${LATX_WHAT:-sid,name,func}
SID=${SID:-%}
LATCH_NAME=${LATCH_NAME:-%}
SQL=" set lines 190 pages 66
DEF _lhp_what='$LATX_WHAT'
DEF _lhp_sid='$SID'
DEF _lhp_name='$LATCH_NAME'
DEF _lhp_samples='$NLOOP'

COL name FOR A35 TRUNCATE
COL latchprof_total_ms HEAD 'Held ms' FOR 999999.999
COL latchprof_pct_total_samples head 'Held %' format 999.99
COL latchprof_avg_ms HEAD 'Avg hold ms' FOR 999999.999
COL dist_samples HEAD Gets
COL total_samples HEAD Held
COL ksllwnam FOR A40 TRUNCATE
COL ksllwlbl FOR A20 TRUNCATE
COL objtype  FOR A20 TRUNCATE
COL object   FOR A17 WRAP JUST RIGHT
COL hmode    FOR A12 TRUNCATE
COL what     FOR A17 WRAP
COL func     FOR A40 TRUNCATE

BREAK ON lhp_name SKIP 1
DEF _IF_ORA_10_OR_HIGHER='--'


COL latchprof_oraversion PRINT NEW_VALUE _IF_ORA_10_OR_HIGHER

col latchprof_oraversion new_value latchprof_oraversion noprint

SELECT DECODE(SUBSTR(BANNER, INSTR(BANNER, 'Release ')+8,1), 1, '', '--') latchprof_oraversion
FROM v\$version WHERE ROWNUM=1;
SET feed on verify off


WITH 
    t1 AS (SELECT hsecs FROM v\$timer),
    samples AS (
        SELECT /*+ ORDERED USE_NL(l.x\$ksuprlat) */
            &_lhp_what
            &_IF_ORA_10_OR_HIGHER , COUNT(DISTINCT gets)        dist_samples
          , COUNT(*)                    total_samples
          , COUNT(*) / &_lhp_samples    total_samples_pct
        FROM 
            (SELECT /*+ NO_MERGE */ 1 FROM DUAL CONNECT BY LEVEL <= &_lhp_samples) s,
            (SELECT ksuprpid PID, ksuprsid SID, ksuprlnm NAME, ksuprlat LADDR, ksulawhr, 
                    TO_CHAR(ksulawhy,'XXXXXXXXXXXXXXXX') object
                    &_IF_ORA_10_OR_HIGHER , ksulagts GETS, lower(ksuprlmd) HMODE
             FROM x\$ksuprlat) l,
            (SELECT indx, 
                    ksllwnam func, ksllwnam,
                    ksllwlbl objtype, ksllwlbl 
             FROM x\$ksllw) w
        WHERE
            l.sid LIKE '&_lhp_sid'
        AND l.ksulawhr = w.indx (+)
        AND (LOWER(l.name) LIKE LOWER('%&_lhp_name%') OR LOWER(RAWTOHEX(l.laddr)) LIKE LOWER('%&_lhp_name%'))
        GROUP BY
            &_lhp_what
        ORDER BY
            total_samples DESC
    ),
    t2 AS (SELECT hsecs FROM v\$timer)
SELECT /*+ ORDERED */
    &_lhp_what
  , s.total_samples
  &_IF_ORA_10_OR_HIGHER , s.dist_samples
 -- , s.total_samples_pct
  , s.total_samples / &_lhp_samples * 100 latchprof_pct_total_samples
  , (t2.hsecs - t1.hsecs) * 10 * s.total_samples / &_lhp_samples latchprof_total_ms
--  , s.dist_events
    &_IF_ORA_10_OR_HIGHER , (t2.hsecs - t1.hsecs) * 10 * s.total_samples / dist_samples / &_lhp_samples latchprof_avg_ms
  FROM
    t1,
    samples s,
    t2
/
"

# ------------------------------
# report current latch activity
# ------------------------------
elif [ "$ACTION" = "LATW" ];then
SQL="
column spec        format a124 heading 'Message'
column evt         format a124 heading 'Message'
column name        format a24 heading 'Latch Name'
column event       format a40 heading 'Event name'
column waits_holding_latch   format 99999999 heading 'Wait     | holding latch'
column sleeps  format 99999999 heading 'Number|Sleeps'
column sw      format 999999 heading 'Seconds| Waiting'
column sid     format 9999 heading 'Sid'
set lines 190
SELECT w.sid ,  w.event,n.name, w.p3 Sleeps, w.seconds_in_wait sw
       , p1, p1raw, p2, p2raw $DETAIL_L $DETAIL_E
 FROM V\$SESSION_WAIT w, V\$LATCHNAME n
WHERE  w.event not in ('rdbms ipc message')
   and w.p2 = n.latch# and latch# not in (1)
order by w.sid ;
"
# ------------------------------
# report current latch activity
# ------------------------------
elif [ "$ACTION" = "ACTIVITY" ];then
SQL="
set linesize 150
column name        format a24 heading 'Latch type'
column event       format a60 heading 'Event name'
column waits_holding_latch   format 99999999 heading 'Wait     | holding latch'
column sleeps  format 99999999 heading 'Number|Sleeps'
column sw      format 999999 heading 'Seconds| Waiting'
column sid     format 9999 heading 'Sid'

select b.sid, event, name, sleeps , sw , address from
v\$open_cursor a,
( SELECT w.sid,  w.event,n.name, SUM(w.p3) Sleeps, SUM(w.seconds_in_wait) sw
 FROM V\$SESSION_WAIT w, V\$LATCHNAME n
WHERE w.p2 = n.latch# and latch# not in (1)
GROUP BY w.sid, n.name, w.event ) b
where b.sid = a.sid
/
"
# ------------------------------
# Show diff latch
# ------------------------------
elif [ "$ACTION" = "DIFF" ];then
sqlplus -s "$CONNECT_STRING"    <<EOF
set linesize 120 pagesize 333 feed off head off
set serveroutput on size 999999
declare
 type s  is table of  number INDEX BY BINARY_INTEGER;
 type t  is table of VARCHAR2(50)  INDEX BY BINARY_INTEGER;
  v1 s;
  v2 s;
  m1 s;
  m2 s;
  t1 t;
  t2 t;
begin
   for c in ( select  a.latch#,b.name,a.gets,a.misses from v\$latch a, v\$latchname b where b.latch# = a.latch# order by 1 )
   loop
       v1(c.latch#):=c.gets;
       m1(c.latch#):=c.misses;
       t1(c.latch#):=c.name;
   end loop;
   dbms_lock.sleep($SLEEP_TIME);

   for c in ( select  a.latch#,b.name,a.gets,a.misses from v\$latch a, v\$latchname b where b.latch# = a.latch# order by 1 )
   loop
       v2(c.latch#):=c.gets;
       m2(c.latch#):=c.misses;
       t2(c.latch#):=c.name;
   end loop;
   DBMS_OUTPUT.PUT_LINE ('Name                             Gets Diff    Gets1         Gets2       Miss Diff   Miss1         Miss2');
   DBMS_OUTPUT.PUT_LINE ('-------------------------------- ------------ ------------- ----------- ----------- ------------- -----------') ;

    FOR i in v2.FIRST .. v2.LAST
    LOOP
        if (v2.exists(i)  ) then
            if (v1.exists(i)  ) then
                if  v2(i) != v1(i) then
                    DBMS_OUTPUT.PUT_LINE(rpad(t2(i),34,' ') || rpad(to_char(v2(i)-v1(i)),12,' ')|| rpad(to_char(v1(i)),12,' ') ||
                                          '  ' || rpad(to_char(v2(i)),12,' ')|| rpad(to_char(m2(i)-m1(i)),12,' ')|| rpad(to_char(m1(i)),12,' ') || '  ' || to_char(m2(i)) );
                end if ;
            else
                   DBMS_OUTPUT.PUT_LINE(rpad(t2(i),34,' ') || rpad(to_char(v2(i)),12,' ')|| '0           ' || '  ' ||  rpad(to_char(v2(i)),12,' ') ||rpad(to_char(m2(i)),12,' ')|| '0           ' || '  ' || to_char(m2(i)) );
            end if ;
        end if ;
    end loop ;

end ;
/
EOF
exit

# ------------------------------
# List latch misses location
# ------------------------------

elif [ "$ACTION" = "MIS" ];then
SQL="set feed on
select PARENT_NAME,location,NWFAIL_COUNT,SLEEP_COUNT,WTR_SLP_COUNT,LONGHOLD_COUNT
from v\$latch_misses where parent_name = '$LATCH_NAME' order by sleep_count desc ;
"

# ------------------------------
# List object from BH
# ------------------------------
elif [ "$ACTION" = "BH" ];then
#--------------------------------------------------------------------------------
#-- File name:   bhla.sql (Buffer Headers by Latch Address)
#-- Purpose:     Report which blocks are in buffer cache, protected by a cache
#--              buffers chains child latch
#-- Author:      Tanel Poder
#-- Copyright:   (c) http://www.tanelpoder.com
#-- Usage:       @bhla <child latch address>
#--              @bhla 27E5A780
#-- Other:       This script reports all buffers "under" the given cache buffers
#--              chains child latch, their corresponding segment names and
#--              touch counts (TCH).
#--------------------------------------------------------------------------------


SQL="col bhla_object head object for a40 truncate
col bhla_DBA head DBA for a13 head 'Data block|address' justify l
col FLG_LRUFLG for a22 head 'Type blk:|lru(cold) mru(hot) flag'
col Obj for 9999999
col tch for 99999
col mode_held head 'Mode|held' for 9999
col dirty_queue head 'Dirty|Queue' for 99999
col status for 99999 head 'Status'
col class for 99999 head 'Class'
set lines 190 pages 66 verify off pause off

prompt cr=consistent mode   xcur=exclusive mode   scur=(rac)shared    read=being readµ
prompt
select  /*+ ORDERED */
        case 
           when bitand(flag,1)= 0 then 'dirty'
           when bitand(flag,16)= 0 then 'temp'
           when bitand(flag,1536)= 0 then 'ping'
           when bitand(flag,16384)= 0 then 'stale'
           when bitand(flag,65536)= 0 then 'direct'
        else 'flag ' ||to_char(flag)
        end || 
	':'|| 
        case
           when bh.lru_flag = 0 then 'lru not set'
           when bh.lru_flag = 2 then 'Cold lru'
           when bh.lru_flag = 4 then 'auxiliary list:4'
           when bh.lru_flag = 6 then 'auxiliary list:6'
           when bh.lru_flag = 8 then 'hot mru'
            else trim(to_char(bh.lru_flag, 'XXXXXXXX'))
        end  	flg_lruflg,
	bh.obj , 
	o.object_type,
	o.owner||'.'||o.object_name		bhla_object,
	bh.tch,
	bh.class,
	decode(state,0,'free',1,'xcur',2,'scur',3,'cr', 4,'read',5,'mrec',6,'irec',7,'write',8,'pi', 9,'memory',10,'mwrite',11,'donated') status,
	bh.mode_held,
	bh.dirty_queue,
	lpad(file#,3,' ') ||' '||dbablk			bhla_DBA
from
	x\$bh		bh,
	dba_objects	o
where
	bh.obj = o.data_object_id
and	hladdr = hextoraw(lpad('$LATCH_RAW_NR', vsize(hladdr)*2 , '0'))
order by
	tch desc
/
"
# ------------------------------
# Latch cold/hot counts
# ------------------------------
elif [ "$ACTION" = "CPT" ];then
# ------------------------------
SQL="select blsiz
    , sum(decode(lru_flag,2,1,0)) cold
    , sum(decode(lru_flag,8,1,0)) hot
    ,set_ds
    from x\$bh
    group by blsiz, set_ds;
"
# ------------------------------
# Library cache buffer chain latch
# ------------------------------
elif [ "$ACTION" = "CBC" ];then
SQL="select CHILD# , ADDR ,  GETS ,   MISSES , SLEEPS from
(select CHILD# , ADDR ,  GETS ,   MISSES , SLEEPS
from v\$latch_children
where name = 'cache buffers chains'
order by 5 desc, 4, 3,1)where rownum <30;
"
# ------------------------------
# Library cache locks
# ------------------------------
elif [ "$ACTION" = "LIB" ];then
# ------------------------------

SQL="break on sid
select sid,type, OWNER||'.'||object obj from v\$access where sid  = $FSID;"

# latch location
# ------------------------------
elif [ "$ACTION" = "LOCATION" ];then
SQL="prompt WTR_SLP_COUNT  : process slept while requesting the latch from this location
prompt SLEEP_COUNT    : process slept while the latch was held from this location
prompt LONGHOLD_COUNT : process slept because the latch was persistently held from this location for an entire spin cycle.
prompt
col sleep_count heading 'SLEEP_COUNT'
select location,parent_name,wtr_slp_count,sleep_count,longhold_count
from v\$latch_misses where sleep_count>0 order by wtr_slp_count,location;"

# ------------------------------
# children latch sleeping
# ------------------------------
elif [ "$ACTION" = "SLEEP" ];then
SQL=" SELECT name,addr, latch#, gets, misses, sleeps from (
SELECT a.name,b.addr, a.latch#, b.gets, b.misses, b.sleeps
FROM v\$latch a, v\$latch_children b WHERE b.sleeps>0 and b.latch# = a.latch#
 ORDER BY 5  desc,1) where rownum <50;
"

# ------------------------------
# Sub pool Latch setting
# ------------------------------
elif [ "$ACTION" = "SUBPOOL" ];then
SQL="set heading off
select 'Number of sub pool in shared pool (_kghdsidx_count) : '|| b.ksppstvl
     from x\$ksppi a,x\$ksppsv b where a.indx=b.indx and a.ksppinm='_kghdsidx_count';
set heading on
prompt
prompt LRU contents breakdown
prompt
select addr,kghluidx,kghlufsh,kghluops,kghlurcr,kghlutrn,kghlumxa
from x\$kghlu
/
prompt
prompt Sub Shared pool lache statistics distirbutions
prompt
select addr,name,gets,misses,waiters_woken from v\$latch_children
where name = 'shared pool'
/
"

# ------------------------------
# Latch miss
# ------------------------------
elif [ "$ACTION" = "MISS" ];then
SQL=" prompt
prompt LOCATION :  Location that attempted to acquire the latch
prompt NWFAIL   :  Number of times that no-wait acquisition of the latch failed
prompt SLEEP    :  Number of times that acquisition attempts caused sleeps
prompt
set feed on
select PARENT_NAME, "LOCATION", NWFAIL_COUNT, SLEEP_COUNT from
  v\$latch_misses where NWFAIL_COUNT > 0; "

# ------------------------------
# Latch sleeping
# ------------------------------
elif [ "$ACTION" = "IMPACT" ];then
SQL="select
  l.name,
  l.sleeps * l.sleeps / (l.misses - l.spin_gets)  impact,
  lpad(to_char(100 * l.sleeps / l.gets, '990.00') || '%', 10)  sleep_rate,
  l.waits_holding_latch, l.level#
from
  v\$latch  l where l.sleeps > 0 order by 2 desc; "

# ------------------------------
# Latch Spining
# ------------------------------
elif [ "$ACTION" = "SPIN" ];then
  SQL="select l.name, l.spin_gets, l.misses - l.spin_gets  sleep_gets,
lpad(to_char(100 * l.spin_gets / l.misses, '990.00') || '%', 13)  hit_rate
from v\$latch l where l.misses > 0 order by l.misses - l.spin_gets desc ;
prompt
select 'ALL LATCHES'  name, sum(l.spin_gets)  spin_gets, sum(l.misses - l.spin_gets) sleep_gets,
  lpad( to_char(100 * sum(l.spin_gets) / sum(l.misses), '990.00') || '%', 13)  hit_rate
from v\$latch  l where l.misses > 0 ;
"
# ------------------------------
# Latch by name and id
# ------------------------------
elif [ "$ACTION" = "CHILDREN" ];then
SQL="SELECT a.name, count(a.latch#) total, sum(b.gets) sg, sum(b.misses) sm, sum(b.sleeps) ss
FROM v\$latch a, v\$latch_children b
   WHERE b.latch# = a.latch# group by a.name, a.latch#  ORDER BY 1 asc ,5  desc;"

# ------------------------------
# Latch by name and id
# ------------------------------
elif [ "$ACTION" = "NAME" ];then
SQL="column name format a45
select latch#,name from v\$latchname $WHERE; "

# ------------------------------
# Default
# ------------------------------

elif [ "$ACTION" = "DEFAULT" ];then
    SQL=" select a.name fname, a.immediate_gets,a.immediate_misses,
a.gets gets, a.misses misses ,a.misses*100/decode(a.gets,0,1,a.gets) miss,sleeps
,to_char(a.spin_gets*100/decode(a.misses,0,1,a.misses),'990.9') cspins
,to_char(a.sleep1*100/decode(a.misses,0,1,a.misses),'990.9') csleep1
,to_char(a.sleep2*100/decode(a.misses,0,1,a.misses),'990.9') csleep2
,to_char(a.sleep3*100/decode(a.misses,0,1,a.misses),'990.9') csleep3
from v\$latch a  $WHERE order by 4 desc;
"
fi

if [ -n "$VERBOSE" ];then
   echo "$SQL"
fi

# ...............................................................................................
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle  skip 1 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   'Page:' format 999 sql.pno  skip 2
set pagesize 66 linesize  132 Heading off pause off embedded on verify off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER,22,' ')  || '$TITTLE (help: lat -h)' from sys.dual
/
set embedded on
set heading on
set feedback off
set linesize 132 pagesize 66
col parent_name  format a31 heading "Parent name "
col segment_name  format a45 heading "Segment name "
col location  format a36 heading "Location "
col where        format a35 heading "Where "
col NWFAIL_COUNT format 99999999999 heading "Nwfail "
col SLEEP_COUNT  format 99999999999 heading "Sleep "
col SLEEPS   format 999999 heading "Sleep "
col CSPINS      form a6 head 'Spin|gets' justify c
col CSLEEP1     form a6 head 'Sleep1' justify c
col CSLEEP2     form a6 head 'Sleep2' justify c
col CSLEEP3     form a6 head 'Sleep3' justify c
col type_num format 999 heading "TYPE|NUMBER"
col type_name format a45 heading "TYPE|NAME"
col parent format 9 heading "PARENT|LATCH"
col children format 999999 heading "CHILD|LATCHES"
col miss     form 90.999 head '% Miss'
col misses   form 99999999 head 'Misses' justify c
col fname     form a37 head 'Latch name'
col gets     form 99999999999 head 'Gets' justify c
col name format A38 head "Children latch name"
col total format 9,999,990 head "Total Latch|Present in System"
col sg format 9,999,999,990 head "Total Gets"
col sm format 9,999,999,990 head "Total Misses"
col ss format 9,999,999,990 head "Total Sleeps"
col immediate_gets format 99999990 heading 'IMMEDIATE|GETS'
col immediate_misses format 99999990 heading 'IMMEDIATE|MISSES'
col waits_holding_latch   format 99999999 heading "Wait     | holding latch"
col sleep_rate  format a10 heading "Sleep rate"
col impact      format 9999999999 heading "Impact"
col addr heading "Sub pool|Latch" justify c
col KGHLURCR heading "Recreatable" justify c
col KGHLUTRN heading "Transcient" justify c
col obj format a60 heading "Object"
col location format a35 heading "Location"
prompt
$SQL
prompt
exit
EOF

