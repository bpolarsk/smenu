#!/usr/bin/ksh
#set -xv
SBINS=${SBIN}/scripts

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`


TMP=$SBIN/tmp
if [ "x-$1" = "x-" ];then
   echo " Table ==> \c"
   read tbl
   TABLE=`echo $tbl | tr '[a-z]' '[A-Z]'`
else
   TABLE=`echo $1 | tr '[a-z]' '[A-Z]'`
fi
FOUT=$TMP/report_constr_on_$TABLE.txt
> $FOUT
cd $TMP

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
cd $TMP
sqlplus  -s "$CONNECT_STRING" <<EOF3
set feedback off
set verify off
set head off
set pagesize 0
spool $TMP/get_usr$$.log
select owner from dba_tables where table_name = '$TABLE'  ;
EOF3

NBR_USER=`cat $SBIN/tmp/get_usr$$.log | wc -l`
while read OWNER
        do
          echo " -------- processing user $OWNER ----------- "
(
sqlplus -s "$CONNECT_STRING" <<EOF5 
drop table table_dependency;  
create table table_dependency (  
 OWNER VARCHAR2(30), /* The owner schema */  
 TABLE_NAME                       VARCHAR2(30), /* Parent Table */  
 CONSTRAINT_NAME                  VARCHAR2(30), /* Parent Constraint */  
 R_TABLE_NAME                     VARCHAR2(30), /* Referencing(Child) Table*/  
 R_CONSTRAINT_NAME                VARCHAR2(30), /* Ref(child) Constraint*/  
 R_OWNER                          VARCHAR2(30), /* Ref(Child) table owner*/  
 delete_rule                      varchar2(30), /* Delete Rule*/  
 cons_stat                        varchar2(8),   /* Child Constraint Status*/  
 Lev                              number(3)
)  
/  
EOF5
) > /dev/null

sqlplus -s "$CONNECT_STRING" <<EOF4 
set termout off
set feedback off
set verify off
set head off
declare
cpt number ;
begin
cpt:=1;
insert into table_dependency  
  select parnt.owner, parnt.table_name, parnt.constraint_name,  
      chld.table_name tabl, chld.constraint_name ccon, chld.owner ownr,  
      decode(chld.delete_rule, 'NO ACTION', 'Delete RESTRICT',  
             'CASCADE', 'On Delete CASCADE'), chld.status  , cpt 
     from all_constraints parnt, all_constraints chld  
     where  chld.constraint_type = 'R'  
      and chld.r_constraint_name = parnt.constraint_name  
      and chld.r_owner = parnt.owner  
      and parnt.table_name = upper('$TABLE')  
 and parnt.owner = upper('$OWNER') ;  
commit ;
WHILE TRUE LOOP  
cpt:=cpt + 1 ;
insert into table_dependency  
      select parnt.owner, parnt.table_name, parnt.constraint_name,  
      chld.table_name tabl, chld.constraint_name ccon, chld.owner ownr,  
      decode(chld.delete_rule, 'NO ACTION', 'DEL RESTRCT',  
             'CASCADE', 'ON DEL CASCD'), chld.status ,cpt 
     from all_constraints parnt, all_constraints chld  
     where  chld.constraint_type = 'R'  
 and chld.r_constraint_name = parnt.constraint_name  
      and chld.r_owner = parnt.owner  
      and not exists (select 'x' from table_dependency  
         where table_name = parnt.table_name  
                      and owner = parnt.owner);  
    if sql%rowcount = 0  
    then  
        exit;  
    end if;  
delete from table_dependency     ----  Delete rows involving
       where owner = r_owner       ----  Self dependencies
             and table_name = r_table_name;
  commit;  
end loop;  
end ;
/
spool $FOUT
set verify off heading on feedback off termout off doc off  
set linesize 122
col reflist head 'Parent <------ Child (Constraint Name) Delete Rule'  
col lev format 999 ;
select to_char(lev) ||' : ' || lpad(' ', 1 * (level -1 )) || owner || '.' || table_name ||  
       ' Rfd By ' ||  r_owner || '.' || r_table_name ||  
              '(' || r_constraint_name || ') ' ||  
         delete_rule || '(' || cons_stat || ')'  reflist  
  from table_dependency  
/  
col reflist head 'Child (Constraint Name) ------> Parent Delete Rule'  
select r_owner || '.' || r_table_name ||  
     '(' || r_constraint_name || ') ' || 'Refs ' ||  
     owner || '.' || table_name || ' ' ||   
     delete_rule || '(' || cons_stat || ')'  reflist  
from table_dependency  
where r_table_name = upper('TABLE')  
/  
spo off  
drop table table_dependency;  

EOF4
done<$TMP/get_usr$$.log
rm $TMP/get_usr$$.log
