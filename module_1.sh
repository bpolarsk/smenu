#!/usr/bin/ksh
#module_sql.sh
# set -xv
SBIN1=$SBIN/module1
SBK=$SBIN/scripts/backup
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
if [ "x-$ORACLE_SID" = "x-" ];then
   THE_ORACLE_SID="NO ORACLE SID!"
fi
while true
  do
clear
choice=''
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/1
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                   Maintenance menu                        *
   *                                                           *
   *************************************************************

      
                1 ) Smenu default settings
                2 ) Maintain passwd
                3 ) Maintain/define a default user per sid




          e ) exit

%
echo $NN "  Your choice : $NC"
read choice
LAST_SELECTION=$choice

if [ "x-$choice" = "x-e" ];then
    break
fi
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
   ksh $SBIN1/smenu_env.ksh
fi
#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
   if [ -f $SBINS/.passwd ];then
       vi $SBINS/.passwd
       chmod 600 $SBINS/.passwd
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch3 -----------------------------------------------------
if [ "x-$choice" = "x-3" ];then
   ksh $SBIN1/smenu_default_user_per_sid.ksh
fi
#---------------------- Done ----------------------------------------------------
done

