#!/usr/bin/ksh
#set -xv
SBIN2=${SBIN}/module3
WK_SBIN=$SBIN2/s2
cd $WK_SBIN
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
       echo "could no get a the password of $S_USER"
       exit 0
fi
TMP=$SBIN/tmp
FOUT=$TMP/Db_Coalescable_extents.txt
> $FOUT

if [ "x-$ORACLE_SID" = "x-" ];then
   echo "Oracle SID is not defined .. aborting "
   exit 0
fi
NBR_EXTENT_BF_END_TO_CHECK=10
while true 
do
echo " "
echo " *************************************************************************"
echo "    Report of next extent within $NBR_EXTENT_BF_END_TO_CHECK of maxextents"
echo " *************************************************************************"
echo " "
cpt=1
while read a
  do
  echo " $cpt : $a "
  cpt=`expr $cpt + 1`
done<$FOUT
echo 
echo " "
echo " e   : exit"
echo " "
echo " Select a number of extent ==> \c"
read NBR_EXTENT_BF_END_TO_CHECK
if [ "x-$NBR_EXTENT_BF_END_TO_CHECK" = "x-e" ];then
   exit
else
   if $SBINS/yesno.sh " to run script  with $NBR_EXTENT_BF_END_TO_CHECK "
      then
        echo "doing : test $NBR_EXTENT_BF_END_TO_CHECK "
sqlplus -s  "$CONNECT_STRING" <<!EOF
clear screen

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 100
set heading off
set embedded off pause off
set verify off
spool $FOUT

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report of next extent within '|| $NBR_EXTENT_BF_END_TO_CHECK || ' of maxextents' nline
from sys.dual
/
	define NBR_EXTENT_BF_END_TO_CHECK = $NBR_EXTENT_BF_END_TO_CHECK
	set embedded on
	set heading on
	set feedback off
	set lines 150
	set verify off
	break on owner
	column object format a30 head 'Object'
	column tbs format a30 head 'Tablespace'
	column tab_or_index format a5 head 'T/I'
	column max_extents format 9990 head 'Maximum|Extents'
	column current_extent format 9990 head 'Current|Extent'
	column ext_to_go format 9990 head 'Remain|Extent'
	column today new_value datevar format a1 noprint
	column bsize new_value max_ext format a1 noprint
	select decode(value,2048,121,4096,240,505) bsize, sysdate today from v\$parameter
	 where name = 'db_block_size';
	select a.owner, table_name object,
	       a.tablespace_name tbs,
	       'T' tab_or_index,
	       a.max_extents max_extents,
	       b.extents current_extent,
	       (a.max_extents - b.extents) ext_to_go
	  from sys.dba_tables a, sys.dba_segments b
	 where table_name = segment_name
	       and ( a.max_extents < extents + &NBR_EXTENT_BF_END_TO_CHECK or &max_ext < extents + &NBR_EXTENT_BF_END_TO_CHECK)
	union  all
	select a.owner, index_name  objects,
	       a.tablespace_name tbs,
	       'I' tab_or_index,
	       a.max_extents max_extents,
	       b.extents current_extent,
	       a.max_extents - b.extents ext_to_go
	from sys.dba_indexes a, sys.dba_segments b 
	 where index_name = segment_name
	       and ( a.max_extents < extents + &NBR_EXTENT_BF_END_TO_CHECK or &max_ext < extents + &NBR_EXTENT_BF_END_TO_CHECK);
spool off
	quit
!EOF
	exit
   else
      echo "Next time may be, life is so unpredictable ....."
   fi
fi
done
