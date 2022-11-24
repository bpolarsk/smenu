#!/bin/ksh
# program smenu_list_user.sh
# Author Bernard Polarski : 21-04-2000
SBINS=${SBIN}/scripts
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
TMP_FIL=$SBIN/tmp/lst_usr$$.txt
sqlplus  -s "$CONNECT_STRING" >$TMP_FIL <<EOF
        set pages 0 
        set feedback off 
        set echo off 
        set termout off 
        set pause off verify off
        select username from dba_users order by username;
EOF
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/2.6
   
   *************************************************************
   *                                                           *
   *                 List of users                             *
   *                                                           *
   *************************************************************
      

%
echo " "
PS3='Select USER or e to leave ==> '
USRLIST=`awk -F" " '{ printf "%s ", $1 }' $TMP_FIL`
if [ -f $TMP_FIL ];then
      rm $TMP_FIL
fi
select F_USER in ${USRLIST}
   do
     export F_USER
     break
done
