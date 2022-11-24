#!/bin/ksh 
# set -x
function help
{
 cat <<EOF

        sqn
        sqn  -cpt -l <Len>      : Count occurence of same type of SQL (not using bind variable
                                  Len is the length of SQL string to scan. Default is 40
        sqn  -l <num>           : to change sql text length to display
        sqn  -u <username>      : limit to user

 Sort options : 
          
                 -t  : text         -b : buffer_gets        -x  : executions      -e : elapsed
                 -c  : cpu          -o : optimizer cost     -d  : disk reads     -dw : direct write

             -hv        : show hash_value
             -v         : verbose
             -r <num>   : limit to <nn> rows       
EOF
}

SILENCE=N
OWNER=
ROWNUM=30
LEN=60
COUNT_LEN=40
METHOD=DEFAULT
typeset -u UPPVAR
VAR_FIELDS="c.buffer_gets, c.buffer_gets/decode(c.executions,0,1,c.executions) xbuffer_gets, users_opening"
VAR_FIELDS1="buffer_gets, buffer_gets/decode(executions,0,1,executions) xbuffer_gets, users_opening"
ORDER=" order by last_active_time desc" 
FTIME=cpu_time
while true
      do
      if [ -z "$1" ];then
         break
      fi
      case $1 in
         -b ) ORDER=" ORDER by buffer_gets desc"  ;;
         -c ) ORDER=" ORDER by cpu_time desc"  ;;
       -cpt ) METHOD=COUNT ;;
        -dw ) ORDER=' ORDER by direct_writes desc' ; 
               VAR_FIELDS="disk_reads,direct_writes,"   ;
                 VAR_FIELDS1="disk_reads,direct_writes,"  ;;
         -d ) ORDER=" ORDER by disk_reads desc"  
                 VAR_FIELDS="disk_reads,disk_reads/decode(executions,0,1,executions) xdisk, direct_writes"   ;
                 VAR_FIELDS1="disk_reads,disk_reads/decode(executions,0,1,executions) xdisk,direct_writes"  ;;
          -e ) ORDER=" ORDER by elapsed_time desc" ; FTIME=elapsed_time ;;
         -hv ) HASH_VALUE=" HASH_VALUE, " ;;
      -l|len ) COUNT_LEN=$2 ; shift ;;
          -o ) ORDER=" and optimizer_cost is not null ORDER by optimizer_cost desc"  ;;
          -t ) ORDER=" ORDER by text "  ;;
          -u ) UPPVAR=$2 ; F_USER=" and parsing_schema_name = upper('$UPPVAR') " ; shift ;;
        -rac ) G=G ;;
          -x ) ORDER=" ORDER by executions desc"  ;;
          -v ) VERBOSE=TRUE;;
         -rn ) ROWNUM=$2 ; shift  ;;
          -h ) help 
               exit ;;
      esac
      shift
done
if [ -n "$HASH_VALUE" ];then
   LEN=`expr $LEN - 9`
fi
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SBINS=$SBIN/scripts

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} 
if [  "x-$CONNECT_STRING" = "x-" ];then
      echo "could no get a the password of $S_USER"
      exit 0
fi

RET=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off feed off pause off
select version from v\\$instance;
EOF
`
VERSION=`echo $RET | awk '{print $1}'| cut -f1 -d'.'`
if [ "$VERSION" = "8" ];then
      FIELD="0"
else
      FIELD="c.$FTIME/1000000"
fi

if [ "$METHOD" = "DEFAULT"  ];then

TITTLE='Display first 60 char of each SQL : $ORDER'
SQL="
set head on pause off feed off linesize 190

col text            FOR a$LEN       HEAD 'SQL Text (first $LEN char)'
col sql_id          head 'Sql id'
col HASH_VALUE      FOR 9999999999  HEAD 'Hash Value'
col executions      FOR 99999999    HEAD 'Exec |Count' justify c
col disk_reads      FOR 99999999    HEAD 'Disks|Reads' justify c
col xdisk           FOR 99999999    HEAD 'Disks|Reads/exec' justify c
col direct_writes   FOR 99999999    HEAD 'Direct|Writes' justify c
col optcost         FOR 99999       HEAD 'Optim|Cost' justify c
col users_opening   FOR 9999        HEAD 'user|open'
col buffer_gets     FOR 999999999   HEAD 'Tot Gets'
col xbuffer_gets    FOR 999999999   HEAD 'Gets/exec'
col cpu_time        FOR 999999      HEAD 'CPU|Time'
col elapsed_time    FOR 999999      HEAD 'Elpase|Time'
col usr             FOR A16         HEAD 'User Name'
col last_active_time FOR A11 head 'Last Active'
set recsep off

select sql_id, usr, executions , trunc($FTIME) $FTIME, $VAR_FIELDS1
          optcost , to_char(LAST_ACTIVE_TIME,'DD/HH24:MI:SS') last_active_time,
         $HASH_VALUE text
     from (
     select
         sql_id,  parsing_schema_name usr,
         c.Executions  , $FIELD $FTIME, $VAR_FIELDS
         ,c.Optimizer_cost optcost , $HASH_VALUE
         substr(c.SQL_text,1,$LEN) text, last_Active_time
      from sys.${G}V_\$SQL c
where
     1=1 $F_USER $ORDER )
     where rownum < $ROWNUM 
/
"
# ------------------------------------------------------------------------------------------
elif  [ "$METHOD"  = "COUNT" ];then

       TITTLE="Count duplicate SQL in v\$sqlarea "
       SQL="
col sql            FOR a$COUNT_LEN       HEAD 'SQL Text (first $COUNT_LEN char)'
        select sql, cpt, exec from (
              SELECT substr(sql_text,1,$COUNT_LEN) sql, count(1) cpt , sum(executions) exec
                    FROM ${G}v\$sqlarea GROUP BY substr(sql_text,1,$COUNT_LEN)
          HAVING count(1) > 5 ORDER BY 2 desc)
        where rownum < $ROWNUM 
/
"
fi

if [ "$VERBOSE" = "TRUE" ];then
   echo "$SQL"
fi

sqlplus -s "$CONNECT_STRING" <<EOF

set linesize 80
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   '    Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66  termout on  embedded off  verify off  heading off pause off
col text  FOR a$COUNT_LEN       HEAD 'SQL Text (first $COUNT_LEN char)'
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       '$TITTLE ' nline
from sys.dual
/   
set head on pause off feed off linesize 190
$SQL
EOF
