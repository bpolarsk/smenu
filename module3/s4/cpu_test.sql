--  FILE:   cpu_test.sql
--
--  AUTHOR: Andy Rivenes, arivenes@appsdba.com, www.appsdba.com
--          Copyright (c) 1999-2003, AppsDBA Consulting.  All Rights Reserved.
--
--  DATE:   10/07/1999
--
--  DESCRIPTION:
--          Simple test to measure logical I/O speed.
--
--          
--  MODIFICATIONS:
--          A. Rivenes, 11/02/01, Made several changes to the output displayed.
--          A. Rivnees, 11/13/01, Added Neil's COLUMN formatting.
--          A. Rivenes, 05/12/03, Added a couple of additional statistics as a
--                                control.
--
SPOOL cputest.txt;
--
set serveroutput on size 999999;
--
--
drop table dbtest
/
--
create table dbtest
(col1 number,
 col2 varchar2(100)
)
storage ( initial 512k next 512k pctincrease 0 )
pctfree 10
pctused 40
cache
/
--
declare
  var_row varchar2(100);
  var_ctr integer;
  var_ins integer;
begin
  for var_ctr in 1..10 loop
    var_row := var_row||'1234567890';
  end loop;
    --
  for var_ins in 1..2000 loop
    insert into dbtest
    values(var_ins,var_row);
  end loop;
end;
/
--
commit;
--
--
COLUMN sid	    HEADING 'SID'          FORMAT 999; 
COLUMN statistic#   HEADING 'Stat Num'     FORMAT 9999;
COLUMN name         HEADING 'Stat Name'    FORMAT A40 TRUNCATE;
COLUMN value        HEADING 'Value'        FORMAT 999,999,999;
--
SELECT a.sid,
       a.statistic#,
       SUBSTR(b.name,1,40) name,
       a.value
  FROM v$sesstat a,
       v$statname b,
       v$session se
 WHERE se.audsid = USERENV('SESSIONID')
   AND a.statistic# = b.statistic#
   AND se.sid = a.sid
   AND b.name IN ('session logical reads', 
                  'physical reads',
                  'CPU used when call started',
                  'CPU used by this session',
                  'buffer is pinned count',
                  'consistent gets',
                  'db block gets')
 ORDER BY b.class,
       b.name
/
--
--
PROMPT > Logical I/O Rate Test ;
PROMPT >  This script will generate output that can be used to ;
PROMPT >  correlate Oracle logical I/Os to CPU capacity and speed. ;
PROMPT >  This can be used to compare CPU speed between platforms and ;
PROMPT >  Oracle releases or to correlate workload capacity for the ;
PROMPT >  system in question. ;
PROMPT > ;
PROMPT >  The basic premise is that Oracle logical I/Os translate directly ;
PROMPT >  to CPU usage. By measuring the time it takes to execute a series ;
PROMPT >  of logical I/Os we can measure the rate a CPU can execute a ;
PROMPT >  logical I/O.  Since all logical I/Os are not the same, the numbers ;
PROMPT >  produced by this test should be considered theoretical maximums. ;
PROMPT >  These numbers will give values that can be used to measure CPU ;
PROMPT >  capacity and relative speed for an Oracle database, and should be ;
PROMPT >  within an acceptable margin of error. ;
PROMPT > ;
PROMPT >  NOTE: It is important that physical reads remain constant for each ;
PROMPT >  loop in order to insure that only logical I/Os affect the timing. ;
PROMPT >  A busy SGA may prevent this as well as CPU queuing for overall ;
PROMPT >  timing.  It is recommended that this test be run on an idle, or ;
PROMPT >  near idle machine. ;
PROMPT > ;
PROMPT >  The results of this script show the session logical reads ;
PROMPT >  performed for each loop, which should be constant, and the total ;
PROMPT >  time, which is in hundredths of a second. The statistic "physical ;
PROMPT >  reads" is included to verify that all blocks were cached. ;
PROMPT >  These values can be used to calculate the maximum logical I/Os per ;
PROMPT >  second that can be executed: ;
PROMPT > ;
PROMPT >  session logical reads / ( total time / 100 ) = maximum logical ;
PROMPT >  I/Os per second ;
PROMPT > ;
PROMPT >  If calculating for capacity against existing information ;
PROMPT >  (e.g. SYSMON data) then the total period (elapsed time) must be ;
PROMPT >  known, the total number of CPUs available, and some fudge factor ;
PROMPT >  (e.g. CPU queuing, SMP scalability): ;
PROMPT >    Interval capacity (with 20% fudge factor) = ;
PROMPT >      logical I/Os per second * total time * # of CPUs * .8 ;
PROMPT ;
--
declare
  cursor dbtest_cur is
    select col2 
      from dbtest;
  --
  cursor stat_cur is
    select b.name,
           a.value
      from v$sesstat a,
           v$statname b,
           v$session se
     WHERE se.audsid = USERENV('SESSIONID')
       AND a.statistic# = b.statistic#
       AND se.sid = a.sid
       AND b.name IN ('session logical reads', 
                      'physical reads',
                      'CPU used when call started',
                      'CPU used by this session',
                      'buffer is pinned count',
                      'consistent gets',
                      'db block gets')
     ORDER BY b.class,
           b.name;
  --
  var_col      varchar2(100);
  var_start    number;
  var_end      number;
  var_ctr      integer;
  var_loop     integer;
  var_lio_beg  integer;
  var_lio_end  integer;
  var_phy_beg  integer;
  var_phy_end  integer;
  var_cpu      integer;
begin
  --
  -- Get the number of CPUs
  --
  select value
    into var_cpu
    from v$parameter
   where name = 'cpu_count';
  --
  -- Load all blocks into the buffer cache
  --
  for dbtest_rec in dbtest_cur loop
    null;
  end loop;
  --
  for var_loop in 1..4 loop
    --
    dbms_output.put_line('**********');
    dbms_output.put_line('Loop > '||to_char(var_loop));
    dbms_output.put_line('**********');
    --
    for stat_rec in stat_cur loop
      dbms_output.put_line(stat_rec.name||' = '||to_char(stat_rec.value)); 
      if stat_rec.name = 'session logical reads' then
        var_lio_beg := stat_rec.value;
      elsif stat_rec.name = 'physical reads' then
        var_phy_beg := stat_rec.value;
      end if;
    end loop;
    dbms_output.put_line('*');
    --
    select hsecs
      into var_start
      from v$timer;
    --
    for var_ctr in 1..20 loop 
      for dbtest_rec in dbtest_cur loop
        null;
      end loop;
    end loop;
    --
    select hsecs
      into var_end
      from v$timer;
    --
    for stat_rec in stat_cur loop
      dbms_output.put_line(stat_rec.name||' = '||to_char(stat_rec.value));
      if stat_rec.name = 'session logical reads' then
        var_lio_end := stat_rec.value;
      elsif stat_rec.name = 'physical reads' then
        var_phy_end := stat_rec.value;
      end if;
    end loop;
    dbms_output.put_line('**');
    --
    dbms_output.put_line( 'total time: '||to_char(var_end - var_start) );
    if ( var_phy_end - var_phy_beg ) = 0 then
      dbms_output.put_line( 'LIOs/sec per CPU: '||
        to_char(ROUND((var_lio_end-var_lio_beg)/((var_end-var_start)/100),0)) );
      dbms_output.put_line( 'LIOs/sec system total: '||
        to_char(ROUND((var_lio_end-var_lio_beg)/((var_end-var_start)/100),0)*var_cpu) );
    else
      dbms_output.put_line( 'Physical reads took place, timing not valid.' );
    end if;
  end loop;
end;
/
--
SELECT a.sid,
       a.statistic#,
       SUBSTR(b.name,1,40) name,
       a.value
  FROM v$sesstat a,
       v$statname b,
       v$session se
 WHERE se.audsid = USERENV('SESSIONID')
   AND a.statistic# = b.statistic#
   AND se.sid = a.sid
   AND b.name IN ('session logical reads', 
                  'physical reads',
                  'CPU used when call started',
                  'CPU used by this session', 
                  'buffer is pinned count',
                  'consistent gets',
                  'db block gets')
 ORDER BY b.class,
       b.name
/
--
SPOOL off;
--
drop table dbtest
/


