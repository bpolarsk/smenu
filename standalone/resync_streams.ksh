#!/bin/sh
 
LIST_TBL=lst_rcy.txt
# .......................................................
function get_pwd
{
echo $1
}
# .......................................................
function get_col_list
{
  owner=$1
  table=$2
 
sqlplus -s $owner/$PASSWD<<EOF
set serveroutput on
set feed off pause off verify off head off
declare
  sep varchar2(1) ;
  v_cols varchar2(32000);
  for col in (select column_name
                   from all_tab_columns
                      where owner=upper('$owner') and table_name=upper('$table') )
  loop
      v_cols:=v_cols||sep|| ''''|| col.column_name||'''' ;
      sep:=',' ;
  end loop ;
  dbms_output.put_line(v_cols);
end;
/
EOF
}
# .......................................................
function check_desync
{
  sowner=$1
  stable=$2
  towner=$3
  ttable=$4
  pwd=`get_pwd $towner`
 
ret=`sqlplus -s $towner/$pwd <<EOF
set pause off feed off verify off head off
select count(*) bcpt from (
        select * from $sowner.$stable
        minus
        select * from $towner.$ttable )
/
EOF`
echo $ret|awk '{print $1}'
}
# .......................................................
function create_err_table
{
  owner=$1
  TBL=$2
  ERR_OWNER=$3
  ERR_TBL=$4
  PASSWD=`get_pwd $1`
 
  ERR_TBL=`echo $ERR_TBL | sed 's/^bk_/err_/'`
sqlplus -s $owner/$PASSWD<<EOF
  execute dbms_errlog.create_error_log('$TBL','$ERR_TBL','$ERR_OWNER') ;
EOF
}
# .......................................................
# .......................................................
function create_bk_table
{
  owner=$1
  TBL=$2
  BK_OWNER=$3
  BK_TBL=$4
  PASSWD=`get_pwd $1`
 
sqlplus -s $owner/$PASSWD<<EOF
 
set serveroutput on
set feed off
declare
    cpt number ;
    sqlcmd varchar2(4000) ;
    begin
      select count(*)   into cpt
        from  all_tables where table_name = upper('$BK_TBL') and owner = upper('BK_OWNER');
      if cpt = 0 then
         sqlcmd:='create table $BK_OWNER.$BK_TBL as select * from $owner.$TBL where 1=2' ;
         dbms_output.put_line('Doing :' || sqlcmd ) ;
         execute immediate sqlcmd ;
      else
         dbms_output.put_line('bk tbl $BK_OWNER.$BK_TBL already exists' );
      end if ;
   end ;
/
EOF
  disable_table_constraint $BK_OWNER $BK_TBL ;
}
# .......................................................
function disable_table_constraint
{
  owner=$1
  TBL=$2
  PASSWD=`get_pwd $1`
sqlplus -s $owner/$PASSWD<<EOF
set serveroutput on
 
  declare
    sqlcmd varchar2(4000) ;
  begin
   for c in (select constraint_name from user_constraints
                where table_name = upper('$TBL')   and status='ENABLED'
             )
   loop
     sqlcmd:='alter table $TBL  disable constraint ' || c.constraint_name ;
     dbms_output.put_line('Doing  :' || sqlcmd);
     execute immediate sqlcmd ;
   end loop ;
end ;
/
EOF
}
# .......................................................
function mv_old_rows
{
  sowner=$1
  spass=`get_pwd $1`
  stable=$2
  towner=$3
  tpass=`get_pwd $3`
  ttable=$4
  bk_owner=$5
  bk_table=$6
 
echo " "
echo "About to save the target rows in backup table"
disable_remote_FK $towner $ttable
 
  COL1=`get_col_list $towner $ttable`
 
sqlplus -s $towner/$tpass<<EOF
set serveroutput on
  declare
    sqlcmd varchar2(4000) ;
    v_col  varchar2(4000);
    cpt number ;
  begin
    dbms_output.put_line('Saving rows from $towner.$ttable that exists in $sowner.$stable');
    for c in (  select a.OWNER, a.TABLE_NAME ,  c.COLUMN_NAME
                       from
                             dba_constraints a,
                             SYS.DBA_CONS_COLUMNS c
                       where  a.owner=upper('$towner') and a.table_name = upper('$ttable')
                         and a.constraint_type in ( 'P')
                         and c.owner=a.owner
                         and c.TABLE_NAME = a.table_name
                         and c.constraint_name = a.constraint_name
                         and position is not null
                    order by c.owner, c.table_name,c.COLUMN_NAME,c.POSITION
             )
    loop
       v_col:=v_col ||' and a.' || c.column_name  || '=b.'||c.column_name  ;
    end loop ;
    --dbms_output.put_line('v_col ='||v_col) ;
    if length(v_col) > 4 then
       sqlcmd:='insert into  $bk_owner.$bk_table select a.* from $towner.$ttable a, $sowner.$stable b'
                 ||chr(10)|| ' where 1=1 ' || v_col ;
       dbms_output.put_line('Doing :' || sqlcmd);
       execute immediate sqlcmd ;
 
       -- Delete the target rows now
       sqlcmd:='delete from $towner.$ttable where rowid in ( select a.rowid ' ||
                  ' from $towner.$ttable a, $sowner.$stable b where 1=1 ' || v_col || ')' ;
       dbms_output.put_line('Doing ' || sqlcmd ) ;
       execute immediate sqlcmd ;
    end if ;
 
    -- no key, do we transfer only rows that are not into source.
    -- for the rest and duplicate, we don't know
 
    select count(*) into cpt from $sowner.$stable ;
    dbms_output.put_line('$stable     : Source  count  :' || to_char(cpt) );
    select count(*) into cpt from  $bk_owner.$bk_table ;
    dbms_output.put_line('$bk_table  : backup  count  :' || to_char(cpt) );
  end;
/
EOF
}
# .......................................................
function disable_remote_FK
{
  towner=$1
  tpass=`get_pwd $1`
  ttable=$2
 
sqlplus -s $towner/$tpass<<EOF
set serveroutput on
  declare
    sqlcmd varchar2(4000) ;
  begin
    for c in ( select b.owner, b.table_name, b.constraint_name
     from
         all_constraints a,
         all_constraints b,
         all_cons_columns c,
         all_cons_columns d
  where a.table_name= upper('$stable' ) and a.owner = upper('$towner') and a.status = 'ENABLED'
      and b.r_constraint_name = a.constraint_name
      and b.r_owner = a.owner
      and c.constraint_name = a.constraint_name
      and c.owner = a.owner
      and c.table_name = a.table_name
     and d.owner = b.owner
     and d.table_name = b.table_name
    and d.constraint_name = b.constraint_name )
  loop
      sqlcmd:='alter table ' ||  c.owner||'.'||c.table_name|| ' disable constraint '|| c.constraint_name ;
      dbms_output.put_line('Doing '|| sqlcmd );
      execute immediate sqlcmd ;
  end loop ;
end;
/
EOF
}
# .......................................................
function  insert_rows_from_src
{
  sowner=$1
  spass=`get_pwd $1`
  stable=$2
  towner=$3
  tpass=`get_pwd $3`
  ttable=$4
  bk_owner=$5
  bk_table=$6
  err_table=`echo $bk_table | sed 's/^bk_/err_/'`
 
  echo " "
  echo "Transfering now the rows from source $sowner.$stable to target $towner.$ttable"
  echo "Rows in error will go into  $bk_owner.$err_table ."
  echo " "
 
sqlplus -s $towner/$tpass<<EOF
set serveroutput on
  declare
      --rec    ${ttable}%ROWTYPE ;
      sqlcmd varchar2(4000) ;
      cpt   number ;
      v_cols    varchar2(4000);
      sep       varchar2(1) ;
  begin
      for rec in (select * from $sowner.$stable
                  minus
                  select * from  $towner.$ttable)
      loop
         begin
            insert into $towner.$ttable values rec log errors into $bk_owner.$err_table REJECT LIMIT UNLIMITED;
         exception
           when others then
              dbms_output.put_line('Error 1');
         end ;
      end loop;
      commit ;
    -- end check
    select count(*) into cpt from $sowner.$stable ;
    dbms_output.put_line('$stable  : Source  count  :' || to_char(cpt) );
 
    select count(*) into cpt from  $towner.$ttable ;
    dbms_output.put_line('$ttable  : Target  count  :' || to_char(cpt) );
 
    select count(*) into cpt from  $bk_owner.$bk_table ;
    dbms_output.put_line('$ttable  : Backup  count  :' || to_char(cpt) );
 
    select count(*) into cpt from  $bk_owner.$err_table ;
    dbms_output.put_line('$ttable  : Error  count  :' || to_char(cpt) );
  end ;
/
EOF
 
}
# .......................................................
function count_before
{
  sowner=$1
  spass=`get_pwd $1`
  stable=$2
  towner=$3
  tpass=`get_pwd $3`
  ttable=$4
 
echo "*******************"
echo "Before count"
echo "*******************"
sqlplus -s $towner/$tpass<<EOF
set serveroutput on
declare
  cpt number;
begin
    select count(*) into cpt from $sowner.$stable ;
    dbms_output.put_line('$stable  : Source  count  :' || to_char(cpt) );
 
    select count(*) into cpt from  $towner.$ttable ;
    dbms_output.put_line('$ttable  : Target  count  :' || to_char(cpt) );
end;
/
EOF
echo
 
}
# .......................................................
function post_status
{
sqlplus -s bpa/bpa <<EOF
 
prompt ======================
prompt
prompt count desync rows $1
prompt
prompt ======================
prompt
set feed off
select 'P111315.R_AUDIT_CRFDATA' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.R_AUDIT_CRFDATA)  a,
      (select count(*) bcpt from (
        select *  from bpa.R_AUDIT_CRFDATA
        minus
        select * from P111315.R_AUDIT_CRFDATA) ) b
/
select 'P111315.R_AUDIT_MESSAGE' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.R_AUDIT_MESSAGE)  a,
      (select count(*) bcpt from (
        select *  from bpa.R_AUDIT_MESSAGE
        minus
        select * from P111315.R_AUDIT_MESSAGE) ) b
/
select 'P111315.R_AUDIT_MSGLINE' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.R_AUDIT_MSGLINE)  a,
      (select count(*) bcpt from (
        select *  from bpa.R_AUDIT_MSGLINE
        minus
        select * from P111315.R_AUDIT_MSGLINE) ) b
/
select 'P111315.R_AUDIT_SUBJECT' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.R_AUDIT_SUBJECT)  a,
      (select count(*) bcpt from (
        select *  from bpa.R_AUDIT_SUBJECT
        minus
        select * from P111315.R_AUDIT_SUBJECT) ) b
/
select 'P111315.R_AUDIT_TRANSDATA' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.R_AUDIT_TRANSDATA)  a,
      (select count(*) bcpt from (
        select *  from bpa.R_AUDIT_TRANSDATA
        minus
        select * from P111315.R_AUDIT_TRANSDATA) ) b
/
select 'P111315.R_CRFDATA' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.R_CRFDATA)  a,
      (select count(*) bcpt from (
        select *  from bpa.R_CRFDATA
        minus
        select * from P111315.R_CRFDATA) ) b
/
select 'P111315.R_MESSAGE' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.R_MESSAGE)  a,
      (select count(*) bcpt from (
        select *  from bpa.R_MESSAGE
        minus
        select * from P111315.R_MESSAGE) ) b
/
select 'P111315.R_MSGLINE' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.R_MSGLINE)  a,
      (select count(*) bcpt from (
        select *  from bpa.R_MSGLINE
        minus
        select * from P111315.R_MSGLINE) ) b
/
select 'P111315.R_SCREENSTATUS' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.R_SCREENSTATUS)  a,
      (select count(*) bcpt from (
        select *  from bpa.R_SCREENSTATUS
       minus
        select * from P111315.R_SCREENSTATUS) ) b
/
select 'P111315.R_SUBACTFROZEN' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.R_SUBACTFROZEN)  a,
      (select count(*) bcpt from (
        select *  from bpa.R_SUBACTFROZEN
        minus
        select * from P111315.R_SUBACTFROZEN) ) b
/
select 'P111315.R_SUBJECT' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.R_SUBJECT)  a,
      (select count(*) bcpt from (
        select *  from bpa.R_SUBJECT
        minus
        select * from P111315.R_SUBJECT) ) b
/
select 'P111315.R_SUBSCHE' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.R_SUBSCHE)  a,
      (select count(*) bcpt from (
        select *  from bpa.R_SUBSCHE
        minus
        select * from P111315.R_SUBSCHE) ) b
/
select 'RDE_COMMON.R_LOGMINER' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.R_LOGMINER)  a,
      (select count(*) bcpt from (
        select *  from bpa.R_LOGMINER
        minus
        select * from RDE_COMMON.R_LOGMINER) ) b
/
select 'RDE_COMMON.R_SEQKEY' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.R_SEQKEY)  a,
      (select count(*) bcpt from (
        select *  from bpa.R_SEQKEY
        minus
        select * from RDE_COMMON.R_SEQKEY) ) b
/
select 'STREAMS_ACCOUNT.WORKING_R_LOGTRACE' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.WORKING_R_LOGTRACE)  a,
      (select count(*) bcpt from (
        select *  from bpa.WORKING_R_LOGTRACE
        minus
        select * from STREAMS_ACCOUNT.WORKING_R_LOGTRACE) ) b
/
select 'STREAMS_ACCOUNT.WORKING_USER_AGREEMENT_CAT' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.WORKING_USER_AGREEMENT_CAT)  a,
      (select count(*) bcpt from (
        select *  from bpa.WORKING_USER_AGREEMENT_CAT
        minus
        select * from STREAMS_ACCOUNT.WORKING_USER_AGREEMENT_CAT) ) b
/
select 'STREAMS_ACCOUNT.WORKING_USER_CAT' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.WORKING_USER_CAT)  a,
      (select count(*) bcpt from (
        select *  from bpa.WORKING_USER_CAT
        minus
        select * from STREAMS_ACCOUNT.WORKING_USER_CAT) ) b
/
select 'STREAMS_ACCOUNT.WORKING_USER_PASSWORD_CAT' Src_Table, acpt count_in_src, bcpt Missing_in_target from
      (select count(*) acpt from bpa.WORKING_USER_PASSWORD_CAT)  a,
      (select count(*) bcpt from (
        select *  from bpa.WORKING_USER_PASSWORD_CAT
        minus
        select * from STREAMS_ACCOUNT.WORKING_USER_PASSWORD_CAT) ) b
/
EOF
 
}
# .......................................................
function bef_action
{
sqlplus bpa/bpa <<EOF
drop trigger P111315.R_SAFDEL_TRG;
drop trigger P111315.R_SAFUPDATE_TRG ;
drop trigger P111315.T_R_SUBJECT_BR ;
EOF
}
# .......................................................
#            Main
# .......................................................
status "BEFORE"
bef_action
 
while read source_owner source_table target_owner target_table bk_owner bk_table
do
    count_before $source_owner $source_table $target_owner $target_table
    a=`check_desync $source_owner $source_table $target_owner $target_table`
    if [ $a -gt 0 ];then
       echo " **********************************************************************"
       echo "  Found $a rows desync for $source_owner.$source_table "
       echo " **********************************************************************"
       create_bk_table $target_owner $target_table $bk_owner $bk_table
       create_err_table $target_owner $target_table $bk_owner $bk_table
       mv_old_rows $source_owner $source_table $target_owner $target_table $bk_owner $bk_table
       insert_rows_from_src  $source_owner $source_table $target_owner $target_table $bk_owner $bk_table
    else
       echo " "
       echo " No dsync found for  $source_owner $source_table "
       echo " "
    fi
done < $LIST_TBL
status AFTER
