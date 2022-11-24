create or replace package backup_mode is

-- to set all  TBS in begin backup mode : SQL> exec backup_mode.set_backup_on   ;
-- to terminate all  backup mode        : SQL> exec backup_mode.set_backup_off  ;
-- perform the copy only 
procedure set_backup_on;
procedure set_backup_off;

end ;
/
create or replace package body backup_mode is
 ------------------------------------------------------------------
procedure set_backup_on  is
  cmd varchar2(250);
begin
  for c1 in (select tablespace_name tbs from dba_tablespaces where contents !='TEMPORARY')
  loop
    cmd:='alter tablespace '||c1.tbs|| ' begin backup ' ;
    dbms_output.put_line(cmd);
    begin
       execute immediate cmd ;
    exception
       when others then
          dbms_output.put_line(SQLERRM);
    end;
  end loop;
  -- you can check if the tablespace is in begin backup mode
  -- with  V$BACKUP (status='ACTIVE'):
  -- select * from v$backup ;
  --
  --  FILE#  STATUS                CHANGE# TIME
  -- ----- ------------------ ---------- ---------
  --       1 ACTIVE                 528547 03-DEC-10
  --       2 ACTIVE                 528554 03-DEC-10
  --       3 ACTIVE                 528559 03-DEC-10
  --       4 ACTIVE                 528564 03-DEC-10
end;
 ------------------------------------------------------------------
procedure set_backup_off  is
  cmd varchar2(250);
  NothingToArchive EXCEPTION;
  PRAGMA EXCEPTION_INIT(NothingToArchive, -00271);
begin
  for c1 in (select tablespace_name tbs from dba_tablespaces where contents !='TEMPORARY' )
  loop
      cmd:='alter tablespace '||c1.tbs|| ' end backup ' ;
      dbms_output.put_line(cmd);
      begin
       execute immediate cmd ;
      exception
       when others then
          dbms_output.put_line(SQLERRM);
      end;
  end loop;
      begin
        cmd:='alter system archive log all' ;
        execute immediate cmd ;
      exception
       when NothingToArchive then
             null;
       when others then
          dbms_output.put_line(SQLERRM);
      end;
      begin
        cmd:='alter system switch logfile' ;
        execute immediate cmd ;
      exception
      when others then
          dbms_output.put_line(SQLERRM);
      end;
end;
end;
/

