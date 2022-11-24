#!/bin/sh
# set -xv
# author :  B. Polarski
# program : This script will extract a table ddl from a partitioned table but only up
#           to the first partition, including the subpartition. It is used to create
#           the dummy table for the exchange partition of a composite partitions
# 13 Juillet 2005
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# --------------------------------------------------------------------------
FOUT=$SBIN/tmp/get_dd_$$.sql
typeset -u FTABLE
typeset -u FSCHEMA
echo " Table name ====== > \c"
read FTABLE
echo " Schema name ====== > \c"
read FSCHEMA

sqlplus -s "$CONNECT_STRING"  <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 190
set termout on pause off
set embedded on
set verify off
set heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'Create ddl for all subpartion of first partition in a partitioned table' nline
from sys.dual
/


set head off
SET PAGESIZE 0
SET LONG 90000
set linesize 190
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'CONSTRAINTS_AS_ALTER', true );
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', false );
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'CONSTRAINTS', false );
execute dbms_metadata.set_transform_param( DBMS_METADATA.SESSION_TRANSFORM, 'REF_CONSTRAINTS', false );
spool $FOUT
SELECT dbms_metadata.get_ddl('TABLE', '$FTABLE','$FSCHEMA') FROM dual
/
EOF

FTABLE_DUMMY=${FTABLE}_DUMMY
cat $FOUT |  sed 's/[ ]*$//' > $FOUT.1
echo "  CREATE TABLE \"$FSCHEMA\".\"$FTABLE_DUMMY\"" > $FOUT
tail +3 $FOUT.1 >> $FOUT
rm $FOUT.1
ret=`grep -n " PARTITION" $FOUT | head -2 | tail -1 | cut -f1 -d:`
if [ -z "$ret" ];then
   echo "could not find the first partiton in $FOUT"
   echo "Please process the file $FOUT for table $FTABLE manually"
   exit
fi
ret=$(expr $ret - 2 )
FOUT2=$SBIN/tmp/new_table$$.sql
cat $FOUT | head -$ret > $FOUT2
mv $FOUT.1 $FOUT
ret=$(expr $ret + 1 )
line=$(head -$ret $FOUT | tail -1 )
echo $line | sed 's/\(.*\),[ ]*$/\1/'>> $FOUT2
echo ")" >> $FOUT2

echo "create table $FSCHEMA.${FTABLE_DUMMY} tablespace data as select * from $FSCHEMA.$FTABLE where 1=2 ;" >> $FOUT2
rm $FOUT
if $SBINS/yesno.sh " to see the result file $FOUT2" DO
then
  vi $FOUT2
fi
