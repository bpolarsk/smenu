#!/bin/sh
# Author : Polarski Bernard 17/07/2000

DATA_FILE=${SBIN}/data/smenu_default_user.txt
if [ ! -f $DATA_FILE ];then
   touch $DATA_FILE
fi
SBINS=$SBIN/scripts
FTMP=$SBIN/tmp/zzgg_def_usr.txt
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
while true
 do


  clear
cat <<EOF


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/1.3
   
   *************************************************************
   *                                                           *
   *       Maintain/defined a default user for each sid        *
   *                                                           *
   *************************************************************

                  Sid             Default User
               -----------   -----------------------
EOF
  cpt=0
  while read lign
   do
    var=`echo $lign |cut -c1`
    if [ "x-$var" = "x-#" ];then
       continue
    fi
    cpt=`expr $cpt + 1`
    SID=`echo $lign | cut -f1 -d: | awk '{printf ("%-15.15s",$1)}'`
    D_USER=`echo $lign | cut -f2 -d: | awk '{printf ("%-15.15s",$1)}'`
    echo "            $cpt  : $SID  $D_USER"
  done<$DATA_FILE
    echo " "
    echo " "
    echo " "
    echo "         (n)d : Append d to row selection to remove it." 
    echo "         a    : add"
    echo "         e    : exit"
    echo " "
    echo $NN "   Selection ==> $NC"
    read SEL_FIL
    if [ "x-$SEL_FIL" = "x-e" ];then
          exit
    elif [ "x-$SEL_FIL" = "x-a" ];then
          echo $NN "   Sid [$ORACLE_SID] ==> $NC"
          read NEW_SID
          if [ "x-$NEW_SID" = "x-" ];then
                 NEW_SID=$ORACLE_SID
          fi
          echo $NN "   New User ==> $NC "
          read NEW_USER
          var=$NEW_SID:$NEW_USER
          cat $DATA_FILE| cut -f1 -d: | grep $NEW_SID >/dev/null 2>&1
          if [ $? -eq 0 ];then
             echo "Error : There is already a Default user for this SID " 
             read ff
          else
             echo "$NEW_SID:$NEW_USER" >> $DATA_FILE
          fi
   else
     var=`echo $SEL_FIL | grep 'd'`
     if [ $? -eq 0 ];then
        SEL_FIL=`echo $SEL_FIL | sed 's/d//'`
        LIGN=`head -$SEL_FIL $DATA_FILE | tail -1`
        F_USER=`echo $LIGN | cut -f1 -d\;`
        if $SBINS/yesno.sh "remove '$F_USER' form default list" DO Y
           then
            CPT1=`expr $SEL_FIL - 1`
            if [ $CPT1 -gt -1 ];then
               head -$CPT1 $DATA_FILE > $FTMP
            fi
            FMAX=`cat $DATA_FILE | wc -l`
            CPT2=`expr $FMAX - $SEL_FIL`
            if [ $CPT2 -gt -1 ];then
                tail -$CPT2 $DATA_FILE >> $FTMP
            fi
            mv $FTMP $DATA_FILE
        fi

     fi
  fi
done
