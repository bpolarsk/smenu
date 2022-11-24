#!/bin/ksh
# set -xv
# program : smenu_rollback_size.sh
# Author  : bernard Polarski
# Date    : 03-Dec-1999
#           15-sep-2006 : added -rec option
cd $WK_SBIN
cd $TMP
TITTLE="Rollback Segment size and Highwatermark"
# ----------------------------------------------------------------
function help
{
cat <<EOF

   rlbs : all about rollbacks and undo

        rlbs -d            # List distribution of extents status
        rlbs -k            # Show undo metadata
        rlbs -s            # show undo stats
        rlbs -rec          # nbr transactions in RS for a specific object
        rlbs -r            # average time to reuse a rollback
        rlbs -tx           # show locked transaction
        rlbs -us           # Show the number of undo megs tbs needed
        rlbs -w            # show undo write stats
      	rlbs -his [-rn n ] # List undo stat history
        rlbs -ret [-rn n ] # List current retention


   -rn : show n rows

EOF
}
# ----------------------------------------------------------------
function do_it
{

sqlplus -s "$CONNECT_STRING" <<EOF1
set heading off embedded off pause off verify off linesize 132 pagesize 66
column nline newline
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report            -  $TITTLE' nline from sys.dual
/
set embedded on
set heading on
prompt         Type rlbs -h for help
prompt
column dummy noprint
column  rname    format a23   heading "Rollback"
column  sid    format 9999 head "Sid"
column  bytes    format 999999.9 heading "Size(m)"
column  Status       format a9    heading "Status"
column  HWM      format 9,999,999,999  heading "High| Watermark" justify c
column  XACTS    format 9,990 heading "Actv|Trans"
column  shr      format 99,990 heading "Shrks"
column  wrp      format 99,990 heading "Wrapd"
column  xts      format 9990 heading "Num|Ext" justify c
col gets head "Header|Gets"
col InitExt for 990.00 head "Init|Ext|(Mb)"

col waits for 99990 head "Header|Waits"
col writes for 999,999,990 head "Total|Writes|Since|Startup|(Kb)"
col wpg for 9990 head "AVG Writes|Per HedGet|(bytes)"
col hwmsize for 9990.00 head "High Water|Mark (Mb)"

column  currxts  format 9990 heading "Curr|Ext"
col rssize for 9990.00 head "Curr|Size|(Mb)"

column  rr heading 'RB Segment' format a22
column  us heading 'Username' format a15
column  os heading 'OS User' format a10
column  te heading 'Terminal' format a10
column  used_urec format 999999990 head 'Nbr undo|records'
column  tablespace_name format a15      heading "Tablespace|Name"
column  file_name format   a48      heading "File|Name"
column  on_1 format      a2      heading "On"
column  min_extents format      999      heading  "Min|ext"
column  max_extents format      99,999      heading  "Max|ext"
column  initial_extent format a10      heading "Initial|extent"
column  Optimal format   a11      heading "Optimal|Size" justify c
column extends format 9999999 heading "Acquire| Extents"
column waits format 9999 heading "Waits for| rollbacks"
column writes format 999,999,999,999 Heading "Writes"
column ratio format 990.99 Heading "Ratio"
column aveshrink format 99999990 heading "Average|Shrink (mb)" justify c
column aveactive format 99999990 heading "Avg siz|actv ext (k)" justify c

$SQL
exit
EOF1

}
# -----------------------------------------------------------------------

if [ -z "$1" ];then
   help 
   exit
fi
ROWNUM=50
while [ -n "$1" ];
do

   case "$1" in
     -tx ) CHOICE=TX   ;;
    -rec ) CHOICE=REC  ; TITTLE="Show records for objects in RBS";;
      -d ) CHOICE=STATUS   ;;
     -us ) CHOICE=USIZE   ;;
      -k ) CHOICE=RLBK ; TITTLE="Show undo metadata";;
      -w ) CHOICE=RLBW; TITTLE="show undo write stats" ;;
      -r ) CHOICE=RLBR ; TITTLE="Average Time before Rollback Segment Extent Reuse" ;;
      -s ) CHOICE=LIST ;;
      -his ) CHOICE=HIST ;;
      -ret ) CHOICE=RETENTION ;;
      -rn ) ROWNUM=$2 ; shift ;;
     *   )  help ; exit ;;
   esac
   shift
done
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# ......................................
# undo history 
# script found at : "https://community.oracle.com/thread/2285305"
# ......................................
if [ "$CHOICE" = "RETENTION" ];then
SQL="
set pages 66 lines 120
col retention for 99999999 head 'Retention(s)'
select * from (
select to_char(begin_time, 'DD-MON-RR HH24:MI') begin_time,
to_char(end_time, 'DD-MON-RR HH24:MI') end_time, tuned_undoretention retention
from v\$undostat order by end_time desc)
where rownum <=$ROWNUM;
"
elif [ "$CHOICE" = "HIST" ];then
SQL="
set linesize 120
set pagesize  60
COL TXNCOUNT         FOR 99,999,999 HEAD 'Txn. Cnt.'
COL MAXQUERYLEN      FOR 99,999,999 HEAD 'Max|Query|Sec'
COL MAXCONCURRENCY   FOR 9,999      HEAD 'Max|Concr|Txn'
COL bks_per_sec      FOR 99,999,999 HEAD 'Blks per|Second'
COL kb_per_second    FOR 99,999,999 HEAD 'KB per|Second'
COL undo_mb_required FOR 999,999    HEAD 'MB undo|Needed'
COL ssolderrcnt      FOR 9,999      HEAD 'ORA-01555|Count'
COL nospaceerrcnt    FOR 9,999      HEAD 'No Space|Count'
col ltime head 'Time'
break on report
compute max of txncount         -
               maxquerylen      -
               maxconcurrency   -
               bks_per_sec      -
               kb_per_second    -
               undo_mb_required on report
compute  sum of -
               ssolderrcnt      -
               nospaceerrcnt    on report

select * from  (
SELECT to_char(begin_time,'mm/dd hh24:mi:ss') ltime,
       txncount-lag(txncount) over (order by end_time) as txncount,
       maxquerylen,
       MAXCONCURRENCY,
       ROUND(UNDOBLKS/((END_TIME - BEGIN_TIME)*86400),4) as BKS_PER_SEC,
       ROUND((UNDOBLKS/((END_TIME - BEGIN_TIME)*86400)),4) * T.BLOCK_SIZE/1024 as KB_PER_SECOND,
       ROUND(((UNDOBLKS/((END_TIME - BEGIN_TIME)*86400)) * T.BLOCK_SIZE/1024) * TO_NUMBER(P2.value)/1024,4) as UNDO_MB_REQUIRED,
      ROUND(SSOLDERRCNT,4) ssocnt,
      round (nospaceerrcnt,4) nospc 
 FROM v\$undostat      s,
      dba_tablespaces t,
      v\$parameter     p,
      v\$parameter     p2
WHERE t.tablespace_name = UPPER(p.value)
  AND p.name            = 'undo_tablespace'
  and P2.name           = 'undo_retention'
ORDER BY begin_time desc
) where rownum <= $ROWNUM
/

"
# ......................................
# average time to reuse a rollback
# ......................................

elif [ "$CHOICE" = "RLBR" ];then

#-------------------------------------------------------------------------------
#-- Script:     rollback_reuse_time.sql
#-- Purpose:    to get the average time to reuse a rollback segment extent
#-- Copyright:  (c) 1999 Ixora Pty Ltd
#-- Author:     Steve Adams
#-------------------------------------------------------------------------------

SQL="select
  trunc(
    24 * (sysdate - i1.startup_time) / v.cycles
  )  IN_HOURS,
  trunc(
    1440 * (sysdate - i1.startup_time) / v.cycles
  )  IN_MINUTES
from
  v\$instance  i1,
  ( select
      max(
        (r.writes + 24 * r.gets) /                      -- bytes used /
        nvl(least(r.optsize, r.rssize), r.rssize) *     -- segment size
        (r.extents - 1) / r.extents                     -- reduce by 1 extent
      )  cycles
    from v\$rollstat  r where r.status = 'ONLINE')  v
/
"

# ......................................
# show undo write stats
# ......................................

elif [ "$CHOICE" = "RLBW" ];then

  #-------------------------------------------------------------------------------
  #-- Purpose:    to get the average writez of a rollback segment extent
  #-- Author:     Drazen Eror
  #-------------------------------------------------------------------------------

SQL="set lines 190 pagesize 66

PROMPT ...................................................................
PROMPT Rollback Segment Contention : When ratio is > .01 then add rollback
PROMPT ...................................................................

select NAME,
       GETS, WAITS,
       decode(gets,0,0.00,waits/gets) Ratio,
       abs(WRITES) WRITES,
       EXTENDS, trunc(AVESHRINK/1024) aveshrink,
       trunc(AVEACTIVE/1024) aveactive
from v\$rollstat t1, v\$rollname t2
where t1.usn=t2.usn ;
"

# ......................................
# Show undo metadata
# ......................................

elif [ "$CHOICE" = "RLBK" ];then

SQL="set lines 190 pagesize 66
select SEGMENT_NAME rname,
       decode(a.status,'ONLINE','Y','N') ON_1,
       lpad(to_char(INITIAL_EXTENT/1024),8,' ') || 'K' initial_extent,
       decode(optsize,NULL,'     -   ',lpad(to_char(optsize/1024),8,' ')||'K') Optimal,
       MIN_EXTENTS ,
       MAX_EXTENTS ,
       b.TABLESPACE_NAME,
       b.file_name from
       dba_data_files b, dba_rollback_segs a  , v\$rollstat s, v\$rollname r
       where a.file_id=b.file_id and
          a.segment_name  = r.name and
          s.usn = r.usn
/
"


# ......................................
# Show requested undo size
# ......................................

elif [ "$CHOICE" = "USIZE" ];then
# got this from orafaq.com
TITTLE="Calculates the number of meg needed for undo tablespace"
SQL="
col bytes head 'Requested tbs Undo Size(m)'
col ur format a19 head 'Undo Retention(sec)'
col ups head 'Undo data blocks|generated per second'
col dbs head 'Undo block size'
SELECT ur ,ups,dbs,((UR * (UPS * DBS)) + (DBS * 24))/1024/1024 AS bytes
            FROM 
               (SELECT value AS UR FROM v\$parameter WHERE name = 'undo_retention'), 
               (SELECT (SUM(undoblks)/SUM(((end_time - begin_time)*86400))) AS UPS FROM v\$undostat), 
               (select block_size as DBS from dba_tablespaces where tablespace_name= 
               (select value from v\$parameter where name = 'undo_tablespace'));
"
# ......................................
# List transaction in RS
# ......................................
elif [ "$CHOICE" = "REC" ];then
SQL="set lines 210 pages 66
col db_user for a30
col schema for a30
col Object_Name for a28
col Type for a10
col RBS for a14
col os_user for a16
col used_urec for a12
select e.sid,substr(a.os_user_name,1,8)  OS_User , substr(a.oracle_username,1,12) DB_User
       ,substr(b.owner,1,12)  Schema , substr(b.object_name,1,28) Object_Name, substr(b.object_type,1,10) Type
       ,substr(c.segment_name,1,14) RBS , substr(d.used_urec,1,12) used_urec ,
      to_char(start_date,'mm-DD HH24:MI:SS') Start_date
   from 
         v\$locked_object a, dba_objects b, dba_rollback_segs c, v\$transaction d, v\$session e
   where a.object_id =  b.object_id and a.xidusn = c.segment_id and a.xidusn = d.xidusn and a.xidslot = d.xidslot
         and d.addr = e.taddr;
"
# ......................................
# List undo segments status
# ......................................
elif [ "$CHOICE" = "STATUS" ];then
   SQL="
col mb head 'Tbs|Total|size'
col pct head 'Total|busy(%)' justify c for 999990
prompt Active: currently in use
prompt Unexpired: Kept to satisfy undo_retention
prompt Expired: May be reused
prompt
with v as
(
SELECT round(sum(bytes) /1048576) mb, tablespace_name , status
       FROM DBA_UNDO_EXTENTS 
 group by tablespace_name, status
)
select * from v
/
      " 
# ......................................
# List undo segments
# ......................................
elif [ "$CHOICE" = "LIST" ];then
 SQL="set lines 190  pagesize 55
break on report
compute sum of gets on report
compute sum of waits on report
compute avg of aveshrink on report
compute avg of wpg on report

select 
    name rname, XACTS, initial_extent/1048576 InitExt,
          RSSIZE/1048576 rssize, HWMSIZE/1048576 hwmsize, wraps, extends, shrinks,
          aveshrink/1048576 aveshrink, gets, waits, writes/1024 writes, writes/gets wpg
from 
      v\$rollstat,v\$rollname,dba_rollback_segs
where
    v\$rollstat.usn=v\$rollname.usn
and dba_rollback_segs.segment_id=v\$rollname.usn
order by name
/
"
# --------------------------------------
# Show transaction in lock
# --------------------------------------
elif [ "$CHOICE" = "TX" ];then

SQL="
SELECT r.name rr,s.sid,  nvl(s.username,'no transaction') us, s.osuser os,  s.terminal te ,
      t.used_ublk, t.status
      FROM  v\$lock l, v\$session s, v\$rollname r, v\$transaction t
      WHERE l.sid = s.sid(+) AND trunc(l.id1/65536) = r.usn AND
      l.type = 'TX' AND l.lmode = 6 and s.saddr=t.ses_addr ORDER BY r.name ; "

fi
do_it

