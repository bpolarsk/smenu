#!/bin/sh
# program  "smenu_sub_capture.ksh"
# Bernard Polarski
# 9-Decembre-2005

NN=
NC=
if echo "\c" | grep c >/dev/null 2>&1; then
    NN='-n'
else
    NC='\c'
fi

WK_SBIN=${SBIN}/module3/s8
if [ -f $SBIN/data/stream_$ORACLE_SID.txt ];then
   STRMADMIN=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep STRMADMIN=| cut -f2 -d=`
   STR_PASS=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep STR_PASS=| cut -f2 -d=`
   DEF_SID=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep DEF_SID=| cut -f2 -d=`
fi
STRMADMIN=${STRMADMIN:-STRMADMIN}
STR_PASS=${STR_PASS:-STRMADMIN}
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

#-----------------------------------------------------------------------
function get_db_name
{
  ret=`sqlplus -s $CONNECT_STRING<<EOF
set lines 190 pages 0 feed off verify off pause off
 select value from v\\$parameter  where name='db_name';
EOF`
echo $ret 
}
#-----------------------------------------------------------------------
function get_dblink_name
{
  ret=`sqlplus -s $CONNECT_STRING<<EOF
set lines 190 pages 0 feed off verify off pause off
 select db_link from DBA_db_links where owner=upper('$STRMADMIN');
EOF`
echo $ret 
}
#-----------------------------------------------------------------------
function get_instantiated_object
{
  ret=`sqlplus -s $CONNECT_STRING<<EOF
set lines 190 pages 0 feed off verify off pause off
 select SOURCE_OBJECT_NAME from DBA_APPLY_INSTANTIATED_OBJECTS where SOURCE_OBJECT_OWNER=upper('$1') order by 1 asc;
EOF`
echo $ret 
}
#-----------------------------------------------------------------------
function get_instantiated_schema
{
  ret=`sqlplus -s $CONNECT_STRING<<EOF
set lines 190 pages 0 feed off verify off pause off
select SOURCE_SCHEMA from DBA_APPLY_INSTANTIATED_SCHEMAS ;
EOF`
echo $ret | tr '\n' ' '
}
#-----------------------------------------------------------------------
function get_capture_name
{
  ret=`sqlplus -s $CONNECT_STRING<<EOF
set lines 190 pages 0 feed off verify off pause off
select capture_name from dba_capture ;
EOF`
echo $ret | tr '\n' ' '
}
#-----------------------------------------------------------------------
function get_lg_id
{
  ret=`sqlplus -s $CONNECT_STRING<<EOF
set lines 190 pages 0 feed off verify off pause off
select session# from system.logmnr_session$;
EOF`
echo $ret | tr '\n' ' '

}
#-----------------------------------------------------------------------
LOG_MINER_ID=`get_lg_id`
while true
do
clear

cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/3.8.1
   Last Selection : $LAST_SELECTION
   *************************************************************
     
       STRMADMIN USER                    : $STRMADMIN 
       AVAILABLE Logminer ID             : $LOG_MINER_ID
       Restrict display to ONLY Lg ID    : $DEFAULT_LOGMINER 
 

           --------------------------------------------------------------               -----------------------
              Capture menu                                                              Shortcut at dot prompt
           --------------------------------------------------------------               -----------------------

           1  :  List capture status                                                     cap -l
           2  :  List logminer sessions and the capture it is attached                   cap -ses
           3  :  List capture parameters                                                 cap -prm
           4  :  List capture logminer processes                                         cap -lg
           5  :  Show row Count for all system.logmnr% data dictionary views             cap -gm
           6  :  List Purgeable archives log                                             cap -lrp
           7  :  List archives log present on disk                                       apl -n
           8  :  List minimum requiered archived log                                     cap -la
           9  :  List Tables prepared for instantiation                                  cap -i
          10  :  List rule associate with the capture                                    cap -lr
          11  :  List required checkpoint scn                                            cap -lck
          12  :  Show capture streams execution server stats                             cap -s
          13  :  List List archives with build in dict above first_scn                   cap -lstb
          14  :  display row count in system.logmnr_restart_ckpt$                        cap -cpt

          20  : Instantiate Schema for capture                                           cap -si 
          21  : List lowest scn instantiated for a schema                                cap -min_si
          22  : Abort capture Schema instantiation                                       cap -abort
          23  : Instantiate a table for capture                                          cap -ti
          24  : Shrink system.logmnr_restart_ckpt$                                       cap -shrk
          25  : Export the data dictionary to redo (dbms_capturea_adm.build)             cap -build
        
          
            30     :     Start capture                                                     cap -start
            31     :     Stop  capture                                                     cap -stop
            32     :     Change a capture parameter                                        cap -ret -par -chk -fk 
            33     :     Purge Restart_logmnr_ckpt$ for a given logminer                   cap -pckb


     e ) exit
     r ) restrict queries to a logminer session
%
echo 

echo $NN "  Your choice : $NC"
read choice


if [ "x-$choice" = "x-r" ];then
   echo $NN "Logminer id (select "$LOG_MINER_ID" or blank to unset ) ==> " $NC
 
   read var
   if [ "x-$var" = "x-" ];then

       unset RESTRICT_LG
       unset DEFAULT_LOGMINER
   else
       RESTRICT_LG=" -id  $var"
       DEFAULT_LOGMINER=$var
   fi
fi
if [ "x-$choice" = "x-e" ];then
    break
fi
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
   clear
   ksh $WK_SBIN/smenu_stream_capture.ksh -l  $RESTRICT_LG

   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
   clear
   ksh $WK_SBIN/smenu_stream_capture.ksh -ses
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch3 -----------------------------------------------------
if [ "x-$choice" = "x-3" ];then
   clear
   ksh $WK_SBIN/smenu_stream_capture.ksh -prm
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch4 -----------------------------------------------------
if [ "x-$choice" = "x-4" ];then
   clear
   ksh $WK_SBIN/smenu_stream_capture.ksh -lg
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch5 -----------------------------------------------------
if [ "x-$choice" = "x-5" ];then
   clear
   ksh $WK_SBIN/smenu_stream_capture.ksh -gm
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch6 -----------------------------------------------------
if [ "x-$choice" = "x-6" ];then
   clear
   ksh $WK_SBIN/smenu_stream_capture.ksh -lrp
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch7 -----------------------------------------------------
if [ "x-$choice" = "x-7" ];then
   clear
   ROWNUM=30
   echo $NN "Number of archive to list ($ROWNUM) => " $NC
   read VAR
   if [ ! "x-$VAR" = "x-" ];then
          ROWNUM=$VAR
   fi
   ksh  $SBIN/module3/s2/smenu_show_applied_arc.ksh -n -r $ROWNUM
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch8 -----------------------------------------------------
if [ "x-$choice" = "x-8" ];then
   clear
   ksh $WK_SBIN/smenu_stream_capture.ksh -la $RESTRICT_LG
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch9 -----------------------------------------------------
if [ "x-$choice" = "x-9" ];then
   clear
   ksh $WK_SBIN/smenu_stream_capture.ksh -i $RESTRICT_LG
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch10 ----------------------------------------------------
if [ "x-$choice" = "x-10" ];then
   clear
   ksh $WK_SBIN/smenu_stream_capture.ksh -lr $RESTRICT_LG
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch11 ----------------------------------------------------
if [ "x-$choice" = "x-11" ];then
   clear
   ksh $WK_SBIN/smenu_stream_capture.ksh -lck $RESTRICT_LG
   echo $NN "\n Press Any key to continue... : " $NC
   read ff
fi
#---------------------- ch12 ----------------------------------------------------
if [ "x-$choice" = "x-12" ];then
   clear
   ksh $WK_SBIN/smenu_stream_capture.ksh -s $RESTRICT_LG
   echo $NN "\n Press Any key to continue... : " $NC
   read ff
fi
#---------------------- ch13 ----------------------------------------------------
if [ "x-$choice" = "x-13" ];then
   clear
   ksh $WK_SBIN/smenu_stream_capture.ksh -lstb
   echo $NN "\n Press Any key to continue... : " $NC
   read ff
fi
#---------------------- ch14 ----------------------------------------------------
if [ "x-$choice" = "x-14" ];then
   clear
   ksh $WK_SBIN/smenu_stream_capture.ksh -cpt
   echo $NN "\n Press Any key to continue... : " $NC
   read ff
fi
#---------------------- c20 -----------------------------------------------------
if [ "x-$choice" = "x-20" ];then
   echo
   echo $NN "Schema name to instantiate =>  " $NC
   read SCHEMA_NAME
   if [ -n "$SCHEMA_NAME" ];then
          if $SBINS/yesno.sh "to instantiated for streams, schema $SCHEMA_NAME"
          then
              echo
              echo
              echo "ksh $WK_SBIN/smenu_stream_capture.ksh -si -so $SCHEMA_NAME -x "  
              ksh $WK_SBIN/smenu_stream_capture.ksh -si -so $SCHEMA_NAME   -x
          fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- c21 -----------------------------------------------------
if [ "x-$choice" = "x-21" ];then
   echo
   VAR=`get_instantiated_schema`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      SCHEMA_NAME=$VAR  
   else
     PS3=' Select schema name  ==> '
     select SCHEMA_NAME in $VAR"Cancel"
       do
            break
       done
   fi
   if [ -n "$SCHEMA_NAME" ];then
       if [ ! "$SCHEMA_NAME" = "Cancel" ];then
              ksh $WK_SBIN/smenu_stream_capture.ksh -min_si -u $SCHEMA_NAME  -x
      fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi
          
#---------------------- c22 -----------------------------------------------------
if [ "x-$choice" = "x-22" ];then
   echo
   VAR=`get_instantiated_schema`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      SCHEMA_NAME=$VAR  
   else
     PS3=' Select schema name  ==> '
     select SCHEMA_NAME in $VAR"Cancel"
       do
            break
       done
   fi
   if [ -n "$SCHEMA_NAME" ];then
       if [ ! "$SCHEMA_NAME" = "Cancel" ];then
          if $SBINS/yesno.sh "to abort instantiation for schema $SCHEMA_NAME"
             then
              echo
              echo
              echo "ksh $WK_SBIN/smenu_stream_capture.ksh -abort -so $SCHEMA_NAME  -x"
              ksh $WK_SBIN/smenu_stream_capture.ksh -abort -so $SCHEMA_NAME  -x
          fi
       fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- c23 -----------------------------------------------------
if [ "x-$choice" = "x-23" ];then
   clear
   cat <<EOF
    
    Instantiate a table
   -----------------------------

   This action is done on the apply site but records also information on the capture site. 

   It consists in registering at the apply site an SCN for the object (object is on capture 
   site).  Usually the SCN is the Current SCN at capture site at the moment when the function 
   is executed.  It is possible to set an older SCN also. No mutation for this object will be 
   replicated for SCN lower than this cut-off SCN.

   In order to achive this remote initialisation, the following components must be gathered
         
       - local current SCN
       - db link to remote DB
       - source owner.table 
       - source db name

  Note that the $source_owner.source_object does not necessary needs to exist on the apply 
  site as it is on the source site. The LCR containing rows mutations, may be intercepted  by 
  transformation functions. But the transformation function needs to know if the LCR they are 
  working on is to be considered or not. This is done by comparing the SCN associated with 
  the LCR to the SCN initialised.

  The purpose of a Streams object intantiation is to send to apply site the starting SCN of 
  the object at capture site. The info is stored in the table SYSTEM.LOGMNRC_GTLO on both 
  capture site and apply site. 

EOF
   echo
   echo $NN "Schema name  =>  " $NC
   read SCHEMA_NAME
   var=`get_instantiated_object $SCHEMA_NAME `
   PS3='Select a table to instantiate ==>'
   select TABLE_NAME in $var
     do
       break
   done
   PS3='Select a db link  ==> '
   echo
   var=`get_dblink_name` 
   select DB_LINK in $var 
           do 
       break
    done
   echo
   SOURCE_SID=`get_db_name`
   echo $NN "Select a source SID [ $SOURCE_SID ] ==> " $NC
   unset var
   read var
   if [ -n "$var" ];then
      SOURCE_SID=$var
   fi    
   echo
   if [ -n "$SCHEMA_NAME" ];then
          if $SBINS/yesno.sh "to instantiated for streams \"$SCHEMA_NAME.$TABLE_NAME\", source SID \"$SOURCE_SID\" using db link \"$DB_LINK\""
          then
              echo
              echo
              echo "ksh $WK_SBIN/smenu_stream_capture.ksh -ti -so $SCHEMA_NAME -t $TABLE_NAME -dblk $DB_LINK -src_sid $SOURCE_SID"
              ksh $WK_SBIN/smenu_stream_capture.ksh -ti -so $SCHEMA_NAME -t $TABLE_NAME -dblk $DB_LINK -src_sid $SOURCE_SID   -strmadmin $STRMADMIN
              ksh $WK_SBIN/smenu_stream_capture.ksh -ti -so $SCHEMA_NAME -t $TABLE_NAME -dblk $DB_LINK -src_sid $SOURCE_SID   -x -strmadmin $STRMADMIN
          fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch24 ----------------------------------------------------
if [ "x-$choice" = "x-24" ];then
   clear
   ksh $WK_SBIN/smenu_stream_capture.ksh -shrk
   echo $NN "\n Press Any key to continue... : " $NC
   read ff
fi
#---------------------- ch25 ----------------------------------------------------
if [ "x-$choice" = "x-25" ];then
   clear
   ksh $WK_SBIN/smenu_stream_capture.ksh -build 
   ksh $WK_SBIN/smenu_stream_capture.ksh -build -x
   echo $NN "\n Press Any key to continue... : " $NC
   read ff
fi
#---------------------- ch30 -----------------------------------------------------
if [ "x-$choice" = "x-30" ];then
   echo
   VAR=`get_capture_name`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      CAPTURE_NAME=$VAR  
   else
     PS3=' Select capture  ==> '
     select CAPTURE_NAME in $VAR"Cancel"
       do
            break
       done
   fi
   if [ -n "$CAPTURE_NAME" ];then
       if [ ! "$CAPTURE_NAME" = "Cancel" ];then
          ksh $WK_SBIN/smenu_stream_capture.ksh -start $CAPTURE_NAME -x
       fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch31 -----------------------------------------------------
if [ "x-$choice" = "x-31" ];then
   echo
   VAR=`get_capture_name`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      CAPTURE_NAME=$VAR  
   else
     PS3=' Select capture  ==> '
     select CAPTURE_NAME in $VAR"Cancel"
       do
            break
       done
   fi
   if [ -n "$CAPTURE_NAME" ];then
       if [ ! "$CAPTURE_NAME" = "Cancel" ];then
          ksh $WK_SBIN/smenu_stream_capture.ksh -stop $CAPTURE_NAME -x
       fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch32 -----------------------------------------------------
if [ "x-$choice" = "x-32" ];then
   echo
   VAR=`get_capture_name`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      CAPTURE_NAME=$VAR  
   else
     PS3=' Select capture  ==> '
     select CAPTURE_NAME in $VAR"Cancel"
       do
            break
       done
   fi
   if [ -n "$CAPTURE_NAME" ];then
       if [ ! "$CAPTURE_NAME" = "Cancel" ];then
          echo 
          echo
          PS3=' ==>  Select parameter to change : '
          select PAR in checkpoint_retention_time parallelism checkpoint_force checkpoint_frequency
          do
            break
          done
          echo $NN  " ==>  New Value                  :" $NC
          unset new_value
          read new_value
          case $PAR in 
               'checkpoint_retention_time' )   ksh $WK_SBIN/smenu_stream_capture.ksh -cn $CAPTURE_NAME -ret $new_value  -x 
                                               echo " "
                                               echo "--------------------------------------------------"
                                               echo "Use cap -lck or sm/3.8.11 to display the new value"
                                               echo "--------------------------------------------------"
                                               echo " "
                                               ;;
               'parallelism'               )   ksh $WK_SBIN/smenu_stream_capture.ksh -cn $CAPTURE_NAME -par $new_value -x ;;
               'checkpoint_force'          )   ksh $WK_SBIN/smenu_stream_capture.ksh -cn $CAPTURE_NAME -fk  -x  ;;
               'checkpoint_frequency'      )   ksh $WK_SBIN/smenu_stream_capture.ksh -cn $CAPTURE_NAME -chk $new_value  ;;
          esac
       fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch33 -----------------------------------------------------
if [ "x-$choice" = "x-33" ];then
   echo
   VAR=`get_capture_name`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      CAPTURE_NAME=$VAR  
   else
     PS3=' Select capture  ==> '
     select CAPTURE_NAME in $VAR"Cancel"
       do
            break
       done
   fi
   if [ -n "$CAPTURE_NAME" ];then
       if [ ! "$CAPTURE_NAME" = "Cancel" ];then
          ksh $WK_SBIN/smenu_stream_capture.ksh -pckp -cn $CAPTURE_NAME  -x
       fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- Done ----------------------------------------------------
done
