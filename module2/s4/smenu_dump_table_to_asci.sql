--
-- dump a table to a comma delimited ASCII file
-- only drawback is line length is likely to be padded with
-- quite a few spaces if the 'set trimspool on' option is
-- not in your version of SQLPLUS
--
-- also builds a control file and a parameter file for SQL*LOADER 
 
set trimspool on pause off
set serverout on
clear buffer
undef dumpfile
undef &2
undef &1
var maxcol number
var linelen number
var dumpfile char(40)
col column_id noprint
set pages0 feed off termout off echo off verify off
define &1=SYSTEM
define &2=INDEX_STATS_ALL
rem accept &1 char prompt 'Owner of table to dump: '
rem accept &2 char prompt 'Table to dump: '
begin
        select max(column_id) into :maxcol
        from all_tab_columns
        where table_name = rtrim(upper('&&2'))
        and owner = rtrim(upper('&&1'));

        select sum(data_length) + ( :maxcol * 3 ) into :linelen           
        from all_tab_columns
        where table_name = rtrim(upper('&&2'))
        and owner = rtrim(upper('&&1'));
end;
/
print linelen
print maxcol
spool f_dump.sql
select 'set trimspool on' from dual;
select 'set termout off pages 0 feed off heading off echo off' from dual;
select 'set line ' || :linelen from dual;
select 'spool ' || lower('&&2') || '.txt' from dual;   
select 'select' || chr(10) from dual;
select '  ' || '''' || '"'  || '''' || ' || ' ||
        'replace(' || column_name || ',' || '''' ||  '"' || '''' || ') ' 
        || ' ||' || '''' || '",' || '''' || ' || ',
        column_id
from all_tab_columns
where table_name = upper('&&2')
and owner = upper('&&1')
and column_id < :maxcol
union
select '  ' || '''' || '"'  || '''' || ' || ' ||
        'replace(' || column_name  || ',' || '''' ||  '"' || '''' || ') ' 
    || ' ||' || '''' || '"' || '''',
        column_id
from all_tab_columns
where table_name = upper('&&2')
and owner = upper('&&1')
and column_id = :maxcol
order by 2
/
select 'from &&1..&&2' from dual;
select '/' from dual;
select 'spool off' from dual;
spool off
@@f_dump
set line 79
-- build a basic control file
spool f_dtmp.sql
select 'spool ' || lower('&&2') || '.par' from dual;   
spool off
@@f_dtmp
 
select 'userid = /' || chr(10) ||
  'control = ' || lower('&&2') || '.ctl' || chr(10) ||           'log = ' || lower('&&2') || '.log' || chr(10) ||           'bad = ' || lower('&&2')|| '.bad' || chr(10)
 from dual;
spool f_dtmp.sql
select 'set termout off pages 0 feed off heading off echo off' from dual;
select 'spool ' || lower('&&2') || '.ctl' from dual;   
spool off
@@f_dtmp
select 'load data' || chr(10) ||
      'infile ' || ''''|| lower('&&2') || '.txt' || '''' ||   chr(10) ||
      'into table &&2' || chr(10) ||
        'fields terminated by ' || '''' || ',' || '''' ||
        'optionally enclosed by ' || '''' || '"' || '''' || chr(10)   from dual;
select '(' from dual;
select '  ' || column_name || ',' ,
        column_id
from all_tab_columns
where table_name = upper('&&2')
and owner = upper('&&1')
and column_id < :maxcol
union
select '  ' || column_name, column_id
from all_tab_columns
where table_name = upper('&&2')
and owner = upper('&&1')
and column_id = :maxcol
order by 2
/
select ')' from dual;
exit
