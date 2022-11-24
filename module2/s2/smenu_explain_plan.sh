#!/usr/bin/ksh
# -------------------------------------------------------------------------------------
#	Script:		explain7.sql & explain8.sql
#	Author:		Jonathan Lewis
#	Purpose:	q and d to execute explain plan (Oracle 7.3)
#
#	Preparation:
#		Run $ORACLE_HOME/rdbms/admin/utlxplan.sql as SYSTEM
#		Create public synonym plan_table for plan_table
#		Grant all on plan_table to public
#		Create an index (id,parent_id) on plan_table
#
#	Use:
#
#		The script displays the current audit id, then
#		the execution path, simultaneously writing the
#		execution path to a file identified by the audit id.
#
#	Suggestions:
#		Adjust termout on/off to taste
#		Adjust pagesize to taste
#		Adjust linesize to taste
#		set pause on/off to taste
#
# Adapted to Smenu by bpa : 16-08-2000
#
# -------------------------------------------------------------------------------------
SBINS=$SBIN/scripts
WK_SBIN=$SBIN/tmp
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

# -------------------------------------------------------------------------------------
show_help()
{
   cat <<EOF


         Usage : xpl -u <USER> -f <SQL FILE PATH> -h


           Notes

               f : Full path of the file containing the SQL to analyze
               h : This Help
               u : Oracle Schema to run explain plan table in
               s :  silence mode


EOF
}
# -------------------------------------------------------------------------------------
if [ "x-$1" = "x-" ];then
     show_help
     exit
fi
SILENT=N
while getopts u:f:hs ARG
  do
    case $ARG in
      h ) show_help
          exit ;;
      f ) PAR_SQL=$OPTARG ;;
      u ) PAR_USER=$OPTARG ;;
      s ) SILENT=Y ;;
      * ) echo "Invalid option"
  esac
done

if [ ! "x-$PAR_USER" = "x-" ];then
     S_USER=$PAR_USER
else
     echo "   Oracle user to use --> \c"
     read S_USER
fi

if [ ! "x-$PAR_SQL" = "x-" ];then
     SQL=$PAR_SQL
else
     echo "   File Sql --> \c"
     read SQL
fi

VAR=`basename $SQL | sed 's/\.sql//'`
TSQL=$SBIN/tmp/txsql_$VAR.sql
FOUT=$SBIN/tmp/explain_$VAR.txt
> $TSQL

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
export S_USER
EXIST=`$SBINS/smenu_check_exists.sh plan_table`
if [ ! "x-$EXIST" = "x-0" ];then
       echo "Ouch ! There is a problem with plan_table in Schema $S_USER"
       echo " Connect an eventually run @?rdbms/admin/utlxplan"
       exit
fi

cat >>$TSQL <<EOF


set pagesize 66 pause off arraysize 1
set linesize 180
set trimspool on
set verify off


set def =
set def &

column plan		format a160	heading "Plan"
column id	 	format 999	heading "Id"
column parent_id 	format 999	heading "Par"
column position 	format 999	heading "Pos"
column object_instance 	format 999	heading "Ins"

column state_id new_value m_statement_id

select userenv('sessionid') state_id from dual;
set feedback off head off

explain plan 
set statement_id = '&m_statement_id' for
EOF

cat $SQL  |sed -e 's/^\///' -e 's/;//' | sed  '/^[ ]*$/d' >> $TSQL
echo "/" >> $TSQL

    cat >>$TSQL <<EOF

spool $FOUT

select
	id,
	parent_id,
	position,
	object_instance,
	rpad(' ',2*level) ||
	operation || ' ' ||
	decode(optimizer,null,null,
		'(' || lower(optimizer) || ') '
	)  ||
	object_type || ' ' ||
	object_owner || ' ' ||
	object_name || ' ' ||
	decode(options,null,null,'('||lower(options)||') ') ||
	decode(search_columns, null,null,
		'(Columns ' || search_columns || ' '
	)  ||
	other_tag || ' ' ||
	decode(partition_id,null,null,
		'Pt id: ' || partition_id || ' '
	)  ||
	decode(partition_start,null,null,
		'Pt Range: ' || partition_start || ' - ' ||
		partition_stop || ' '
	) ||
	decode(cost,null,null,
		'Cost (' || cost || ',' || cardinality || ',' || bytes || ')'
	)
		plan
from
	plan_table
connect by
	prior id = parent_id and statement_id = '&m_statement_id'
start with
	id = 0 and statement_id = '&m_statement_id'
order by
	id
;

rem	*************************************
rem
rem	Dump remote code, PQ slave code etc.
rem	but only for lines which have some
rem
rem	*************************************

set long 20000

select
	id, object_node, other
from
	plan_table
where
	statement_id = '&m_statement_id'
and	other is not null
order by
	id;


rollback;

spool off

exit

EOF

sqlplus -s "$CONNECT_STRING" @$TSQL

if [ $SILENT = 'N' -a -s $TSQL ];then
  if $SBIN/scripts/yesno.sh "TO view path" DO Y
     then
      vi $FOUT
  fi
fi
