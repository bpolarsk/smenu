#!/usr/bin/ksh
# program smenu_list_tbl_for_user.sh
# Author Bernard Polarski : 21-04-2000
#
#

T_USER=${T_USER:-$1}
if [ "x-$T_USER" = "x-" ]; then
   echo "I need a User name : Do not forget to fill T_USER, L_FIELD, L_TYPE"
   echo "\n     Usag: $0 Username\n\n"
fi
SBINS=${SBIN}/scripts
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
TMP_FIL=$SBIN/tmp/lst_tbl_usr$$.txt

if [ $T_USER = "SYS_XTBL" ];then
    SQL="select name from sys.v_\$fixed_table where name like 'X\$%' order by name ;"
elif [ $T_USER = "SYS_VW" ];then
    SQL="select view_name from sys.v_\$fixed_view_definition ;"
else
    SQL="select ${L_FIELD} from dba_${L_TYPE} where owner = '$T_USER' ;"
fi
sqlplus  -s "$CONNECT_STRING" >$TMP_FIL <<EOF
        set pages 0 
        set feedback off 
        set echo off 
        set termout off 
        set pause off verify off
        $SQL
EOF

THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
F_USER=`echo $F_USER | awk '{printf ("%-15.15s",$1)}'`
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/2.6
   
   *************************************************************
   *                                                           *
             List ${L_TYPE} for user : $F_USER            
   *                                                           *
   *************************************************************
      

%
echo " "
PS3='Select ${L_TYPE}, e to leave ==> '
TBLLIST=`awk -F" " '{ printf "%s ", $1 }' $TMP_FIL`
if [ -f $TMP_FIL ];then
      rm $TMP_FIL
fi
select T_TBL in ${TBLLIST}
   do
     export T_TBL
     break
done
