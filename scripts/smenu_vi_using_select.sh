#!/bin/ksh
# program smenu_vi_using_select.sh
# Author Bernard Polarski : 16-Nov-2000
trap 'rm $TMP_FIL' 0 1 2 3 4 5 6 7 8 9 11 13 14 15

SBINS=${SBIN}/scripts
TMP_FIL=$SBIN/tmp/list_shell.txt
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : smmenu utils
   
   *************************************************************
   *                                                           *
   *                 Edit scripts                              *
   *                                                           *
   *************************************************************
      

%
case $1 in
  sh  ) ls -t *sh > $TMP_FIL ;;
  sub ) ls -t smenu_sub_*sh > $TMP_FIL ;;
  txt ) ls -t *.txt > $TMP_FIL ;;
  sql ) ls -t *.sql > $TMP_FIL ;;
  menu ) ls -t smenu_menu* > $TMP_FIL ;;
  * ) exit ;;
esac
       
echo "e" >> $TMP_FIL
echo " "
PS3='Select scripts or e to leave ==> '
TLIST=`awk -F" " '{ printf "%s ", $1 }' $TMP_FIL`
select F_USER in ${TLIST}
   do
     if [ "x-$REPLY" = "x-e" - "x-$REPLY" = "x-" ];then
        break
     else
        cp $F_USER $SBIN/tmp/$F_USER.old
        vi $F_USER
        clear
     fi
done
