#!/bin/sh
#set -xv
SBINS=${SBIN}/scripts
SBIN1=${SBIN}/module1
cd $SBIN1
FTMP=/tmp/zzgg_mail.txt
FMAIL=$SBIN/data/.smenu_mail_list.txt
if [ ! -f $FMAIL ];then
   touch $FMAIL
fi
while true 
do
clear
echo " "
echo " *********************************************************************"
echo "    Mail list :    "
echo " "
echo "    -Select 'a' to add a name to the list or "
echo "    -append 'd' to selection number to remove the name from mail list"
echo "    -append 't' to selection number to test the mail address "
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
echo " "
echo " a   : Add a name"
echo " e   : exit"
echo " "
echo $NN " Your choice  ==> $NC"
read xchoice
if [ "x-$xchoice" = "x-e" ];then
   exit
else
   if [ "x-$xchoice" = "x-a" ];then
      echo $NN "==> name  : $NC"
      read f_name
      echo $NN "==> Email : $NC"
      read f_email
      if [ ! "x-$f_name" = "x-" -a ! "x-$f_email" = "x-" ];then
         echo "$f_name ; $f_email" >> $FMAIL
      else
         echo " Wrong input ! "
         read ff
      fi
      continue
   fi
   var=`echo $xchoice | grep 'd'`
   if [ $? -eq 0 ];then
        xchoice=`echo $xchoice | sed 's/d//'`
        LIGN=`head -$xchoice $FMAIL | tail -1`
        F_USER=`echo $LIGN | cut -f1 -d\;`
        if $SBINS/yesno.sh "remove '$F_USER' form Email list"
           then
            CPT1=`expr $xchoice - 1`
            if [ $CPT1 -gt -1 ];then
               head -$CPT1 $FMAIL > $FTMP
            fi
            FMAX=`cat $FMAIL | wc -l`
            CPT2=`expr $FMAX - $xchoice`
            if [ $CPT2 -gt -1 ];then
                tail -$CPT2 $FMAIL >> $FTMP
            fi
            mv $FTMP $FMAIL
        fi
   else
      var=`echo $xchoice | grep 't'`
      if [ $? -eq 0 ];then
         if [  "x-$MAIL_PRG" = "x-" ];then
            . $SBIN/smenu.env
         fi
         xchoice=`echo $xchoice | sed 's/t//'`
         LIGN=`head -$xchoice $FMAIL | tail -1`
         F_MAIL=`echo $LIGN | cut -f2 -d\;`
         echo " From `hostname`  :" > /tmp/hello_world.txt
         echo " " >> /tmp/hello_world.txt
         echo "       Hello World " >> /tmp/hello_world.txt
         $MAIL_PRG $F_MAIL </tmp/hello_world.txt
         rm /tmp/hello_world.txt
         echo " Test sent ... Press any key to continue"
        read ff
      fi
   fi
fi
done
