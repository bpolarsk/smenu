#!/bin/ksh
# program : smenu_list_of_db_links.sh
# Author  : B. Polarski
# date    : 1999
# set -xv
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

TMP=$SBIN/tmp
FOUT=$TMP/Db_link_list_$ORACLE_SID.txt
> $FOUT
cd $TMP
# ----------------------------------------------------------------
function help
{
cat <<EOF

         List all info in DB link

   dblk -sys          #  list database link (from link\$) requires access to SYS
   dblk               #  list database link (from dba_db_link)
   dblk -x            #  list extended info
   dblk -cr           #  generate create db link script

 -v  : Verbose
EOF
exit
}
# ----------------------------------------------------------------
while [ -n "$1" ];
do
   case "$1" in
        -x    ) ACTION=EXT;;
        -sys  ) S_USER=SYS  ; export S_USER;;
        -cr   ) ACTION=SCRIPT ;;
        -v    ) set -xv ;;
     -h|-help ) help;;
   esac
   shift
done

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# ----------------------------------------------------------------------
if [ "$ACTION" = "SCRIPT" ];then
sqlplus -s "$CONNECT_STRING" <<EOF

 set pages 0 long 1000 lines 190

 with v as (
      select 
          extract(xmltype(dbms_metadata.get_xml('DB_LINK',x.name,u.name)),'//PASSWORDX/text()').getStringVal() vpass,
          x.name, x.owner#
      from  link$ x , user$ u 
      where x.owner# = u.user#
  )
 select 'create database link ' || b.name ||'.'|| a.name || ' connect to ' ||userid ||  ' identified by ' || ''''||
       utl_raw.cast_to_varchar2(dbms_crypto.decrypt((substr(v.vpass,19)), 4353, (substr(v.vpass,3,16))))  || ''';'
 from sys.link$ a, user$ b , v
 where
         b.name != 'PUBLIC' and a.owner# = b.user#
     and a.owner#=v.owner# and a.name = v.name
 union
  select 'create public database link ' || b.name ||'.'|| a.name || ' connect to ' ||userid ||  ' identified by ' || ''''||
  utl_raw.cast_to_varchar2(dbms_crypto.decrypt((substr(v.vpass,19)), 4353, (substr(v.vpass,3,16))))  || ''';'
  from sys.link$ a, user$ b , v
  where  
          b.name = 'PUBLIC' and a.owner# = b.user#
      and a.owner#=v.owner# and a.name = v.name
;
EOF
exit
# ----------------------------------------------------------------------
elif [ "$ACTION" = "EXT" ];then
    POSTSQL="select db_link wk_name, owner_id,logged_on,open_cursors,in_transaction,
                update_sent,commit_point_strength from v\$dblink;"

fi
# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
if [ "$S_USER"  = "SYS" ];then
  SQL="select db.owner wk_owner,db.DB_LINK wk_name,db.USERNAME wk_user,l.PASSWORDX wk_passwd, db.HOST wk_host
               from 
                   dba_db_links db, 
                   sys.link\$ l ,
                   sys.user\$ u
        where 
          db.DB_LINK = l.NAME
          and u.user#  = l.owner#
          and u.name = db.owner;
"
# ----------------------------------------------------------------------
else # default
    SQL="select  db.owner wk_owner,db.DB_LINK wk_name,db.USERNAME wk_user, db.HOST wk_host from dba_db_links db ;"
fi

echo "MACHINE $HOST - ORACLE_SID : $ORACLE_SID                          Page 1"
sqlplus -s "$CONNECT_STRING" <<EOF
column nline newline
set pagesize 66 linesize 80 head off pause off embedded off verify off
spool $FOUT

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline , 'List of Database links  ' nline
from sys.dual
/
prompt
set embedded on heading on linesize 125
column  wk_owner        format a13                      heading "Owner"
column  wk_name         format a41                      heading "DbLink|Name" wrap
column  wk_user         format a20                      heading "DbLink|User"
column  wk_passwd       format a12                      heading "DbLink|Passwd"
column  wk_host         format a30                      heading "DbLink|Host"
column  owner_id head "Owner|ID" justify c
column  logged_on head "DB link|logged" justify c
column  open_cursor head "Open|cursor" justify c
column  commit_point_strength  head "Commit|streng|point" justify c
column  update_sent  head "update|sent" justify c
$SQL
$POSTSQL
spool off
exit

EOF

