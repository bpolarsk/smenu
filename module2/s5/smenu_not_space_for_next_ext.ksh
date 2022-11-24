#!/usr/bin/ksh
#set -xv
SBINS=$SBIN/scripts
SBIN2=${SBIN}/module3/s2
WK_SBIN=$SBIN2
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
cd $WK_SBIN
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
TMP=$SBIN/tmp
FOUT=$TMP/Db_Not_Enough_Space_For_Next_extents.txt
> $FOUT

if [ "x-$ORACLE_SID" = "x-" ];then
   echo "Oracle SID is not defined .. aborting "
   exit 0
fi

sqlplus -s "$CONNECT_STRING" <<!EOF
clear screen

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 80
set heading off
set embedded off pause off
set verify off
spool $FOUT

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List of objects which have not enough free space for their next extent ' nline
from sys.dual
/
prompt
set embedded on
set heading on
set feedback off
set linesize 155 pagesize 66 

column  tbs_name format a25 heading 'Tablespace Name'
column  object_name format a25 heading 'Object Name'
column  next_extent_size format 9,999,999,990 heading 'Next|Extent Size' justify c
column  max_free_space format 9,999,999,990 heading 'Max|Free Space' justify c
break on tbs_name

Column cTSDictionary   New_Value pTSDictionary   NoPrint
Column cAutoExtensible New_Value pAutoExtensible NoPrint
Column cGrowBytes      New_Value pGrowBytes      NoPrint
Column cMaxBytes       New_Value pMaxBytes       NoPrint
Column cIncrementBytes New_Value pIncrementBytes NoPrint
Column cMaxBlocks      New_Value pMaxBlocks      NoPrint
Column cIncrementBy    New_Value pIncrementBy    NoPrint
Column cDBA_Segments New_Value DBA_Segments    NoPrint
define fe=2

select Decode ( Count(*) , 0, 'DBA_SEGMENTS' ,  'SYS.SYS_DBA_SEGS') cDBA_Segments
  From DBA_Views Where View_Name = 'SYS_DBA_SEGS' And Owner = 'SYS'
/

Select Decode ( Count(*) , 0, '' ,  'And TS.Extent_Management = ''DICTIONARY''') cTSDictionary
  From dba_tab_columns Where table_name = 'DBA_TABLESPACES' And column_name = 'EXTENT_MANAGEMENT' And Owner = 'SYS';

Select Decode ( Count(*) , 0, '' ,  'AutoExtensible = ''YES'' And') cAutoExtensible
     , Decode ( Count(*) , 0, '0' ,
     'Decode(Increment_By, 0, 0, Trunc((MaxBlocks - Blocks)/Increment_By)) * Increment_By * (Bytes/Blocks)') cGrowBytes
     , Decode ( Count(*) , 0, 'Bytes' , 'MaxBytes') cMaxBytes
     , Decode ( Count(*) , 0, 'Null' , 'Increment_By * (Bytes/Blocks)') cIncrementBytes
     , Decode ( Count(*) , 0, 'Blocks' , 'MaxBlocks') cMaxBlocks
     , Decode ( Count(*) , 0, '0' , 'Increment_By') cIncrementBy
  From dba_tab_columns
 Where table_name = 'DBA_DATA_FILES'
   And column_name = 'INCREMENT_BY' And Owner = 'SYS'
/

REM no space left in tablespace for next extent

Select
       Decode( Trunc(S.MaxBytes/O.MaxBytes) + Trunc(Nvl(F.GrowBytes, 0)/O.MaxBytes)
                               , 0, 'CRITICAL'
                               , 1, 'Warning'
                               , 2, 'Warning'
                                  , 'OK'
                               )
     || O.Tablespace_Name
     || ' Needed: '    || To_Char(round(O.maxbytes/1048576,2)) || ' Mb'
     || ', Current Free: ' || To_Char(round(S.maxbytes/1048576,2)) || ' Mb'
     || ', Extendable: '  || To_Char(round(Nvl(F.GrowBytes, 0)/1048576,2)) || ' Mb, '
                                Line
  from ( Select S.tablespace_name, max(S.next_extent) maxbytes
           From &Dba_Segments S, DBA_Tablespaces TS
          Where S.Tablespace_Name = TS.Tablespace_Name  &pTSDictionary
          Group by S.Tablespace_Name
       ) O
     , ( select tablespace_name, max(bytes) maxbytes
           From Dba_Free_Space
          Group By Tablespace_Name
       ) S
     , ( Select Tablespace_Name
              , Max(&pGrowBytes) GrowBytes
           From Dba_Data_Files
          Where &pAutoExtensible
                (Bytes + &pGrowBytes) <= &pMaxBytes
          Group By Tablespace_Name
       ) F
 where O.Tablespace_Name = S.Tablespace_Name (+)
   And O.Tablespace_Name = F.Tablespace_Name (+)  $EXCLUDED_TBS_LIST
   And &fe * O.MaxBytes > Nvl(S.MaxBytes, 0)
   And &fe * O.MaxBytes > Nvl(F.GrowBytes, 0)
   And &fe - Trunc(Nvl(F.GrowBytes, 0)/O.MaxBytes)
           > ( Select Nvl(Sum(Trunc(Free.Bytes/O.MaxBytes)),0)
                 From Dba_Free_Space Free
                Where Free.Tablespace_Name = O.Tablespace_Name
                  And Free.Bytes >= O.MaxBytes
             )
 Order By O.Tablespace_Name
/ 
spool off
exit
!EOF
echo
echo
