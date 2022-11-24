#!/bin/sh
# program get_user_to_mail.sh
# Author : Bernard Polarski
#set -xv
SBIN1=$SBIN/module1
cd $SBIN1
FMAIL=$SBIN/data/.smenu_mail_list.txt
if [ ! -f $FMAIL ];then
   echo " No Mail list file ... Aborting "
   exit 1
fi
LIST_MAIL=""
while true 
do
clear
echo " "
echo " *********************************************************************"
echo "    Mail list :  $LIST_MAIL"
echo " *********************************************************************"
echo " "
cpt=1
while read a 
  do
     echo " $cpt : $a "
     cpt=`expr $cpt + 1`
done<$FMAIL
echo 
echo 
echo " a   : add new users"
echo " e   : exit"
echo " "
echo $NN " Your choice  ==> $NC"
read xchoice
if [ "x-$xchoice" = "x-e" ];then
   break
elif [ "x-$xchoice" = "x-a" ];then
     $SBIN1/smenu_mail_list.sh 
else
        LIGN=`head -$xchoice $FMAIL | tail -1`
        F_USER=`echo $LIGN | cut -f2 -d\;`
        F_USER=`echo $F_USER | awk '{print $1}'`
        if [ "x-$LIST_MAIL" = "x-" ];then
           LIST_MAIL=$F_USER
        else
           LIST_MAIL=$LIST_MAIL","$F_USER
        fi
        export LIST_MAIL
fi
done
