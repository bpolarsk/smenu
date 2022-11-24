#!/bin/ksh
#set -xv
SBINS=$SBIN/scripts
WK_SBIN=${SBIN}/module2/s1
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
# -------------------------------------------------------------------------------------
get_nls_value()
{
par1=`echo $1 | tr '[a-z]' '[A-Z]'`
var=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off feed off pause off
select $FNAME1  value   from nls_database_parameters where parameter like '$par1' ;
exit

EOF
`
if [ -z "$FNAME1" ];then
  var=`echo $var | tr -d '\r'| awk '{print $1}'`
fi
echo "$var"
}
# -------------------------------------------------------------------------------------
get_value()
{
var=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off feed off pause off
select $FNAME value  from v\\$parameter where name like '$1' ;
exit
EOF
`
if [ -z "$FNAME" ];then
  var=`echo $var | tr -d '\r'| awk '{print $1}'`
fi
echo "$var"
}
# -------------------------------------------------------------------------------------
function do_execute
{
$SETXV
if [ -z "$NO_FOUT" ];then
   SPOOL_ON="spool $FOUT"
   SPOOL_OFF="spool off"
fi
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 1 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER, '$TITTLE ' from sys.dual
/
set head on linesize 132 pagesize 66
$SPOOL_ON
$SQL
$SPOOL_OFF
EOF
}
# -------------------------------------------------------------------------------------
show_help()
{
   cat <<EOF


         Usage :
 
              vsp -l          # List all parameters
              vsp -i          # List all hidden parameters
              vsp -m          # List only modifiable parameters
              vsp -p <par>    # Get value parameter.
              vsp -vv         # List valid value together with current value

EOF
}
# -------------------------------------------------------------------------------------


if [ -z "$1" ];then
   show_help
   exit
fi

TITTLE="System parameter from v\$parameter"
while [ -n "$1" ]
  do
    case "$1" in
        -l ) ACTION=LIST_ALL ;;
        -i ) ACTION=LIST_HIDDEN ;;
        -m ) ACTION=MODIF ;;
        -p ) ACTION=GET ; par=$2; shift ;;
       -vv ) ACTION=VALID ;; 
        -v ) VERBOSE=TRUE ;;
        -h ) show_help; exit ;;
    esac
    shift
done

  S_USER=SYS
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

#......................................................................................
#   List valid values
#......................................................................................
if [ "$ACTION" = "VALID" ];then
   NO_FOUT=TRUE
   SQL=" set line 190 pages 66j
col INST_ID head 'Inst|id' for 9999
col NAME_KSPVLD_VALUES head 'Name' for a37
col VALUE_KSPVLD_VALUES head 'Value' for a40
col ISDEFAULT_KSPVLD_VALUES head 'Is|Default' for a8
col ORDINAL_KSPVLD_VALUES head 'Ord' for 999
col curr head 'Current Value' for a40
break on inst_id on NAME_KSPVLD_VALUES on curr on report
with v_hid as (
  select  x.ksppinm pname ,
          v.ksppstvl value
  from    x\$ksppi x, x\$ksppcv v
  where   translate(ksppinm,'_','#') like '#%'    and
          v.indx = x.indx                         and
          v.inst_id = x.inst_id
  order by x.ksppinm
)
 SELECT 
      INST_ID,  NAME_KSPVLD_VALUES, ORDINAL_KSPVLD_VALUES, 
      VALUE_KSPVLD_VALUES, ISDEFAULT_KSPVLD_VALUES, p.value curr
 FROM X\$KSPVLD_VALUES k , v\$parameter p
 where  k.NAME_KSPVLD_VALUES = p.name 
union
 SELECT 
      INST_ID,  NAME_KSPVLD_VALUES, ORDINAL_KSPVLD_VALUES, 
      VALUE_KSPVLD_VALUES, ISDEFAULT_KSPVLD_VALUES, h.value curr
 FROM X\$KSPVLD_VALUES k , v_hid h 
 where  k.NAME_KSPVLD_VALUES = h.pname 
order by 2,1,3
/
"
#......................................................................................
#   List all regular parameter
#......................................................................................
elif [ "$ACTION" = "LIST_ALL" ];then
   FOUT=$SBIN/tmp/list_init_param_$ORACLE_SID.txt
   SQL="set embedded on
set heading on  feedback off
set linesize 190 pagesize 0 trimspool on
col name     form A37 head 'Name' justify l
col value    form A45 head 'Value' justify l
col description form A90 head 'Description' justify l
col ISSES_MODIFIABLE head 'Ses|Mod'
col ISSYS_MODIFIABLE head 'Sys|Mod'

select name, value, description, ISSES_MODIFIABLE,ISSYS_MODIFIABLE from v\$parameter order by name
/
"
#......................................................................................
#   List modifiables parameters
#......................................................................................
elif [ "$ACTION" = "MODIF" ];then
     TITTLE="show modifiable parameters"
     FOUT=$SBIN/tmp/list_init_modif_$ORACLE_SID.txt
     SQL="set linesize 190 pagesize 66 heading on feed off trimspool on
prompt  Use 'alter session set <paramter => value' to modify value for your current session.
prompt
prompt  If effect is <> FALSE then the change is possible and permanent witout rebooting
prompt  by using 'alter system ' command with the two possibles effects :
prompt  .               IMMEDIATE - parameter will take effect for all current and future sessions
prompt  .               DEFERRED -  parameter will take effect only for future sessions.


set heading on  feedback off
set linesize 150 pagesize 0 trimspool on
col name     form A33 head 'Name' justify l
col value    form A32 head 'Value' justify l
col description form A65 head 'Description' justify l
col ISSES_MODIFIABLE head 'Ses|Mod'
col ISSYS_MODIFIABLE head 'Sys|Mod'
col ISINSTANCE_MODIFIABLE head 'Inst|Mod'
col ISDEFAULT head 'Default'
col ISMODIFIED head 'Modified'
col ISADJUSTED head 'Adjusted'
select
    name,
    value,
    issys_modifiable, ISSYS_MODIFIABLE, ISINSTANCE_MODIFIABLE, ISDEFAULT, ISMODIFIED, ISADJUSTED
from v\$parameter
where
    issys_modifiable != 'FALSE' or ISSYS_MODIFIABLE != 'FALSE' or ISINSTANCE_MODIFIABLE != 'FALSE'
order by name ;
"
#......................................................................................
#   List all regular parameter
#......................................................................................
elif [ "$ACTION" = "LIST_HIDDEN" ];then
     FOUT=$SBIN/tmp/list_init_hidden_$ORACLE_SID.txt
     TITTLE="Show hidden parameters"
     SQL="col pname format a40 head 'Name'
col value format A12 head 'Value'
col def   format A12 head 'Default'
col description format a40 head 'Description'

select  x.ksppinm pname ,
        v.ksppstvl value,
        v.ksppstdf def,
        x.ksppdesc description
from    x\$ksppi x, x\$ksppcv v
where   translate(ksppinm,'_','#') like '#%'    and
        v.indx = x.indx                         and
        v.inst_id = x.inst_id
order by x.ksppinm
/
"
#......................................................................................
#   get single parameter value
#......................................................................................
elif [ "$ACTION" = "GET" ];then
     if [ -z "$par" ];then
           exit
     fi
     if [ $par  = ${par##\%} ];then
        unset FNAME
        unset FNAME1
     else
        FNAME="name,"
        FNAME1="parameter,"
        CHR10=",chr(10)"
     fi
     echo $par | grep -i NLS > /dev/null
     if [ $? -eq 1 ];then
       get_value $par
     else
       get_nls_value $par
    fi
    exit
fi

if [ "$VERBOSE" = "TRUE" ];then
   echo "$SQL"
fi
do_execute
if [ "$NO_FOUT"  = "TRUE" ];then
    exit
fi
echo
echo ".........................................................."
echo "Results in $FOUT"
echo ".........................................................."
if $SBIN/scripts/yesno.sh " to view the results " DO Y
   then
     vi $FOUT
fi
echo
