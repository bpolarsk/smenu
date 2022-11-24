#!/bin/ksh
# set -x
# B. Polarski
# 27 January 2014
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
TABLE_VIEW=dba_profiles
# --------------------------------------------------------------------------
function help {


     cat <<EOF

       List user settings:
       ========================

          usr -h                            # This help
          usr -l [<USER>]                   # List user info
          usr -cr <USER> [<-all>]           # Generate create user script. -cr -all will do it for all users
          usr -xp <USER>                    # List expired accounts
          usr -lck <USER>                   # List locked  accounts
          usr -rst                          # Reset password

EOF
exit
}
# --------------------------------------------------------------------------
if [ -z "$1" ];then
    echo "\nI need an argument:"
    help
fi
while [ -n "$1" ]
do
  case "$1" in
     -cr ) if [ "$2" = "-all" -o "$2"  = "-ALL" ]; then
             CHOICE=CR_ALL ; shift
           else
             CHOICE=CR_ONE ; fuser=$2 ; shift 
           fi ;;
      -l ) CHOICE=LIST_USR
           if [  -z "$2" ];then
                fuser="-all" 
           else
                fuser=$2
                shift 
           fi ;;
     -xp ) CHOICE=EXPIRED_USR ;;
    -lck ) CHOICE=LOCKED_USR ;;
    -rst ) CHOICE=RESET_USR ; fuser=$2; shift ;;
      -h ) help ;;
      -v ) set -xv ;;
       * ) help ;;
  esac
  shift
done

fuser=`echo $fuser | awk '{print toupper($0)}'`

# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi


# --------------------------------------------------------------------------
if [  "$CHOICE"  = "LIST_USR"  ];then
   if [ "$fuser" = "-all" -o  "$fuser" = "-ALL" ];then
       FUSER=" username"
   else
       FUSER="upper('$fuser')"
   fi
echo $NN "MACHINE $HOST - ORACLE_SID : $ORACLE_SID $NC"
sqlplus -s "$CONNECT_STRING"  <<EOF
set pages 100
column nline newline
set pagesize 66  linesize 120  heading off  embedded off pause off  termout on  verify off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER  ,15) || 'List user $fuser'
from sys.dual
/

set lines 190 head on
col USERNAME for a30 head 'Username' 
col ACCOUNT_STATUS for a23 head 'Status' 
col DEFAULT_TABLESPACE for a20 head 'Default|Tablespace' 
col TEMPORARY_TABLESPACE for a20 head 'Temp|Tablespace' 
col PROFILE for a20 head 'Profile' 
col USER_ID for 99999 head 'Id' justify c
col LOCK_DATE for a22 head 'Lock date' justify c
col EXPIRY_DATE for a22 head 'Expired date' justify c
select USERNAME,USER_ID,ACCOUNT_STATUS, DEFAULT_TABLESPACE, 
       TEMPORARY_TABLESPACE, PROFILE, to_char(LOCK_DATE,'YYYY-MM-DD HH24:MI:SS') LOCK_DATE, 
       to_char(EXPIRY_DATE,'YYYY-MM-DD HH24:MI:SS') EXPIRY_DATE
from dba_users where username = $FUSER order by 1;
EOF
exit
# --------------------------------------------------------------------------
elif [  "$CHOICE"  = "CR_ONE"  -o "$CHOICE"  = "CR_ALL" ];then
  if [ "$CHOICE"  = "CR_ALL" ];then
       PRED=" u.name and u.name  not in ( 'SYS','SYSTEM','SYSAUX','MDSYS','DBSNMP')"
  else
       # one user
       PRED="'$fuser'"
sqlplus -s "$CONNECT_STRING"  <<EOF
set feed off
EXEC DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'PRETTY',TRUE);
EXEC DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',TRUE);
set linesize 1000 pages 0
set long 2000000000
select (case
when ((select count(*)
from dba_users
where username = '$fuser' and profile <> 'DEFAULT') > 0)
then chr(10)||' -- Note: Profile'||(select dbms_metadata.get_ddl('PROFILE', u.profile) AS ddl from dba_users u where u.username = '$fuser')
else to_clob (chr(10)||' -- Note: Default profile, no need to create!')
end ) from dual
/
EOF
  fi
(
sqlplus -s "$CONNECT_STRING"  <<EOF

set feed off verify off trimspool on
set serveroutput on
set lines 1000 trimspool on pages 0
EXEC DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',TRUE);
declare
  v_line  varchar2(4000) ;
  v_link  varchar2(4000) ;
begin
  for u in (  select u.name username, 
                   case
                       when u.spare4 is null  then password
                       else u.spare4||';'||password
                   end password , t1.name DEFAULT_TABLESPACE, t2.name TEMPORARY_TABLESPACE, p.name profile
           from sys.user$ u , sys.ts$ t1, sys.ts$ t2, 
                   sys.profname$ p 
              where u.type#=1 and DATATS#= t1.ts# and TEMPTS# = t2.ts#  and p.PROFILE# = u.resource$
      and u.name = $PRED
   )
  loop
    dbms_output.put_line (chr(10)||'-- '||u.username||' :') ;
    -- create the user
    v_line:='CREATE USER '|| u.username || ' IDENTIFIED by values ''' || u.PASSWORD || ''''||chr(10)||' default tablespace  '
          || u.default_tablespace || '  temporary tablespace ' || u.temporary_tablespace || ' profile ' || u.profile || ';' ;
    dbms_output.put_line(v_line) ;
    ------------
    -- quota
    ------------
    for q in ( select DECODE (max_bytes, -1, 'Unlimited', max_bytes) FQUOT, tablespace_name 
                      from  sys.dba_ts_quotas where username = u.username )
    loop 
       v_line:='ALTER USER '|| u.username || ' QUOTA ' || q.FQUOT || ' ON ' || q.tablespace_name || ';' ;
       dbms_output.put_line(v_line) ;
    end loop ;
    -------------
    -- Privileges
    -------------
    for p in (
               SELECT LOWER(granted_role) privilege,   DECODE(admin_option,'YES', decode(granted_role,'EXECUTE',' WITH GRANT OPTION;',' WITH ADMIN OPTION;'),';') admin_option
                       FROM sys.dba_role_privs WHERE grantee = u.username
               union
               SELECT LOWER(privilege) privilege, DECODE(admin_option,'YES', decode(privilege,'EXECUTE',' WITH GRANT OPTION;',' WITH ADMIN OPTION;'),';') admin_option
               FROM dba_sys_privs s WHERE grantee  = u.username
               union
               SELECT
                      case privilege
                           when 'READ'  then LOWER(privilege) || ' ON DIRECTORY ' || upper(owner) ||'.'||upper(table_name)
                           when 'WRITE' then LOWER(privilege) || ' ON DIRECTORY ' || upper(owner) ||'.'||upper(table_name)
                      else
                           LOWER(privilege) || ' ON ' || owner ||'."'||table_name||'"'
                      end privilege,
                      DECODE(grantable,'YES', decode(privilege,'EXECUTE',' WITH GRANT OPTION;',' WITH ADMIN OPTION;'),';') admin_option
               FROM dba_tab_privs t
               WHERE grantee = u.username and t.privilege !='EXECUTE'
             )
    loop
       v_line:='grant ' || p.privilege || ' to "'|| upper(u.username) || '"'|| p.admin_option ;
       dbms_output.put_line(v_line) ;
    end loop ;
    for x in ( SELECT UPPER(privilege) || ' ON "' || UPPER(owner) ||'".'||UPPER(table_name) privilege,
                      DECODE(grantable,'YES', decode(privilege,'EXECUTE',' WITH GRANT OPTION;',' WITH ADMIN OPTION;'),';') admin_option
               FROM dba_tab_privs t WHERE grantee = u.username and t.privilege ='EXECUTE' )
    loop
       v_line:='grant ' || x.privilege || ' to "'|| UPPER(u.username) || '"' || x.admin_option ;
       dbms_output.put_line(v_line) ;
    end loop ;


    --------------
    -- Default Role
    --------------
    for i in ( select granted_role from  dba_role_privs where grantee  = u.username and default_role = 'YES' )
    loop 
       SELECT DBMS_METADATA.GET_GRANTED_DDL('DEFAULT_ROLE', u.username) into v_line from dual ;
       dbms_output.put_line(v_line ) ;
       exit ;
    end loop ;

    --------------
    -- SYNONYM
    --------------
    for s in ( SELECT DISTINCT  LOWER(SYNONYM_NAME) syn, table_owner, table_name
                      FROM SYS.DBA_SYNONYMS WHERE owner = u.username ORDER BY 1 )
    loop
       v_line:='Create synonym ' || lower(u.username) || '.'|| s.syn || ' for '|| lower(s.table_owner) ||'.'|| s.table_name || ';' ;
       dbms_output.put_line(v_line) ;
    end loop ;
    
    ---------------
    -- dblink
    ---------------
    dbms_metadata.set_transform_param (dbms_metadata.session_transform, 'SQLTERMINATOR', true);
    dbms_metadata.set_transform_param (dbms_metadata.session_transform, 'PRETTY', true);

    for b in ( select db_link from dba_db_links a where a.owner = upper(u.username)  )
    loop
       SELECT DBMS_METADATA.GET_DDL('DB_LINK',b.db_link, u.username)  into v_link FROM dual  ;
       dbms_output.put_line(v_link) ;
    end loop ;

    ---------------
    -- profile
    ---------------
    -- for c in ( select profile from dba_users where  username = u.username and profile <> 'DEFAULT' )
    -- loop 
    --    select dbms_metadata.get_ddl('PROFILE', c.profile)  into v_link  from dual ;
    --    dbms_output.put_line(v_link);
    -- end loop ;

  end loop ;
end ;
/

EOF
) | sed '/^$/d'
  exit
elif [ "$CHOICE"  = "EXPIRED_USR" ];then
(
echo $NN "MACHINE $HOST - ORACLE_SID : $ORACLE_SID $NC"
sqlplus -s -l "$CONNECT_STRING"  <<EOF

column nline newline
set pagesize 66  linesize 80  heading off  embedded off pause off  termout on  verify off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER  ,15) || 'Expired users'
from sys.dual
/

set feed off verify off trimspool on
set lines 167 pages 99
set head on
  col TEMPORARY_TABLESPACE for a20 head 'Temp|Tablespace'
  col PROFILE for a20 head 'Profile'
  col USER_ID for 99999 head 'Id' justify c
  col LOCK_DATE for a22 head 'Lock date' justify c
  col EXPIRY_DATE for a22 head 'Expired date' justify c
 select USERNAME,USER_ID,ACCOUNT_STATUS, DEFAULT_TABLESPACE,
       TEMPORARY_TABLESPACE, PROFILE, to_char(LOCK_DATE,'YYYY-MM-DD HH24:MI:SS') LOCK_DATE,
       to_char(EXPIRY_DATE,'YYYY-MM-DD HH24:MI:SS') EXPIRY_DATE
 from dba_users where ACCOUNT_STATUS in ('EXPIRED(GRACE)') order by 1
/
 disconnect
 exit
EOF
)
elif [ "$CHOICE"  = "LOCKED_USR" ];then
(
echo $NN "MACHINE $HOST - ORACLE_SID : $ORACLE_SID $NC"
sqlplus -s -l "$CONNECT_STRING"  <<EOF
column nline newline
set pagesize 66  linesize 80  heading off  embedded off pause off  termout on  verify off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER  ,15) || 'Locked users'
from sys.dual
/

  set feedback off verify off trimspool on
  set linesize 190 pagesize 66
  set head on
  col DEFAULT_TABLESPACE for a15 head 'Default|Tablespace'
  col TEMPORARY_TABLESPACE for a15 head 'Temp|Tablespace'
  col PROFILE for a20 head 'Profile'
  col USER_ID for 99999 head 'Id' justify c
  col LOCK_DATE for a22 head 'Lock date' justify c
  col EXPIRY_DATE for a22 head 'Expired date' justify c
 select USERNAME,USER_ID,ACCOUNT_STATUS, DEFAULT_TABLESPACE,
       TEMPORARY_TABLESPACE, PROFILE, to_char(LOCK_DATE,'YYYY-MM-DD HH24:MI:SS') LOCK_DATE,
       to_char(EXPIRY_DATE,'YYYY-MM-DD HH24:MI:SS') EXPIRY_DATE
 from dba_users where ACCOUNT_STATUS in ('LOCKED' ,'LOCKED(TIMED)') order by 1
/
 disconnect
 exit
EOF
)
elif [ "$CHOICE"  = "RESET_USR" ];then
(
echo $NN "MACHINE $HOST - ORACLE_SID : $ORACLE_SID $NC"
sqlplus -s -l "$CONNECT_STRING"  <<EOF

column nline newline
set pagesize 66  linesize 80  heading off  embedded off pause off  termout on  verify off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER  ,15) || 'Reset users'
from sys.dual
/

  set feed off verify off trimspool on
  set linesize 1000 pagesize 1000
  col DEFAULT_TABLESPACE for a15 head 'Default|Tablespace'
  col TEMPORARY_TABLESPACE for a15 head 'Temp|Tablespace'
  col PROFILE for a20 head 'Profile'
  col USER_ID for 99999 head 'Id' justify c
  col LOCK_DATE for a22 head 'Lock date' justify c
  col EXPIRY_DATE for a22 head 'Expired date' justify c
with v_user as (
select to_char(sysdate + 50,'Mon') ||'_'|| dbms_random.string('A', 4) ||'_'||to_char(sysdate + 50,'DD')||'_'|| to_char(sysdate + 50,'YYYY') as VPASSWORD,
       '$fuser' as VACCOUNT,
       USERNAME AS VUSERNAME,
       (select global_name from Global_name) as VGLOBAL_NAME,
        to_char(sysdate + 50,'DD') as VDAY,
        to_char(sysdate + 50,'MON') as VMON,
       to_char(sysdate + 50,'YYYY') as VYEAR
from dba_users where 
   -- ACCOUNT_STATUS in ('LOCKED','EXPIRED(GRACE)') and
        uSERNAME='$fuser')
select
chr(10)||chr(10)||'Hi,'||chr(10)||chr(10)||
'Your personal account on the Oracle database $ORACLE_SID (service '||VGLOBAL_NAME||')'||chr(10)||
' has a profile forcing You ('||VUSERNAME||') to a password change every 50 days. '||chr(10)||
'    (The grace period will be started for 10 days, after that point the account will EXPIRE)' ||chr(10)||
'     Once expired, the account is unusable.'||chr(10)||
'You can only change the password once a day '||chr(10)||
' and it must be different from the last 5 passwords. '||chr(10)||chr(10)||
'For Your Info:'||chr(10)||chr(10)||
' Some applications do not show you that your password is about to expire'||chr(10)||
'       and allow you to enter the database during the grace period. '||chr(10)||
'       finally you will get the following message:'||chr(10)||chr(10)||
'      ORA-28001: The password has expired '||chr(10)||chr(10)||
'Your password is case sensitive '||VPASSWORD||chr(10)||chr(10)||
'It will expire on '||VDAY||' '||VMON||' '||VYEAR||'. To change the password in Oracle SQL developer.' ||chr(10)||chr(10)||
'  alter user '||VACCOUNT||' identified by yourNEWPassword replace '||VPASSWORD||' ;' ||chr(10)||chr(10)||
'regards,' ||chr(10)||' The DBA Team' as MAIL ,
chr(10)||'  alter user '||VACCOUNT||' identified by '||VPASSWORD||' account unlock ;' ||chr(10)||chr(10) as CMD from v_user
/
 disconnect
 exit
EOF
)
fi
