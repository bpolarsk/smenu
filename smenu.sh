#!/bin/sh
# program smenu.sh
# top menu 

if [ ! -f ./smenu.env ];then
   ./scripts/smenu_env.sh
fi
. ./smenu.env
# check if  there are local modules
local_module_list=`ls -d $SBIN/module[4-9]` 1>/dev/null 2>&1
if [ -n "$local_module_list" ];then
   for mod in $local_module_list
   do
       rad=`echo $mod | sed 's/.*\([4-9]\)/\1/'`
       if [ -f $mod/module_$rad.sh ];then
             TITLE=`grep  ^MODULE_TITLE $mod/module_$rad.sh | cut -f2 -d=`
             LOCAL_MODULE=${LOCAL_MODULE}"                $rad ) ${TITLE}\\n" 
       fi
   done
fi

#---------------------- Main Loop -----------------------------
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
LAST_SELECTION=`echo 0| awk '{printf ("%-5.5s",$1)}'`

while true
  do
clear
choice=''
cat <<%
 

   $MSG
   Date           : `date +%d/%m-%H:%M`         Host    : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu    : sm/0
   Last Selection : $LAST_SELECTION              $YOUR Version : $VERSION
   *************************************************************
   *                                                           *
   *                       SMENU                               *
   *                                                           *
   *************************************************************


                1 ) Smenu administration
                2 ) DB Info 
                3 ) DB Utilities
`echo "$LOCAL_MODULE"`
  


           s ) Shortcuts/users
           t ) Test connection
           h ) View History
 
           e ) exit






%
echo $NN "  Your choice : $NC"
read choice
LAST_SELECTION=`echo $choice | awk '{printf ("%-5.5s",$1)}'`

if [ "x-$choice" = "x-t" ];then
   ksh $SBINS/smenu_check_connect.sh
   echo "\n Press Any key to continue... : "
   read ff
fi
if [ "x-$choice" = "x-s" ];then
   view $SBINS/shortcuts.txt
fi
if [ "x-$choice" = "x-h" ];then
   view $SBINS/history.txt
fi
if [ "x-$choice" = "x-e" ];then
    break
fi
if [ "x-$choice" = "x-1" ];then
   $SBIN/module_1.sh
elif [ "x-$choice" = "x-2" ];then
   $SBIN/module_2.sh
elif [ "x-$choice" = "x-3" ];then
   $SBIN/module_3.sh
else
   fdir=module$choice
   if [ -d "$fdir" ];then
       if [ -x "$fdir/module_$choice.sh" ];then
             $fdir/module_$choice.sh
       fi
   fi
fi
done
