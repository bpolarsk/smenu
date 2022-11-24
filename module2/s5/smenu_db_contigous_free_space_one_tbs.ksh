#!/usr/bin/ksh
#set -xv
SBINS=$SBIN/scripts
WK_SBIN=${SBIN}/module3/s2
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

cd $WK_SBIN
TMP=$SBIN/tmp
FOUT=$TMP/Db_Contigous_free_space.txt
> $FOUT
cd $TMP

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
unset Tbs_to_test
echo 'Enter the name of the Tablespace to check : \c'
read Tbs_to_test  
res=$(echo "`sqlplus -s "$CONNECT_STRING" <<EOF
set head off  pagesize 0
select table_name from user_tables where table_name = 'SMENU_SPACE_TEMP'
/
EOF` " | awk '{print $1}')
if  [ "$res" = "SMENU_SPACE_TEMP" ] ;then
    sqlplus -s  "$CONNECT_STRING" <<EOF
drop table SMENU_SPACE_TEMP
/
EOF
fi

sqlplus -s  "$CONNECT_STRING" <<EOF
create table SMENU_SPACE_TEMP (
  TABLESPACE_NAME        varchar2(30),
  CONTIGUOUS_BYTES       NUMBER)
/
declare
  cursor query is select *
          from dba_free_space
                  order by tablespace_name, file_id,block_id;
  this_row        query%rowtype;
  previous_row    query%rowtype;
total           number;

begin
  open query;
  fetch query into this_row;
  previous_row := this_row;
  total := previous_row.bytes;
  loop
 fetch query into this_row;
     exit when query%notfound;
     if this_row.file_id = previous_row.file_id then
     if this_row.block_id = previous_row.block_id + previous_row.blocks then
        total := total + this_row.bytes;
        insert into SMENU_SPACE_TEMP (tablespace_name)
                  values (previous_row.tablespace_name);
     else
        insert into SMENU_SPACE_TEMP values (previous_row.tablespace_name,
               total);
        total := this_row.bytes;
     end if;
     else
        insert into SMENU_SPACE_TEMP values (previous_row.tablespace_name,
               total);
        total := this_row.bytes;
     end if;
previous_row := this_row;
  end loop;
  insert into SMENU_SPACE_TEMP values (previous_row.tablespace_name,
                           total);
end;
/
rem clear screen

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 80
set heading off
set termout on
set embedded off
set verify off
spool $FOUT 

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List Contiguous free space in the Tablespace ' || upper('$Tbs_to_test' ) nline
from sys.dual
/
prompt
set embedded on
set heading on
set feedback off
set linesize 155 pagesize 66 
break on tbs_name 

column tbs_name  	form a30 head 'Tablespace Name'             just c 
column cont_bytes  	format 9,999,999,999,990 head 'Contiguous space'
column count_ext        format 990 head 'Contiguous|Number of Extents'
column count_ext_real   format 990 head 'Real|Number of Extents'
column tot_bytes        format 9,999,999,999,990 head 'Total Bytes'

select TABLESPACE_NAME  tbs_name,
       CONTIGUOUS_BYTES cont_bytes
from SMENU_SPACE_TEMP
where CONTIGUOUS_BYTES is not null
and tablespace_name =  upper('$Tbs_to_test')
order by tablespace_name  asc ,2 desc
/
rem
rem
select a.tablespace_name tbs_name, count(a.contiguous_bytes)/count( distinct b.file_id||'.'||b.block_id ) count_ext, count( distinct b.file_id||'.'||b.block_id ) count_ext_real,
         sum(contiguous_bytes)/count( distinct b.file_id||'.'||b.block_id ) tot_bytes
from SMENU_SPACE_TEMP a, dba_free_space b
where b.tablespace_name = upper('$Tbs_to_test')
and a.tablespace_name =  upper('$Tbs_to_test')
group by a.tablespace_name,b.tablespace_name
order by a.tablespace_name
/ 
spool off
 
drop table SMENU_SPACE_TEMP
/
exit
EOF

