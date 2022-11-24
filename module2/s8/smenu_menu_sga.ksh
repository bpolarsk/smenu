#!/usr/bin/ksh
# program 
# Bernard Polarski
HOST=`hostname`
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
SBINS=${SBIN}/scripts
WK_SBIN=${SBIN}/module2/s8
while true
do
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/2.8
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *          Database Shared Memory report scripts            *
   *                                                           *
   *************************************************************
      
        Information :
        -------------
           6  :   Get Large objects present in memory
           7  :   
           8  :   Data dictionary status
           9  :   Data dictionary efficiency
          10  :   Show Instance variables
          11  :   Show v\$systat values 
          12  :   Show parsing values
          13  :   Show recursive parsing values
          14  :   
          15  :   
          16  :   Shared Memory Usage Report
          17  :   Shared Pool Fragmentation (Give Free chunk)
          18  :   Free sga space left



     e ) exit

%
echo $NN "  Your choice : $NC"
read choice
LAST_SELECTION=$choice

if [ "x-$choice" = "x-e" ];then
    break
fi
 
#---------------------- ch1 -----------------------------------------------------
#---------------------- ch2 -----------------------------------------------------
#---------------------- ch3 -----------------------------------------------------
#---------------------- ch4 -----------------------------------------------------
#---------------------- ch5 -----------------------------------------------------
#---------------------- ch6 -----------------------------------------------------
if [ "x-$choice" = "x-6" ];then
      clear
      cat <<EOF

   You can determine what large stored objects are in the shared pool by
   selecting from the v\$db_object_cache fixed view.  This will also tell you
   which objects have been marked kept.  This can be done with the following
   query:

     The SQL :

       select * from v\$db_object_cache where sharable_mem > 1000;

EOF
      echo " "
      echo " Program in progress, please wait.... $NC"
      min_siz=10000
      echo "Minimun size of Object to include : [10000 Bytes] $NC"
      read min_siz
      if [ "x-$min_siz" = "x-" ];then
         min_siz=10000
      fi
      echo " "
      echo " "
      #sqlplus $S_USER/$PASSWD @$WK_SBIN/smenu_large_object_in_mem $HOST $ORACLE_SID $min_siz
      $WK_SBIN/smenu_large_object_in_mem.sh $HOST $ORACLE_SID $min_siz
      echo " "
      echo " -----------------------------------------------------------------------------------"
      echo " "
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch7 -----------------------------------------------------
#---------------------- ch8 -----------------------------------------------------
if [ "x-$choice" = "x-8" ];then
      $SBIN/module2/s1/smenu_cpt_obj.sh -dcs
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch9 -----------------------------------------------------
if [ "x-$choice" = "x-9" ];then
      $WK_SBIN/smenu_cpt_obj.sh -dce
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch10 ----------------------------------------------------
if [ "x-$choice" = "x-10" ];then
      $SBIN/module2/s1/smenu_view_archive_mode.sh -v
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch11 ----------------------------------------------------
if [ "x-$choice" = "x-11" ];then
      $WK_SBIN/smenu_v_sysstat.sh
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch12 ----------------------------------------------------
if [ "x-$choice" = "x-12" ];then
      $WK_SBIN/smenu_show_parse_values.sh
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch13 ----------------------------------------------------
if [ "x-$choice" = "x-13" ];then
      $WK_SBIN/smenu_show_parse_recurse.sh
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch14 ----------------------------------------------------
#---------------------- ch15 ----------------------------------------------------
#---------------------- ch16 ----------------------------------------------------
if [ "x-$choice" = "x-16" ];then
      $WK_SBIN/smenu_share_mem_usage.sh
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch17 ----------------------------------------------------
if [ "x-$choice" = "x-17" ];then
      $WK_SBIN/smenu_share_mem_usage.sh -f
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch18 -----------------------------------------------------
if [ "x-$choice" = "x-18" ];then
   ksh $WK_SBIN/smenu_free_sga.ksh
   echo $NN " Press Any key to continue... : $NC"
   read ff
fi
#---------------------- ch1 -----------------------------------------------------
done
