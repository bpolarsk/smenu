#!/usr/bin/ksh
#set -xv
SBINS=$SBIN/scripts
WK_SBIN=${SBIN}/module3/s2
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

cd $WK_SBIN
TMP=$SBIN/tmp
FOUT=$TMP/Db_Coalescable_${ORACLE_SID}.txt
> $FOUT
cd $TMP
S_USER=system
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} 
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
sqlplus -s "$CONNECT_STRING" <<EOF

clear screen

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pause off
set pagesize 66
set linesize 80
set heading off
set embedded off
set termout on
set verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List Coalescable extents for all the Tablespaces ' nline
from sys.dual
/
prompt

set embedded on
set heading on
set feedback off
set linesize 90 pagesize 66 

column c1 heading "Tablespace|Number"
column c2 heading "Tablespace|Name"
column c3 heading "Coalescable|Extents"
select c.ts#    c1
      ,c.name   c2
      ,count(*) c3
  from sys.fet$ a
      ,sys.fet$ b
      ,sys.ts$  c
 where a.ts# = b.ts#
   and a.ts# = c.ts#
   and a.file# = b.file#
   and (a.block#+a.length) = b.block#
group by c.ts#,c.name
/ 
EOF

if $SBINS/yesno.sh "to coalese now " DO Y
   then
     echo " Generating the script, please wait .... "
sqlplus -s  "$CONNECT_STRING" << EOF

spool $FOUT 
set pause off
set embedded on
set heading off
set feedback off
set termout off
set linesize 130 pagesize 0

select 'alter tablespace '||c.name|| ' coalesce ;'
  from sys.fet$ a
      ,sys.fet$ b
      ,sys.ts$  c
 where a.ts# = b.ts#
   and a.ts# = c.ts#
   and a.file# = b.file#
   and (a.block#+a.length) = b.block#
group by c.ts#,c.name
/ 
spool off
exit

EOF
# ok, doing the job
sqlplus -s  "$CONNECT_STRING" << EOF
@$FOUT
EOF
fi

