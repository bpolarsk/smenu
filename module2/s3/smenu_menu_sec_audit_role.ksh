#!/usr/bin/ksh
# program 
# Bernard Polarski
# 06-June-2005

WK_SBIN=${SBIN}/module2/s3
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
while true
do
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/2.3
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                  Role, audit & quotas                     *
   *                                                           *
   *************************************************************
      

           Quota :
           -----------------
             1  :  Display Quota per user
             2  :  List user quotas for each tablespace
             3  :  Show user occupancy per tablespace
  
           Audit :
           -----------------
             4  :  Show audit parameters
             5  :  List audit active in Database

           Role & security :
           -----------------
             6  :  Display user with SYSDBA/SYSOPR privilige (pwfile_users)
             7  :  List profiles attributes
             8  :  Roles in the database
             9  :  Roles by Users on the database ( list by user)
            10  :  role/user distribution  (all)
            11  :  System Privilege for a User on the database
            12  :  Objects privilege for a single User or Role 
            14  :  System privileges for a User or Role 
            15  :  List all system privileges

       Script Generation :
       -------------------
        21  : Script to create a specific User with his System Privileges and Roles



     e ) exit



%
echo $NN "  Your choice : $NC"
read choice


if [ "x-$choice" = "x-e" ];then
    break
fi
 
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
    ksh $WK_SBIN/smenu_report_user_ts_quota.ksh
    echo $NN " Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
    ksh $WK_SBIN/smenu_report_ts_user_quota.ksh
    echo $NN " Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch3 -----------------------------------------------------
if [ "x-$choice" = "x-3" ];then
    ksh $SBIN/module2/s5/smenu_free_space_summary.ksh -dus
    echo $NN " Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch4 -----------------------------------------------------
if [ "x-$choice" = "x-4" ];then
    ksh $WK_SBIN/smenu_list_audit_on.ksh -prm
    echo $NN " Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch5 -----------------------------------------------------
if [ "x-$choice" = "x-5" ];then
    ksh $WK_SBIN/smenu_list_audit_on.ksh
    echo $NN " Press Any key to continue... : $NC"
    read ff
fi
#---------------------- ch6 -----------------------------------------------------
if [ "x-$choice" = "x-6" ];then
   ksh $WK_SBIN/smenu_check_sysdba.ksh
   echo $NN " Press Any key to continue... : $NC"
   read ff
fi
#---------------------- ch7 -----------------------------------------------------
if [ "x-$choice" = "x-7" ];then
    ksh $WK_SBIN/smenu_list_profile_attribute.ksh
    echo $NN " Press Any key to continue... : $NC"
    read ff
fi

#---------------------- ch8 -----------------------------------------------------
if [ "x-$choice" = "x-8" ];then
      ksh $WK_SBIN/smenu_db_role.sh -l
      echo " "
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch9 -----------------------------------------------------
if [ "x-$choice" = "x-9" ];then
      cat <<EOF
	    This script reports all the roles of all the users for the instance $ORACLE_SID

            Result in SMENU/tmp
EOF
        echo " "
        cd $WK_SBIN
        $WK_SBIN/smenu_db_role.sh -u
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
        read ff
fi

#---------------------- ch10 -----------------------------------------------------
if [ "x-$choice" = "x-10" ];then
        echo " "
        cd $WK_SBIN
        $WK_SBIN/smenu_db_role.sh -r
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
        read ff
fi
#---------------------- ch11 -----------------------------------------------------
if [ "x-$choice" = "x-11" ];then
        echo " "
        cd $WK_SBIN
        echo $NN " User/role => $NC"
        read REP
        $WK_SBIN/smenu_db_role.sh -s  $REP
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
        read ff
fi

#---------------------- ch12 -----------------------------------------------------
if [ "x-$choice" = "x-12" ];then
      cat <<-EOF
	    This script reports all the objects privilege of a specific user or role for the instance $ORACLE_SID
            Result in SMENU/tmp
EOF
        echo $NN " User/role => $NC"
        read REP
        cd $WK_SBIN
        $WK_SBIN/smenu_db_role.sh -o  $REP
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
        read ff
fi
#---------------------- ch13 -----------------------------------------------------
if [ "x-$choice" = "x-13" ];then
      cat <<-EOF
	    This script reports all the objects / privileges of a 
            specific user or role for the instance $ORACLE_SID
            Result in SMENU/tmp
EOF
        echo " "
        cd $WK_SBIN
        echo $NN " User => $NC"
        read REP
         $SBIN/module2/s3/smenu_db_role.sh -o $REP
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
        read ff
fi

#---------------------- ch14 -----------------------------------------------------
if [ "x-$choice" = "x-14" ];then
      cat <<-EOF
            Report System Privilege and System Role  for a User/Role on the database
            Result in SMENU/tmp
EOF
        echo " "
        echo $NN " User => $NC"
        read REP
        cd $WK_SBIN
        $WK_SBIN/smenu_db_role.sh -s  $REP
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
        read ff
fi
#---------------------- ch15 -----------------------------------------------------
if [ "x-$choice" = "x-15" ];then
        cd $WK_SBIN
        ksh $WK_SBIN/smenu_db_role.sh -smap
        echo $NN " Press Any key to continue... : $NC"
        read ff
fi
#---------------------- ch21 -----------------------------------------------------
if [ "x-$choice" = "x-21" ];then
      cat <<-EOF
            Generate Script to create a specific User with his System Privileges and Roles
            Result in SMENU/tmp
EOF
        echo " "
        cd $WK_SBIN
        $WK_SBIN/smenu_gen_user_privs_for_one_user.sh
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
        read ff
fi
#---------------------- ch22 -----------------------------------------------------
#---------------------- Done ----------------------------------------------------
done
