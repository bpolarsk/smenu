
clear screen

ttitle skip 2 'MACHINE &&1 - ORACLE_SID : &&2 '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pause off
set pagesize 66
set linesize 80
set termout on
set heading off
set embedded off
set verify off
define NBR_EXTENT_BF_END_TO_CHECK=&&4
spool &&3

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List Coalescable extents for all the Tablespaces ' || &&4 nline
from sys.dual
/
prompt
set embedded on
set heading on
set feedback off
set linesize 155 pagesize 66

column today new_value datevar format a1 noprint
column bsize new_value max_ext format a1 noprint 
select decode(value,2048,121,4096,240,515) bsize, sysdate today from v$parameter;

select a.owner, table_name "object", a.tablespace_name "tablespace", 'T' "T/I",
a.max_extents max_extents, b.extents current_extent, (a.max_extents - b.extents) "Ext_To_Go"
from sys.dba_tables a, sys.dba_segments b
where table_name = segment_name
and 	( a.max_extents < extents + &NBR_EXTENT_BF_END_TO_CHECK or &max_ext < extents + &NBR_EXTENT_BF_END_TO_CHECK)
union
select a.owner, index_name "object", a.tablespace_name "tablespace", 'I' "T/I",
a.max_extents max_extents, b.extents current_extent, a.max_extents - b.extents "Ext_To_Go"
from sys.dba_indexes a, sys.dba_segments b
where index_name = segment_name
and 	( a.max_extents < extents + &NBR_EXTENT_BF_END_TO_CHECK or max_ext < extents + &NBR_EXTENT_BF_END_TO_CHECK)
/
spool off
exit

