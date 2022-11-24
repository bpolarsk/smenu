#!/usr/bin/ksh
# program smenu_analyse_db.sh
# Author : Bernard Polarski : 19-06-2000
#set -xv
    #--------------- comments section ---------------------
    # This script is part of the module 3 (DB utilities)
    # in smenu
    # Purpose : Return QUICK info off all index attached to 
    # a table
    #--------------- Environement section ---------------------
    #
    SBIN2=$SBIN/module2
    SBINS=$SBIN/scripts
    HOST=`hostname`
    #--------------- Test variables section ---------------------
    #--------------- Process section ---------------------
    #--------------- Get system password section ---------------------

    if [  "x-$1" = "x-" ];then
       cat <<EOF


         Usage : $0 -I 
         Usage : $0 -S 

             -I : ask before effectively running
             -S : Do not ask, and run directly

EOF
      exit
    fi
    if [  "x-$1" = "x-S" -o "x-$1" = "x--S" ];then
       INTERACT=N
    else
       INTERACT=Y
    fi
    . $SBIN/scripts/passwd.env
    . ${GET_PASSWD} 
    if [  "x-$CONNECT_STRING" = "x-" ];then
          echo "could no get a the password of $S_USER"
          exit 0
    fi
    FOUT=$SBIN/tmp/analyse_db_$ORACLE_SID.sql
    #--------------- Process section ---------------------
       sqlplus -s "$CONNECT_STRING" <<EOF
set heading off;
set feedback off;
set pages 0;
set termout off;
set flush off;
set echo off;
set pause off;
spool $FOUT
select 'prompt  Table ' || t.owner||'.'||t.table_name || ' compute statistics' ,
'analyze table ' || t.owner||'.'||t.table_name, 'compute statistics;'
from   dba_tables t, dba_segments s
where  t.owner not in ('SYS','SYSTEM')
and    s.owner not in ('SYS','SYSTEM')
and    t.table_name = s.segment_name
and    t.owner = s.owner
and    s.bytes < 5000000
;
select 'prompt  Table ' || t.owner||'.'||t.table_name || ' compute statistics' ,
 'analyze table '  || t.owner||'.'||t.table_name, 'estimate statistics sample 15 percent;'
from   dba_tables t, dba_segments s
where  t.owner not in ('SYS','SYSTEM')
and    s.owner not in ('SYS','SYSTEM')
and    t.table_name = s.segment_name
and    t.owner = s.owner
and    s.bytes >= 5000000
;
EOF

if [ $INTERACT = 'Y' ];then
   if $SBINS/yesno.sh "to run now" DO Y
      then
       sqlplus -s "$CONNECT_STRING" <<EOF1
               set pause off timing on
               set term on
               set pagesize 0
               set feedback on
               @$FOUT
EOF1
   fi
else
       sqlplus -s "$CONNECT_STRING" <<EOF1
               set pause off timing on
               set term on
               set pagesize 0
               set feedback on
               @$FOUT
EOF1
fi

