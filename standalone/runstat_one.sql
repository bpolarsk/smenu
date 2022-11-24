-- you are supposed to have run runstat before
CREATE OR REPLACE PACKAGE rs1
AS
  PROCEDURE fstart;
  --
  PROCEDURE stop(
    p_difference_threshold IN NUMBER DEFAULT 0,
    p_output               IN VARCHAR2 DEFAULT NULL);
  --
  PROCEDURE version;
  --
  PROCEDURE help;
END rs1;
/
--
drop package body rs1 ;
CREATE OR REPLACE PACKAGE BODY rs1
AS
  g_fstart NUMBER;
  g_run  NUMBER;
  --
  g_version_txt   VARCHAR2(60)
        := 'runstats - Version 1.0, January 29, 2008';
  --
  -- Procedure to mark the fstart of the two runs
  --
  PROCEDURE fstart
  IS 
  BEGIN
    DELETE FROM run_stats;
    INSERT INTO run_stats SELECT 'before', stats.* FROM stats;
    g_fstart := DBMS_UTILITY.get_time;
  END fstart;
  
  -- Procedure to run after 
  --
  PROCEDURE stop(
    p_difference_threshold IN NUMBER DEFAULT 0,
    p_output               IN VARCHAR2 DEFAULT NULL)
  IS
  BEGIN
    g_run := (DBMS_UTILITY.get_time - g_fstart);
    --
    DBMS_OUTPUT.put_line
      ( 'Process ran in ' || g_run || ' hsecs' );
    DBMS_OUTPUT.put_line( CHR(9) );
    --
    INSERT INTO run_stats SELECT 'after', stats.* FROM stats;
    --
    DBMS_OUTPUT.put_line
    ( rpad( 'Name', 40 ) || lpad( 'Before Run', 12 ) || lpad( 'Diff', 12 ) );
    --
    -- Output choice
    --
    IF p_output = 'WORKLOAD' THEN 
      FOR x IN 
      ( SELECT 
          RPAD( a.name, 40 ) || TO_CHAR(( b.value-a.value), '999,999,999' ) data
        FROM
          run_stats a,
          run_stats b
        WHERE
           a.name = b.name
           AND a.runid = 'before'
           AND b.runid = 'after'
           AND ABS( (b.value-a.value) ) > p_difference_threshold
           AND b.name IN
            (
              'STAT...Elapsed Time',
              'STAT...DB Time',
              'STAT...CPU used by this session',
              'STAT...parse time cpu',
              'STAT...recursive cpu usage',
              'STAT...session logical reads',
              'STAT...physical reads',
              'STAT...physical reads cache',
              'STAT...physical reads direct',
              'STAT...sorts (disk)',
              'STAT...sorts (memory)',
              'STAT...sorts (rows)',
              'STAT...queries parallelized',
              'STAT...redo size',
              'STAT...user commits'
            )
         ORDER BY
           ABS( (b.value-a.value))
      ) LOOP
        DBMS_OUTPUT.put_line( x.data );
      END LOOP;
    ELSE
      -- Assume the default of NULL, all stats will be displayed
      FOR x IN 
      ( SELECT 
          RPAD( a.name, 40 ) || TO_CHAR( (b.value-a.value), '999,999,999' ) data
        FROM
          run_stats a,
          run_stats b
        WHERE
           a.name = b.name
           AND a.runid = 'before'
           AND b.runid = 'after'
           AND ABS( (b.value-a.value) ) > p_difference_threshold
         ORDER BY
           ABS( b.value-a.value)
      ) LOOP
        DBMS_OUTPUT.put_line( x.data );
      END LOOP;
    END IF;
    --
    DBMS_OUTPUT.put_line( CHR(9) );
    DBMS_OUTPUT.put_line
      ( 'Run1 latches total' );
    DBMS_OUTPUT.put_line
      ( lpad( 'Run1', 12 ) );
    --
    FOR x IN 
    ( SELECT
        TO_CHAR( run, '999,999,999' )  data
      FROM 
        (
          SELECT
            SUM(b.value-a.value) run
          FROM
            run_stats a,
            run_stats b
          WHERE
            a.name = b.name
            AND a.runid = 'before'
            AND b.runid = 'after'
            AND a.name like 'LATCH%'
        )
    ) LOOP
      DBMS_OUTPUT.put_line( x.data );
    END LOOP;
  END stop;
  --
  -- Display version
  --
  PROCEDURE version
  IS
  -- 
  BEGIN
    IF LENGTH(g_version_txt) > 0 THEN
      dbms_output.put_line(' ');
      dbms_output.put_line(g_version_txt);
    END IF;
  -- 
  END version;
  --
  -- Display help
  --
  PROCEDURE help 
  IS
  -- 
  -- Lists help menu
  --
  BEGIN
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE(g_version_txt);
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE('Procedure fstart');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'Run to mark the fstart of the test');
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE('Procedure middle');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'Run to mark the middle of the test');
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE('Procedure stop');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'Run to mark the end of the test');
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE('Parameters:');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'p_difference_threshold - Controls the output. Only stats greater');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'than p_difference_threshold will be displayed.');
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'p_output - Controls stats displayed.');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'  Default is NULL, all stats displayed.');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'  WORKLOAD, only workload related stats are displayed.');
    --
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE('Example:');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'Add the following calls to your test code:');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'    exec rs1.fstart;');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'    exec rs1.stop;');
    --
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE('NOTE: In SQL*Plus set the following for best results:');
    DBMS_OUTPUT.put_line(CHR(9));
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'Before 10g:   SET SERVEROUTPUT ON SIZE 1000000');
    DBMS_OUTPUT.PUT_LINE(CHR(9)||'10g or later: SET SERVEROUTPUT ON');
  END help;
  --
END rs1;
/
--
-- Grant privileges on runstats objects
--
-- CREATE PUBLIC SYNONYM rs1 FOR P0957.rs1;
-- GRANT EXECUTE ON rs1 TO PUBLIC;
--
-- EXIT;


