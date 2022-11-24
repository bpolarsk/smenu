#!/bin/sh
# Author : B. Polarski
# date   : 2015-07-22
# 
# This script will compare a list of table on 2 DB (T1 & T2). The table name are given in the form of SCHEMA.TABLE separated with a white space
# The DDL is put into a file and the files of each DB are compared with the diff utility. At the end of the report all files are included into the report.
# when there is no difference, then the diff returns nothing. No news, good news !
# Lines which starts with a '>' refers to T1 while '<' refers to T2. When something appears then it means it is missing on this site
# Ie : if you see this : '> columns   varchar2(3)' it  means  'columns' is missing on site T1
# there are plenty room for improvements. I need a beautifier on system generated names. next time....

#TLIST=`cat fff | tr '\n' ' '`
TLIST=SYSTEM.TOTO
T1=hacc
T2=hemr
FUSER1=system
FPWD1=Manager1
FUSER2=system
FPWD2=Manager1
TODAY=`date +%Y%m%d`

CS1=$FUSER1/$FPWD1@$T1
CS2=$FUSER2/$FPWD2@$T2


CMP_DIR=cmp_dir
if [ ! -d "$CMP_DIR" ];then
   mkdir "$CMP_DIR"
   if [ !  $? -eq 0 ];then
      echor "Error creating $CMP_DIR here :--> aborting"
      exit
   fi
fi
FLOG=${CMP_DIR}/diff_schema.$FUSER1_${T1}.${FUSER2}_${T2}_`date +%y%m%d`.log
# .....................................................................................
function get_meta_table
{
CONNECT_STRING=$1
fowner=$2
ftable=$3
 sqlplus -s "$CONNECT_STRING"  <<EOF
set echo  off verify off feed off
set head off
SET PAGESIZE 0 line 160
SET LONG 90000
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'CONSTRAINTS_AS_ALTER', true ) ;
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', TRUE ) ;
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'CONSTRAINTS', TRUE ) ;
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'REF_CONSTRAINTS', TRUE ) ;
execute dbms_metadata.set_transform_param(dbms_metadata.session_transform, 'TABLESPACE', true) ;
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY', true ) ;
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', true ) ;
set echo  on
set serveroutput on size 99999 format wrapped
col fline for a4000
spool $FOUT.tmp
SELECT dbms_metadata.get_ddl('TABLE', '$ftable','$fowner') fline FROM dual
/
select dbms_metadata.get_ddl('INDEX',index_name,'$fowner') fline from (
select index_name from dba_indexes where table_name = '$ftable' and table_owner = '$fowner')
/
EOF
}
# .....................................................................................

# .....................................................................................
function init {

  if [ -f $FLOG ];then
       cp $FLOG $CMD_DIR/$FLOG.$$
  fi
  cat > $FLOG <<EOF

 Date              : `date`
 Directory         : $CMP_DIR
 Differential meta :

     Source $FUSER1 in $T1
     Target $FUSER2 in $T2

 List of tables : $TLIST

EOF
}
# .....................................................................................

init 

 echo "\n............. Start of comparison section ............. \n" >> $FLOG
for i in $TLIST
do
 echo "processing now $i"
 fo=`echo $i | cut -f1 -d'.'` 
 ft=`echo $i | cut -f2 -d'.'` 
 get_meta_table $CS1 $fo $ft > $CMP_DIR/${fo}_${ft}_${T1}_${TODAY}.txt
 get_meta_table $CS2 $fo $ft > $CMP_DIR/${fo}_${ft}_${T2}_${TODAY}.txt
 echo "\nComparing now ${fo}.${ft}:" >> $FLOG 2>&1
 diff  $CMP_DIR/${fo}_${ft}_${T1}_${TODAY}.txt  $CMP_DIR/${fo}_${ft}_${T2}_${TODAY}.txt >> $FLOG 2>&1
 
done

 echo "\n......... End of comparison section ............. " >> $FLOG
 echo "\nAdding all references into the log : " >> $FLOG
 for i in `ls ${CMP_DIR}/*_${TODAY}.txt`
 do
   echo "\n........................................................." >> $FLOG
   var=`basename $i`
   echo "$var :\n" >> $FLOG
   cat $i >> $FLOG
done
