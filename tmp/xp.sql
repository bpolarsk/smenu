set lines 190 pages 0
select * from TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST')) ;
