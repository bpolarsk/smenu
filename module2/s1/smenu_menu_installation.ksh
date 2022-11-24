#!/usr/bin/ksh
# program 
# Bernard Polarski
# 18-april-2005

WK_SBIN=${SBIN}/module2/s1

THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
while true
do
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/2.1
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                  Installation                             *
   *                                                           *
   *************************************************************
      

           Information :
           -------------
             1  :  List installed component
             2  :  List active statistics
             3  :  List init parameters
             4  :  List Modifiable parameters
             5  :  List Hidden parameters
             6  :  Show DB uptime
             7  :  show archive mode
             8  :  List dblink
             9  :  Report user object distribution (fast)
            10  :  List datafile with no logging ops
            11  :  Generated statements to change redo size online
            12  :  Show source code for View/Pkg/proc/func



     e ) exit



%
echo $NN "  Your choice : $NC"
read choice


if [ "x-$choice" = "x-e" ];then
    break
fi
 
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
   ksh $WK_SBIN/smenu_list_product.ksh
   echo $NN "\n Press Any key to continue... : $NC"
   read ff
fi
#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
    ksh $WK_SBIN/smenu_view_archive_mode.sh -s
    echo "\n Press Any key to continue... : "
    read ff
fi
#---------------------- ch3 -----------------------------------------------------
if [ "x-$choice" = "x-3" ];then
    ksh $WK_SBIN/smenu_list_init_param.sh -l
    echo $NC "\n Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch4 -----------------------------------------------------
if [ "x-$choice" = "x-4" ];then
    ksh $WK_SBIN/smenu_list_init_param.sh -m
    echo $NN "\n Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch5 -----------------------------------------------------
if [ "x-$choice" = "x-5" ];then
    ksh $WK_SBIN/smenu_list_init_param.sh -i
    echo $NN "\n Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch6 -----------------------------------------------------
if [ "x-$choice" = "x-6" ];then
    ksh $WK_SBIN/smenu_uptime.sh
    echo $NN "\n Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch7 -----------------------------------------------------
if [ "x-$choice" = "x-7" ];then
    ksh $WK_SBIN/smenu_view_archive_mode.sh
    echo $NN "\n Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch8 -----------------------------------------------------
if [ "x-$choice" = "x-8" ];then
    ksh $WK_SBIN/smenu_list_of_db_links.sh
    echo $NN "\n Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch9 -----------------------------------------------------
if [ "x-$choice" = "x-9" ];then
    ksh $WK_SBIN/smenu_cpt_obj.sh
    echo $NN "\n Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch10 -----------------------------------------------------
if [ "x-$choice" = "x-10" ];then
    ksh $WK_SBIN/
    $SBIN/module2/s1/smenu_view_archive_mode.sh -urc
    echo $NN "\n Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch11 -----------------------------------------------------
if [ "x-$choice" = "x-11" ];then
    ksh $WK_SBIN/smenu_chg_redo_size.sh
    echo $NN "\n Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch12 -----------------------------------------------------
if [ "x-$choice" = "x-12" ];then
    echo "VIEW_NAME ==> \c"
    read OBJ
    echo "OWNER ==> \c"
    read OWNER
    ksh $WK_SBIN/smenu_src.ksh $OBJ -u $OWNER
    echo $NN "\n Press Any key to continue... : $NC" 
    read ff
fi
#---------------------- ch13 -----------------------------------------------------
#---------------------- Done ----------------------------------------------------
done
