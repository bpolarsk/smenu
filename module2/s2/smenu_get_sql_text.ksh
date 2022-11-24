#!/bin/ksh
# set -xv
SBINS=$SBIN/scripts
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
# Modified : 17 Jun 2009    Added the get_hash_Value function
# ......................................................................................................
function help
{
  cat <<EOF

      Show statment :


           st  <hash_value|sql_id>        # show the sql statement 
           st  <hash_value|sql_id> -f     # Format SQL statement (SELECT only)

           st  -sgen <hash_value|sql_id>  # sql text +  fetch & initialize binds from v\\$sql_bind_capture
           st  -lb <sql_id>               # show bind variable sample (10g)+
             -c <nn>      : child number
             -u <owner>   : parsing sql schema


EOF
exit
}
# ......................................................................................................
function get_min_child
{
 if [ -z "$fowner" ];then
 ret=`sqlplus -s "$CONNECT_STRING" <<EOF
 set head off pagesize 0 feed off verify off
 select min(child_number) from v\\$sql_bind_capture where SQL_ID='$SQL_ID';
EOF`
  else
 ret=`sqlplus -s "$CONNECT_STRING" <<EOF
 set head off pagesize 0 feed off verify off
 select min(a.child_number) 
     from v\\$sql_bind_capture a ,
          v\\$sql b 
    where b.SQL_ID='$SQL_ID'                  and 
          b.parsing_schema_name='$fowner'     and 
          b.sql_id=a.sql_id                  and 
          b.child_number=a.child_number;
EOF`
 fi
 ret=${ret:-0}
 echo "$ret"| awk '{print $1}'
}
# ......................................................................................................
function exists_binds
{
 unset ret
 ret=`sqlplus -s "$CONNECT_STRING" <<EOF
 set head off pagesize 0 feed off verify off
 select count(*) from v\\$sql_bind_capture where sql_id='$SQL_ID';
EOF`
 ret=${ret:-0}
 echo "$ret"| awk '{print $1}'
}
# ......................................................................................................
function get_sql_id
{
 PAR=$1
 if [ -z "${PAR%%*[a-z]*}" ];then
    # $1 is a mix
    echo "$PAR"
    return
 fi
 # $1 is a hash_value made of only digit
 ret=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off pagesize 0 feed off verify off
select distinct sql_id from v\\$sql where hash_value = $PAR;
EOF`
 echo "$ret"| awk '{print $1}'
}
# ......................................................................................................
function get_hash_value
{
 PAR="$1"
 if [ -n "${PAR%%*[a-z]*}" ];then
    # $1 is only digit
    echo "$PAR"
    return
 fi
ret=`sqlplus -s "$CONNECT_STRING" <<EOF
 set head off pagesize 0 feed off verify off
 select trunc(mod(sum((instr('0123456789abcdfghjkmnpqrstuvwxyz',substr(lower(trim('$PAR')),level,1))-1)
        *power(32,length(trim('$PAR'))-level)),power(2,32))) hash_value
     from dual connect by level <= length(trim('$PAR'));
EOF`
 echo "$ret"| awk '{print $1}'
}
# ......................................................................................................
function do_sql
{
if [ -n "$VERBOSE" ];then
   echo "$SQL"
fi
sqlplus -s "$CONNECT_STRING" <<EOF

-- ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
-- column nline newline
-- set pagesize 66 linesize 150 termout on pause off embedded on verify off heading off
-- select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
--        'Username          -  '||rpad(USER,13)  || '  $TITTLE  ' nline
-- from sys.dual
-- /

set head on
$SQL
EOF
}
# ......................................................................................................
#                                Main 
# ......................................................................................................
if [ -z "$1" ];then
   help
fi

while [ -n "$1" ]
do
   case "$1" in
   -c  ) CHILD=$2 ; shift ;;
    -f ) METHOD="TO_FILE" ;;
 -sgen ) METHOD=GEN_SQL_BIND; SQL_ID="$2"; shift ;;
   -lb ) METHOD=BIND; SQL_ID=$2; shift;;
    -v ) VERBOSE=true ;;
    -u ) fowner=$2; shift ;;
    -h ) help ;;
    *  ) HASH_VALUE="$1" ;;
   esac
   shift
done

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
if [ -n "$fowner" ]; then
   fowner=`echo $fowner|awk '{print toupper($1)}'`
fi
HASH_VALUE=${HASH_VALUE:-$SQL_ID}
HASH_VALUE=`get_hash_value ${HASH_VALUE:-$sql_id}`
if [ -z "$HASH_VALUE" ];then
   echo "I need hash_value or sql_id"
   exit
fi
FOUT=$SBIN/tmp/sql_${HASH_VALUE}.sql
# --------------------------------------------------------------------------
# Return the binds associated to a given sql_id
# --------------------------------------------------------------------------

if [ "$METHOD" = "BIND" ];then
  if [ -z "$SQL_ID" ];then
     SQL_ID=`get_sql_id $HASH_VALUE`
  fi
  SQL="col value_string format a40
      col name format A25 head 'Bind name'
      set lines 190 pages 60
      select child_number child,name, position, datatype, 
         decode ( VALUE_STRING, null,
             case DATATYPE
                 when  1   then
                              decode( sys.anydata.GETTYPEname(value_anydata), null, value_string, anydata.AccessVarchar2(value_anydata ) )
                 when  2   then
                              decode( sys.anydata.GETTYPEname(value_anydata), null, value_string, anydata.AccessNumber(value_anydata ) )
                 when  12  then decode( sys.anydata.GETTYPEname(value_anydata), null, value_string,
                                            to_char(anydata.accessdate(value_anydata),'YYYY-MM-DD HH24:MI:SS') )
                 when  96  then
                           decode( sys.anydata.GETTYPEname(value_anydata), null, value_string, anydata.AccessChar(value_anydata ) )
                           -- timestamp
                 when  180 then
                              decode( sys.anydata.GETTYPEname(value_anydata), null,value_string,
                                          to_char(anydata.accessTimestamp(value_anydata),'YYYY-MM-DD HH24:MI:SS') )
                           -- timestampTZ
                 when  181 then
                           decode(  sys.anydata.GETTYPEname(value_anydata), null, value_string,
                                        to_char(anydata.accessTimestampTZ(value_anydata),'YYYY-MM-DD HH24:MI:SS') )
                           -- clob
                 when  112 then
                           decode( sys.anydata.GETTYPEname(value_anydata), null, value_string, anydata.AccessClob(value_anydata ) )
               else
                                   value_string
               end  ,
        value_string ) VALUE_STRING,
             to_char(last_captured,'DD-MM HH24:MI:SS') capture_date
      from v\$sql_bind_capture
      where SQL_ID = '$SQL_ID' order by last_captured desc, child_number,position
/
"
# -------------------------------------------------------------
#  author : B. Polarski 2010 http://www.smenu.org
# -------------------------------------------------------------
elif [ "$METHOD" = "GEN_SQL_BIND" ];then
  SQL_ID=`get_sql_id $SQL_ID`
  if [ -z "$SQL_ID" ];then
       echo "I don't find this SQL_ID into DB"
       exit
   fi
  ret=`exists_binds $SQL_ID`
  if [ $ret -eq 0 ]; then
      echo "This query has no binds"
      exit
  fi
  if [ -z "$CHILD" ];then
     CHILD=`get_min_child $SQL_ID`
  fi
SQL="

    set lines 32000 head off trimspool off pages 0
    break on fdate on report
   set trimspool on
    prompt
    prompt  Warning : This query does not support mix of system generated named binds and user named binds within same query
    prompt            binds Timestamp are transformed into date type, affect index and partition pruning and loose their 'FFFFFF' 
    prompt
select line from (
     select  decode(position, 1,  
                                  '-------------------------------------' ||chr(10) ||
                                  '-- Date :'||to_char(LAST_CAPTURED,'YYYY-MM-DD HH24:MI:SS')||chr(10)  ||
                                  '-------------------------------------' ||chr(10)|| chr(10)
                                  || '-- alter session set NLS_DATE_FORMAT=''YYYY-MM-DD HH24:MI:SS'' ;' || chr(10)
                                  || 'alter session set statistics_level=''ALL'' ;' || chr(10)
                               --   || 'alter session set NLS_TIMESTAMP_FORMAT=''YYYY-MM-DD HH24:MI:SS.FFFFFF'' ;' || chr(10)
                              , chr(10) 
             )||
            'variable ' ||
                   substr(regexp_replace(name,':[[:digit:]][[:digit:]]*', ':a'||position),2)
              || ' '
            || case DATATYPE
                       -- varchar2
                 when  1   then 'varchar2(4000) ;' || chr(10) || 'Exec :'||
                   substr(regexp_replace(name,':[[:digit:]][[:digit:]]*', ':a'||position),2)
                                 || ':='''||  value_string || ''';'
                          -- number
                 when  2   then 'number ;'         || chr(10) || 'exec :'||
                   substr(regexp_replace(name,':[[:digit:]][[:digit:]]*', ':a'||position),2)
                                 || ':='  ||  value_string || ';'
                          -- date
                 when  12  then 'varchar2(30) ;'   || chr(10) || 'exec :'||
                   substr(regexp_replace(name,':[[:digit:]][[:digit:]]*', ':a'||position),2)
                                        || ':='''||
                                        decode( sys.anydata.GETTYPEname(value_anydata), null, value_string,
                                                to_char(anydata.accessdate(value_anydata),'YYYY-MM-DD HH24:MI:SS') )  || ''';'
                           -- char
                 when  96  then 'char(3072) ;'     || chr(10) || 'exec :'||
                   substr(regexp_replace(name,':[[:digit:]][[:digit:]]*', ':a'||position),2)
                                 || ':='''||  value_string || ''';'
                           -- timestamp
                 when  180 then 'varchar2(26) ;'   || chr(10) || 'exec :'||
                   substr(regexp_replace(name,':[[:digit:]][[:digit:]]*', ':a'||position),2)
                                         || ':='''||
                                         decode( sys.anydata.GETTYPEname(value_anydata), null,value_string,
                                                 to_char(anydata.accessTimestamp(value_anydata),'YYYY-MM-DD HH24:MI:SS') ) || ''';'
                                         ||chr(10)||'-- Warning: implicit timestamp to date conversion: the bind was a timesstamp'
                                                 --to_char(anydata.accessTimestamp(value_anydata),'YYYY-MM-DD HH24:MI:SS.FFFFFF') ) || ''';'
                           -- timestampTZ
                 when  181 then 'varchar2(26) ;'   || chr(10) || 'exec :'||
                   substr(regexp_replace(name,':[[:digit:]][[:digit:]]*', ':a'||position),2)
                                          || ':='''||
                                         decode(  sys.anydata.GETTYPEname(value_anydata), null, value_string,
                                                 to_char(anydata.accessTimestampTZ(value_anydata),'YYYY-MM-DD HH24:MI:SS') ) || ''';'
                                        ||chr(10)||'-- Warning: implicit timestamp to date conversion: the bind was a timesstamp'
                 when  112 then 'CLOB ;'            || chr(10) || 'exec :'||
                   substr(regexp_replace(name,':[[:digit:]][[:digit:]]*', ':a'||position),2)
                                           || ':='''||  value_string || ''';'
               else
                               'Varchar2(4000) ;'  || chr(10) || 'exec :'||
                   substr(regexp_replace(name,':[[:digit:]][[:digit:]]*', ':a'||position),2)
                                 || ':='''||  value_string || ''';'
               end line
     from v\$sql_bind_capture where sql_id = '$SQL_ID'  and child_number = '$CHILD'
order by last_captured,child_number,position )
union all
select  regexp_replace(line,':([[:digit:]][[:digit:]]*)',':a\1')||chr(10)  ||'/' line from (
select  regexp_replace(
          max(sys_connect_by_path (sql_text,'{') ),
          '{','') line
from (
select
        piece,   sql_text
  from v\$sqltext_with_newlines where  sql_id='$SQL_ID'
order by 1
)
start with piece=0
connect by  piece  = prior piece + 1
)
/
    prompt
"
# -------------------------------------------------------------
elif [ "$METHOD" = "TO_FILE" ];then
   F_USER=`sqlplus -s "$CONNECT_STRING" <<EOF
set linesize 64 pagesize 0 head off feed off
select username from v\\$sql ,dba_users where
       hash_value='$HASH_VALUE' and parsing_user_id = user_id and rownum = 1;
EOF`
#  PASS=`grep "$ORACLE_SID:$F_USER:" $SBINS/.passwd | cut -f3 -f:` 2>/dev/null
  echo "rem F_USER=$F_USER"
  SQL=`sqlplus -s "$CONNECT_STRING" <<EOF
set linesize 32767 pagesize 0 head off feed off
break on sql_text
select  regexp_replace(
          max(sys_connect_by_path (sql_text,'{') ),
          '{','') sql_text
from (
select
        piece,   sql_text
from v\\$sqltext_with_newlines where  HASH_VALUE=$HASH_VALUE
order by 1
)
start with piece=0
connect by  piece  = prior piece + 1
/
EOF`
VAR="`echo $SQL | tr -d '\n'| tr -d '\r'`"
echo "$VAR" | sed -e 's@|@@' -e 's@\(.*\)|$@\1@' -e 's@| |@@g'  -e 's/[^a-zA-Z0-0_][wW][hH][eE][rR][eE][^a-zA-Z0-0_]/\
WHERE \
         /g' -e 's/[^a-zA-Z0-0_]*[sS][eE][lL][eE][cC][tT][^a-zA-Z0-0_]/\
SELECT \
     /g' -e 's/[^a-zA-Z0-0_][fF][rR][oO][mM][^a-zA-Z0-0_]/\
FROM \
    /g'   -e 's/ [aA][nN][dD] /\
     AND /g' -e    's/ [oO][rR][dD][eE][rR] [bB][yY] /\
ORDER BY /g'  -e    's/ [gG][rR][oO][uU][pP] [bB][yY] /\
GROUP BY /g' -e    's/[sS][eE][tT][^a-zA-Z0-0_]/\
SET    /g' -e 's/[^a-zA-Z0-0_][cC][aA][sS][Ee][^a-zA-Z0-0_]/\
      CASE   /g'   -e 's/[^a-zA-Z0-0_][wW][hH][eE][nN][^a-zA-Z0-0_]/\
          WHEN /g' -e  's/,\([^,][^,]*\),\([^,][^,]*\),\([^,][^,]*\),/,\1,\2,\3,\
    /g' > $FOUT
echo "File : $FOUT"

echo "$VAR" | sed -e 's@|@@' -e 's@\(.*\)|$@\1@' -e 's@| |@@g'  -e 's/[^a-zA-Z0-0_][wW][hH][eE][rR][eE][^a-zA-Z0-0_]/\
WHERE \
         /g' -e 's/[^a-zA-Z0-0_]*[sS][eE][lL][eE][cC][tT][^a-zA-Z0-0_]/\
SELECT \
     /g' -e 's/[^a-zA-Z0-0_][fF][rR][oO][mM][^a-zA-Z0-0_]/\
FROM \
    /g'   -e 's/ [aA][nN][dD] /\
     AND /g' -e    's/ [oO][rR][dD][eE][rR] [bB][yY] /\
ORDER BY /g'  -e    's/ [gG][rR][oO][uU][pP] [bB][yY] /\
GROUP BY /g' -e    's/[sS][eE][tT][^a-zA-Z0-0_]/\
SET    /g' -e 's/[^a-zA-Z0-0_][cC][aA][sS][Ee][^a-zA-Z0-0_]/\
      CASE   /g'   -e 's/[^a-zA-Z0-0_][wW][hH][eE][nN][^a-zA-Z0-0_]/\
          WHEN /g' -e  's/,\([^,][^,]*\),\([^,][^,]*\),\([^,][^,]*\),/,\1,\2,\3,\
    /g'


# -------------------------------------------------------------
elif [ -n "$SQL_ID" ];then


TITTLE='get sql text'
SQL="
set heading on
set linesize 132 pagesize 0
col HASH_VALUE format 999999999
col sql_text format A4000
break on sql_text

prompt
prompt .    Type      sq -hv $HASH_VALUE  to see stats on this sql
prompt
select  regexp_replace(
          max(sys_connect_by_path (sql_text,'{') ),
          '{','') sql_text
from (
select
        piece,   sql_text
  from v\$sqltext_with_newlines where  sql_id='$sql_id'
order by 1
)
start with piece=0
connect by  piece  = prior piece + 1
/
select sid from v\$session where sql_id = '$SQL_ID' or prev_sql_id = '$SQL_ID'
/
"
# -------------------------------------------------------------
else
TITTLE='get sql text'

         SQL=" set long 32767 pages 0 lines 3200 trimspool on
col sql_fulltext format a32767
  select sql_fulltext from v\$sql where HASH_VALUE=$HASH_VALUE and child_number=(
   select min(child_number)  from v\$sql where HASH_VALUE=$HASH_VALUE) 
/
"
 SQL="$SQL
set feed off head on
select sid sid_running_this_query from v\$session where sql_hash_value = $HASH_VALUE 
union
select sid sid_running_this_query from v\$session where prev_hash_value = $HASH_VALUE ;
"
fi

# ................................
# we do the job here
# ................................
do_sql

