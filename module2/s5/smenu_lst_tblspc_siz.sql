ttitle skip 2 'MACHINE &&1 - ORACLE_SID : &&2 '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pause off
set pagesize 66
set linesize 80
set termout on
set heading off
set embedded off
set verify off
spool &&3

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'FREE - Free space by Tablespace  ' nline
from sys.dual
/
prompt
set embedded on
set pagesize 66
set heading on
column dummy noprint
column  pct_used format 99.9       heading "%|Used"
column  name    format a25      heading "Tablespace Name"
column  ON      format a2       heading "On"
column  bytes   format 9,999,999,999,999    heading "Total Bytes"
column  used    format 9,999,999,999,999   heading "Used"
column  free    format 9,999,999,999,999  heading "Free"
break   on report
compute sum of bytes on report
compute sum of free on report
compute sum of used on report
set lines 100

select c.tablespace_name name,decode(c.status,'ONLINE','Y','N') "ON" ,
           d.bytes,
           d.used,
           d.free,
           d.pct_used
from dba_tablespaces c, (
          select
           a.tablespace_name tablespace_name,
           sum(nvl(b.bytes,0))/count( distinct a.file_id||'.'||a.block_id )      bytes,
           sum(nvl(b.bytes,0))/count( distinct a.file_id||'.'||a.block_id ) -
           sum(nvl(a.bytes,0))/count( distinct b.file_id )                       used,
           sum(nvl(a.bytes,0))/count( distinct b.file_id )                       free,
           100 * ( (sum(nvl(b.bytes,0))/count( distinct a.file_id||'.'||a.block_id )) -
                           (sum(nvl(a.bytes,0))/count( distinct b.file_id ) )) /
           (sum(nvl(b.bytes,0))/count( distinct a.file_id||'.'||a.block_id )) pct_used
        from sys.dba_free_space a, sys.dba_data_files b
                where a.tablespace_name(+) = b.tablespace_name 
                group by a.tablespace_name, b.tablespace_name ) d
where c.tablespace_name = d.tablespace_name
/
spool off
exit
