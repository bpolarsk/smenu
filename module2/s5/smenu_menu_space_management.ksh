#!/usr/bin/ksh
# program 
# Barjasse Didier
#set -xv
SBIN2=${SBIN}/module2
WK_SBIN=$SBIN2/s5
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`

while true
do
clear
x_choice=''
cat <<%

   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/2.5
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                  Space management                         *
   *                                                           *
   *************************************************************
      
     Report :
     ---------

         1  : Report Tablespaces size
         2  : Report FreeSpace Summary
         3  : Report Contiguous free Space for a Tablespace
         4  : Report Contiguous free Space for all Tablespace
         5  : Report Coalescable extents for all tablespace 
         6  : Report of next extent within a given number of extents
         7  : Report objects whith not enough space for next extent
         8  : Tablespace Analysis - Space Management and Fragmentation
         9  : Reports datafile's last checkpoint
         10 : List of Objects for a specific Tablespace
         11 : List datafiles
         12 : Report Tablespaces default creation values
         14 : Show top 30 users table mutations
         15 : Report space usage per user in db
         16 : Report space usage per user per tablespace
         17 : Report Tablespaces default creation values
         18 : Report ASM free space

     Script Generation :
     -------------------
         20 :  Coalesce all coalescable tablespaces 
     Information :
     -------------
         30 :  Coalescing a tablespace
              
     e ) exit

%
echo $NN "  Your choice : $NC"
read choice


if [ "x-$choice" = "x-e" ];then
    break
fi


 
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
      echo "\n\n\n\n"
      cat <<EOF
	    This script reports all the tablespace & size 

            Result in SMENU/tmp
EOF
        echo " "
        cd $WK_SBIN
        ksh $WK_SBIN/smenu_lst_tblspc_siz.ksh
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
        read ff
fi

#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
      echo "\n\n\n\n"
      cat <<EOF
	    This script reports the free space summary

            Result in SMENU/tmp
EOF
        echo " "
        cd $WK_SBIN
        ksh $WK_SBIN/smenu_free_space_summary.ksh
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
        read ff
fi
#---------------------- ch3 -----------------------------------------------------
if [ "x-$choice" = "x-3" ];then
      echo "\n\n\n\n"
      cat <<EOF
	    This script reports the free contiguous space in a given tablespace

            Result in SMENU/tmp
EOF
        echo " "
        cd $WK_SBIN
        ksh $WK_SBIN/smenu_db_contigous_free_space_one_tbs.ksh
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
        read ff
fi
#---------------------- ch4 -----------------------------------------------------
if [ "x-$choice" = "x-4" ];then
      echo "\n\n\n\n"
      cat <<EOF
	    This script reports the free contiguous space in all tablespace

            Result in SMENU/tmp
EOF
        echo " "
        cd $WK_SBIN
        ksh $WK_SBIN/smenu_db_contigous_free_space.ksh
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
        read ff
fi
#---------------------- ch5 -----------------------------------------------------
if [ "x-$choice" = "x-5" ];then
      echo "\n\n\n\n"
      cat <<EOF
	    This script reports the coalescable extents for all the tablespaces 

            Result in SMENU/tmp
EOF
        echo " "
        cd $WK_SBIN
        ksh $WK_SBIN/smenu_db_coalescable_extents.ksh
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
        read ff
fi

#---------------------- ch6 -----------------------------------------------------
if [ "x-$choice" = "x-6" ];then
      echo "\n\n\n\n"
      cat <<EOF
	    This script reports all the objects which have the next extent 
            within a given number of extents

EOF
echo " "
	cd $WK_SBIN
        ksh $WK_SBIN/smenu_db_within_nbr_extents.ksh
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch7 -----------------------------------------------------
if [ "x-$choice" = "x-7" ];then
      echo "\n\n\n\n"
      cat <<EOF
	    This script reports all the objects which have not enough 
            free space to create a new next extent 

            Result in SMENU/tmp
EOF
        ksh $WK_SBIN/smenu_not_space_for_next_ext.ksh
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch8 -----------------------------------------------------
if [ "x-$choice" = "x-8" ];then
      echo "\n\n\n\n"
      cat <<EOF
	    This script reports a tablespace Analysis about Space Management and Fragmentation

            Result in SMENU/tmp
EOF
if $SBINS/yesno.sh "to Run the script "; then
	cd $WK_SBIN
        ksh $WK_SBIN/smenu_db_tabspace_info.ksh
        echo " "
        echo " Result in SMENU/tmp "
else
       echo "Next time may be"
fi
echo $NN " Press Any key to continue... : $NC"
    read ff
fi

#---------------------- ch9 -----------------------------------------------------
if [ "x-$choice" = "x-9" ];then
      cd $WK_SBIN
      ksh $WK_SBIN/smenu_disk_lst.ksh -ck
      echo $NN " Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch10 -----------------------------------------------------
#14
if [ "x-$choice" = "x-10" ];then
      echo "\n\n\n\n\n\n\n\n"
      cat <<-EOF
            This Script create a report which describe the name , the type ,
            the size, the number of extents and the pct free of the object
            Result in SMENU/tmp
	EOF
        echo $NN " Tablespace =>$NC"
        read TBS
        ksh $SBIN/module2/s5/smenu_free_space_summary.ksh -t  $TBS -os
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
        read ff
fi
#---------------------- ch11 -----------------------------------------------------
if [ "x-$choice" = "x-11" ];then
      echo "\n\n\n\n\n\n\n\n"
        cd $WK_SBIN
        ksh $WK_SBIN/smenu_disk_lst.ksh
        echo " "
        echo $NN " Press Any key to continue... : $NC"
        read ff
fi
#---------------------- ch12 -----------------------------------------------------
if [ "x-$choice" = "x-12" ];then
      echo "\n\n\n\n"
      cat <<EOF
	    This script reports all tablespace default creation values.
            These  values are used if you do not provide them.

EOF
echo " "
	cd $WK_SBIN
        ksh $WK_SBIN/smenu_tbs_def.ksh
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch14 -----------------------------------------------------
if [ "x-$choice" = "x-14" ];then
   ksh $WK_SBIN/smenu_show_tab_mod.ksh
   echo $NN " Press Any key to continue... : $NC"
   read ff
fi
#---------------------- ch14 -----------------------------------------------------
if [ "x-$choice" = "x-15" ];then
   ksh $WK_SBIN/smenu_free_space_summary.ksh -dus
   echo $NN " Press Any key to continue... : $NC"
   read ff
fi
#---------------------- ch16 -----------------------------------------------------
if [ "x-$choice" = "x-16" ];then
   ksh $WK_SBIN/smenu_db_usage_tbs_user.ksh
   echo $NN " Press Any key to continue... : $NC"
   read ff
fi
#---------------------- ch17 -----------------------------------------------------
if [ "x-$choice" = "x-17" ];then
   ksh $WK_SBIN/smenu_free_space_summary.ksh -i
   echo $NN " Press Any key to continue... : $NC"
   read ff
fi
#---------------------- ch18 -----------------------------------------------------
if [ "x-$choice" = "x-18" ];then
   ksh $WK_SBIN/smenu_asm.ksh
   echo $NN " Press Any key to continue... : $NC"
   read ff
fi
#---------------------- Script Generation ----------------------------------------
if [ "x-$choice" = "x-20" ];then
      echo "\n\n\n\n"
      cat <<EOF
	    This script coalesce all coalescable tablespaces

            Result in SMENU/tmp
EOF
if $SBINS/yesno.sh "to Run the script " DO Y
    then
	cd $WK_SBIN
        ksh $WK_SBIN/smenu_db_alter_tbs_coalesce.ksh
        echo " "
        echo " Result in SMENU/tmp "
else
       echo "Next time may be"
fi
echo $NN " Press Any key to continue... : $NC"
    read ff
fi
#---------------------- tips -----------------------------------------------------
if [ "x-$choice" = "x-30" ];then
        view $WK_SBIN/smenu_tips_coalsce_tablespace.txt
fi
#---------------------- done-----------------------------------------------------
done

