# This scripts generates the statement to unload table in CSV format.
# Next your have to run this by yourself
# bpa 2017-05-04


# put the table list in upper case unless you dumb created table with lower case separated by a blank
TABLE_LIST=" CLD01 CLD02 CLD70 CCD52 EID01"
TABLE_OWNER=THALER_OWNER
CONNECT_STRING=user/password@mydb

   cat <<EOF 
set lines 2000
set trimspool on
set head off
set pages 0 trimspool on
alter session set nls_date_format = 'YYYYMMDD';

EOF
for ftable in $TABLE_LIST
 do
   cat <<EOF 

prompt
prompt Doing $ftable
prompt

EOF

echo "sqlplus -s $CONNECT_STRING > $ftable.csv 2>&1 <<EOF" > $ftable.ksh
echo "set pages 0 lines 4000" >> $ftable.ksh
echo "set feed off trimspool on termout off echo off" >> $ftable.ksh
echo " " >> $ftable.ksh
sqlplus -s $CONNECT_STRING >> $ftable.ksh<<EOF
  set pages 0 lines 4000
  set feed off
select  'select ''"''||'||
  listagg('"'||column_name||'"' ,'||''","''||') WITHIN GROUP  (order by column_id )  || '||''"'' from $TABLE_OWNER.$ftable  ' f 
  from
  all_tab_columns 
where owner = '$TABLE_OWNER' and table_name = '$ftable'  
/
EOF
echo "/" >>  $ftable.ksh
echo "EOF">>  $ftable.ksh
echo "exit">>  $ftable.ksh
chmod 755 $ftable.ksh
done
echo ""
