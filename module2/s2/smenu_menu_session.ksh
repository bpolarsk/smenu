#!/usr/bin/ksh
# program 
# Bernard Polarski, Didier Barjasse
#set -xv
WK_SBIN=$SBIN/module2/s2
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`

while true
do
clear
cat <<%
                 

   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/2.2
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *             Database Users sessions maintenance           *
   *                                                           *
   *************************************************************

      
        Users info :
        -------------
          1  : 
          2  : Top 20 CPU Utilized Sessions
          3  : Sessions generic overview
          4  : Session activity
          5  : 
          6  : View Session IO + objects accessed
          7  : Kill session
          8  : Show session hit
          9  : Which session is sorting
         10  : Session in fail over mode (8i+)
         12  : Display Session, with sql figures  (sq)
         13  : display Sql for username 
         14  : Display Sql, with Text and figures  (sqt)
         15  : Explain plan for an SQL file
         16  : View Open cursors in system plus stats
         17  : Suspend a session
         18  : Resume a session


         Script Generation :
         -------------------
          20 : Gen a create user script preserving actual passwd

  e ) exit

%
echo $NN "  Your choice : $NC"
read choice


if [ "$choice" = "e" ];then
    break
fi
 
#---------------------- ch1 -----------------------------------------------------
if [ "$choice" = "1" ];then
:
#---------------------- ch2 -----------------------------------------------------
elif [ "$choice" = "2" ];then
   $WK_SBIN/smenu_db_top_session2.sh
   echo $NN "\n Press Any key to continue... : $NC"
   read ff 
#---------------------- ch3 -----------------------------------------------------
elif [ "$choice" = "3" ];then
      clear
      cat <<EOF
           Produce info on the session of the current SID
           (Shortcut : cs )

EOF
         echo " "
         echo " Program in progress, please wait.... "
         echo " --------------------------------------------------------------"
         echo " "
         $WK_SBIN/smenu_sessions_overview.sh  
         echo " "
         echo " --------------------------------------------------------------"
         echo " "
      echo $NN "\n Press Any key to continue... : $NC"
      read ff 
fi
#---------------------- ch4 ----------------------------------------------------
if [ "$choice" = "4" ];then
      clear
      cat <<EOF
           Produce info for a given session.
	   Run Sessions overview to get the sessions info
           (Shortcut : ca <session_id_num>)

EOF
         echo " "
         echo " Program in progress, please wait.... "
         echo " --------------------------------------------------------------"
         echo $NN " Session ID ==> $NC"
         read SESS_ID
         $WK_SBIN/smenu_session_activity.sh  $SESS_ID
         echo " "
         echo " --------------------------------------------------------------"
         echo " "
      echo $NN "\n Press Any key to continue... : $NC"
      read ff 
fi
#---------------------- ch5 -----------------------------------------------------
if [ "$choice" = "5" ];then
:
#---------------------- ch6 -----------------------------------------------------
elif [ "$choice" = "6" ];then
      clear
      cat <<EOF

            List IO and abject accessed  by a session
EOF
         echo " --------------------------------------------------------------"
         echo $NN " Session sid : $NC "
         read sid
         $WK_SBIN/smenu_sessions_overview.sh -io $sid
         echo " "
         echo " --------------------------------------------------------------"
         echo " "
      echo $NN "\n Press Any key to continue... : $NC"
      read ff 
fi
#---------------------- ch7 -----------------------------------------------------
if [ "$choice" = "7" ];then
     cat <<EOF
            This option enable you to kill a session. You must provide an SID first
            and them confirm the kill. Press <enter> to cancel. Shortcut : ks
            Use Session overview to get the proper SID.

EOF
    echo $NN " PID to kill ==> $NC"
    read  PID
    if [ ! "$PID" = "" ];then
       $WK_SBIN/smenu_kill_session.sh $PID
       echo $NN "\n Press Any key to continue... : $NC"
       read ff 
    fi
fi
#---------------------- ch8 -----------------------------------------------------
if [ "$choice" = "8" ];then
      $WK_SBIN/smenu_sessions_overview.sh -l
      echo $NN " Press Any key to continue... : $NC"
      read ff 
fi
#---------------------- ch20 -----------------------------------------------------
if [ "$choice" = "20" ];then
	    cat <<-EOF
              This Script create an SQL to re-create the users, default tablespace,
	      temporary tablespace and default tables space. No grants, no roles.
              May be used before partial import. Result in $SBIN/tmp
EOF
       echo " "
        $SBIN/module2/s1/smenu_view_archive_mode.sh -pwd
       echo " "
       echo $NN " Press Any key to continue... : $NC"
       read ff
fi
#---------------------- ch11 -----------------------------------------------------
#---------------------- ch9 -----------------------------------------------------
if [ "$choice" = "9" ];then
        $WK_SBIN/smenu_handle.ksh -s
        echo $NN " Press Any key to continue... : $NC"
        read ff
#---------------------- ch10 -----------------------------------------------------
elif [ "$choice" = "10" ];then
        $WK_SBIN/smenu_get_sql_figures.sh -f
        echo $NN " Press Any key to continue... : $NC"
        read ff
#---------------------- ch 11 -------------------------------------------
#---------------------- ch 12 -------------------------------------------
elif [ $choice -eq 12 ];then
   $WK_SBIN/smenu_get_sql_figures.sh
   echo "Press Any key to continue"
   read ff
#---------------------- ch 13 -------------------------------------------
elif [ $choice -eq 13 ];then
   $WK_SBIN/smenu_get_sql_sid.sh
   echo "Press Any key to continue"
   read ff
#---------------------- ch 14 -------------------------------------------
elif [ $choice -eq 14 ];then
   $WK_SBIN/smenu_get_sql_sid_text.sh
   echo "Press Any key to continue"
   read ff
#---------------------- ch 15 -------------------------------------------
elif [ $choice -eq 15 ];then
   cat <<EOF

        This procedure enable you to give a user and sql location. 
        You will obtain in retrun the explain plan for the execution


EOF
   $WK_SBIN/smenu_explain_plan.sh
   echo "Press Any key to continue"
   read ff

#---------------------- ch 16 -------------------------------------------
elif  [ $choice -eq 16 ];then
     ${WK_SBIN}/smenu_handle.sh 
     echo " Press Any key to continue... : "
     read ff    
#---------------------- ch7 -----------------------------------------------------
elif [ "$choice" = "17" ];then
     cat <<EOF
            This option enable you to suspend a session. You must provide an SID first
            and them confirm the suspend. Press <enter> to cancel. Shortcut : 'ssp'
            Use Session overview ('sl') to get the proper SID.

EOF
    echo $NN " PID to suspend ==> $NC"
    read  PID
    $WK_SBIN/smenu_sessions_overview.sh -sup $PID s
    echo " Press Any key to continue... : "
    read ff 
#---------------------- chi18 -----------------------------------------------------
elif [ "$choice" = "18" ];then
     cat <<EOF
            This option enable you to suspend a session. You must provide an SID first
            and them confirm the suspend. Press <enter> to cancel. Shortcut : 'ssp'
            Use Session overview ('sl') to get the proper SID.

EOF
    echo $NN " PID to resume ==> $NC"
    read  PID
    $WK_SBIN/smenu_sessions_overview.sh -sup $PID r
    echo $NN "\n Press Any key to continue... : $NC"
    read ff 
#---------------------- Done --------------------------------------------
fi
done
