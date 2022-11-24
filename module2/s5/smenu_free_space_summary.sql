ttitle skip 2 'MACHINE &&1 - ORACLE_SID : &&2 '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pause off
set pagesize 66
set linesize 80
set heading off
set embedded off
set verify off
set termout on
spool &&3


select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'FREE - Free space summary by Tablespace  ' nline
from sys.dual
/
prompt
set embedded on
set pagesize 66
set linesize 90
set heading on
comp sum of nfrags totsiz avasiz on report 
break on report 
 
column dummy noprint
col name  format         a27 justify c heading 'Tablespace' 
col nfrags  format    999,990 justify c heading 'Free|Frags' 
col mxfrag  format 9,999,999,990 justify c heading 'Largest|Frag (Bytes)' 
col totsiz  format 9,999,999,990 justify c heading 'Total|(Bytes)' 
col avasiz  format 9,999,999,990 justify c heading 'Available|(Bytes)' 
col pctusd  format         990 justify c heading '%|Used' 
 
select  b.tablespace_name								name,
	a.tablespace_name                       					dummy,
	count(a.bytes )/count( distinct b.file_id)					nfrags,
  	nvl(max(a.bytes),0)                     					mxfrag, 
	sum(nvl(b.bytes,0))/count( distinct a.file_id||'.'||a.block_id ) 		totsiz,
	sum(nvl(a.bytes,0))/count( distinct b.file_id )                       		avasiz,
           100 * ( (sum(nvl(b.bytes,0))/count( distinct a.file_id||'.'||a.block_id )) -
        (sum(nvl(a.bytes,0))/count( distinct b.file_id ) )) /
           (sum(nvl(b.bytes,0))/count( distinct a.file_id||'.'||a.block_id )) 		pctusd
from 
  (select tablespace_name, bytes, file_id from dba_data_files
   union all 
   select tablespace_name, bytes, file_id from dba_temp_files ) b ,
  dba_free_space  a 
where 
  b.tablespace_name = a.tablespace_name(+) 
group by a.tablespace_name, b.tablespace_name
/
spool off
exit

