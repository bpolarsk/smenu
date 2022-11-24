create or replace view stats as
with v as ( select sid from v$mystat where rownum = 1 )
SELECT
  'STAT...' || a.name name, b.value
FROM
  v$statname a,
  v$mystat b
WHERE
  a.statistic# = b.statistic#
-- UNION ALL SELECT 'LATCH.' || name,  gets FROM v$latch
UNION ALL
 SELECT 'EVENT..' || event name, TIME_WAITED value
FROM
   v$session_event e, v
where  e.sid = v.sid
UNION ALL
SELECT
  'STAT...Elapsed Time',
  hsecs
FROM
  v$timer
/

