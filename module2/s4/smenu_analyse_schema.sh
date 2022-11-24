#!/usr/bin/ksh
# program smenu_nsiz_schema.sh
# Author : Bernard Polarski : 07/12/99
#set -xv
    #--------------- comments section ---------------------
    # This script is part of the module 3 (DB utilities)
    # in smenu
    # Purpose : Return QUICK info off all index attached to 
    # a table
    # PARAMETERS : $1 table name
    #              $2 generate log in $SBIN/tmp [K or KEEP]
    #--------------- Environement section ---------------------
    #
    SBINS=$SBIN/scripts
    HOST=`hostname`
    #--------------- Test variables section ---------------------
    if [ "x-$1" = "x-" ];then
       echo "I need a User name as argument"
    fi
    OWNER=`echo $1 | tr '[a-z]' '[A-Z]'`
    #--------------- Process section ---------------------
    #--------------- Get system password section ---------------------
    if [ ! "x-$2" = "x-" ];then
       SILENT=Y
    else
       SILENT=N
    fi
    if [ "x-$SILENT" = "x-N" ];then
       . $SBIN/scripts/passwd.env
       . ${GET_PASSWD} 
       if [  "x-$CONNECT_STRING" = "x-" ];then
          echo "could no get a the password of $S_USER"
          exit 0
       fi
    else
      if [ "x-$SILENT" = "x-Y" ];then   # silent mode
         S_USER=$3
         PASSWD=$4
      fi
    fi
    FOUT=$SBIN/tmp/analyse_sch$$.txt
    #--------------- Process section ---------------------
    if [  ! "x-$OWNER" = "x-" ];then
       sqlplus -s "$CONNECT_STRING" <<EOF
set term on
set pagesize 0 
set feedback off
column nl newline

spool $FOUT
select 'prompt Analysing ' || table_name nl ,
       'analyze table '||owner||'.'||table_name||' estimate statistics;'
from dba_tables
where owner = nvl(upper('$OWNER'),owner)
/
EOF
    if [ "x-$SILENT" = "x-Y" ];then   # silent mode
       sqlplus -s "$CONNECT_STRING" <<EOF1
       set term on
       set pagesize 0 
       set feedback off
       @$FOUT
EOF1
       
    else
       cat $FOUT
       if $SBINS/yesno.sh "to process now " DO Y
          then
      sqlplus -s "$CONNECT_STRING" <<EOF1
       set term on
       set pagesize 0
       set feedback on
       @$FOUT
EOF1
       fi
     fi
    else
       echo "Owner $OWNER not found"
       exit
    fi
