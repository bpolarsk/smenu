set termout on
set head off pause off
set pages 0
set feedback off
     select sum(reloads)
     	from v$librarycache
     	where namespace in ('SQL AREA','TABLE/PROCEDURE', 'BODY','TRIGGER')
/
exit
