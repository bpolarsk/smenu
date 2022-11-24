#!/usr/bin/ksh
#set -xv
#-------------------------------------------------------------------------------
#-- Script:	smenu_unindexed_foreign_keys.sh
#-- Purpose:	Report unindexed foreign keys
#-- Author:	Tom kyte
#__ adapted to smenu by By. Polarski
#-------------------------------------------------------------------------------
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SBINS=$SBIN/scripts
USER=`echo $USER | $NAWK '{ print toupper($1) }'`
FOUT=$SBIN/tmp/unindexed_foreign_keys_${ORACLE_SID}.log
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

sqlplus -s "$CONNECT_STRING" <<-EOF


ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
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
       'Report unindexed foreign keys'
from sys.dual
/   

set heading on linesize 132
column columns format a24 word_wrapped
column owner format a16 word_wrapped
column table_name format a30 word_wrapped
break on owner

select a.owner,decode( b.table_name, NULL, '****', 'ok' ) Status, 
	   a.table_name, a.columns, b.columns
from 
( select a.owner,substr(a.table_name,1,30) table_name, 
		 substr(a.constraint_name,1,30) constraint_name, 
	     max(decode(position, 1,     substr(column_name,1,30),NULL)) || 
	     max(decode(position, 2,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(position, 3,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(position, 4,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(position, 5,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(position, 6,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(position, 7,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(position, 8,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(position, 9,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(position,10,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(position,11,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(position,12,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(position,13,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(position,14,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(position,15,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(position,16,', '||substr(column_name,1,30),NULL)) columns
    from dba_cons_columns a, dba_constraints b
   where a.owner = b.owner                     and
         a.constraint_name = b.constraint_name and 
         b.constraint_type = 'R'
   group by a.owner, substr(a.table_name,1,30), substr(a.constraint_name,1,30) ) a, 
( select index_owner owner, substr(table_name,1,30) table_name, substr(index_name,1,30) index_name, 
	     max(decode(column_position, 1,     substr(column_name,1,30),NULL)) || 
	     max(decode(column_position, 2,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(column_position, 3,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(column_position, 4,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(column_position, 5,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(column_position, 6,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(column_position, 7,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(column_position, 8,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(column_position, 9,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(column_position,10,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(column_position,11,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(column_position,12,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(column_position,13,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(column_position,14,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(column_position,15,', '||substr(column_name,1,30),NULL)) || 
	     max(decode(column_position,16,', '||substr(column_name,1,30),NULL)) columns
    from dba_ind_columns 
   group by index_owner,substr(table_name,1,30), substr(index_name,1,30) ) b
where a.owner = b.owner and
    a.table_name = b.table_name (+)
  and b.columns (+) like a.columns || '%'
/

EOF

if $SBINS/yesno.sh "to view log" DO N
   then
     vi $FOUT
fi
