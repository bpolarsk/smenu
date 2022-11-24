-- +----------------------------------------------------------------------------+
-- |                          Jeffrey M. Hunter                                 |
-- |                      jhunter@idevelopment.info                             |
-- |                         www.idevelopment.info                              |
-- |----------------------------------------------------------------------------|
-- |      Copyright (c) 1998-2009 Jeffrey M. Hunter. All rights reserved.       |
-- |----------------------------------------------------------------------------|
-- | DATABASE : Oracle                                                          |
-- | FILE     : lob_dump_blob.sql                                               |
-- | CLASS    : LOBs                                                            |
-- | PURPOSE  : This script can be used to dump the contents of a BLOB column.  |
-- |            The user will be prompted for the OWNER, TABLE_NAME, and        |
-- |            COLUMN_NAME for the BLOB column to read from. The anonymous     |
-- |            PL/SQL block will write the contents of the BLOB to a file      |
-- |            named using the format:  OWNER_TABLE_COLUMN_<counter>.out       |
-- |            An example would be:     SCOTT_XML_DOCS_LOG_1.out               |
-- |                                     SCOTT_XML_DOCS_LOG_2.out               |
-- | NOTE     : As with any code, ensure to test this script in a development   |
-- |            environment before attempting to run it in production.          |
-- +----------------------------------------------------------------------------+

set verify off
set serveroutput on

accept oname   prompt 'Enter Owner Name                          : '
accept tname   prompt 'Enter Table Name                          : '
accept cname   prompt 'Enter Column Name                         : '
accept wclause prompt 'SQL WHERE clause (including WHERE clause) : '
accept odir    prompt 'Enter Output Directory                    : '

DECLARE

  -- +----------------------------------------------------+
  -- | INCOMING VARIABLES                                 |
  -- +----------------------------------------------------+
  v_oname         VARCHAR2(100)  := UPPER('&oname');
  v_tname         VARCHAR2(100)  := UPPER('&tname');
  v_cname         VARCHAR2(100)  := UPPER('&cname');
  v_outdir        VARCHAR2(2000) := '&odir';
  v_wclause       VARCHAR2(4000) := '&wclause';

  -- +----------------------------------------------------+
  -- | OUTPUT FILE VARIABLES                              |
  -- +----------------------------------------------------+
  v_out_filename       VARCHAR2(500)  := v_oname || '_' || v_tname || '_' || v_cname;
  v_out_fileext        VARCHAR2(4)    := '.out';
  v_out_filename_full  VARCHAR2(500);
  v_file_count         NUMBER         := 0;
  v_file_handle        UTL_FILE.FILE_TYPE;

  -- +----------------------------------------------------+
  -- | DYNAMIC SQL VARIABLES                              |
  -- +----------------------------------------------------+
  TYPE v_lob_cur_typ IS REF CURSOR;
  v_lob_cur v_lob_cur_typ;
  v_sql_string    VARCHAR2(4000);

  -- +----------------------------------------------------+
  -- | BLOB WRITE VARIABLES                               |
  -- +----------------------------------------------------+
  v_blob_loc      BLOB;
  v_buffer        RAW(32767);
  v_buffer_size   CONSTANT BINARY_INTEGER := 32767;
  v_amount        BINARY_INTEGER;
  v_offset        NUMBER(38);

  -- +----------------------------------------------------+
  -- | EXCEPTIONS                                         |
  -- +----------------------------------------------------+
  invalid_directory_path EXCEPTION;
  PRAGMA EXCEPTION_INIT(invalid_directory_path, -29280);

  table_does_not_exist EXCEPTION;
  PRAGMA EXCEPTION_INIT(table_does_not_exist, -00942);

  invalid_identifier EXCEPTION;
  PRAGMA EXCEPTION_INIT(invalid_identifier, -00904);

  SQL_cmd_not_prop_ended EXCEPTION;
  PRAGMA EXCEPTION_INIT(SQL_cmd_not_prop_ended, -00933);

BEGIN

  -- +----------------------------------------------------+
  -- | ENABLE SERVER-SIDE OUTPUT                          |
  -- +----------------------------------------------------+
  DBMS_OUTPUT.ENABLE(1000000);

  v_sql_string := 'SELECT ' || v_cname || '  FROM ' || v_oname || '.' || v_tname || ' ' || v_wclause;

  OPEN v_lob_cur FOR
      v_sql_string;

  LOOP

    FETCH v_lob_cur INTO v_blob_loc;
    EXIT WHEN v_lob_cur%NOTFOUND;

    v_file_count := v_file_count + 1;
    v_out_filename_full := v_out_filename || '_' || v_file_count || v_out_fileext;

    v_file_handle := UTL_FILE.FOPEN(v_outdir, v_out_filename_full, 'w', 32767);

    v_amount := v_buffer_size;
    v_offset := 1;

    DECLARE
      invalid_LOB_locator EXCEPTION;
      PRAGMA EXCEPTION_INIT(invalid_LOB_locator, -06502);

    BEGIN

      WHILE v_amount >= v_buffer_size
      LOOP

        DBMS_LOB.READ(
            lob_loc    => v_blob_loc,
            amount     => v_amount,
            offset     => v_offset,
            buffer     => v_buffer);

        v_offset := v_offset + v_amount;

        UTL_FILE.PUT_RAW(
            file      => v_file_handle,
            buffer    => v_buffer,
            autoflush => true);

        UTL_FILE.FFLUSH(file => v_file_handle);

      END LOOP;

    EXCEPTION

      WHEN invalid_LOB_locator THEN
        UTL_FILE.PUT_LINE(file => v_file_handle, buffer => '+----------------------------+');
        UTL_FILE.PUT_LINE(file => v_file_handle, buffer => '|      ***   ERROR   ***     |');
        UTL_FILE.PUT_LINE(file => v_file_handle, buffer => '+----------------------------+');
        UTL_FILE.NEW_LINE(file => v_file_handle);
        UTL_FILE.PUT_LINE(file => v_file_handle, buffer => 'Invalid LOB Locator Exception for :');
        UTL_FILE.PUT_LINE(file => v_file_handle, buffer => '===================================');
        UTL_FILE.PUT_LINE(file => v_file_handle, buffer => '    --> ' || v_oname || '.' || v_tname || '.' || v_cname);
        UTL_FILE.NEW_LINE(file => v_file_handle);
        UTL_FILE.PUT_LINE(file => v_file_handle, buffer => 'SQL Text:');
        UTL_FILE.PUT_LINE(file => v_file_handle, buffer => '===================================');
        UTL_FILE.PUT_LINE(file => v_file_handle, buffer => '    --> ' || v_sql_string);
        UTL_FILE.FFLUSH(file => v_file_handle);

      WHEN others THEN
        UTL_FILE.PUT_LINE(file => v_file_handle, buffer => '+----------------------------+');
        UTL_FILE.PUT_LINE(file => v_file_handle, buffer => '|      ***   ERROR   ***     |');
        UTL_FILE.PUT_LINE(file => v_file_handle, buffer => '+----------------------------+');
        UTL_FILE.NEW_LINE(file => v_file_handle);
        UTL_FILE.PUT_LINE(file => v_file_handle, buffer => 'WHEN OTHERS ERROR');
        UTL_FILE.PUT_LINE(file => v_file_handle, buffer => '=================');
        UTL_FILE.PUT_LINE(file => v_file_handle, buffer => '    --> SQL CODE          : ' || SQLCODE);
        UTL_FILE.PUT_LINE(file => v_file_handle, buffer => '    --> SQL ERROR MESSAGE : ' || SQLERRM);
        UTL_FILE.FFLUSH(file => v_file_handle);

    END;

    UTL_FILE.FCLOSE(v_file_handle);

  END LOOP;

  CLOSE v_lob_cur;

  DBMS_OUTPUT.PUT_LINE('Wrote out ' || v_file_count || ' file(s) to ' || v_outdir || '.');

EXCEPTION

  WHEN invalid_directory_path THEN
    DBMS_OUTPUT.PUT_LINE('** ERROR ** : Invalid Directory Path: ' || v_outdir);

  WHEN table_does_not_exist THEN
    DBMS_OUTPUT.PUT_LINE('** ERROR ** : Table Not Found.');
    DBMS_OUTPUT.PUT_LINE('--> SQL: ' || v_sql_string);

  WHEN invalid_identifier THEN
    DBMS_OUTPUT.PUT_LINE('** ERROR ** : Invalid Identifier.');
    DBMS_OUTPUT.PUT_LINE('--> SQL: ' || v_sql_string);

  WHEN SQL_cmd_not_prop_ended THEN
    DBMS_OUTPUT.PUT_LINE('** ERROR ** : SQL command not properly ended.');
    DBMS_OUTPUT.PUT_LINE('--> SQL: ' || v_sql_string);

END;
/

