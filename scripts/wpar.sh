#!/bin/ksh
#........................................................................................
# program smenu_what_is_it.sh 
# Purpose :  what is this Oracle parameters meaning ? ===> wpar !
# This program is a standalone version of the wpar of smenu.
# Visit 'http://www.geocities.com/bpolarsk' for smenu or later release 
# of wpar.sh
#
# HOW to BEST use : Create an alias to wpar.sh (wp) or rename the file 
# for better convenience. Type 'wpar <partial word>' and you will get
# a list of all entries. Pick a number and you will get blabla. 
#
#          Run in Ksh or any any Shell that implement 'select'
#
# Author : Bernard Polarski
# Date   : 19-05-2000
#........................................................................................

if [ -f $SBIN/data/smenu_what_is_it.txt ];then
    FILE=$SBIN/data/smenu_what_is_it.txt
else
    FILE=$0
fi
OS=`uname | cut -c1-6 `
if [ "$OS" = "CYGWIN" ];then
    unset CLEAR
else
    CLEAR=clear
fi
function help
{
   cat <<EOF

        Usage : wp -a
                wp -k <word>     or    wpar <word>
                wp -v <word> 

             -h : Usage
             -a : show all discussions
             -k : show only dicussions about parameter containing word <word>
             -v : put you in vi mode at <word> position. word must be a title

EOF
exit
}
if [ -z "$1" ];then
     help
fi
if [  "$1" = "-h" ];then
     help
fi

if [ "$1" = "-v" ];then
       LST=`grep -n '^#-#' $FILE | grep -i $2 | sed 's/^#-#//' | sed 's/#-//' | head -1 | cut -f1 -d:`
       if [ -n "$LST" ];then
            vi +$LST $FILE
       fi
       exit
elif [ "$1" = "-a" ];then
       VAR=`grep '^#-#' $FILE | sed 's/^#-#//' | sed 's/#-//' | sort -u | sed '/\\\n/d'`
elif [ "$1" = "-k" ];then
   if [ -n "$2" ];then
       VAR=`grep '^#-#' $FILE | grep -i $2 | sed 's/^#-#//' | sed 's/#-//' |sort -u|sed '/\\\n/d'`
   else
       VAR=`grep '^#-#' $FILE | sed 's/^#-#//' | sed 's/#-//' | sort -u |tr '\n' ' '| sed '/\\\n/d'`
   fi
else
   VAR=`grep '^#-#' $FILE | grep -i "$1" |sed 's/^#-#//;s/#-//'|sort -u |sed '/\\\n/d'`
fi
LST=`echo $VAR |sed 's/# /#/g'`


PS3='Select a field to explain, 'e' to leave ==> '
IFS=#
export IFS
$CLEAR
echo
echo
echo
select F_VALUE in ${LST}
   do
     $CLEAR
     VAR=`echo $F_VALUE | sed 's/ $//'| sed 's/^ //'| sed 's/[*]/\\\*/g'`
     if [ "x-$VAR" = "x-" ];then
        exit
     fi
     MARKA=`grep -n "#-#${VAR}#-#" $FILE | head -1 | cut -f1 -d:`
     MARKB=`grep -n "#-#${VAR}#-#" $FILE | head -2 | tail -1 | cut -f1 -d:`
     MARKB=`expr $MARKB - 1`
     TO_CUT=`expr $MARKB - $MARKA`
     echo " "
     echo " "
     echo "  ------------------------------------------------- "
     echo "  $F_VALUE "
     echo "  ------------------------------------------------- "
     echo " "
     head -$MARKB $FILE |tail -$TO_CUT | grep -v "#-#" 
     echo " "
     echo " "
done
#................................................................................................
