rem  awr_io_file_smpl.sql  
rem   -- Adapted from the scripts written by Karl Arao: http://karlarao.wordpress.com
rem
rem  check if there are I/O problem from AWR. 
rem  normally atpr (Average time per read)  should be less than 20 ms
rem  if atpr > 100 ms, it obviously indicates that we have problem
rem   
rem  note: the statistics are based on  (tm-interval, tm)
rem    


col atpr format 999,999
col atpw format 999,999

set echo off
-- set markup HTML ON
-- SPOOL ON ENTMAP ON PREFORMAT OFF
-- spool awr_io_file_smpl.html
spool awr_io_file_smpl.log
select * from (
SELECT 
--      s0.snap_id snap_id,
       to_char(s1.END_INTERVAL_TIME, 'YYMMDD HH24:MI') tm,
--      s0.instance_number inst,
       ROUND(EXTRACT(DAY FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 1440 + EXTRACT(HOUR FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 60 + EXTRACT(MINUTE FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) + EXTRACT(SECOND FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) / 60, 2) dur,
--      e.tsname,
      e.file# ,
--      SUBSTR(e.filename, 1, 52) filename ,
--      e.readtim         - NVL(b.readtim,0) readtim ,
      e.phyrds          - NVL(b.phyrds,0) reads ,
      DECODE ((e.phyrds - NVL(b.phyrds, 0)), 0, to_number(NULL), ((e.readtim - NVL(b.readtim,0)) 
                   / (e.phyrds - NVL(b.phyrds,0)))*10) atpr ,
--      (e.phyrds         - NVL(b.phyrds,0)) / ((ROUND(EXTRACT(DAY FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 1440 + EXTRACT(HOUR FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 60 + EXTRACT(MINUTE FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) + EXTRACT(SECOND FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) / 60, 2))*60) rps  ,
--      DECODE ((e.phyrds  - NVL(b.phyrds, 0)), 0, to_number(NULL), (e.phyblkrd - NVL(b.phyblkrd,0)) / (e.phyrds - NVL(b.phyrds,0)) ) bpr ,
--      e.writetim         - NVL(b.writetim,0) writetim ,
      e.phywrts          - NVL(b.phywrts,0) writes ,
      DECODE ((e.phywrts - NVL(b.phywrts, 0)), 0, to_number(NULL), ((e.writetim - NVL(b.writetim,0)) / (e.phywrts - NVL(b.phywrts,0)))*10) atpw ,
--      (e.phywrts         - NVL(b.phywrts,0)) / ((ROUND(EXTRACT(DAY FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 1440 + EXTRACT(HOUR FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 60 + EXTRACT(MINUTE FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) + EXTRACT(SECOND FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) / 60, 2))*60) wps ,
--      DECODE ((e.phywrts    - NVL(b.phywrts, 0)), 0, to_number(NULL), (e.phyblkwrt - NVL(b.phyblkwrt,0)) / (e.phywrts - NVL(b.phywrts,0)) ) bpw ,
--      e.wait_count          - NVL(b.wait_count,0) waits ,
--      DECODE ((e.wait_count - NVL(b.wait_count, 0)), 0, 0, ((e.time - NVL(b.time,0)) / (e.wait_count - NVL(b.wait_count,0)))*10) atpwt,
      (e.phyrds             - NVL(b.phyrds,0)) + (e.phywrts - NVL(b.phywrts,0)) ios,
      ((e.phyrds            - NVL(b.phyrds,0)) + (e.phywrts - NVL(b.phywrts,0))) / ((ROUND(EXTRACT(DAY FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 1440 + EXTRACT(HOUR FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 60 + EXTRACT(MINUTE FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) + EXTRACT(SECOND FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) / 60, 2))*60) iops
    FROM dba_hist_snapshot s0,
      dba_hist_snapshot s1,
      dba_hist_filestatxs e,
      dba_hist_filestatxs b
    WHERE s0.dbid =(select dbid from v$database)
    AND s1.dbid            = s0.dbid
    AND b.dbid(+)          = s0.dbid -- begin dbid
    AND e.dbid             = s0.dbid -- end dbid
    AND b.dbid             = e.dbid  -- remove oj
    AND s0.instance_number =dbms_utility.CURRENT_INSTANCE
    AND s1.instance_number = s0.instance_number
    AND b.instance_number(+) = s0.instance_number 
    AND e.instance_number    = s0.instance_number 
    AND b.instance_number    = e.instance_number 
    AND s1.snap_id           = s0.snap_id + 1
    AND b.snap_id(+)         = s0.snap_id      
    AND e.snap_id            = s0.snap_id + 1 
    AND b.tsname             = e.tsname      
    AND b.file#              = e.file#           
    AND b.creation_change#   = e.creation_change# 
    AND ((e.phyrds - NVL(b.phyrds,0)) + (e.phywrts - NVL(b.phywrts,0))) > 0
    AND s0.END_INTERVAL_TIME >= to_date('2011-02-18 13:00:00', 'YYYY-MM-DD HH24:MI:SS') 
    AND s0.END_INTERVAL_TIME <= to_date('2011-02-18 16:00:00', 'YYYY-MM-DD HH24:MI:SS') 
    order by s1.END_INTERVAL_TIME, e.tsname
--    and b.tsname='xxxx'
)
where atpr > 100 
;
spool off
set markup html off spool off
set termout on


