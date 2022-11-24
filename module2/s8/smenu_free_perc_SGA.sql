set head off pause off
set termout on
set pages 0
set feedback off
 select round((sum(decode(name, 'free memory', bytes, 0)) / sum(bytes)) * 100,2) from v$sgastat
/
exit
