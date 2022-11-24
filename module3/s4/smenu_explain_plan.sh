#!/bin/sh
#set -x
# -------------------------------------------------------------------------------------
# contains also :
#	Script:		explain7.sql & explain8.sql
#	Author:		Jonathan Lewis
#	Purpose:	q and d to execute explain plan (Oracle 7.3)
#
# Adapted to Smenu by bpa : 16-08-2000
#
# -------------------------------------------------------------------------------------
NN=
NC=
if echo "\c" | grep c >/dev/null 2>&1; then
    NN='-n'
else
    NC='\c'
fi
SBINS=$SBIN/scripts
WK_SBIN=$SBIN/tmp
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

# -------------------------------------------------------------------------------------
show_help()
{
   cat <<EOF


         Usage : xpl -u <USER> -f <SQL FILE PATH>  
                 xpl -bu <USER> -f <SQL FILE PATH> -m [<BASIC|TYPICAL|SERIAL|ALL>]
                 xpl -bu <USER> -f <SQL FILE PATH> -j


           Notes

               -bu : Connect as SYS and becore Oracle Schema to run explain plan table in
               -f : Full path of the file containing the SQL to analyze
               -h : This Help
               -u : Oracle Schema to run explain plan table in
               -j : Jonathan table plan display mode
               -s :  silence mode
               -m : use DBMS_EXPLAIN, default mode is typcal

Other valid options for -m : 

    * ROWS - if relevant, shows the number of rows estimated by the optimizer
    * BYTES - if relevant, shows the number of bytes estimated by the optimizer
    * COST - if relevant, shows optimizer cost information
    * PARTITION - if relevant, shows partition pruning information
    * PARALLEL - if relevant, shows PX information (distribution method and table queue information)
    * PREDICATE - if relevant, shows the predicate section
    * PROJECTION -if relevant, shows the projection section
    * ALIAS - if relevant, shows the "Query Block Name / Object Alias" section
    * REMOTE - if relevant, shows the information for distributed query (for example, remote from serial distribution and remote SQL)
    * NOTE - if relevant, shows the note section of the explain plan
 
              ie ) xpl -f g.sql -u system -m "BASIC ROWS"

  a minus negate substract the option from the report

                    xpl -f h.sql -u IBS6_EB_OWNER -m "SERIAL -ROWS"

EOF
}
# -------------------------------------------------------------------------------------
if [ -z "$1"  ];then
     show_help
     exit
fi
SILENT=N
typeset -u PAR_USER
while [ -n "$1" ]
  do
    case $1 in
      -h ) show_help
           exit ;;
      -f ) PAR_SQL=$2; shift ;;
      -u ) PAR_USER=$2;shift ;;
      -bu ) PAR_USER=$2;shift 
            BECOME="alter session set current_schema=\"$PAR_USER\";";;
      -s ) SILENT=Y ;;
      -j ) JL_COMP_MODE=TRUE ;;
      -m ) METHOD="DBMS";
           if [ -n "$2" ];then
              MODE=$2; shift
           fi;;
       	
       * ) echo "Invalid option"
  esac
  shift
done


if [ -n "$PAR_USER" ];then
     S_USER=$PAR_USER
else
     echo $NN "   Oracle user to use --> $NC"
     read S_USER
fi

if [ -n "$PAR_SQL" ];then
     SQL=$PAR_SQL
else
     echo $NN "   File Sql --> $NC"
     read SQL
fi

VAR=`basename $SQL | sed 's/\.sql//'`
TSQL=$SBIN/tmp/txsql_$VAR.sql
FOUT=$SBIN/tmp/explain_$VAR.txt
> $TSQL
echo "$BECOME" >> $TSQL

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
export S_USER
VAR=`$SBINS/smenu_check_exists.sh plan_table`
if [ ! $? -eq 0  ];then
       echo "Ouch ! There is a problem with plan_table in Schema $S_USER"
       echo " Connect an eventually run @?rdbms/admin/utlxplan"
       exit
fi


cat >>$TSQL <<EOF


set pagesize 555 pause off arraysize 1 linesize 140 trimspool on verify off

set def =
set def &

column plan		format a120	heading "Plan"
column id	 	format 999	heading "Id"
column parent_id 	format 999	heading "Par"
column position 	format 999	heading "Pos"
column object_instance 	format 999	heading "Ins"

column state_id new_value m_statement_id

select userenv('sessionid') state_id from dual;
set feedback off head on

explain plan 
set statement_id = '&m_statement_id' for
EOF

cat $SQL  |sed -e 's/^\///' -e 's/;//' | sed  '/^[ ]*$/d' >> $TSQL
echo "/" >> $TSQL
# ----------------------------------------------------------------------------
if [ "$JL_COMP_MODE" = "TRUE" ];then
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
	object_owner || '.' ||
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
#-----------------------------------------------------------------------
elif [  "$METHOD" = "DBMS" ];then
    MODE=${MODE:-TYPICAL}
    cat >>$TSQL <<EOF

SELECT * FROM TABLE(dbms_xplan.display('PLAN_TABLE','&m_statement_id','$MODE'));
rollback ;
exit ;
EOF
#-----------------------------------------------------------------------
else # normal mode

    cat >>$TSQL <<EOF

spool $FOUT
COL task_name       FORMAT  A20 heading 'Task'
COL command         FORMAT  A19 heading 'Command'
COL tt              FORMAT  A80   HEADING 'Type'

COL id          FORMAT 999
COL parent_id   FORMAT 999 HEADING "PARENT"
COL operation   FORMAT a35 TRUNCATE
COL object_name FORMAT a30
COL Operation FORMAT a40
COL search_columns FORMAT 9999 head "Search| Cols"

SELECT     id, parent_id, LPAD (' ', LEVEL - 1) || operation || ' ' || options operation, 
           cost ,cardinality,search_columns,$COST object_name
FROM       (
           SELECT id, parent_id, operation, options, cost, cardinality,search_columns, $COST object_name
           FROM   plan_table
           WHERE  statement_id =  '&m_statement_id'
           )
START WITH id = 0
CONNECT BY PRIOR id = parent_id
/
rem	*************************************
rem
rem	Dump remote code, PQ slave code etc.
rem	but only for lines which have some
rem
rem	*************************************

set long 20000

select id, object_node, other from plan_table
where
	statement_id = '&m_statement_id'
and	other is not null
order by id;

rollback;
spool off
exit
/
EOF

fi
sqlplus -s "$CONNECT_STRING" @$TSQL
exit
if [ "$SILENT" = 'N' ];then
  if [  -a -s $TSQL ];then
     if $SBIN/scripts/yesno.sh "TO view path" DO Y
        then
          vi $FOUT
     fi
  fi
fi
