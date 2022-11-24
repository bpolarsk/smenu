clear screen

ttitle skip 2 'MACHINE &&1 - ORACLE_SID : &&2 '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pause off
set pagesize 66
set linesize 80
set heading off
set embedded off
set termout on
set verify off
spool &&3

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List Coalescable extents for all the Tablespaces ' nline
from sys.dual
/
prompt
set embedded on
set heading on
set feedback off
set linesize 90 pagesize 66 

column c1 heading "Tablespace|Number"
column c2 heading "Tablespace|Name"
column c3 heading "Coalescable|Extents"
select c.ts#    c1
      ,c.name   c2
      ,count(*) c3
  from sys.fet$ a
      ,sys.fet$ b
      ,sys.ts$  c
 where a.ts# = b.ts#
   and a.ts# = c.ts#
   and a.file# = b.file#
   and (a.block#+a.length) = b.block#
group by c.ts#,c.name
/ 
spool off
