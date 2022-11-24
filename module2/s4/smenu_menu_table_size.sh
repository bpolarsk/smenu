#!/usr/bin/ksh
# program smenu_siz.sh
# Author Bernard Polarski : 21-04-1999
#set -xv
SBIN2=${SBIN}/module2
WK_SBIN=$SBIN2/s4
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
while true
  do
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/2.4
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *               Table, index and constraints                *
   *                                                           *
   *************************************************************
      

         1  :  reports table info
         2  :  Report all tables sizes of a schema
         3  :  Report all index for a table
         4  :  List indexes, index extents & size of a table 
         5  :  Report extents and index size
         7  :  Analyse schema
         8  :  Unload a table to Ascii file (generate ctl & par)
         9  :  List Index Heigth and % occupancy for schema
        10  :  List Index Heigth and % occupancy for 1 index
        12  :  
        13  :  Quick desc tables, views and clusters
        14  :  Quick select tables, views &  X\$tables 
        15  :  Quick source views for v\$views
        16  :  Show extents mapping for a given datafile
        17  :  Analyze DB 
        18  :  Calculate & Rebuild index per /tbs/user/index name



        e ) exit


%
echo "  Your choice : \c"
read choice
LAST_SELECTION=$choice

if [ "x-$choice" = "x-e" ];then
    break
fi
#---------------------- ch1 -----------------------------------------------------
# 59 lines
if [ "x-$choice" = "x-1" ];then
      unset table_name
      echo "\n"
      echo "  Table name  ===> \c"
      read table_name
      ksh $WK_SBIN/smenu_desc_table.ksh -t $table_name
      echo " "
      echo "\n Press Any key to continue... : \c"
      read ff 
fi
#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
      echo "\n"
      unset user_name
      echo "  Schema name  ===> \c"
      read user_name
      echo " "
      ksh $WK_SBIN/smenu_desc_table.ksh -u $user_name
      echo " "
      echo "\n Press Any key to continue... : \c"
      read ff 
fi
#---------------------- ch3 -----------------------------------------------------
if [ "x-$choice" = "x-3" ];then
      unset user_name
      unset table_name
      echo "\n"
      echo "  Schema name  ===> \c"
      read user_name
      echo "  Table name  ===> \c"
      read table_name
      echo " "
      ksh $WK_SBIN/smenu_desc_idx.ksh -u $user_name -t $table_name
      echo " "
      echo "\n Press Any key to continue... : \c"
      read ff 
fi
#---------------------- ch4 -----------------------------------------------------
if [ "x-$choice" = "x-4" ];then
      echo "\n\n\n\n"
      cat <<EOF

            This script 'nisiz' reports stats for any index.

            You can also launch it directly  :

                idx -i INDEX_NAME 

            Press <Enter> to accept default value
 
EOF
      echo "\n"
      echo "  index name  ===> \c"
      read index_name
      echo " "
      $SBINS/smenu_desc_idx.ksh -i $index_name $GEN_REPORT 
      echo " "
      echo "\n Press Any key to continue... : \c"
      read ff 
fi
#---------------------- ch5 -----------------------------------------------------
if [ "x-$choice" = "x-5" ];then
      echo "\n\n\n\n"
      cat <<EOF
            This script (shortcut : 'idx') reports stats for all index in a schema : 

                idx -u OWNER_NAME 

 
EOF
      echo "\n"
      echo "  Schema name  ===> \c"
      read user_name
      echo " "
      $WK_SBIN/smenu_desc_idx.ksh -u $user_name 
      echo " "
      echo "\n Press Any key to continue... : \c"
      read ff 
fi
#---------------------- ch7 -----------------------------------------------------
if [ "x-$choice" = "x-7" ];then
      echo "\n\n\n\n"
      cat <<EOF
            This script (shortcut : 'ans') analyse all tables in a schema : 

                ans OWNER_NAME 
 
EOF
      echo "\n"
      echo "  Schema name  ===> \c"
      read user_name
      echo " "
      $WK_SBIN/smenu_analyse_schema.sh $user_name 
      echo " "
      echo "\n Press Any key to continue... : \c"
      read ff 
fi
#---------------------- ch8 -----------------------------------------------------
if [ "x-$choice" = "x-8" ];then
      echo "\n\n\n\n"
      cat <<EOF
            This script download a table to a flat file.
            I also generate a control file and a par file 
            for the reload

EOF
      $WK_SBIN/smenu_dump_table_to_asci.sh
      echo " "
      echo "\n Press Any key to continue... : \c"
      read ff 
fi
#---------------------- ch9 -----------------------------------------------------
if [ "x-$choice" = "x-9" ];then
      echo "\n\n\n\n"
      cat <<EOF
            This script (shortcut : 'nisb') reports stats for all index in a schema : 

                -Index size
                -Index height
                -Number of rows 
                -Number of deleted 
                -Table total size.
                -Owner [ only when same table in multiple shcema]

            You can also launch it directly  :

                nisb [OWNER] [B] [K] [M] [G]

                     B=Bytes K=Kilobytes M=Megs G=Gigs

 
EOF
      echo "\n"
      echo "  Schema name  ===> \c"
      read user_name
      echo "  Progam in progress... Please wait."
      $SBIN/nisb $user_name 
      echo " "
      echo "\n Press Any key to continue... : \c"
      read ff 
fi
#---------------------- ch10 -----------------------------------------------------
if [ "x-$choice" = "x-10" ];then
      echo "\n\n\n\n"
      cat <<EOF
            This script (shortcut : 'nisb') reports stats for 1 index in a schema : 

                -Index size
                -Index height
                -Number of rows 
                -Number of deleted 
                -Table total size.

            You can also launch it directly using the shortcuts :

                nisb [INDEX_NAME] [B] [K] [M] [G]

                     B=Bytes K=Kilobytes M=Megs G=Gigs

 
EOF
      echo "\n"
      echo "  Index name  ===> \c"
      read index_name
      echo "  Progam in progress... Please wait."
      $SBIN/nisu $index_name 
      echo " "
      echo "\n Press Any key to continue... : \c"
      read ff 
fi
#---------------------- ch11 -----------------------------------------------------
if [ "x-$choice" = "x-11" ];then
      echo "\n Press Any key to continue... : \c"
      read ff
fi
#---------------------- ch12 -----------------------------------------------------
if [ "x-$choice" = "x-12" ];then
      echo " "
      echo "\n Press Any key to continue... : \c"
      read ff
fi
#---------------------- ch13 -----------------------------------------------------
if [ "x-$choice" = "x-13" ];then
      cat <<EOF
            This script (shortcut : 'qdk') run a describe for the select user & object:

                 qdk -t
                 qdk -v
                 qdk -c
    
                    -t : Describe tables
                    -v : Describe views
                    -c : Describe clusters


EOF
      echo type [t,v,c]
      read ttype
      $WK_SBIN/smenu_quick_desc.sh -$ttype
      echo " "
      echo "\n Press Any key to continue... : \c"
      read ff
fi
#---------------------- ch14 -----------------------------------------------------
if [ "x-$choice" = "x-14" ];then
      cat <<EOF
            This script (shortcut : 'qds') run a select count(1) for the selected
            user.objcts to show the number of records in object, and then proposes
            to perform either : 

                          select * from user.object 
                    or
                          select * from user.object where rownum < 10


                 qdk -t
                 qdk -v
                 qdk -c
                 qdk -x
    
                    -t : Select on tables
                    -v : Select on views
                    -c : Select on clusters
                    -x : Select on X$tables


EOF
      echo type [t,v,c,x]
      read ttype
      $SBINS/qds -$ttype
      echo " "
      echo "\n Press Any key to continue... : \c"
      read ff
fi
#---------------------- ch15 -----------------------------------------------------
if [ "x-$choice" = "x-15" ];then
      $SBINS/qdv
      echo " "
      echo "\n Press Any key to continue... : \c"
      read ff
fi
#---------------------- ch16 -----------------------------------------------------
if [ "x-$choice" = "x-16" ];then
      echo "File ID ==> \c"
      read ID
      $WK_SBIN/smenu_mapx.sh $ID
      echo " "
      echo "\n Press Any key to continue... : \c"
      read ff
fi
#---------------------- ch17 -----------------------------------------------------
if [ "x-$choice" = "x-17" ];then
      $WK_SBIN/smenu_analyse_db.sh -I
      echo " "
      echo "\n Press Any key to continue... : \c"
      read ff
fi
#---------------------- ch18 -----------------------------------------------------
if [ "x-$choice" = "x-18" ];then
      cat << EOF

          This script calculatge new storage for your indexes. 
          You can select your index, by name, by owner, by tablespace

          This scripts is also available as shortcut :


          Usage : rblx   -e <number of extents>  -n -u  USER  -i INDEX NAME  -t TABLESPACE -x
 

                 -e : index with min number of extents  to rebuild [default : 2]
                 -i : Index name to rebuild, 'ALL' to select all index of this user
                 -t : Rebuild all index in this tablespace 
                 -n : Rebuild Unrecoverable
                 -r : Rebuild recoverable
                 -u : Owner name
                 -x : Execute automatically at the end [default is no] 

         NOTES : type rblx -e 1  to rebuild all index, including those with only one extent.
               : -t and (-u or -i) are exclusives.

         This command generates an rblx_{SID}.sql file in SBIN/tmp

         When the scripts in its turn is executed, it generates a log file in /opt/oracle/7.3.4/util/smenu/tmp
         rblx_idx_{TABLESPACE}.log or rblx_idx_{OWNER}.log


         Use this script in conjunction with 'nisb','nish', map -i
 

EOF

      echo "   Tablespace [<Enter> if you prefer to work per user ] ==> \c"
      read TBS
      if [ ! "x-$TBS" =  "x-" ];then
         ARGS=" -t $TBS"
      else 
           echo "   User       [<Enter> to enter menu] ==> \c"
           read USR
           echo "   Index name [ Index name or press enter ] ==> \c"
           read IDX
           ARGS=" -u  $USR"
           if [ ! "x-$IDX" = "x-" ];then
              ARGS=${ARGS}" -i $IDX"
           fi
      fi
      echo "   Process only index with min nbr. extents [0] ==> \c"
      read EXT
      echo "   Rebuild indexes unrecoverable [N] ==> \c"
      read REC
      if [ ! "x-$EXT" =  "x-" ];then
         ARGS=${ARGS}" -e $EXT"
      fi
      if [ ! "x-$REC" =  "x-" ];then
         ARGS=${ARGS}" -n "
      fi
      $WK_SBIN/smenu_rebuild_idx.sh  $ARGS
      echo " "
      echo "\n Press Any key to continue... : \c"
      read ff
fi
#---------------------- Done -----------------------------------------------------
done
