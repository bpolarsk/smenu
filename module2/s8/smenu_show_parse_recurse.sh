#!/bin/sh
#---------------------------------------------------------------------------------
# Show recursive calls
#---------------------------------------------------------------------------------
SBINS=$SBIN/scripts

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

cd $SBIN/tmp
FOUT=$SBIN/tmp/rec_pars_${ORACLE_SID}.txt

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} 
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 80
set termout on pause off
set embedded on
set verify off
set heading off
spool $FOUT

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report recursive parsing from v\$sysstat' nline
from sys.dual
/

set linesize 100
set heading on
set  space 3 heading on pause off 
prompt
prompt ----------------------------------------------------------------------------------------

prompt Parse Ratio usually falls between 1.15 and 1.45.  If it is higher, then  
prompt Recursive Call Ratio will usually be between  
prompt  7.0 - 10.0 for tuned production systems  and  10.0 - 14.5 for tuned development systems  
prompt ----------------------------------------------------------------------------------------

prompt

column pcc   heading 'Parse|Ratio'       format 99.99  
column rcc   heading 'Recsv|Cursr'       format 9999.99  
column rwr   heading 'Rd/Wr|Ratio'       format 999,999.9  
column bpfts heading 'Blks per|Full TS'  format 999,999  

 select sum(decode(a.name,'parse count',value,0)) /  
       sum(decode(a.name,'opened cursors cumulative',value,.00000000001)) pcc,  
       sum(decode(a.name,'recursive calls',value,0)) /  
       sum(decode(a.name,'opened cursors cumulative',value,.00000000001)) rcc,  
       sum(decode(a.name,'physical reads',value,0)) /  
       sum(decode(a.name,'physical writes',value,.00000000001)) rwr,  
       (sum(decode(a.name,'table scan blocks gotten',value,0)) -  
       sum(decode(a.name,'table scans (short tables)',value,0)) * 4) /  
       sum(decode(a.name,'table scans (long tables)',value,.00000000001))  bpfts 
 from   v\$sysstat a  
/
EOF
