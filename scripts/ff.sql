
set serveroutput on  FORMAT WORD_WRAPPED;
set trimspool on longchunksize 32000 long 32000 
set lines 190 pages 0 feed off verify off head off


declare

v_owner varchar2(30):='WAAPOC_M';
v_table varchar2(30):='WLP_OBJECT_INFO';
sql_01 varchar2(32000);
sql_02 varchar2(32000);
sql_03 varchar2(32000);
v_com varchar2(1):='';
v_com20 varchar2(20):='"';
v_sep_deb varchar2(20):='"';
v_sep_end varchar2(20):='","';
v_sep varchar(20) := '"' ;
cpt  number:=0;

lStr Varchar2(1000);
PROCEDURE put_long_line(Ptext IN LONG, Plen  IN NUMBER DEFAULT 80, Pwhsp IN VARCHAR2 DEFAULT
                                   CHR(10) || CHR(32) || CHR(9) || ',')
  IS
 
    NL CONSTANT VARCHAR2(1) := CHR(10);    -- newline character (OS-independent)
    SP CONSTANT VARCHAR2(1) := CHR(32);    -- space character
    TB CONSTANT VARCHAR2(1) := CHR(9);     -- tab character
    CM CONSTANT VARCHAR2(1) := ',';        -- comma
    start_pos   INTEGER := 1;              -- start of string to print
    stop_pos    INTEGER;                   -- end of substring to print
    done_pos    INTEGER := LENGTH(Ptext);  -- end of string to print
    nl_pos      INTEGER;       -- point where newline found
    len         INTEGER := GREATEST(LEAST(Plen, 255), 10);  -- 10 <= len <= 255!
 
  BEGIN
 
    IF (done_pos <= len) THEN  -- short enough to write in one chunk
      DBMS_OUTPUT.put_line(Ptext);
    ELSE  -- must break up string
      WHILE (start_pos <= done_pos) LOOP
        nl_pos := INSTR(SUBSTR(Ptext, start_pos, len), NL) + start_pos - 1;
 
        IF (nl_pos >= start_pos) THEN  -- found a newline to break on
          DBMS_OUTPUT.put_line(SUBSTR(Ptext, start_pos, nl_pos-start_pos));
 
          start_pos := nl_pos + 1;  -- skip past newline
        ELSE  -- no newline exists in chunk; look for whitespace
 
          stop_pos := LEAST(start_pos+len-1, done_pos);  -- next chunk not EOS
 
          IF (stop_pos < done_pos) THEN  -- intermediate chunk
            FOR i IN REVERSE start_pos .. stop_pos LOOP
 
              IF (INSTR(Pwhsp, SUBSTR(Ptext, i, 1)) != 0) THEN
                stop_pos := i;  -- found suitable break pt
                EXIT;  -- break out of loop
              END IF;
            END LOOP;  -- find break pt
          ELSE  -- this is the last chunk
            stop_pos := stop_pos + 1;  -- point just past EOS
          END IF;  -- last chunk?
 
          DBMS_OUTPUT.put_line(SUBSTR(Ptext, start_pos, stop_pos-start_pos+1));
          start_pos := stop_pos + 1;  -- next chunk
        END IF;  -- find newline to break on
      END LOOP;  -- writing chunks
    END IF;  -- short enou
 end;

begin
  sql_01:='select '|| chr(10) || '                     ';
  for c in ( select column_name, data_type
              from all_tab_columns
                    where owner=upper(v_owner) and table_name = upper(v_table)  order by column_id )
  loop
       sql_01:=sql_01|| v_com|| c.column_name ;
       cpt :=cpt+1;
       if cpt=3 then
          sql_01:=sql_01||chr(10)||'                    ';
          cpt:=0;
       end if;
       v_com:=',' ;
  end loop;
  sql_01:=sql_01||chr(10) || '                from ' || v_owner ||'.'|| v_table ;
  sql_02:=q'{set serveroutput on
set lines 32000 longchunksize 32000 head off pages 0
set verify off feed off trimspool on
declare
      ret    varchar2(32000);
      v_user varchar2(30);
      function frlob( loc blob) return varchar2
    is
      l_buffer    varchar2(32000);
      ret         varchar2(32000);
      l_amount    BINARY_INTEGER := 32767;
      l_pos       INTEGER := 1;
      l_blob_len  INTEGER;
   begin
       l_blob_len := DBMS_LOB.getlength(loc);
       WHILE l_pos < l_blob_len LOOP
            DBMS_LOB.read(loc, l_amount, l_pos, l_buffer);
            l_pos := l_pos + l_amount;
            ret:=ret||l_buffer;
       END LOOP;
       return ret;
   end ;
   begin
      for c in (}';
  sql_02:=sql_02||sql_01 || ' )'||chr(10) || '    Loop';

  -- We start now to buid the output query
  sql_03:=sql_02||chr(10)||' dbms_output.put_line( ' ;
  v_com:='';
  cpt:=0;
  v_com20:=v_sep_deb;
  for c in ( select column_name, data_type
              from all_tab_columns
                    where owner=upper(v_owner)
                    and table_name = upper(v_table) order by column_id )
  loop
       if c.data_type = 'BLOB' then
           sql_03:=sql_03|| v_com20|| ' frlob(  c.'||c.column_name ||')';
       elsif  c.data_type = 'NUMBER' then
           sql_03:=sql_03|| v_com20|| ' to_char(c.'||c.column_name ||')';
       else
           sql_03:=sql_03|| v_com20|| 'c.'||c.column_name ;
       end if;
        cpt :=cpt+1;
        if cpt=3 then
           sql_03:=sql_03||chr(10)||'                    ';
           cpt:=0;
        end if;
        if ( v_com20 = '|' or v_com20 = '"' ) then
           v_com20:=q'{|| '''||v_sep || ''' ||}';
        end if ;
  end loop;
  sql_03:=sql_03||'||''' ||v_sep_end|| ''');'||chr(10)||' end loop;' || chr(10) || 'end;'||chr(10)||'/';
  -- dbms_output.put_line(sql_03);
  put_long_line(sql_03);
end;
/
