#!/usr/bin/ksh
# program all_idx
# Author : Bernard Polarski : 26/07/2000
SBINS=$SBIN/scripts
HOST=`hostname`
#--------------- Test variables section ---------------------
if [ "x-$1" = "x-" ];then
       echo 
       echo 
       echo "I need at least Table name as argument"
       echo 
       echo "dsk [OWNER] <TABLE>"
       echo 
       echo 
       exit
elif [ $# -eq 2 ];then
       OWNER=`echo $1 | tr '[a-z]' '[A-Z]'`
       TABLE=$2
elif [ $# -eq 1 ];then
       TABLE=$1
fi
TABLE=`echo $TABLE | tr '[a-z]' '[A-Z]'`
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} 

if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
    #--------------- Process section ---------------------
if [ "x-$OWNER" = "x-" ];then
      L_OWNER=`sqlplus -s "$CONNECT_STRING" <<EOF
set term off
set feedback off
set head off
set pagesize 0
select owner from dba_tables where table_name = '\$TABLE'
/
EOF`
     cpt=`echo $L_OWNER |wc -w`
     if [ $cpt -gt 1 ];then
        echo "There are more than one user with this table. \nSelect please select the correct one."
        PS3='Select USER or e to leave ==> '
        select OWNER in ${L_OWNER}
        do
          break
        done
     else
        OWNER=$L_OWNER
     fi
fi
if [  ! "x-$OWNER" = "x-" ];then
       FOUT=$SBIN/tmp/t_${OWNER}_${TABLE}.txt
       sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 110
set termout on pause off
set embedded on
set verify off
set heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report all info for table $TABLE' nline
from sys.dual
/

set head on
set verify off
set feedback off 
 
-- ======================================================
-- Script to identify everything to do with a table.
--
-- This includes a DESC equivalent, sizing information, Triggers, Constraints, Granted priviliges
-- that are associated with a table or from other tables foreign keys that reference
-- that table.
--
-- Instructions
-- ============
-- Either run this script logged on to SYS or SYSTEM or GRANT SELECT on the DICTIONARY
-- TABLES:
--
-- DBA_TAB_COLUMNS
-- V$DATABASE
-- DBA_TABLES
-- DBA_EXTENTS
-- DBA_CONS_COLUMNS 
-- DBA_CONSTRAINTS
-- DBA_TRIGGERS
-- DBA_TAB_PRIVS
-- DBA_COL_PRIVS
--
-- At SQL*PLUS You will be requested to enter the schema owner and the tablename.
-- If you want a count of the number of rows in that table you will need to manually
-- edit this file beforehand.
--
--
-- Mark Searle
-- Searle Database Systems Ltd -  marksearle@mistral.co.uk
-- FILE NAME: DISPLAY_.SQL
-- Last Modified 10/01/97
--
--======================================================

spool $FOUT

SET ECHO ON FEED OFF ARRAYSIZE 1  LONG 5000 VERIFY OFF TIMING OFF PAUSE OFF
set embedded on linesize 132 pagesize 500

prompt
prompt

-- Show the Table Structure
-- ========================

COLUMN POS FORMAT 999 heading "POS"
COLUMN PCT_FREE FORMAT A4 heading "Null"


SELECT COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE, COLUMN_ID POS
FROM   SYS.DBA_TAB_COLUMNS
WHERE  OWNER = '$OWNER'
AND    TABLE_NAME = '$TABLE'
ORDER  BY COLUMN_ID;


prompt
prompt

-- Show Physical Attributes
-- ========================
COLUMN PCT_FREE FORMAT 999 heading "Pct|Free"
COLUMN PCT_USED FORMAT 999 heading "Pct|Used"
COLUMN PCT_INCREASE FORMAT 999 heading "Pct|Incr"
COLUMN INITIAL_EXTENT FORMAT 9999999 heading "Init|Extent(k)"
COLUMN NEXT_EXTENT FORMAT    9999999 heading "Next|Extent(k)"
COLUMN TABSIZE FORMAT    9999990 heading "Size (k)"
COLUMN MAX_EXTENTS FORMAT 999999 heading "Max|Ext"
COLUMN AVG_ROW_LEN FORMAT 9999 heading "Avg|Row|Len"
COLUMN SEGMENT_NAME FORMAT A23 HEADING 'Table Name'
COLUMN COUNTER FORMAT 9999 HEADING 'Num |Ext'
COLUMN MAXRL FORMAT 99999 HEADING 'Max row| length'

SELECT segment_name,
       PCT_FREE,
       PCT_USED,
       PCT_INCREASE,
       INITIAL_EXTENT/1024 INITIAL_EXTENT,
       NEXT_EXTENT/1024 NEXT_EXTENT,
       MAX_EXTENTS,
       counter,
       NUM_ROWS,
       maxrl,
       AVG_ROW_LEN,
       TABSIZE
FROM   DBA_TABLES, 
       (
        SELECT SEGMENT_NAME, COUNT(*) COUNTER
        FROM   DBA_EXTENTS WHERE  OWNER = '$OWNER' AND    SEGMENT_NAME = '$TABLE'
        GROUP  BY SEGMENT_NAME),
       ( 
        SELECT SUM(DATA_LENGTH) MAXRL 
               FROM   DBA_TAB_COLUMNS
               WHERE  OWNER = '$OWNER' AND    TABLE_NAME = '$TABLE'),
       (
         SELECT SUM(BYTES)/1024 TABSIZE FROM   DBA_EXTENTS
                WHERE  OWNER = '$OWNER' AND SEGMENT_NAME = '$TABLE' 
                GROUP  BY SEGMENT_NAME
       )
WHERE  OWNER = '$OWNER'
AND    TABLE_NAME = '$TABLE';


prompt
prompt


-- GET ALL THE INDEX DETAILS
-- =========================


-- Show all the indexes and their columns for this table
-- =====================================================

COLUMN OWNER FORMAT A8 heading "Index|Owner"
COLUMN TABLE_OWNER FORMAT A8 heading "Table|Owner"
COLUMN INDEX_NAME FORMAT A25 heading "Index Name"
COLUMN COLUMN_NAME FORMAT A20 heading "Column Name"
COLUMN COLUMN_POSITION FORMAT 9999 heading "Pos"
COLUMN PCT_FREE FORMAT 999 heading "%|Free"
COLUMN PCT_INCREASE FORMAT 999 heading "%|Incr"
COLUMN INITIAL_EXTENT FORMAT 99999999 heading "Init|Extent"
COLUMN NEXT_EXTENT FORMAT 99999999 heading "Next|Extent"
COLUMN MAX_EXTENTS FORMAT 999 heading "Max|Ext"
BREAK ON OWNER ON TABLE_OWNER ON INDEX_NAME ON CONSTRAINT_NAME 

SELECT IND.OWNER,
       IND.TABLE_OWNER,
       IND.INDEX_NAME,
       IND.PCT_FREE,
       IND.PCT_INCREASE,
       IND.INITIAL_EXTENT/1024 INITIAL_EXTENT,
       IND.NEXT_EXTENT/1024 NEXT_EXTENT,
       IND.MAX_EXTENTS,
       IND.UNIQUENESS,
       COL.COLUMN_NAME,
       COL.COLUMN_POSITION
FROM   SYS.DBA_INDEXES IND,
       SYS.DBA_IND_COLUMNS COL
WHERE  IND.TABLE_NAME = '$TABLE'
AND    IND.TABLE_OWNER = '$OWNER'
AND    IND.TABLE_NAME = COL.TABLE_NAME
AND    IND.OWNER = COL.INDEX_OWNER
AND    IND.TABLE_OWNER = COL.TABLE_OWNER
AND    IND.INDEX_NAME = COL.INDEX_NAME;

--
-- GET ALL THE CONSTRAINT DETAILS
-- ==============================

-- Show the Non-Foreign Keys Constraints on this table
-- ====================================================================
COLUMN OWNER FORMAT A9 heading "Owner"
COLUMN CONSTRAINT_NAME FORMAT A23 heading "Constraint|Name"
COLUMN R_CONSTRAINT_NAME FORMAT A23 heading "Referenced|Constraint|Name"
COLUMN DELETE_RULE FORMAT A9 heading "Del|Rule"
COLUMN TABLE_NAME FORMAT A18 heading "Table Name"
COLUMN COLUMN_NAME FORMAT A30 heading "Column Name"
--COLUMN CONSTRAINT_TYPE FORMAT A4 heading "Type"
--COLUMN POSITION ALIAS POS
--COLUMN POSITION 9999 heading "Pos"
COLUMN POSITION FORMAT 9999 heading "Pos"
BREAK ON CONSTRAINT_NAME 



SELECT COL.OWNER,
       COL.CONSTRAINT_NAME,
       COL.COLUMN_NAME,
       COL.POSITION,
--     CON.CONSTRAINT_TYPE
DECODE (CON.CONSTRAINT_TYPE,
       'P','primary','R','foreign','U','unique','C','check') "Type"
FROM   DBA_CONS_COLUMNS COL,
       DBA_CONSTRAINTS CON
WHERE  COL.OWNER = '$OWNER'
AND    COL.TABLE_NAME = '$TABLE'
AND    CONSTRAINT_TYPE <> 'R'
AND    COL.OWNER = CON.OWNER
AND    COL.TABLE_NAME = CON.TABLE_NAME
AND    COL.CONSTRAINT_NAME = CON.CONSTRAINT_NAME
ORDER BY COL.CONSTRAINT_NAME, COL.POSITION;


-- Show the Foreign Keys on this table pointing at other tables Primary
-- Key Fields for referential Integrity purposes.
-- ====================================================================


SELECT CON.OWNER,
       CON.TABLE_NAME,
       CON.CONSTRAINT_NAME,
       CON.R_CONSTRAINT_NAME,
       CON.DELETE_RULE,
       COL.COLUMN_NAME,
       COL.POSITION,
--     CON1.OWNER,
       CON1.TABLE_NAME "Ref Tab",
       CON1.CONSTRAINT_NAME "Ref Const"
--     COL1.COLUMN_NAME "Ref Column",
--     COL1.POSITION
--FROM   DBA_CONS_COLUMNS COL,
FROM   DBA_CONSTRAINTS CON1,
       DBA_CONS_COLUMNS COL,
       DBA_CONSTRAINTS CON
WHERE  CON.OWNER = '$OWNER'
AND    CON.TABLE_NAME = '$TABLE'
AND    CON.CONSTRAINT_TYPE = 'R'
AND    COL.OWNER = CON.OWNER
AND    COL.TABLE_NAME = CON.TABLE_NAME
AND    COL.CONSTRAINT_NAME = CON.CONSTRAINT_NAME
-- Leave out next line if looking for other Users with Foriegn Keys.
AND    CON1.OWNER = CON.OWNER
AND    CON1.CONSTRAINT_NAME = CON.R_CONSTRAINT_NAME
AND    CON1.CONSTRAINT_TYPE IN ( 'P', 'U' );
-- The extra DBA_CONS_COLUMNS will give details of refered to columns,
-- but has a multiplying effect on the query results.
-- NOTE: Could use temporary tables to sort out.
--AND    COL1.OWNER = CON1.OWNER
--AND    COL1.TABLE_NAME = CON1.TABLE_NAME
--AND    COL1.CONSTRAINT_NAME = CON1.CONSTRAINT_NAME;



-- Show the Foreign Keys pointing at this table via the recursive call
-- to the Constraints table.
-- ================================================================

SELECT CON1.OWNER,
       CON1.TABLE_NAME,
       CON1.CONSTRAINT_NAME,
       CON1.DELETE_RULE,
       CON1.STATUS,     
       CON.TABLE_NAME,
       CON.CONSTRAINT_NAME,
       COL.POSITION,
       COL.COLUMN_NAME
FROM   DBA_CONSTRAINTS CON,
       DBA_CONS_COLUMNS COL,
       DBA_CONSTRAINTS CON1
WHERE  CON.OWNER = '$OWNER'
AND    CON.TABLE_NAME = '$TABLE'
AND    ((CON.CONSTRAINT_TYPE = 'P') OR (CON.CONSTRAINT_TYPE = 'U'))
AND    COL.TABLE_NAME = CON1.TABLE_NAME
AND    COL.CONSTRAINT_NAME = CON1.CONSTRAINT_NAME
AND    CON1.OWNER = CON.OWNER
AND    CON1.R_CONSTRAINT_NAME = CON.CONSTRAINT_NAME
AND    CON1.CONSTRAINT_TYPE = 'R'
GROUP BY CON1.OWNER,
         CON1.TABLE_NAME,
         CON1.CONSTRAINT_NAME,
         CON1.DELETE_RULE,
         CON1.STATUS,     
         CON.TABLE_NAME,
         CON.CONSTRAINT_NAME,
         COL.POSITION,
         COL.COLUMN_NAME;



--
-- Show all the check Constraints
-- ==========================================================

SET  HEADING OFF
prompt
SELECT 'alter table '|| TABLE_NAME|| ' add constraint ',
        CONSTRAINT_NAME || ' check ( ', SEARCH_CONDITION ,' ); '
FROM DBA_CONSTRAINTS
WHERE OWNER = '$OWNER'
AND TABLE_NAME = '$TABLE'
AND CONSTRAINT_TYPE = 'C';

--
-- Show all the Triggers that have been created on this table
-- ==========================================================

-- add query to extract Trigger Body etcc WHEN CLAUSE here.

SET ARRAYSIZE 1
SET LONG 6000000


SELECT OWNER,
'CREATE OR REPLACE TRIGGER ',
       TRIGGER_NAME,
       DESCRIPTION,
       TRIGGER_BODY,
       '/'
FROM  DBA_TRIGGERS
WHERE OWNER = '$OWNER'
AND   TABLE_NAME = '$TABLE';



--
-- Show all the GRANTS made on this table and it's columns.
-- ========================================================


-- Table 1st
-- =========
SELECT 'GRANT ',
        PRIVILEGE,
      ' ON ',
        TABLE_NAME,
      ' TO ',
        GRANTEE,
       ';'
FROM DBA_TAB_PRIVS
WHERE OWNER = '$OWNER'
AND   TABLE_NAME = '$TABLE';

-- Columns 2nd
-- ===========

SELECT 'GRANT ',
        PRIVILEGE,
      ' ( ',
        COLUMN_NAME,
      ' ) ',
      ' ON ',
        TABLE_NAME,
      ' TO ',
        GRANTEE,
       ';'
FROM DBA_COL_PRIVS
WHERE OWNER = '$OWNER'
AND   TABLE_NAME = '$TABLE';

exit
EOF
 
else
       echo "Owner $OWNER not found"
       exit
fi

if $SBINS/yesno.sh "to view script" DO Y
   then 
    vi $FOUT
fi
