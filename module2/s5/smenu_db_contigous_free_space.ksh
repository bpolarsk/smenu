#!/usr/bin/ksh
#set -xv
# Author : didier Barjasse, revamp for smenu by bpa

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
VAR=`sqlplus -s  "$CONNECT_STRING" <<EOF
set head off feed off pause off
select table_name from dba_tables where table_name = 'SMENU_SPACE_TEMP' and owner = '$S_USER' ;
exit
EOF`
TBL=`echo $VAR | awk '{print $1}'`

if [ "x-$TBL" = "x-" ];then
(
sqlplus -s  "$CONNECT_STRING" <<EOF
set termout off
drop table SMENU_SPACE_TEMP
/
create table SMENU_SPACE_TEMP ( TABLESPACE_NAME  varchar2(30) not null,CONTIGUOUS_BYTES NUMBER)
/
exit
EOF
) 1>/dev/null 2>&1

else

(
sqlplus -s  "$CONNECT_STRING" <<EOF
set termout off pause off
truncate table SMENU_SPACE_TEMP
/
exit
EOF
) 1>/dev/null 2>&1
fi

sqlplus -s  "$CONNECT_STRING" <<EOF

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
clear screen

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 90
set heading off pause off
set embedded off
set termout on
set verify off
spool $FOUT 

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List Contiguous free space for all the Tablespaces ' nline
from sys.dual
/
prompt
set embedded on
set heading on
set feedback off
set linesize 100 pagesize 66 
rem break on tbs_name skip page duplicate
break on tbs_name 

column tbs_name  	form a25 head 'Tablespace Name'   
column cont_bytes  	format 99,999,999,990 head 'Contiguous| space'
column count_ext        format 990 head 'Contiguous|Num of Extents'
column count_ext_real   format 99,990 head 'Real Number |of Extents'
column tot_bytes        format 99,999,999,990 head 'Total Contg|of Bytes'

select substr(TABLESPACE_NAME,1,25)  tbs_name,
       CONTIGUOUS_BYTES cont_bytes
from SMENU_SPACE_TEMP
where CONTIGUOUS_BYTES is not null
order by tablespace_name  asc ,2 desc
/
prompt 
select substr(b.tablespace_name,1,25) tbs_name, 
       fa1/fb1 count_ext, 
       fb1 count_ext_real,
       nvl(fa2,0) tot_bytes
from ( select tablespace_name tablespace_name,
                count(contiguous_bytes) fa1,
                  sum(contiguous_bytes) fa2
        from SMENU_SPACE_TEMP
             group by tablespace_name ) a, 
      ( select tablespace_name tablespace_name,
               count( distinct file_id||'.'||block_id ) fb1
               from dba_free_space group by tablespace_name )b
where 
b.tablespace_name = a.tablespace_name 
group by b.tablespace_name,fa1/fb1,fb1, nvl(fa2,0)
order by b.tablespace_name
/ 
spool off
 
drop table SMENU_SPACE_TEMP
/
exit
EOF
