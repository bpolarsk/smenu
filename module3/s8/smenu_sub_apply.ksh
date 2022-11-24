#!/bin/sh
# program  "smenu_sub_apply.ksh"
# Bernard Polarski
# initial    :  9-Dec-2005
# redisigned : 19-Jun-2008

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
function get_source_database
{
  ret=`sqlplus -s "$CONNECT_STRING"<<EOF
set lines 190 pages 0 feed off verify off pause off
 select source_database from DBA_STREAMS_RULES where RULE_TYPE= 'DML' and  streams_name = '$1' ;
EOF`
echo $ret
}
#-----------------------------------------------------------------------
function get_table_name
{
  ret=`sqlplus -s "$CONNECT_STRING"<<EOF
set lines 190 pages 0 feed off verify off pause off
 select TABLE_NAME from DBA_TABLES where OWNER=upper('$1') order by 1 asc;
EOF`
echo $ret| tr '\n' ' '
}
#-----------------------------------------------------------------------
function get_apply_name
{
  ret=`sqlplus -s "$CONNECT_STRING"<<EOF
set lines 190 pages 0 feed off verify off pause off
select apply_name from dba_apply;
EOF`
echo $ret | tr '\n' ' '
}
#-----------------------------------------------------------------------


while true
do
clear

cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/3.8.2
   Last Selection : $LAST_SELECTION
   *************************************************************
     
             STRMADMIN USER                    : $STRMADMIN



           --------------------------------------------------------------               -----------------------
               Apply  menu                                                              Shortcut at dot prompt
           --------------------------------------------------------------               -----------------------

             1  :  List apply process                                                    app -l
             2  :  List reader process                                                   app -r
             3  :  List coordinator process                                              app -c
             4  :  List apply server process                                             app -s
             5  :  Show parameter for apply processes                                    app -prm
             6  :  List apply process with full rule                                     app -lr
             7  :  Show latency between source and apply                                 app -lat
             8  :  Show apply errors counts                                              app -erc
             9  :  List apply errors                                                     app -err
            10  :  Show instantiated objects                                             app -i
            11  :  List objects with apply on them                                       app -o
            12  :  List object in local streams data dictionary and their SCN            app -li
            13  :  List instantiated schema                                              app -lo
            14  :  Show applied scn                                                      app -as
            15  :  List dml apply handler                                                app -dmlh

            20     : Delete all apply errors for an apply                                app -delerr
            21     : Re-execute one or all errors for an apply                           app -xerr
            22     : Remove/set apply schema instantiated SCN                            app -si
            23     : Remove/set apply table  instantiated SCN                            app -ti

            30     :     Start Apply                                                     app -start
            31     :     Stop  Apply                                                     app -stop
            32     :     Change Apply parameter                                          app 

     e ) exit
%
echo 
echo "  Your choice : \c"
read choice


if [ "x-$choice" = "x-e" ];then
    break
fi
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
   ksh $WK_SBIN/smenu_stream_apply.ksh -l
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
   ksh $WK_SBIN/smenu_stream_apply.ksh -r
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch3 -----------------------------------------------------
if [ "x-$choice" = "x-3" ];then
   ksh $WK_SBIN/smenu_stream_apply.ksh -c
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch4 -----------------------------------------------------
if [ "x-$choice" = "x-4" ];then
   ksh $WK_SBIN/smenu_stream_apply.ksh -s
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch5 -----------------------------------------------------
if [ "x-$choice" = "x-5" ];then
   ksh $WK_SBIN/smenu_stream_apply.ksh -prm
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch6 -----------------------------------------------------
if [ "x-$choice" = "x-6" ];then
   ksh $WK_SBIN/smenu_stream_apply.ksh  -lr
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch7 -----------------------------------------------------
if [ "x-$choice" = "x-7" ];then
   ksh $WK_SBIN/smenu_stream_apply.ksh -lat
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch8 -----------------------------------------------------
if [ "x-$choice" = "x-8" ];then
   ksh $WK_SBIN/smenu_stream_apply.ksh -erc
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch9 -----------------------------------------------------
if [ "x-$choice" = "x-9" ];then
   ksh $WK_SBIN/smenu_stream_apply.ksh -err
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch10 -----------------------------------------------------
if [ "x-$choice" = "x-10" ];then
   ksh $WK_SBIN/smenu_stream_apply.ksh -i
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch11 -----------------------------------------------------
if [ "x-$choice" = "x-11" ];then
   ksh $WK_SBIN/smenu_stream_apply.ksh -o
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch12 -----------------------------------------------------
if [ "x-$choice" = "x-12" ];then
   ksh $WK_SBIN/smenu_stream_apply.ksh -li
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch13 -----------------------------------------------------
if [ "x-$choice" = "x-13" ];then
   ksh $WK_SBIN/smenu_stream_apply.ksh -lo
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch14 -----------------------------------------------------
if [ "x-$choice" = "x-14" ];then
   ksh $WK_SBIN/smenu_stream_apply.ksh -as
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch15 -----------------------------------------------------
if [ "x-$choice" = "x-15" ];then
   ksh $WK_SBIN/smenu_stream_apply.ksh -dmlh
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch20 -----------------------------------------------------
if [ "x-$choice" = "x-20" ];then
   echo
   VAR=`get_apply_name`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      APPLY_NAME=$VAR
   else
     PS3=' Select Apply  ==> '
     select APPLY_NAME in $VAR"Cancel"
       do
            break
       done
   fi
   if [ -n "$APPLY_NAME" ];then
       if [ ! "$APPLY_NAME" = "Cancel" ];then
           echo " $WK_SBIN/smenu_stream_apply.ksh -delerr $APPLY_NAME -x"
           ksh $WK_SBIN/smenu_stream_apply.ksh -delerr $APPLY_NAME -x
       fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch21 -----------------------------------------------------
if [ "x-$choice" = "x-21" ];then
   echo
   VAR=`get_apply_name`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      APPLY_NAME=$VAR
   else
     PS3=' Select Apply  ==> '
     select APPLY_NAME in $VAR"Cancel"
       do
            break
       done
   fi
   unset var
   echo $NN " Transaction ID to re-execute:  [Enter for ALL or give TXID ] ==> " $NC
   read var
   if [ -n "$var" ];then
       TXID=" -tx $var"
   fi
   if [ -n "$APPLY_NAME" ];then
       if [ ! "$APPLY_NAME" = "Cancel" ];then
           echo " $WK_SBIN/smenu_stream_apply.ksh -delerr $APPLY_NAME $TXID -x"
           ksh $WK_SBIN/smenu_stream_apply.ksh -xerr $APPLY_NAME $TXID -x
       fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch22 -----------------------------------------------------
if [ "x-$choice" = "x-22" ];then
   cat <<EOF
 
       The procedure to set or unset an SCN for an object on the apply site is the same. You set an SCN
       by providing an SCN to the function "dbms_apply_adm.set_table_instantiation_scn" and you unsetting
       it by providing the same object with null value as SCN.

       You will want to reset the SCN of a table to jump a series of transaction. Either your repliaction 
       was down and you don't bother the gap, or you can't provide the missing redo logs.
 
EOF
   echo
   echo $NN "Table owner =>  " $NC
   read SCHEMA_NAME
   echo
   var=`get_table_name $SCHEMA_NAME `
   PS3='Select a table to alter instantiation ==>'
   select TABLE_NAME in $var
     do
       break
   done

   echo
   echo
   echo $NN "SCN (give SCN or leave blank for null)=>  " $NC
   read SCN
   if [ -z "$SCN" ];then
        SCN=null
   fi
   echo
   VAR=`get_apply_name`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      APPLY_NAME=$VAR
   else
     PS3=' Select Apply  ==> '
     select APPLY_NAME in $VAR"Cancel"
       do
            break
       done
   fi
   if [ -n "$APPLY_NAME" ];then
       if [ ! "$APPLY_NAME" = "Cancel" ];then
           SOURCE_DATABASE=`get_source_database $APPLY_NAME`
           echo "ksh $WK_SBIN/smenu_stream_apply.ksh -ti -so $SCHEMA_NAME -t $TABLE_NAME -scn $SCN -src_sid $SOURCE_DATABASE -x"
           ksh $WK_SBIN/smenu_stream_apply.ksh -ti -so $SCHEMA_NAME -t $TABLE_NAME -scn $SCN -src_sid $SOURCE_DATABASE  -x
       fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch23 -----------------------------------------------------
if [ "x-$choice" = "x-23" ];then
  cat <<EOF

       The procedure to set or unset an SCN for an object on the apply site is the same. You set an SCN
       by providing an SCN to the function "dbms_apply_adm.set_table_instantiation_scn" and you unsetting
       it by providing the same object with null value as SCN.

       You will want to reset the SCN of a table to jump a series of transaction. Either your repliaction
       was down and you don't bother the gap, or you can't provide the missing redo logs.

EOF
   echo
   echo $NN "SCHEMA to initialize =>  " $NC
   read SCHEMA_NAME
   echo

   echo
   VAR=`get_apply_name`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      APPLY_NAME=$VAR
   else
     PS3=' Select Apply  ==> '
     select APPLY_NAME in $VAR"Cancel"
       do
            break
       done
   fi
   echo
   echo
   echo $NN "SCN (give SCN or leave blank for null)=>  " $NC
   read SCN
   if [ -z "$SCN" ];then
        SCN=null
   fi
   echo
   if [ -n "$APPLY_NAME" ];then
       if [ ! "$APPLY_NAME" = "Cancel" ];then
           SOURCE_DATABASE=`get_source_database $APPLY_NAME`
           if $SBINS/yesno.sh "to Streams instantiate schema $SCHEMA_NAME" 
           then
              echo "ksh $WK_SBIN/smenu_stream_apply.ksh -si -so $SCHEMA_NAME  -src_sid $SOURCE_DATABASE -scn $SCN -x "
              ksh $WK_SBIN/smenu_stream_apply.ksh -si -so $SCHEMA_NAME  -src_sid $SOURCE_DATABASE -scn $SCN -x 
           fi
       fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch30 -----------------------------------------------------
if [ "x-$choice" = "x-30" ];then
   echo
   VAR=`get_apply_name`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      APPLY_NAME=$VAR
   else
     PS3=' Select Apply  ==> '
     select APPLY_NAME in $VAR"Cancel"
       do
            break
       done
   fi
   if [ -n "$APPLY_NAME" ];then
       if [ ! "$APPLY_NAME" = "Cancel" ];then
          ksh $WK_SBIN/smenu_stream_apply.ksh -start $APPLY_NAME -x
       fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch31 -----------------------------------------------------
if [ "x-$choice" = "x-31" ];then
   echo
   VAR=`get_apply_name`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      APPLY_NAME=$VAR
   else
     PS3=' Select Apply  ==> '
     select APPLY_NAME in $VAR"Cancel"
       do
            break
       done
   fi
   if [ -n "$APPLY_NAME" ];then
       if [ ! "$APPLY_NAME" = "Cancel" ];then
          ksh $WK_SBIN/smenu_stream_apply.ksh -stop $APPLY_NAME -x
       fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch32 -----------------------------------------------------
if [ "x-$choice" = "x-32" ];then
   echo
   VAR=`get_apply_name`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      APPLY_NAME=$VAR
   else
     PS3=' Select apply  ==> '
     select APPLY_NAME in $VAR"Cancel"
       do
            break
       done
   fi
   if [ -n "$APPLY_NAME" ];then
       if [ ! "$APPLY_NAME" = "Cancel" ];then
          echo
          echo
          PS3=' ==>  Select parameter to change : '
          select PAR in disable_on_error parallelism trace_level txn_lcr_spill_threshold commit_serialization _dynamic_stmts _hash_table_size
          do
            break
          done
          echo $NN  " ==>  New Value                  : " $NC
          unset new_value
          read new_value
          case $PAR in
               'parallelism'               )   ksh $WK_SBIN/smenu_stream_apply.ksh -an $APPLY_NAME -par $new_value -x ;;
               'disable_on_error'          )   ksh $WK_SBIN/smenu_stream_apply.ksh -sn $APPLY_NAME -dis_on_err $new_value -x ;;
               'trace_level'               )   ksh $WK_SBIN/smenu_stream_apply.ksh -sn $APPLY_NAME -trace $new_value -x ;;
               'txn_lcr_spill_threshold'   )   ksh $WK_SBIN/smenu_stream_apply.ksh -sn $APPLY_NAME -trh  $new_value -x ;;
               'commit_serialization'      )   ksh $WK_SBIN/smenu_stream_apply.ksh -sn $APPLY_NAME -cms  $new_value -x ;;
          esac
       fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi

#---------------------- Done ----------------------------------------------------
done
