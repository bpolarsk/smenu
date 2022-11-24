set head off pause off
set termout on
set pages 0
set feedback off
     select round((sum(decode(w.class, 'free list',count, 0)) / (sum(decode(name,'db block gets', value, 0)) 
     	+ sum(decode(name,'consistent gets', value, 0)))) * 100,2)
     	from v$waitstat w, v$sysstat
/
exit
