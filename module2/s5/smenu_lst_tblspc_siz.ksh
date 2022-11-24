#!/usr/bin/ksh
#set -xv
# Author : RAJIV KUMAR 
# Adapted to Smenu by bpa : 24-Jan-2001
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SBIN2=${SBIN}/module3
WK_SBIN=$SBIN2/s2
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
TMP=$SBIN/tmp
FOUT=$TMP/tblspc_siz_$ORACLE_SID.txt

sqlplus -s "$CONNECT_STRING" <<EOF

set echo off pause off
set feedback off
set verify off
clear breaks
clear computes
set pagesize 100
set linesize 120


col database_name noprint new_value db_name 
rem col TODAY noprint NEW_VALUE _DATE 


ttitle skip 1 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pause off
set termout on
set heading off
set embedded off
set verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Storage summary   -  Space by Daltafile and Tablespace  ' nline
from sys.dual
/

rem set termout off
rem select to_char(SYSDATE,'fmMonth DD, YYYY') TODAY from DUAL;
set termout on
set heading on

TTITLE OFF


REM -----------------------------------------------------
REM Retrieve Datafiles information
REM -----------------------------------------------------

ttitle CENTER "Datafiles used by " $ORACLE_SID " database" Skip 1 -
CENTER "===================================" skip 2

col file_name format a55 heading 'File Name'
col tablespace_name format a10 heading 'Tablespace'
col status format a10 heading 'Status'
col autoxtnd format a3 heading 'Auto|Xtnd'
col file_size format 99,990.90 heading 'Size|(Mb)'
col used format 99,990.90 heading 'Used|(in Mb)'

SELECT 
d.file_name file_name, 
d.tablespace_name tablespace_name, 
NVL(d.bytes / 1024 / 1024, 0) file_size, 
NVL((d.bytes - NVL(s.bytes, 0))/1024/1024, 0) used,
TO_CHAR(NVL((d.bytes - NVL(s.bytes, 0)) / d.bytes * 100, 0), '990.00') "Used %",
NVL(d.autoextensible, 'NO') autoxtnd, 
v.status status 
FROM 
sys.dba_data_files d, 
v\$datafile v, 
(SELECT file_id, SUM(bytes) bytes 
FROM sys.dba_free_space GROUP BY file_id) s 
WHERE (s.file_id (+)= d.file_id) 
AND (d.file_name = v.name) 
UNION ALL 
SELECT 
d.file_name file_name, 
d.tablespace_name tablespace_name, 
NVL(d.bytes / 1024 / 1024, 0) file_size,
NVL(t.bytes_used/1024/1024, 0) used,
TO_CHAR(NVL(t.bytes_used / d.bytes * 100, 0), '990.00') "Used %", 
/*
NVL(t.bytes_cached/1024/1024, 0) "Used (M)",
NVL(t.bytes_cached / d.bytes * 100, 0) "Used %", 
*/
NVL(d.autoextensible, 'NO') autoxtnd, 
v.status status
FROM 
sys.dba_temp_files d, 
v\$temp_space_header t, 
/*
v\$temp_extent_pool t, 
*/
v\$tempfile v 
WHERE (t.file_id (+)= d.file_id) 
AND (d.file_id = v.file#);



REM -----------------------------------------------------
REM Retrieve Tablespace information
REM -----------------------------------------------------


TTITLE CENTER "Tablespace used by " $ORACLE_SID " database" Skip 1 -
CENTER "===================================" skip 2

col tablespace_name format a10 heading 'Name'
col initial_extent_size format 99,999 heading 'Initial|Extent|in (KB)'
col next_extent_size format 99,999 heading 'Next|Extent|in (KB)'
col min_extents format 99 heading 'Min|Extent'
col max_extents heading 'Max|Extent'
col status format a8 heading 'Status'
col contents format a9 heading 'Type'
col avail format 99,990.90 heading 'Total Size|(in Mb)'
col free format 99,990.90 heading 'Free |(in Mb)'
col used format 99,990.90 heading 'Used |(in Mb)'
col extent_management format a10 heading 'Extent |Management'

SELECT 
dts.tablespace_name,
initial_extent/1024 initial_extent_size,
next_extent/1024 next_extent_size,
NVL(ddf.bytes / 1024 / 1024, 0) avail,
NVL(ddf.bytes - NVL(dfs.bytes, 0), 0)/1024/1024 used,
NVL(dfs.bytes / 1024 / 1024, 0) free,
TO_CHAR(NVL((ddf.bytes - NVL(dfs.bytes, 0)) / ddf.bytes * 100, 0), '990.00') "Used %", 
dts.contents,
dts.extent_management, 
dts.status
FROM 
sys.dba_tablespaces dts, 
(select tablespace_name, sum(bytes) bytes 
from dba_data_files group by tablespace_name) ddf, 
(select tablespace_name, sum(bytes) bytes 
from dba_free_space group by tablespace_name) dfs 
WHERE 
dts.tablespace_name = ddf.tablespace_name(+) 
AND dts.tablespace_name = dfs.tablespace_name(+) 
AND NOT (dts.extent_management like 'LOCAL' 
AND dts.contents like 'TEMPORARY') 
UNION ALL 
SELECT 
dts.tablespace_name,
initial_extent/1024 initial_extent_size,
next_extent/1024 next_extent_size,
NVL(dtf.bytes / 1024 / 1024, 0) avail,
NVL(t.bytes, 0)/1024/1024 used, 
NVL(dtf.bytes - NVL(t.bytes, 0), 0)/1024/1024 free,
TO_CHAR(NVL(t.bytes / dtf.bytes * 100, 0), '990.00') "Used %", 
dts.contents,
dts.extent_management, 
dts.status
FROM 
sys.dba_tablespaces dts, 
(select tablespace_name, sum(bytes) bytes 
from dba_temp_files group by tablespace_name) dtf, 
(select tablespace_name, sum(bytes_used) bytes 
from v\$temp_space_header group by tablespace_name) t 
/*
(select tablespace_name, sum(bytes_cached) bytes 
from v\$temp_extent_pool group by tablespace_name) t 
*/
WHERE 
dts.tablespace_name = dtf.tablespace_name(+) 
AND dts.tablespace_name = t.tablespace_name(+) 
AND dts.extent_management like 'LOCAL' 
AND dts.contents like 'TEMPORARY';

prompt
prompt

EOF

