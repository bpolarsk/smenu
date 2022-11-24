CREATE OR REPLACE TRIGGER sys.trg_login
AFTER LOGON ON DATABASE
DECLARE
  var1 VARCHAR2(50);
  var2 VARCHAR2(50);
  var3 VARCHAR2(50);
  var4 VARCHAR2(50);
  pgr1 VARCHAR2(50);
  sid NUMBER;
  ser NUMBER;
BEGIN
  BEGIN
    SELECT sid,program
      INTO sid,pgr1
      FROM v$session
     WHERE audsid = userenv('SESSIONID')
       AND audsid > 0;
    EXCEPTION
      when NO_DATA_FOUND then
        null;
  END;
  IF pgr1 like 'sqlldr%'
  THEN
--    execute immediate ('alter session set sql_trace = true');
    execute immediate ('alter session set events ''10053 trace name context forever, level 12''');
    execute immediate ('alter session set events ''10046 trace name context forever, level 12''');
--    execute immediate ('sys.dbms_system.set_ev(' || sid || ', ' || ser || ', 10046, 4, '''')');
--    execute immediate ('alter session set sql_trace = false');
--    execute immediate ('alter session set optimizer_index_cost_adj = 10');
  END IF;
END;
