#!/bin/ksh
# set -xv
# B. Polarski
# 06 June 2005
WK_SBIN=$SBIN/module2/s3
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

# -------------------------------------------------------------------------------------
function help
{
   cat <<EOF

     Auditing suppose that init.ora parameter 'audit_trail'=TRUE or there is no rows kept

    Command : 

         aud -a -p -o -m -u <USER> -prm
         aud -f -t <tbl> -u <user>
         aud -rt [-tz 11] [-tm |-ti | -th ] -t <tbl> -u <user>  
         aud -rt -at AUD_ARCH -part <partname> [-days 1]

              -at : later AUD table : -at AUD_ARCH, case you transfer to an audit archive
               -a : List Active Statement Audit Options
               -p : List Active Privilege Audit Options
               -o : List Active Objects Audit Options
               -m : List last connection for user
             -prm : List audit related parameters
              -rt : Break down AUD per return code/objects
                    -tz  : single out one hour of the day to look at (values  are 01-23)
                    -obj : table so report on
                    -tm  : list per 1 minutes
                    -ti  : list per 10 minutes
                    -th  : list per 60 minutes
                    -td  : list per day

         aud -lp  : List policy rules from fga$
         aud -ll  : audit last statement inserted into fga_log$
         aud -f -t <OJBECT_NAME> [-u <OWNER>]  : Get the policy name from a given object
         aud -ll -n <OBJECT_NAME> [-u <OWNER>] : restrict search  to given arguments
         aud -at <TNAME>   : audit records in this table, optionally partionned (pref ntimestamp#)
         aud -ac <action#> : 100=login only, 101=logout, 102=disconnect idle etc..
         aud -c <returncode> : limit selection to return code
         aud -lss            : list statistcs usages at logoff
       
       Examples:  list audit from table system.aud_arch partition PM2019_03_06 only for login (code=100)       
         aud -rt -at system.aud_arch -th -part PM2019_03_06  -ac 100
         aud -ls -rn <nn> [-c <code>] : list last  nn entries in AUD\$, restrict to return <code>

            List failed login attempt :

           aud -ls -c 1017

         -v   : verbose         
EOF
}
# -------------------------------------------------------------------------------------
function do_execute
{
$SETXV
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER ||  '      $TTITLE (aud -h for help)' nline
from sys.dual
/
set head on
COL user_name           FORMAT A25      HEADING 'User audited'
COL username           FORMAT A30      HEADING 'User'
COL audit_option        FORMAT A50      HEADING 'Auditing action'
$BREAK
set linesize 125
prompt
$SQL
EOF
}
# -------------------------------------------------------------------------------------
#                    Main
# -------------------------------------------------------------------------------------

if [ -z "$1" ];then
   help
fi
typeset -u PAR2
typeset -u FOBJECT
ROWNUM=50
FAUD='sys.aud$'
while [ -n "$1" ]
do
  case "$1" in
       -a ) ACTION=AUDIT_ST ; EXECUTE=YES ; TTITLE="List Audit Statement in DB" ;;
      -at ) FAUD=$2 ; shift ;;
   -part  ) PARTNAME=$2 ; shift ;;
       -f ) ACTION=GET_FGA_NAME ; EXECUTE=YES ;;
    -days ) DAYS=$2; shift ;;
      -lp ) ACTION=LIST_FGA_POLICY ; OBJ=$2 ; EXECUTE=YES ;;
      -ls ) ACTION=LIST_LAST_AUD_ROWS ; EXECUTE=YES ;;
      -ll ) ACTION=LIST_LAST_FGA_LOG ; EXECUTE=YES ;;
     -lss ) ACTION=LSS ; EXECUTE=YES ; TITTLE="List statistics usage" ;;
       -t ) FOBJECT=$2 ; shift ;;
       -m ) ACTION=LIST_CONNECT ; EXECUTE=YES ; TITTLE="List last logong for $2"  ;;
       -o ) ACTION=OBJECT ; EXECUTE=YES ; TTITLE="List active object Audit in DB" ;;
       -p ) ACTION=PRIVS ; EXECUTE=YES ; TTITLE="List Audit Privilege in DB" ;;
     -prm ) ACTION=PRM ; EXECUTE=YES ; TITTLE="List audit specific parameters" ;;
      -rt ) ACTION=RT ;  EXECUTE=YES ; TITTLE="Break down return code (use: oerr ORA <code>)" ;;
       -u ) PAR2=$2
            A_USER=" and a.username = '$PAR2'" ; U_USER=" and u.username = '$PAR2'" 
            FV_USER=" and username = '$PAR2'"; 
            FP_USER=" and USERID = '$PAR2'"; 
            F_USER=" and user_name = '$PAR2'"; shift ;;
       -v ) SETXV="set -xv"; set -x;;
       -x ) EXECUTE=YES;;
      -tz ) ONE_HOUR=$2; shift ;;
      -ti ) MINUTES10=TRUE;;
      -tm ) MINUTES=TRUE;;
      -th ) HOUR=TRUE;;
       -c ) RET_CODE=$2; shift ;;
      -ac ) ACTION_CODE=$2; shift ;;
       -h ) help ;;
      -rn ) ROWNUM=$2 ; shift ;; 
        * ) echo "What is $1 ? "; help ;;
  esac
  shift
done

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of SYS"
   exit 0
fi
# ...............................................................................................
# List statistics usage on logoff
# ...............................................................................................
if [ "$ACTION" = "LSS" ];then
#FAUD=DBA_AUDIT_TRAIL
FAUD=${FAUD:-DBA_AUDIT_TRAIL}
#AND_USER_LIKE=" and ( USERNAME like 'P%' or USERNAME='THALER_RO')"
AND_USER_LIKE=" and ( USERID like 'P%' or USERID='THALER_RO')"
if [ "$P_ORD" = "r" ];then
   ORDER="order by LOGOFF\$PREAD "
else
   ORDER="order by timestamp# desc "
fi
SQL="
col LOGOFF_LREAD for 99999999999 head 'Logical|Reads' Justify c
col LOGOFF_PREAD for 99999999999 head 'Physical|Reads' Justify c
col LOGOFF_LWRITE for 99999999999 head 'Logical|Write' Justify c
col SESSION_CPU for 99999999999 head 'Sesion|CPU' Justify c
col USERNAME for a22 head 'User Name'
col flogin for a20 head 'Login time'
col flogoff for a20 head 'Logoff' 
col userhost for a20
col os_username for a20
col userid for a30

set line 200 pages 66
compute sum of LOGOFF_PREAD  on report
break on report
select * from (
select 
    userid, act.name, userhost,spare1 os_username,
    to_char(timestamp#,'YYYY-MM-DD HH24:MI:SS') flogin, to_char(LOGOFF\$TIME,'YYYY-MM-DD HH24:MI:SS') flogoff,
    LOGOFF\$LREAD, LOGOFF\$PREAD, LOGOFF\$LWRITE, SESSIONCPU
from sys.aud\$ , audit_actions act
 where  action#     = act.action    (+)
    and LOGOFF\$LREAD>0  and ( USERID like 'P%' or USERID='THALER_RO')
   order by flogin desc
)
 where rownum <= $ROWNUM 
/
"

# ...............................................................................................
# Retrieve the name of policy rules for given object name
# ...............................................................................................
# ALTER, AUDIT, COMMENT, DELETE, GRANT, INDEX, INSERT, LOCK, RENAME, SELECT, UPDATE, REFERENCES, and EXECUTE
# ...............................................................................................
elif [ "$ACTION" = "RT" ];then

A=$MINUTES
if [ ! -z "$RET_CODE" ];then
    AND_RT_CODE=" and returncode = $RET_CODE "
fi
if [ ! -z "$ACTION_CODE" ];then
    AND_ACTION_CODE=" and action# = $ACTION_CODE "
fi
A1=$MINUTES
if [ ! -z "$ONE_HOUR" ];then
    AND_HOUR=" and to_char(NTIMESTAMP# ,'HH24') = '$ONE_HOUR' and to_Char(NTIMESTAMP#,'YYYY-MM-DD') = to_char(sysdate $DAYS ,'YYYY-MM-DD')"
    C_HOUR=",to_char(NTIMESTAMP#,'YYYY-MM-DD HH24') ltime "
    C_HOUR0=",to_char(NTIMESTAMP#,'YYYY-MM-DD HH24') "
    LTIME=", ltime"
    ORDER_LTIME=" ltime ,"
fi
if [  "$MINUTES" = "TRUE" ];then
    C_HOUR=",substr(to_char(NTIMESTAMP#,'YYYY-MM-DD HH24:MI'),1,16) ltime" 
    C_HOUR0=",substr(to_char(NTIMESTAMP#,'YYYY-MM-DD HH24:MI'),1,16)"
    LTIME=", ltime"
    ORDER_LTIME=" ltime ,"
elif [ ! -z "$MINUTES10" ];then
    C_HOUR=",substr(to_char(NTIMESTAMP#,'YYYY-MM-DD HH24:MI'),1,15)||'0' ltime" 
    C_HOUR0=",substr(to_char(NTIMESTAMP#,'YYYY-MM-DD HH24:MI'),1,15)||'0'"
    LTIME=", ltime"
    ORDER_LTIME=" ltime ,"
elif [ ! -z "$HOUR" ];then
    C_HOUR=",substr(to_char(NTIMESTAMP#,'YYYY-MM-DD HH24:MI'),1,13) ltime" 
    C_HOUR0=",substr(to_char(NTIMESTAMP#,'YYYY-MM-DD HH24:MI'),1,13)"
    LTIME=", ltime"
    ORDER_LTIME=" ltime ,"
fi
if [ -n "$FOBJECT" ] ;then
   AND_TABLE=" and OBJ\$NAME = upper('$FOBJECT') " 
   AUTH0=',PRIV$USED  '
   AUTH1=',PRIV$USED  authp '
   AUTH2=',authp '
fi
if [ -n "$PAR2" ] ;then
   AND_OWNER=" and OBJ\$CREATOR = upper('$PAR2') "
fi
if [ -n "$PARTNAME" ];then
   PART=" partition ($PARTNAME) "
fi
SQL="
set lines 190 pages 66
col fname for a40 head 'Object'
col fsa  Head 'Action' for a20
col returncode head 'Error|code' for 99999
col userid head 'Running user' for a20
col os_user for a20
select spare1 as os_user, userid, owner||'.'||a.name fname $AUTH2, 
           action#, RETURNCODE, cpt count,
           case 
                when  instr(sa,'F') > 0 then  
                                              case 
                                                 when instr(sa,'F') = 4 then 'delete'
                                                 when instr(sa,'F') = 6 then 'index'
                                                 when instr(sa,'F') = 7 then 'insert'
                                                 when instr(sa,'F') = 8 then 'lock'
                                                 when instr(sa,'F') = 10 then 'sel for update'
                                                 when instr(sa,'F') = 11 then 'update'
                                                 else to_char(instr(sa,'F'))
                                              end 
                when  instr(sa,'S') >0  then  'S=' || to_char( instr(sa,'S'))
            else sa
            end fsa $LTIME
   from (
          select /*+ parallel(a,4) */ 
                  count(*)cpt, spare1, obj\$name name $AUTH1 ,obj\$creator owner, userid, action# ,RETURNCODE $C_HOUR , SES\$ACTIONS sa
          from $FAUD $PART
          where 1=1 $AND_HOUR  $AND_OWNER $AND_TABLE $AND_RT_CODE $AND_ACTION_CODE
                -- action# not in (100,101) 
          group by obj\$name $AUTH0,obj\$creator, spare1,userid , action#, SES\$ACTIONS 
                   $C_HOUR0, RETURNCODE,  SES\$ACTIONS 
          order by  cpt desc 
          )a , 
           sys.audit_actions b 
where action# = b.action
and rownum < $ROWNUM
order by $ORDER_LTIME count desc
/
"
# ...............................................................................................
# Retrieve the name of policy rules for given object name
# ...............................................................................................
elif [ "$ACTION" = "LIST_LAST_AUD_ROWS" ];then
if [ ! -z $RET_CODE ];then
   WHERE_CODE=" and returncode = $RET_CODE $FP_USER "
elif [ ! -z $FP_USER ];then
   WHERE_CODE="   $FP_USER "
fi

 if [ -n "$PARTNAME" ];then
    FAUD="$FAUD partition($PARTNAME) "
fi
SQL="
prompt for code 1017 - failed loging attempt - 'audit create session whenever not successful;'
prompt
set lines 210 pages 900
col OS_USERNAME for a30
col USERHOST for a30
col TERMINAL for a20
col Lo_reads for 99999999999
col Lo_write for 99999999999
col phys_read for 99999999999
select * from (
select spare1 as os_username, to_char( NTIMESTAMP#,'YYYY-MM:DD HH24:MI:SS') LTIME, userid USERNAME, USERHOST
     , RETURNCODE, SESSIONID, act.name action_name,  LOGOFF\$PREAD phys_read, logoff\$lread Lo_reads, logoff\$lwrite lo_write
from $FAUD  , audit_actions act
where   action#     = act.action    (+)
 $WHERE_CODE order by  NTIMESTAMP# desc )
where rownum <= $ROWNUM ;
"
#exit
# ...............................................................................................
# Retrieve the name of policy rules for given object name
# ...............................................................................................
elif [ "$ACTION" = "PRM" ];then

SQL="
COL name                FORMAT A20      HEADING 'Parameter'
COL value               FORMAT A40      HEADING 'Value'
COL description         FORMAT A50      HEADING 'Description'
select name, value, description from v\$parameter where name like '%audit%' ;
"
# ...............................................................................................
# Retrieve the name of policy rules for given object name
# ...............................................................................................
elif [ "$ACTION" = "GET_FGA_NAME" ];then
   TTITLE="Get  data from fga_log\$"
   FOBJECT=${FOBJECT:-%}
   SQL="prompt Wlidcard accepted (%) : aud -t TBL%
prompt
set lines 190
col object_schema for a18 head 'Owner'
col pname for a20 head 'Policy name'
col POLICY_TEXT for a55 head 'Policy check text' truncate
col object_name for a18

select OBJECT_SCHEMA, OBJECT_NAME, POLICY_NAME pname,  ENABLED, SEL, INS, UPD, DEL, ' '||POLICY_TEXT policy_text
       from (
        select OBJECT_SCHEMA, OBJECT_NAME, POLICY_NAME, POLICY_TEXT, ENABLED, SEL, INS, UPD, DEL
          from DBA_AUDIT_POLICIES where  object_name like '$FOBJECT' $AND_OWNER )
where rownum <= $ROWNUM ;
"
# ...............................................................................................
# list rules
# ...............................................................................................
elif [ "$ACTION" = "LIST_FGA_POLICY" ];then
   if [ -n "$FOBJECT" ];then
        AND_FOBJECT=" and object_name = '$FOBJECT' "
   fi
   if [ -n "$PAR2" ];then
        AND_OWNER=" and object_schema = '$PAR2' "
   fi
   TTITLE="List FGA rules"
   SQL="set lines 190
prompt use aud -lp -rn <nn> to see more rows
prompt
col policy_text for a60
col policy_name for a18 head 'Policy|Name'
col object_name for a26 head 'Object Name'
col object_schema for a18 head 'Owner'
select OBJECT_SCHEMA, OBJECT_NAME, POLICY_NAME,
                  ENABLED, SEL, INS, UPD, DEL , POLICY_TEXT
from
 (
select OBJECT_SCHEMA, OBJECT_NAME, POLICY_NAME, POLICY_TEXT,
                  ENABLED, SEL, INS, UPD, DEL
          from DBA_AUDIT_POLICIES where 1=1 $AND_FOBJECT $AND_OWNER
)where rownum <= $ROWNUM ;

"
# ...............................................................................................
# list last log entries
# ...............................................................................................
elif [ "$ACTION" = "LIST_LAST_FGA_LOG" ];then
 
   if [ -n "$FOBJECT" ];then
        AND_FOBJECT=" and OBJECT_NAME = '$FOBJECT' "
   fi
   if [ -n "$PAR2" ];then
        AND_OWNER=" and OBJECT_SCHEMA = '$PAR2' "
   fi

   TTITLE="Get  data from fga_log\$"
   SQL="set lines 190
col object_name for a22
col sql_text for a55 truncate
col owner for a18
col SCN for 99999999999999
col INSTANCE_number for 99 head 'In|st'

set longchunksize 60


select INSTANCE_number,  owner, object_name, fdate, scn,   statement_type type, sql_text from (
select INSTANCE_number, OBJECT_SCHEMA owner, object_name, 
        to_char(timestamp,'YYYY-DD-MM HH24:MI:SS') fdate, scn,  statement_type, sql_text 
        from dba_fga_audit_trail f  where 1=1 $AND_FOBJECT $AND_OWNER
        order by timestamp desc
) where rownum <=$ROWNUM;
"
# ...............................................................................................
# ...............................................................................................
elif [ "$ACTION" = "AUDIT_ST" ];then
   SQL="break on user
   select user_name, audit_option, success, failure from DBA_STMT_AUDIT_OPTS where 1=1 $F_USER order by user_name ;"

# ...............................................................................................
# ...............................................................................................
elif [ "$ACTION" = "LIST_CONNECT" ];then
   SQL="SELECT distinct (u.username), to_char(last_logoff,'DD-MM-YYYY HH24:MI:SS') last_logoff
  FROM dba_users u,
       (select max(logoff_time) last_logoff, username from dba_audit_trail group by username) b
  WHERE u.username = b.username (+) $U_USER ;
"
# ...............................................................................................
# ...............................................................................................
elif [ "$ACTION" = "PRIVS" ];then
   SQL="break on user
   select * from dba_priv_audit_opts ;"
# ...............................................................................................
# ...............................................................................................
elif [ "$ACTION" = "OBJECT" ];then
     SQL="break on owner
      SELECT * FROM DBA_OBJ_AUDIT_OPTS  order by owner, object_type;"
fi

if [ "$EXECUTE" = "YES" ];then
   do_execute
else
  echo "$SQL"
fi

