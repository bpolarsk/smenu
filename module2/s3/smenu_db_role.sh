#!/bin/ksh
# set -x
# program: smenu_db_role.sh
# author : Bernard Polarski
#          18 Jun 2009
#
# this script regroup all role/grants utilities

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

# -------------------------------------------------------------------------------------
function object_occurence {
#set -x
var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select trim(to_char(sum(cpt))) cpt from (
select  count(*) cpt from dba_objects where object_name=upper('$fobj') and object_type != 'SYNONYM'
) ;
EOF`
  ret=`echo "$var" | tr -d '\r' | awk '{print $1}'`
  if [ -z "$ret" ];then
     echo "Currently, there is no entry in dba_objects for $fobj"
     exit
  elif [ "$ret" -eq "0" ];then
     echo "Currently, there is no entry in dba_objects for $fobj"
     exit
   elif [ "$ret" -eq "1" ];then
      var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
col owner for a30
select owner from dba_objects where  OBJECT_NAME=upper('$fobj') and object_type != 'SYNONYM' and rownum=1 ;
EOF`
   export fowner=`echo "$var" | tr -d '\r' | awk '{print $1}'`
   elif [ "$ret" -gt "0"  ];then
       if [ -z "$fowner" ];then
         echo " there are many object for $fobj:"
         echo " Use : "
         echo
         echo " rol -tx $fobj -u <owner> "
         echo
         sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 66 head on lines 190
col object_name for a30
col owner for a30
select owner, object_name , OBJECT_TYPE from dba_objects where object_name=upper('$fobj') and object_type !='SYNONYM';
EOF
exit
       fi
   fi
}
# -------------------------------------------------------------------------------------
function table_occurence {
#set -x
var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select trim(to_char(sum(cpt))) cpt from (
select  count(*) cpt from dba_tables where table_name='$ftable' 
union
select  count(*) cpt from dba_views where view_name='$ftable'
) ;
EOF`
  ret=`echo "$var" | tr -d '\r' | awk '{print $1}'`
  if [ -z "$ret" ];then
     echo "Currently, there is no entry in dba_tables for $ftable"
     exit
  elif [ "$ret" -eq "0" ];then
     echo "Currently, there is no entry in dba_tables for $ftable"
     exit
   elif [ "$ret" -eq "1" ];then
      var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select owner from dba_tables where  TABLE_NAME='$ftable' and rownum=1 
union 
select owner from dba_views where  VIEW_NAME='$ftable' and rownum=1 ;
EOF`
     fowner=`echo "$var" | tr -d '\r' | awk '{print $1}'`
     FOWNER="owner = '$fowner' "
     AND_FOWNER=" and  $FOWNER"
   elif [ "$ret" -gt "0"  ];then
       if [ -z "$fowner" ];then
         echo " there are many tables for $ftable:"
         echo " Use : "
         echo
         echo " rol -t $ftable -u <user> "
         echo
         sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 66 head on
select owner, table_name , 'table' from dba_tables where table_name='$ftable' ;
union 
select owner, view_name, 'view'  from dba_views where  VIEW_NAME='$ftable' ;
EOF
exit
       fi
   fi
}
# -------------------------------------------------------------------------------------
if [ -n "$fuser" ];then
   fowner=`echo $fuser | awk '{print toupper($0)}'`
   FOWNER="owner = '$fowner' "
   AND_FOWNER=" and  $FOWNER"
fi
# -------------------------------------------------------------------------------------
function do_execute
{
$SETXV
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline 
set pagesize 66 linesize 100 
set termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER,15)|| '$TITTLE (rol -h : help)' nline
from sys.dual
/
set head on
set linesize 132 pages 65
col roleh   form a30 head '   Role in the Database' 
col Grantee for a30
col role for a30
col table_name for a50
col privilage for a20

$SQL
EOF
}
# -------------------------------------------------------------------------------------
function help
{
 cat <<EOF

                    ------------------------------------------
                     USER, ROLES, SYSTEM GRANTS and OBJECT GRANTS     
                    ------------------------------------------

User:                rol -usr <user> [-sum]        : show all about the user   [ -sum : summary ]
-----

Role:                rol -l                        : role present in DB
-----                rol -u  [<user>]              : role/user distribution   [ restricted to <role> ]
                     rol -r  [<role>]              : user/role distribution   [ restricted to <user> ]

Object grants:       rol -o   [<usr|role>]         : object / user:role   object grants
                     rol -t  <table> [-u owner]    : list user with privilege on this table
                     rol -tx <Object> [-u owner]   : List grants for any object
                     rol -sc <table> [-u owner]    : script accesss privilege on this table
--------------

System grants:       rol -s   [<usr>]              : user   / system Privileges
-------------

Grants:              rol -g <role>                 : System Grants for role
-------              rol -th <user>                : Grants hierarchy for user
                     rol -dir <directory>          : list grants for the directories

Misc:                rol -sp                       : Display users with the SYSDBA or SYSOPR privilge
-----                rol -smap                     : List system privilege map
                     rol -quot                     : List user quota per tablespaces

Generated Scripts:  
------------------
                     rol -cr <user>                : user grants script
                     rol -gr <role>                : role grants script

                     
   
EOF
exit
}
# -------------------------------------------------------------------------------------
#                    Main
# -------------------------------------------------------------------------------------

if [ -z "$1" ];then
    help
fi
typeset -u fuser
typeset -u frole
typeset -u fentity

while [ -n "$1" ]
do
  case "$1" in
      -cr ) CHOICE=SCRIPT ; fuser=$2; shift ;;
     -sum ) SUMMARY=Y ;;
       -g ) CHOICE=LIST_ROLE_GRANT ; frole=$2 ; shift ;;
      -gr ) CHOICE=ROB_CR ; frole=$2 ; shift ;;
       -l ) CHOICE=LIST_ROLE ;;
     -dir ) CHOICE=DIRECTORY;;
       -o ) CHOICE=OBJECT_GRANT ; fentity=$2; shift ;;
       -r ) CHOICE=ROLE_USER ; EXECUTE=YES 
            if [ -n "$2" -a ! "$2" = "-v"  ];then
               frole=$2 ; shift ; 
            fi
            ;;
    -quot ) CHOICE=quota ;;
       -s ) CHOICE=SYSTEM_GRANT_TO_USER 
            if [ -n "$2" -a ! "$2" = "-v" -a ! "$2" = "-u" ];then
               fuser=$2 ; shift ;
            fi ;;
    -smap ) CHOICE=MAP ; EXECUTE=YES ;; 
      -sp ) CHOICE=PF ;;
      -th ) CHOICE=TREE ; fuser=$2 ; shift ;;
       -t ) CHOICE=LIST_ACCESS ; ftable=$2 ; shift ;;
      -sc ) CHOICE=ACCESS_SCRIPT ; ftable=$2 ; shift ;;
       -x ) EXECUTE=YES;;
       -v ) SETXV="set -xv";;
       -u ) if [ -n "$2" -a ! "$2" = "-v" ];then
                  fuser=$2 ; shift 
            fi
            if [ -z "$ACTION" -a -z "$CHOICE"  ];then
               CHOICE=USER_ROLE ; EXECUTE=YES
            fi;;
     -usr ) CHOICE=USER; USR=$2 ; shift ;;
      -tx ) EXECUTE=YES; CHOICE=ANY_OBJ ; fobj=$2; shift ;;
       -h )  help ;;
        * ) echo "Unknown parameter : $1" ; exit ;;
 esac
 shift
done
# ......................................
# 
# ......................................
$SETXV
# ......................................
# 
# ......................................
if [ "$CHOICE" = "ANY_OBJ" ];then
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

   if [ -z "$fuser" ];then
     object_occurence
   else
     fowner=`echo $fuser | awk '{print toupper($0)}'`
   fi
SQL="
set lines 190
col privilege for a12
col foption form a20 head 'Option'
col grantee for a20
col grantor for a20
col object for a40
col ftype for a15 head 'Type'
col owner for a30

SELECT 
       grantor, 
       o.owner || '.'||   o.object_name  object, 
       o.object_type ftype
       ,grantee,
       privilege, 
       decode(grantable, 'YES', 'WITH GRANT OPTION;','-') foption
FROM 
     dba_objects o , dba_tab_privs p
WHERE    o.object_name = upper('$fobj') and o.owner=upper('$fowner')
      and o.owner=p.owner and o.object_name=p.table_name
/
"

# ......................................
elif [ "$CHOICE" = "DIRECTORY" ];then
SQL="
set lines 190 pages 66
col owner for a24
col grantor for a24
col table_name for a25 head 'Directory'
col privilege for a20
select * from dba_Tab_privs where table_name in ( select directory_name from dba_directories) ;
"
# ......................................
# 
# ......................................
elif [ "$CHOICE" = "quota" ];then
   if [ -n "$fuser" ];then
          AND_USER=" and username = upper('$fuser') "
   fi
SQL="
set lines 157
set pages 66
col cur_m for 99999
col curr_m head 'Current|size(m)'
col max_m head 'Quota(m)' format a10
col curr_block head 'Current|blocks' justify c
col max_blocks head 'Max blocks'  for a12
col drp format a3  
break on Schema on report
select  USERNAME Schema, TABLESPACE_NAME, round(BYTES/1048576,1) curr_m,
     case
        when max_bytes = -1 then 'Unlimited'
        else to_char(round(BYTES/1048576,1))
     end  max_m, 
     blocks curr_block, 
     case 
       when max_blocks=-1 then 'Unlimited'
       else to_char(max_blocks)
     end max_blocks, 
     dropped drp
from 
     dba_ts_quotas 
where 
     1=1 $AND_USER
order by USERNAME , TABLESPACE_NAME
/
"
# ......................................
elif [ "$CHOICE" = "ACCESS_SCRIPT" ];then
   if [ -n "$ftable" -a -z "$fuser" ];then
      ftable=`echo $ftable | awk '{print toupper($0)}'`
      . $SBIN/scripts/passwd.env
      . ${GET_PASSWD} $S_USER $ORACLE_SID
      table_occurence
   fi 
if [ -n "$fuser" ];then
   fowner=`echo $fuser | awk '{print toupper($0)}'`
   FOWNER="owner = '$fowner' "
   AND_FOWNER=" and  $FOWNER"
fi
SQL="
  set lines 190 pages 66 head off
 -- grants
 select distinct 'grant ' || rtp.privilege || ' on ' || rtp.owner || '.'|| rtp.table_name|| ' to ' ||  rtp.role || ';' fgrant
from role_tab_privs rtp, dba_role_privs drp
where rtp.role = drp.granted_role
and table_name = '$ftable' $AND_FOWNER
union
select 'grant ' || a.privilege || ' on ' || a.owner || '.'|| a.table_name || ' to ' ||  a.grantee || ';' 
from dba_tab_privs a
where table_name = '$ftable' $AND_FOWNER
order by 1
/
set feed off
prompt -- synonyms
select 
    case OWNER
     when 'PUBLIC' then
        'create public synonym ' || SYNONYM_NAME || ' for ' || TABLE_OWNER ||'.' || TABLE_NAME ||';'
     else 
        'create synonym ' || owner ||'.'||SYNONYM_NAME || ' for ' || TABLE_OWNER ||'.' || TABLE_NAME ||';'
    end fline
  from  DBA_SYNONYMS
 where  table_name = '$ftable' and table_owner = upper('$fowner' )
/
prompt
with v as ( select owner, trigger_name name , 'TRIGGER' type from dba_triggers where table_name = '$ftable' and table_owner = '$fowner' 
            union
            select owner, name, referenced_type type from dba_dependencies 
                    where 
                        referenced_name = '$ftable' and referenced_owner = '$fowner'   and referenced_type in ('PROCEDURE','FUNCTION')
          )
  select 'Alter ' ||
           decode( object_type, 'PACKAGE BODY', 'PACKAGE', 'TYPE BODY', 'TYPE', 'UNDEFINED', 'SNAPSHOT', object_type ) ||
           ' ' || o.owner || '.' ||
           DECODE(object_type,'JAVA CLASS','||dbms_java.longname(object_name)||',object_name) || ' Compile ' ||
           decode( object_type, 'PACKAGE', 'SPECIFICATION', 'PACKAGE BODY', 'BODY', 'TYPE BODY', 'BODY', ' ' ) ||
           ';'
    from dba_objects o , v 
    where -- status='INVALID' and not (object_type = 'SYNONYM' and o.owner = 'PUBLIC') and
              DECODE(UPPER(v.owner),NULL,'x',o.owner) like NVL(UPPER(v.owner),'x')
          and object_name = v.name
          and object_type = v.type
/

"
# ......................................
#  generate script to create role
# ......................................
elif [ "$CHOICE" = "LIST_ACCESS" ];then
# ................................................
if [ -n "$ftable" -a -z "$fuser" ];then
  ftable=`echo $ftable | awk '{print toupper($0)}'`
  . $SBIN/scripts/passwd.env
  . ${GET_PASSWD} $S_USER $ORACLE_SID
  table_occurence
fi 

if [ -n "$fuser" ];then
   fowner=`echo $fuser | awk '{print toupper($0)}'`
   FOWNER="owner = '$fowner' "
   AND_FOWNER=" and  $FOWNER"
fi
SQL="
  set lines 190 pages 66
  select Grantee,'Granted Through Role' as Grant_Type, role, owner||'.'||table_name table_name, privilege, grantable
from role_tab_privs rtp, dba_role_privs drp
where rtp.role = drp.granted_role
and table_name = '$ftable' $AND_FOWNER
union
select Grantee,'Direct Grant' as Grant_type, null as role, owner||'.'||table_name table_name, privilege, grantable
from dba_tab_privs
where table_name = '$ftable' $AND_FOWNER
order by 1, 3,4
/
"
# ......................................
#  generate script to create role
# ......................................
elif [ "$CHOICE" = "USER" ];then
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
   # script by Bill Hoyle : http://freespace.virgin.net/bill.doyle/or1_sysp.htm
   SUMMARY=${SUMMARY:-N}
SQL="
   set serveroutput on size unlimited
   set lines 190 pages 300
declare
  type tt_privs is table of varchar2( 30 ) index by binary_integer;
  lt_privs tt_privs;
  ln_priv_counter number := 0;
  lb_priv_found boolean;

  ls_user varchar2( 30 ) := upper( '$USR' );
  ls_summ_only varchar2( 1 ) := substr( upper( nvl( '$SUMMARY', 'N' ) ), 1,1 );

  cursor c_user_dets is
    select *
     from dba_users
   where username = ls_user;
  lr_user_dets dba_users%rowtype;

  cursor c_role_dets is
    select *
    from dba_roles
    where role = ls_user;
  lr_role_dets dba_roles%rowtype;

  li_counter number := 0;

  ln_level number := 0;

  procedure p_get_role( x_role_name in varchar2 ) is
    ls_role varchar2( 30 );
    cursor c_role_privs( x_role in varchar2 ) is
      select * from dba_role_privs
      where grantee = x_role;

    cursor c_sys_privs( x_role in varchar2 ) is
      select * from dba_sys_privs
      where grantee = x_role;

    ls_role_line varchar2( 1000 );

  begin

    ln_level := ln_level + 1;

    if ls_summ_only <> 'Y' then
      dbms_output.put_line( chr(10) );

      dbms_output.put_line( 'Level : ' || ln_level || ' - System Privileges granted to : ' || x_role_name );
      dbms_output.put_line( rpad( 'Privilege', 30 ) || ' ' ||
                            'Admin Option' );
      dbms_output.put_line( rpad( '---------', 30 ) || ' ' ||
                            '------------' );
    end if;

    for i in c_sys_privs( x_role_name ) loop
      if ls_summ_only <> 'Y' then
        dbms_output.put_line( rpad( i.privilege, 30 ) || ' ' || i.admin_option );
      end if;

      lb_priv_found := false;

      for j in 1..ln_priv_counter loop
        if lt_privs( j ) = i.privilege then
          lb_priv_found := true;
        end if;
      end loop;
      if not lb_priv_found then
        ln_priv_counter := ln_priv_counter + 1;
        lt_privs( ln_priv_counter ) := i.privilege;
      end if;

    end loop;

    if ls_summ_only <> 'Y' then
      dbms_output.put_line( chr(10) );
    end if;

    ls_role_line := 'Level : ' || ln_level || ' - Role granted to : ' || x_role_name;

    for i in c_role_privs( x_role_name ) loop

      if ls_summ_only <> 'Y' then
        dbms_output.put_line( ls_role_line );
        dbms_output.put_line( 'Role : ' || i.granted_role );
        dbms_output.put_line( 'Admin Option : ' || i.admin_option );
        dbms_output.put_line( 'Default : ' || i.default_role );
      end if;

      p_get_role( i.granted_role );

    end loop;

    if ls_summ_only <> 'Y' then
      dbms_output.put_line( '########################## End Level ' || ln_level || ' ####################' || chr(10) );
    end if;

    ln_level := ln_level - 1;


  end;

begin

  -- if suplied user/role id not PUBLIC, confirm it exists
  if ls_user <> 'PUBLIC' then
    open c_user_dets;
    fetch c_user_dets into lr_user_dets;
    close c_user_dets;

    if lr_user_dets.username is null then
      open c_role_dets;
      fetch c_role_dets into lr_role_dets;
      close c_role_dets;
      if lr_role_dets.role is null then
        dbms_output.put_line( 'User/role not found : ' || ls_user );
        return;
      end if;
    end if;
  end if;

  dbms_output.put_line( chr(10) );
  dbms_output.put_line( 'User Details' );
  dbms_output.put_line( '------------' );
  dbms_output.put_line( 'Username      : ' || lr_user_dets.username );
  dbms_output.put_line( 'User Id       : ' || lr_user_dets.user_id);
  dbms_output.put_line( 'Acc Status    : ' || lr_user_dets.account_status);
  dbms_output.put_line( 'Lock Date     : ' || to_char( lr_user_dets.lock_date, 'yyyy/mm/dd hh24:mi' ) );
  dbms_output.put_line( 'Expiry Date   : ' || to_char( lr_user_dets.expiry_date, 'yyyy/mm/dd hh24:mi' ) );
  dbms_output.put_line( 'Def TSpace    : ' || lr_user_dets.default_tablespace);
  dbms_output.put_line( 'Temp TSpace   : ' ||  lr_user_dets.temporary_tablespace);
  dbms_output.put_line( 'Created       : ' || to_char( lr_user_dets.created, 'yyyy/mm/dd hh24:mi' ) );
  dbms_output.put_line( 'Profile       : ' || lr_user_dets.profile);
  dbms_output.put_line( 'Init RSCR grp : ' || lr_user_dets.initial_rsrc_consumer_group);
  dbms_output.put_line( 'Ext Name      : ' || lr_user_dets.external_name);
  dbms_output.put_line( '-----------------------------------------------------------------------------------------' );

  p_get_role( ls_user );

  dbms_output.put_line( '-----------------------------------------------------------------------------------------' );

  dbms_output.put_line( chr(10) || 'Summary of system privileges :' || chr(10) );
  for j in 1..ln_priv_counter loop
    dbms_output.put_line( lt_privs( j ) );
  end loop;

end;
/
"
# ......................................
#  generate script to create role
# ......................................
elif [ "$CHOICE" = "ROB_CR" ];then
   
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
sqlplus -s "$CONNECT_STRING" <<EOF
   set pagesize 333 linesize 132 heading off pause off embedded off verify off feed off trimspool on
spool cr_${fuser}.sql
select 'create role $frole ; ' from dual;
select
    'grant ' || t.privilege || ' on ' ||t.owner||'.' || t.table_name || ' to ' || '$frole' ||
    decode(GRANTABLE,'YES', decode(t.privilege,'EXECUTE',' WITH GRANT OPTION;',' WITH ADMIN OPTION;'),';') admin_option
from
  dba_roles r, dba_tab_privs  t
where
  r.ROLE = t.grantee  and r.ROLE = upper('$frole')
UNION
select  'grant ' || t.privilege || ' to ' || '$frole' || ';'
   from dba_roles r,
        dba_sys_privs t
where
  r.ROLE = t.grantee  and r.ROLE = '$frole' $ADD_AND_GRANTEE
union
 select 'grant ' || granted_role  || ' to ' || grantee || ' ;'  admin_option from dba_role_privs where grantee = upper('$frole')
/
spool off
EOF
exit
# ......................................
#  List System Privilege(s) 
# ......................................
elif [ "$CHOICE" = "SYSTEM_GRANT_TO_USER" ];then
    if [ -z "$fuser" ];then
        unset AND_USER
     else
       AND_USER="and username = upper('$fuser')"
       FSQL="
col a1 head 'System grants obtained from Role' for a60
select
  lpad(' ', 4*level) || granted_role a1
from
  (
    select grantee, granted_role
    from
      dba_role_privs
    union 
    (
    select grantee, privilege from dba_sys_privs where grantee <> '$fuser'
   -- union
   --  select grantee, privilege from dba_tab_privs  where grantee <> '$fuser'
    )
  )
start with grantee = '$fuser'
connect by grantee = prior granted_role ;
"
    fi

    TITTLE="List System Grants"
SQL="
col username form a23 head 'Username'             just l
col grantee form a16 head 'Username'             just l
col dts      form a23 head 'Default|Tablespace'   just c
col tts      form a16 head 'Temporary|Tablespace' just c
col privilege      form a18 head 'Privilege' just c
col fprivilege      form a35 head 'Privilege' just c
col grantable      form a4 head 'Grant'          just c
col prof     form a12 head 'Profile'              just c
col owner     form a16 head 'Owner'              just c
col table_name     form a29 head 'Table'         just c
col column_name     form a16 head 'Column'       just c

break on username  on dts on tts on prof

prompt.          Type:    ros <user>           to limit to one user
prompt
prompt Direct System privileges
select
  username,
  default_tablespace    dts,
  temporary_tablespace  tts,
  PRIVILEGE || decode(admin_option,'YES','-A',' ') fprivilege
from
  dba_users,
  dba_sys_privs
where
  dba_users.username = dba_sys_privs.grantee $AND_USER
order by
  1,2,3,4
/
$FSQL
"
# ......................................
# List user/role object privilege
# ......................................
elif [ "$CHOICE" = "OBJECT_GRANT" ];then
    DO_EXECUTE=YES
    TITTLE="List user/role object privilege"
    SQL="set linesize 155 pagesize 66 verify off feed on pause off 
col user_name   form a22 head 'Username/Role'        just c
col object_type   form a16 head 'Type'                 just c
col table_name    form a30 head 'Object|Name'          just c
col column_name    form a26 head 'Column|Name'          just c
col tab_priv    form a18 head 'Object|Privilege'     just c
col grantable   form a9 head 'Grantable'
col privilege     form a18 head 'privilege'
-- set  timing on
prompt Direct Objects privileges given to $fentity:
         col grantee form a23 head 'Granted user' justify left
         col owner  form a16 head 'Object Owner' justify l
         -- break on object_type on grantee on owner on table_name
         prompt
       -- Both blocks do same thing, but I could not manage to unnest or merge the obj$
       --   Select   o.object_type, 
       --            pp.owner, pp.table_name, pp.column_name, pp.privilege, pp.grantable
       --   from   sys.dba_objects o,
       --         (Select p.grantee, p.owner, p.table_name, null column_name, p.privilege, p.grantable
       --                 from   sys.dba_tab_privs p where p.grantee =  '$fentity'
       --          UNION  
       --          Select p.grantee, p.owner, p.table_name, p.column_name, p.privilege, p.grantable
       --                 from   sys.dba_col_privs p where  p.grantee =  '$fentity'
       --         ) pp
       --   where o.OWNER  = pp.owner and o.object_name = pp.table_name ;

         Select    decode(type#, 0, 'NEXT OBJECT', 1, 'INDEX', 2, 'TABLE', 3, 'CLUSTER',
                      4, 'VIEW', 5, 'SYNONYM', 6, 'SEQUENCE',
                      7, 'PROCEDURE', 8, 'FUNCTION', 9, 'PACKAGE',
                      11, 'PACKAGE BODY', 12, 'TRIGGER',
                      13, 'TYPE', 14, 'TYPE BODY',
                      19, 'TABLE PARTITION', 20, 'INDEX PARTITION', 21, 'LOB',
                      22, 'LIBRARY', 23, 'DIRECTORY', 24, 'QUEUE',
                      28, 'JAVA SOURCE', 29, 'JAVA CLASS', 30, 'JAVA RESOURCE',
                      32, 'INDEXTYPE', 33, 'OPERATOR',
                      34, 'TABLE SUBPARTITION', 35, 'INDEX SUBPARTITION',
                      40, 'LOB PARTITION', 41, 'LOB SUBPARTITION',
                      42, NVL((SELECT distinct 'REWRITE EQUIVALENCE'
                               FROM sys.sum$ s
                               WHERE s.obj#=obj#
                                     and bitand(s.xpflags, 8388608) = 8388608),
                              'MATERIALIZED VIEW'),
                      43, 'DIMENSION',
                      44, 'CONTEXT', 46, 'RULE SET', 47, 'RESOURCE PLAN',
                      48, 'CONSUMER GROUP',
                      51, 'SUBSCRIPTION', 52, 'LOCATION',
                      55, 'XML SCHEMA', 56, 'JAVA DATA',
                      57, 'SECURITY PROFILE', 59, 'RULE',
                      60, 'CAPTURE', 61, 'APPLY',
                      62, 'EVALUATION CONTEXT',
                      66, 'JOB', 67, 'PROGRAM', 68, 'JOB CLASS', 69, 'WINDOW',
                      72, 'WINDOW GROUP', 74, 'SCHEDULE', 79, 'CHAIN',
                      81, 'FILE GROUP',
                     'UNDEFINED') object_type, 
                  owner, table_name, column_name, privilege, grantable
 from(
     select u.name owner, o.name table_name,null column_name,  tpm.name privilege,
            decode(mod(oa.option$,2), 1, 'YES', 'NO') grantable,
            o.type#,o.obj#
     from sys.objauth$ oa, sys.obj$ o, sys.user$ u, sys.user$ ur, sys.user$ ue,
          table_privilege_map tpm
     where oa.obj# = o.obj#
       and oa.grantor# = ur.user#
       and oa.grantee# = ue.user#
       and oa.col# is null
       and oa.privilege# = tpm.privilege
       and u.user# = o.owner#
       and ue.name='$fentity'
     union
     select u.name owner, o.name table_name, c.name column_name, tpm.name privilege,
            decode(mod(oa.option$,2), 1, 'YES', 'NO') grantable,
            o.type#, o.obj#
     from sys.objauth$ oa, sys.obj$ o, sys.user$ u, sys.user$ ur, sys.user$ ue,
          sys.col$ c, table_privilege_map tpm
     where oa.obj# = o.obj#
       and oa.grantor# = ur.user#
       and oa.grantee# = ue.user#
       and oa.obj# = c.obj#
       and oa.col# = c.col#
       and bitand(c.property, 32) = 0 /* not hidden column */
       and oa.col# is not null
       and oa.privilege# = tpm.privilege
       and u.user# = o.owner#
       and ue.name='$fentity'
) order by 3
/

prompt
Prompt Excluded from this list are Object grants from role 'SELECT_CATALOG_ROLE' and 'DBA'
prompt
col a1 head '$fentity''s Object privileges Obtained from Roles' for a80
select
    decode (instr(granted_role,' on '),0, lpad(' ', 4*level) ||granted_role || '  (Role)',
                                            lpad(' ', 4*level) || granted_role
    ) a1
from
  (
    select grantee, granted_role
    from
      dba_role_privs
    union
    select grantee,  rpad(privilege,10) || ' on   ' || owner||'.'||table_name as granted_role
           from dba_tab_privs  where grantee not in ('$fentity','SELECT_CATALOG_ROLE','DBA')
  )
start with grantee = '$fentity'
connect by grantee = prior granted_role
/
"
# ......................................
# List system privilege map 
# ......................................

elif [ "$CHOICE" = "MAP" ];then
   TITTLE="List system privilege map"
   SQL="select * from system_privilege_map;"

# ......................................
# List Role and grants hierarchy for a user
# ......................................
elif [ "$CHOICE" = "TREE" ];then
   TITTLE="List Role and grants hierarchy for a user"
   SQL="col a1 head 'User, his roles and privileges'
select
  lpad(' ', 4*level) || granted_role a1
from
  (
  /* THE USERS */
    select
      null     grantee,
      username granted_role
    from
      dba_users
    where
      username = upper('$fuser')
  /* THE ROLES TO ROLES RELATIONS */
  union
    select
      grantee,
      granted_role
    from
      dba_role_privs
  /* THE ROLES TO PRIVILEGE RELATIONS */
  union (
    select grantee, privilege from dba_sys_privs
    union
    select grantee, privilege from dba_tab_privs )
  )
start with grantee is null
connect by grantee = prior granted_role
/
"
#echo "$SQL"
# ......................................
# Privs for one role
# ......................................
elif [ "$CHOICE" = "LIST_ROLE_GRANT" ];then
   TITTLE="Grant for role $frole"
  SQL=" 
set pages  999
col rp format a80 head 'Object/system and roles privileges'

select ftype || ':    ' || lpad(' ', 4*level) || granted_role|| decode(admin_option,'YES','-A','') rp
    from (
       select 'ROL' ftype, grantee , granted_role , admin_option from dba_role_privs
    union
     select 'SYS' ftype , grantee ,  privilege granted_role , admin_option 
    from
      dba_sys_privs --  where GRANTEE = '$frole'
     union 
    select 'Obj' ftype , grantee,  table_name granted_role , GRANTABLE from dba_tab_privs   where GRANTEE = '$frole'
    )
start with grantee = '$frole'
connect by grantee = prior granted_role
/
"

# ......................................
# Display users with the SYSDBA or SYSOPR privilge
# ......................................
elif [ "$CHOICE" = "PF" ];then
   TITTLE="Display users with the SYSDBA or SYSOPR privilge"
   SQL=" rem COL Violations                FORMAT A170      HEADING 'Violations'
select * from V_\$PWFILE_USERS;
"

# ......................................
#  List role distribution among users
# ......................................
# ......................................
elif [ "$CHOICE" = "ROLE_USER" ];then
  # this query consider only direct role, not sub-hierchical exploration done 
  if [ -n "$frole" ];then
       TITTLE="List user with role $frole"
       AND_ROLE=" and granted_role = '$frole' "
  fi
  TITTLE="List roles / user distribution"
  SQL="set linesize 80 pagesize 0
col role     form a30 head 'Role (admin,grant)'   just c
col username form a22 head 'Username'             just c

break  on role
select
  granted_role role ,
  username ||
  decode(admin_option,'YES','-A',' ') ||
  decode(granted_role,'YES','-G',' ') username
from
  dba_users,
  dba_role_privs
where
    dba_users.username = dba_role_privs.grantee  $AND_ROLE
and username not in ('PUBLIC')
order by
  1,2
/
"
# ......................................
# list existing role in DB 
# ......................................
elif [ "$CHOICE" = "LIST_ROLE" ];then
     TITTLE='List Role(s) in Database'
     SQL="prompt Use rol -g <role> to list grants of role
prompt
col  roleh for a35
col AUTH_TYPE for a20
select '    ' ||ROLE roleh, AUTHENTICATION_TYPE AUTH_TYPE from dba_roles  order by 1;"
# ......................................
# 
# ......................................
elif [ "$CHOICE" = "USER_ROLE" ];then
  if [ -n "$fuser" ];then
     AND_USER=" and username = '$fuser' "
  else
     AND_USER=" and username not in ('PUBLIC')"
  fi
  TITTLE='List User  / ROLE distribution (rol -h : help)'
  SQL="
set linesize 132 pagesize 0
col username form a15 head 'Username'             just c
col dts      form a12 head 'Default|Tablespace'   just c
col tts      form a12 head 'Temporary|Tablespace' just c
col prof     form a14 head 'Profile'              just c
col role     form a27 head 'Role (admin,grant)'   just c
col default_role     form a7 head 'Default|Role'   just c
col ACCOUNT_STATUS     form a17 head 'Account|Status'   just c

break  on username on dts on tts  on prof

select
  username,
  default_tablespace    dts,
  temporary_tablespace  tts,
  profile prof,
  granted_role ||
  decode(admin_option,'YES','-A',' ') ||
  decode(granted_role,'YES','-G',' ') role , default_role, ACCOUNT_STATUS
from
  dba_users,
  dba_role_privs
where 
  dba_users.username = dba_role_privs.grantee  $AND_USER
order by
  1,2,3,4
/
"
# ......................................
# Generate a user creation script 
# ......................................
elif [ "$CHOICE" = "SCRIPT" ];then
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
sqlplus -s "$CONNECT_STRING" <<EOF
set verify on feedback on termout on linesize 200 verify off feedback off pagesize 0
set trimspool on
set head off
spool cr_${fuser}.sql
SELECT 'CREATE USER $fuser IDENTIFIED by values ' ||''''||PASSWORD ||''' default tablespace  '
  || default_tablespace || '  temporary tablespace ' || temporary_tablespace ||';'
  FROM sys.dba_users
 WHERE username = '$fuser'
/
SELECT    'ALTER USER $fuser QUOTA '
       || DECODE (max_bytes, -1, 'Unlimited', max_bytes)
       || ' ON '
       || tablespace_name
       || ';'
  FROM sys.dba_ts_quotas
 WHERE username = '$fuser'
/

SELECT 'GRANT ' || privilege || ' TO $fuser ' || admin_option
  FROM (
   SELECT LOWER(grantee) grantee, LOWER(granted_role) privilege,
           DECODE(admin_option,'YES', decode(granted_role,'EXECUTE',' WITH GRANT OPTION;',' WITH ADMIN OPTION;'),';') admin_option 
     FROM sys.dba_role_privs
     WHERE grantee = '$fuser'
   union
   SELECT LOWER(grantee) grantee, LOWER(privilege) privilege,
           DECODE(admin_option,'YES', decode(privilege,'EXECUTE',' WITH GRANT OPTION;',' WITH ADMIN OPTION;'),';') admin_option 
     FROM dba_sys_privs s
     WHERE grantee  = '$fuser'
   union
   SELECT LOWER(grantee) grantee,
          case privilege
               when 'READ'  then
                     LOWER(privilege) || ' ON DIRECTORY ' || lower(owner) ||'.'||LOWER(table_name)
               when 'WRITE'  then
                     LOWER(privilege) || ' ON DIRECTORY ' || lower(owner) ||'.'||LOWER(table_name)
               else
                     LOWER(privilege) || ' ON ' || lower(owner) ||'.'||LOWER(table_name)
               end privilege,
               DECODE(grantable,'YES',  decode(privilege,'EXECUTE',' WITH GRANT OPTION;',' WITH ADMIN OPTION;'),';') admin_option
           FROM dba_tab_privs t
           WHERE grantee != 'SYS'
             and t.privilege !='EXECUTE'
   union
   SELECT LOWER(grantee) grantee, LOWER(privilege) || ' ON ' ||
         lower(owner) ||'.'||LOWER(table_name) privilege, 
         DECODE(grantable,'YES', decode(privilege,'EXECUTE',' WITH GRANT OPTION;',' WITH ADMIN OPTION;'),';') admin_option
     FROM dba_tab_privs t
     WHERE grantee != 'SYS'
       and t.privilege ='EXECUTE'
   union
   SELECT LOWER(owner) grantee, 'ALL ON ' || LOWER(owner) ||'.'||
         LOWER(table_name) privilege, ';' admin_option
     FROM all_tables
    WHERE owner = upper('$fuser')
   ORDER BY 1
       )
  WHERE grantee = LOWER('$fuser');

SELECT DISTINCT 'CREATE SYNONYM '|| LOWER('$fuser') || '.' || LOWER(SYNONYM_NAME) ||
       ' FOR ' || LOWER(TABLE_OWNER) || '.' || LOWER(TABLE_NAME) || ';'
  FROM SYS.DBA_SYNONYMS
 WHERE owner = upper('$fuser')
 ORDER BY 1
/
SELECT  'CREATE DATABASE LINK ' || l.name ||
   ' CONNECT TO ' || LOWER(l.userid) || ' IDENTIFIED BY ' || LOWER(l.password) ||
   DECODE(l.host,NULL, NULL, ' USING '''||l.host) || ''';'
  FROM     sys.link$ l, sys.user$ u
 WHERE    l.owner# = u.user#
   AND    u.name = UPPER('$fuser')
 ORDER BY l.name
/
spool off

EOF

fi

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
do_execute
