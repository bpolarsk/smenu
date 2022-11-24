#!/bin/ksh
# author   : B. Polarski
# program  : smenu_dsk.sh
# purpose  : Display table/view structure
# Date     : December  2000
# set -x

help()
{
   cat <<EOF

     Describe an object columns, list all object and type when given a partial name
     Find who is the owner of a an object

          dsk TABLE       [-u <OWNER>]
          dsk VIEW        [-u <OWNER>]
          dsk OWNER.TABLE
          dsk OWNER.VIEW
          dsk -p <partial name>   # just produce a list of what exists
          dsk -c <TABLE|VIEW> [-u [OWNER>]

           note : You can omit OWNER if the OWNER is \$S_USER (default Smenu user)


EOF
   exit 0
}
if [ -z "$1" ];then
   echo " I need something to describe !"
   help
fi
typeset -u TBL
while [ -n "$1" ]
do
   case $1 in
      -u ) OWNER=`echo $2| awk '{print toupper($1)'}`
           AND_OWNER=" and owner = '$OWNER'"
           shift ;;
      -c ) ACTION=COMMENT;;
      -p ) TBL=$2 ; shift ; ACTION=LIKE ;;
-h|-help ) help ;;
       * ) TBL=$1 ;;
   esac
   shift
done
#--------------- declare some parameters -------------

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi


if [ "$ACTION" = "COMMENT" ];then
   sqlplus -s "$CONNECT_STRING" <<EOF
      set pagesize 66 linesize 125 feed off verify off pause off
      set heading on
      col column_name format A26
      col comments format A96
      select column_name, comments from dba_col_comments where table_name='$TBL' $AND_OWNER ;
EOF
elif [ "$ACTION" = "LIKE" ];then

   sqlplus -s "$CONNECT_STRING" <<EOF
      set pagesize 0 feed off head off verify off pause off
      set head on
      col owner format A16
   select 'TABLE' ,owner, table_name from dba_tables where table_name like '%$TBL%' $AND_OWNER
   union all
   select 'VIEW', owner, view_name from dba_views where view_name  like '%$TBL%'  $AND_OWNER
   union all
   select 'TABLE','SYS' as owner,name from sys.v_\$fixed_table where name like '%$TBL%'
   union all
   select 'VIEW','SYS' as owner, view_name from sys.v_\$fixed_view_definition where view_name like '%$TBL%'
   order by owner
/
EOF
else # default
   if [ -n "$OWNER" ];then
      sqlplus -s "$CONNECT_STRING"<<EOF
      set pagesize 0 feed off head off verify off pause off
      set head on
      prompt Desc $OWNER.$TBL
      prompt
      desc  $OWNER.$TBL
EOF
   else
      sqlplus -s "$CONNECT_STRING" <<EOF
set feed off
col t_owner new_value t_owner noprint
col t_type  new_value t_type  noprint

select t_type, t_owner  
   from (
select 'Table : ' t_type, owner||'.'||table_name t_owner from dba_tables where table_name = '$TBL'
union all
select 'View : ' t_type, owner||'.'||view_name  t_owner from dba_views where view_name = '$TBL'
union all
select 'Type : ' t_type, owner||'.'||type_name  t_owner from dba_types where type_name = '$TBL'
union all
select 'Package : ' t_type, b.username||'.'||a.object_name  t_owner from dba_objects a, dba_users b where 
                a.object_name = '$TBL' and a.object_type='PACKAGE' and a.owner=b.username
) where rownum = 1;

prompt &t_type  &t_owner
prompt
set lines 80
desc &t_owner

exit
EOF


   fi
fi


