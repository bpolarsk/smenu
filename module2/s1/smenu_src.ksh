#!/bin/ksh
# set -xv
# B. Polarski
# 02 May 2006
# modified : 20-Jul-2007 Added support for MV
#                        Added support for trigger
#            08-Jul-2009 Added -st option to list system views view given string
#
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
function help
{
cat <<EOF

   Output the source of an object.

      src <object> -u <OWNER>  -f  -l
      src -syn <SYNONYM>  -u <OWNER>                         # show what is behind a synonym 
      src -st <string>
      src -ext <VIEW>                                        # Extract all sub view text from  view


     -f : the object is a fixed view.  Don't forget to add a \ before the $.
          ie ) src -f GV\\\$SGASTAT
     -l : If the object is a package, list only the procedure. Use dsk <package> if you want to see the parameters also
    -st : search string into fixed views and dba views. Useful to look where x\$ are used, or their columns


   Where object can be any of the type PKG, FUNCTION, PROCEDURE, VIEW, TRIGGER

EOF
exit
}
if [ -z "$1" ];then
   help
fi
typeset -u fowner
typeset -u OBJ_NAME
typeset -u SYN_NAME
while [ -n "$1" ]
do
   case "$1" in
      -h ) help 
           exit ;;
     -syn) ACTION=SYN ; SYN_NAME=$2; shift ;;
      -u ) fowner=`echo $2 | awk '{print toupper($1)}'`; 
           WHERE_OWNER=" where owner='$fowner' " ; 
           AND_OWNER=" and owner='$fowner' " ; 
           AND_A_OWNER=" and a.owner='$fowner' " ; 
           AND_S_OWNER=" and s.owner='$fowner' " ; 
           AND_OWNER2=" and owner=''$fowner'' " ; 
           shift ;;
     -f  ) ACTION=FIXED_VIEW ;;
     -l  ) ACTION=LIST_FUNCT ;;
    -ext ) ACTION=EXTEND_VIEW ; VIEW_NAME=$2 ;shift ;;
    -st  ) ACTION=SEARCH_FV ; V_STRING="$2" ; shift ;;
    -su  ) ACTION=SEARCH_USR ; V_STRING="$2" ; shift ;;
      -v ) set -xv ;;
       * ) OBJ_NAME=$1  ;;
   esac
   shift
done
# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# --------------------------------------------------------------------------
if [ "$ACTION" = "EXTEND_VIEW" ];then
sqlplus -s "$CONNECT_STRING" <<EOF
   set lines 190 long 32000 trimspool on head off
   set long 999999 
   set serveroutput on
declare 
    l_char  VARCHAR2(32767);
    v_view CLOB ; 
    o_view CLOB; 
begin 
      select text into l_char from dba_views where view_name =upper('$VIEW_NAME') $AND_OWNER;
      v_view := RTRIM(l_char);
      DBMS_UTILITY.EXPAND_SQL_TEXT ( v_view ,o_view);
      dbms_output.put_line(o_view); 
end;
/
EOF
exit
# --------------------------------------------------------------------------
elif [ "$ACTION" = "SEARCH_USR" ];then
   echo
   if [ -z "$fowner" ];then
      A_OWNER=' a.owner,' 
      OWNER=' owner,' 
      RPAD_OWNER=" rpad(c.owner,24) || ' '||"
   fi
   LLEN=120
sqlplus -s "$CONNECT_STRING" <<EOF
   set lines 190 long 32000 trimspool on
   set serveroutput on
declare
  pos number ;
  v_text varchar2(32000);
  v_owner varchar2(30);
begin
   v_owner:='$OWNER' ;
   if length ( v_owner ) > 0 then
      dbms_output.put_line(' OWNER                   Type         Name                      What  ');
      dbms_output.put_line('------------------------ ------------ ------------------------- ---------------------------------------------------------');
   else
      dbms_output.put_line('Type        Name                      What  ');
      dbms_output.put_line(' ------------ ------------------------- ---------------------------------------------------------');
   end if;
   for c in (select $A_OWNER initcap (object_type) fobj,
                  0 pos,
                  table_name fname,  
                  a.column_name var,
                  DATA_TYPE ||'(' ||DATA_LENGTH ||')' ftype
             from all_tab_columns a, all_objects  b
                   where  a.owner=b.owner and a.table_name = b.object_name and b.object_type in ('VIEW','TABLE')
                      and column_name = upper('$V_STRING')  $AND_A_OWNER
             union
             select $OWNER initcap(type) fobj, line ,  name  fname, to_char(line) || ': '||replace(trim(substr(text,1,$LLEN)),chr(10),'') var, '' 
                     from  ALL_source where instr(text, '$V_STRING' ) > 0  $AND_OWNER
            )
   
    loop
      if c.fobj = 'View' or c.fobj = 'Table' then
         dbms_output.put_line($RPAD_OWNER  rpad(c.fobj,12)||' '|| rpad(c.fname, 25) ||' '||rpad(c.var,30) ||' '|| rpad(c.ftype,20)  );
      else
         dbms_output.put_line($RPAD_OWNER  rpad(c.fobj,12)||' '|| rpad(c.fname, 25) ||' '||rpad(c.var,$LLEN) ||' '|| rpad(c.ftype,20)  );
      end if;
    end loop;  
end;
/
EOF

exit
# --------------------------------------------------------------------------
elif [ "$ACTION" = "SEARCH_FV" ];then
   echo
   V_STRING_LIKE=`echo "$V_STRING" | awk '{ print "%"toupper($0)"%"}'`

echo $NN "MACHINE $HOST - ORACLE_SID : $ORACLE_SID $NC"
sqlplus -s "$CONNECT_STRING" <<EOF
column nline newline
set pagesize 66  linesize 80  heading off  embedded off pause off  termout on  verify off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER  ,15) || 'Search system views for string ''$V_STRING'' '
from sys.dual
/
set lines 190
set serveroutput on 
declare
  pos number ;
  v_text varchar2(32000);
begin
   dbms_output.put_line('Checking (G)V\$% and DBA_% : Use ''src -f <view>'' to view GV\$ sources and  ''src <view>'' for DBA_%');
   dbms_output.put_line(lpad('Don''t forget to escape \$ : ie) src -f gv\\\$datafile',60)|| chr(10)||chr(10));
   dbms_output.put_line('Pos   View Name                     Position in view Text or column position in view');
   dbms_output.put_line('----- ----------------------------- ----------------------------------------------------------------');
   for c in (select VIEW_NAME,  VIEW_DEFINITION  
                from  v\$fixed_view_definition 
                where view_name in (select view_name 
                                           from v\$fixed_view_definition where substr(view_name,1,2)  != 'GV'
                                     minus
                                     select substr(view_name,2)
                                           from v\$fixed_view_definition where substr(view_name,1,2)  = 'GV' )
             union all
             select view_name,VIEW_DEFINITION
                from v\$fixed_view_definition where substr(view_name,1,2)  = 'GV' )
   loop
       pos:=instr(c.view_definition,'$V_STRING') ;
       if pos != 0 then
           dbms_output.put_line(rpad(to_char(pos),5)||' '||rpad(c.view_name,30)||substr(c.view_definition,greatest(0,pos),80) );
       end if;
   end loop;
   --dbms_output.put_line(chr(10)||'Checking DBA_% views '||chr(10));
   for c in (select view_name,text 
             from dba_views where owner = 'SYS' and view_name  like 'DBA%')
   loop
       v_text:=c.text;
       pos:=instr(v_text,'$V_STRING') ;
       v_text:=regexp_replace(v_text,chr(10),' ');
       if pos != 0 then
           dbms_output.put_line(rpad(to_char(pos),5)||' '||rpad(c.view_name,30)||substr(v_text,greatest(0,pos),80) );
       end if;
       
   end loop;
   for c in (select VIEW_NAME, owner, column_id as pos, data_type, data_length, decode(nullable,'Y','NULLABLE','NOT NULL') nullable
                 from (select  distinct b.owner, b.view_name, a.column_id ,
                           data_type, data_length, nullable
                       from 
                           dba_tab_cols a, 
                           dba_views b 
                       where
                          a.owner = b.owner           and
                          a.table_name = b.view_name  and
                          a.column_name like ('$V_STRING_LIKE') order by b.owner,b.view_name
                  ) 
            )
   loop
         dbms_output.put_line(rpad(to_char(c.pos),5)||' '||rpad(c.view_name,30)|| '  -- '|| c.owner || ' :  ' ||c.nullable|| '  ' || 
                                  c.data_type || ' (' || c.data_length ||')' || ' -- ' );
   end loop;
end;
/
EOF
exit
# --------------------------------------------------------------------------
elif [ "$ACTION" = "LIST_FUNCT" ];then

   sqlplus -s "$CONNECT_STRING"<<EOF

set pagesize 333 linesize 124
select PROCEDURENAME,PROCEDURE#,OVERLOAD# from procedureinfo$ a, obj\$ b where upper(b.name) = '$OBJ_NAME' and a.OBJ# = b.obj# 
   order by PROCEDURE#;
EOF
exit
elif [ "$ACTION" = "FIXED_VIEW" ];then

   sqlplus -s "$CONNECT_STRING"<<EOF
set pagesize 333 linesize 124
select view_definition from v\$fixed_view_definition where VIEW_NAME = '$OBJ_NAME';
EOF
exit
# --------------------------------------------------------------------------
elif [ "$ACTION" = "SYN" ];then

   sqlplus -s "$CONNECT_STRING"<<EOF
col owner format a18
col table_owner format a24
col table_name format a30
col db_link format a30
col SYNONYM_NAME for a30
set linesize 190 pagesize 333
select s.owner, SYNONYM_NAME,
      table_owner , table_name, db_link
          from dba_synonyms s
            where  synonym_name = '$SYN_NAME' $AND_S_OWNER 
/
EOF
exit

fi  # end of if ACTION

# --------------------------------------------------------------------------
# main  of src
# --------------------------------------------------------------------------
VAR=`sqlplus -s "$CONNECT_STRING" <<EOF
set pause off pagesize 0 head off feed off verify off
set lines 400
Column SqlStmnt New_Value SqlStatement noprint
select decode(count(*),1
    , 'object_type from dba_objects where upper(object_name)=''$OBJ_NAME'' and object_type in (''VIEW'',''PACKAGE'',''FUNCTION'',''PROCEDURE'',''TRIGGER'',''MATERIALIZED VIEW'') $AND_OWNER2'
    , 'owner,object_type from dba_objects where  upper(object_name) = ''$OBJ_NAME'' and object_type <> ''TABLE PARTITION'' $AND_OWNER2') SqlStmnt
      from 
        dba_objects 
      where 
        upper(object_name) = '$OBJ_NAME' and object_type in ('VIEW','PACKAGE','FUNCTION','PROCEDURE','TRIGGER','MATERIALIZED VIEW') 
        and object_type <> 'TABLE PARTITION' $AND_OWNER ;
select &SqlStatement ;
EOF`
#echo "|$VAR=|"
var=`echo "$VAR" |sed '/Session/d' |sed 's/MATERIALIZED VIEW/MV/g'| sed '/session/d'| sed '/^$/d'| awk '{print $1}'`
#echo "|$var|"
NBR=`echo "$var" |wc -l`
if [ $NBR -gt 1 ];then
   echo "\n Use src -u <ONWER> $OBJ_NAME  option"
   echo " There are more than one copy of object $OBJ_NAME : "
   echo "$VAR"
   echo 
   echo
   exit
elif [ $NBR -eq 0 ];then
   echo "I did not found any object of name $OBJ_NAME in DB\n"
   exit
fi

OBJ_TYPE=`echo "$var"| sed 's/MATERIALIZED VIEW/MV/g' |sed '/^$/d'|awk '{print $1}'| tr -d '\n'`

#cho "O=$OBJ_TYPE"
echo
echo
# ........................................
# Views
# ........................................
#set -x
if [ "$OBJ_TYPE" = "VIEW" ];then

sqlplus -s "$CONNECT_STRING" <<EOF

set pagesize 0 linesize 32000 termout on pause off embedded on verify off heading off
set long 32000 longchunksize 32000

select distinct '       --> ' ||owner ||  '.' || VIEW_NAME ||  ' : VIEW' FROM   dba_views WHERE  view_name  = '$OBJ_NAME'  $AND_OWNER
/
prompt
SELECT text FROM   dba_views WHERE  view_name  = '$OBJ_NAME' $AND_OWNER
/

EOF
# ........................................
# package, function, procedure
# ........................................
elif [ "$OBJ_TYPE" = "PACKAGE" -o "$OBJ_TYPE" = "FUNCTION" -o  "$OBJ_TYPE" = "PROCEDURE" ];then
sqlplus -s "$CONNECT_STRING" <<EOF

set pagesize 0 linesize 250 termout on pause off embedded on verify off heading off
set head off

select distinct '       --> '||owner||'.'|| name ||  ' : ' || TYPE FROM   dba_source
WHERE  name  = UPPER('$OBJ_NAME') $AND_OWNER
/
prompt
SELECT DECODE(ROWNUM,1,'CREATE OR REPLACE '||text,text)
FROM   dba_source
WHERE  name  = UPPER('$OBJ_NAME') $AND_OWNER
ORDER BY owner, type, line
/

EOF
elif [ "$OBJ_TYPE" = "MV" ];then

sqlplus -s "$CONNECT_STRING" <<EOF

set pagesize 0 linesize 190 termout on pause off embedded on verify off heading off head off
set long 320000 longchunksize 320000
col query format a88
col mname format a35

select distinct '  MATERIALIZED VIEW     --> '||owner||'.'|| mview_name ||  ' : '  FROM  dba_mviews where mview_name = '$OBJ_NAME' $AND_OWNER
/
select query from dba_mviews where mview_name = '$OBJ_NAME' $AND_OWNER
/
EOF
elif [ "$OBJ_TYPE" = "TRIGGER" ];then

sqlplus -s "$CONNECT_STRING" <<EOF

set pagesize 0 linesize 190 termout on pause off embedded on verify off heading off head off
set long 32000 longchunksize 32000
col query format a88
col mname format a35

select distinct '  TRIGGER --> '||owner||'.'|| trigger_name ||  ' : '  FROM  dba_triggers where upper(trigger_name) = '$OBJ_NAME' $AND_OWNER
/
select 'Create or replace  trigger '||
DESCRIPTION   ,
TRIGGER_BODY
 from dba_triggers where upper(TRIGGER_NAME) = '$OBJ_NAME' $AND_OWNER
/
EOF
fi

echo

