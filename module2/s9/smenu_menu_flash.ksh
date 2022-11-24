#!/usr/bin/ksh
# program 
# Bernard Polarski
# 18-april-2005

WK_SBIN=${SBIN}/module2/s9
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
while true
do
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/2.9
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                  Flash back, RMAN and Rollback            *
   *                                                           *
   *************************************************************
      

           Flashback :
           -----------
             1  :  Display flash back setup
             2  :  Display flash back available 
             3  :  list registered database
             4  :  Show Rman Backup current progression (v$session_longops)

           Rollback :
           ----------

             11  :  Report Rollbacks status of the DB
             12  :  Report rollback used in transactions
             13  :  Show the number of undo megs tbs needed
             14  :  Report rollback size and highwatermark
             15  :  Report rollback reuse extents
             16  :  Report rollback average writes
             17  :  Report redo logs informations

          Script Generation :
          -------------------
            20  :  Generate script to change size of online redo logs


          About Rollback Segment
          ----------------------
          30 :  How many transactions can a rollback seg. handle concurrently

     e ) exit



%
echo "  Your choice : \c"
read choice


if [ "x-$choice" = "x-e" ];then
    break
fi
 
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
   ksh $WK_SBIN/smenu_flash_info.ksh
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
    ksh $WK_SBIN/smenu_flash_available.ksh
    echo "\n Press Any key to continue... : \c"
    read ff
fi
#---------------------- ch3 -----------------------------------------------------
if [ "x-$choice" = "x-3" ];then
    ksh $WK_SBIN/smenu_rman_list_reg_db.ksh
    echo "\n Press Any key to continue... : \c"
    read ff
fi
#---------------------- ch4 -----------------------------------------------------
if [ "x-$choice" = "x-4" ];then
    $SBIN/module2/s2/smenu_long_ops.ksh -f
    echo "\n Press Any key to continue... : \c"
    read ff
fi

#---------------------- ch11 -----------------------------------------------------
if [ "x-$choice" = "x-11" ];then
      echo "\n\n\n\n"
      cat <<EOF
	    This script reports the rollback status ans location 

EOF
        echo " "
        cd $WK_SBIN
        ksh $WK_SBIN/smenu_rollback_size.sh -k
        echo " "
        echo "\n Press Any key to continue... : \c"
        read ff
fi
#---------------------- ch12 -----------------------------------------------------
if [ "x-$choice" = "x-12" ];then
      echo "\n\n\n\n"
      cat <<EOF
	    This script reports the transaction in the rollbacks and their owner 

EOF
        echo " "
        cd $WK_SBIN
        ksh $WK_SBIN/smenu_rollback_size.sh -tx
        echo " "
        echo "\n Press Any key to continue... : \c"
        read ff
fi
#---------------------- ch13 -----------------------------------------------------
if [ "x-$choice" = "x-13" ];then
    ksh $WK_SBIN/smenu_rollback_size.sh -us
        echo " "
        echo "\n Press Any key to continue... : \c"
        read ff
fi
#---------------------- ch14 -----------------------------------------------------
if [ "x-$choice" = "x-14" ];then
      echo "\n\n\n\n"
      cat <<EOF
	    This script reports the size of rollbacks.

EOF
        echo " "
        cd $WK_SBIN
        ksh $WK_SBIN/smenu_rollback_size.sh
        echo " "
        echo "\n Press Any key to continue... : \c"
        read ff
fi
#---------------------- ch15 -----------------------------------------------------
if [ "x-$choice" = "x-15" ];then
         ksh $WK_SBIN//smenu_rollback_size.sh -r
         echo " "
      echo "\n Press Any key to continue... : \c"
      read ff
fi
#---------------------- ch16 -----------------------------------------------------
if [ "x-$choice" = "x-16" ];then
        ksh $WK_SBIN/smenu_rollback_size.sh -w
        echo " "
        echo "\n Press Any key to continue... : \c"
        read ff
fi
#---------------------- ch17 -----------------------------------------------------
if [ "x-$choice" = "x-17" ];then
         echo " "
         echo " Program in progress, please wait.... \c"
         ksh $WK_SBIN/smenu_show_redo_logs.ksh
         echo " "
      echo "\n Press Any key to continue... : \c"
      read ff
fi
#---------------------- ch20 -----------------------------------------------------
if [ "x-$choice" = "x-20" ];then
      echo "\n\n\n\n\n\n\n\n"
      cat <<EOF

                 This script will enable you to change the size of your redo logs.
                 You need to be connected in Unix as the owner of the DB. 
                 It is a potential dangerous operation, so we recommand that 
                 you perform a backup (cold) before this operation.
   
                 Read carrefully the script generated and cut and paste 
                 to run each command and check validity. use shotcuts 'rdl' 
                 to see intermediate operation.

EOF
         if $SBINS/yesno.sh "to change the size of you redo logs" DO Y
            then
            ksh $WK_SBIN/smenu_chg_redo_size.sh
         fi 

         echo " Result in SBIN/tmp/change_${ORACLE_SID}_redo_size.sql. "
         echo " Press any key to continue ..."
         read ff
fi
#---------------------- ch7 -----------------------------------------------------
if [ "x-$choice" = "x-30" ];then
        view $WK_SBIN/smenu_roll_trans.txt
fi
#---------------------- Done ----------------------------------------------------
done
