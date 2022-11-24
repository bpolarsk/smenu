#!/usr/bin/ksh
#set -xv
if [ "x-$1" = "x-" ];then
      cat <<EOF

         Quick describe :  Will list all DB users, let you pick one and display
                           all objects (of selected type) 

         Usage : qdk -t -v -c -x -u USER -s
 

                 -t : List tables
                 -v : List views
                 -c : List clusters
                 -x : List x\$tables (requires SYS password)
                 -u : Schema owner
                 -s : Silence : will export the table name in T_TBL and exit
                      use this if you want just to pick an object name 



EOF
      exit
fi
SILENT=FALSE
while getopts svctxu: ARG
do
   case $ARG in
    v) L_TYPE=VIEWS
       L_FIELD=view_name ;;
    c) L_TYPE=CLUSTERS
       L_FIELD=cluster_name ;;
    t) L_TYPE=TABLES
       L_FIELD=table_name;;
    s) SILENT=TRUE;;
    x) L_TYPE=X_TABLES ;;
    u ) F_USER=$OPTARG ;;
    * ) echo "Invalid Type "
        exit;;
   esac
done
export L_TYPE L_FIELD
FPATH=$SBIN/scripts
export FPATH
if [ "x-$L_TYPE" = "x-X_TABLES" ];then
     T_USER=SYS_XTBL
else
   if [ "x-$F_USER" = "x-" ];then
     smenu_list_user.sh 1>/dev/null 2>&1
     if [ "x-$F_USER" = "x-" ];then
       exit
     fi
   fi
   T_USER=$F_USER
fi


smenu_list_tbl_for_user.sh 1>/dev/null 2>&1
TBLLIST=$TBLLIST
if [ "x-$T_TBL" = "x-" ];then
   exit
fi
 if [ "x-$SILENT" = "x-TRUE" ];then
       export T_TBL
       return
 fi

SBINS=$SBIN/scripts
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

if [ $T_USER = SYS_XTBL ];then
   S_USER=SYS
   T_USER=SYS
fi
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
sqlplus -s "$CONNECT_STRING" <<EOF 

clear screen

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '      'Page:' format 999 sql.pno skip 2
column nline newline
set pause off
set pagesize 66
set linesize 80
set heading off
set embedded on
set termout on
set verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Describe $T_USER.$T_TBL ' nline
from sys.dual
/
desc $T_USER.$T_TBL
EOF


if [ $L_TYPE = VIEWS ];then
   sqlplus -s "$CONNECT_STRING" <<EOF
set pause off
set pagesize 66
set linesize 80
set heading off
set long 2000

select text from dba_views where  view_name = '$T_TBL' and owner = '$T_USER' ;
EOF
   
fi

echo " "
echo "Press any key to continue ... \c"
read gg

PS3='Select TABLE, e to leave ==> '
select L_TABLE in ${TBLLIST} 
    do
 if [ "x-$L_TABLE" = "x-" ];then
      break
 fi

sqlplus -s "$CONNECT_STRING" <<EOF

clear screen

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '      'Page:' format 999 sql.pno skip 2
column nline newline
set pause off
set pagesize 66
set linesize 80
set heading off
set embedded on
set termout on
set verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Describe $T_USER.$L_TABLE ' nline
from sys.dual
/

desc $T_USER.$L_TABLE
EOF
if [ $L_TYPE = VIEWS ];then
   sqlplus -s "$CONNECT_STRING" <<EOF
set pause off
set pagesize 66
set linesize 80
set heading off
set long 2000

select text from dba_views where  view_name = '$L_TABLE' and owner = '$T_USER' ;
EOF
fi
done
