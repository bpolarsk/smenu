#!/usr/bin/ksh
# program smenu_what_is_it.sh
# Author : Bernard Polarski
# Date   : 19-05-2000
FILE=$SBIN/data/smenu_what_is_it.txt

if [ "x-$1" = "x-" ];then
   #LST=`grep '^#-#' $FILE | sed 's/#-#$//' | sed 's/#-//' | sort -u `
   LST=`grep '^#-#' $FILE | sed 's/^#-#//' | sed 's/#-//' | sort -u `
elif [ "x-$1" = "x--h" ];then
   cat <<EOF

        Usage : wpar -a
                wpar -k <word>     or    wpar <word>


             -h : Usage
             -a : show all discussions
             -k : show only dicussions about parameter containing word <word>

EOF
exit
elif [ "x-$1" = "x--k" ];then
   if [ ! "x-$2" = "x-" ];then
       LST=`grep '^#-#' $FILE | grep -i $2 | sed 's/^#-#//' | sed 's/#-//' | sort -u `
   else
       LST=`grep '^#-#$' $FILE | sed 's/^#-#//' | sed 's/#-//' | sort -u `
   fi
else
   LST=`grep '^#-#' $FILE |  grep -i $1 |sed 's/^#-#//' | sed 's/#-//' | sort -u `
fi
PS3='Select a field to explain, 'e' to leave ==> '
LST=" "`echo $LST |tr -d '\n'`
IFS=#
export IFS
clear
echo
echo
echo
select F_VALUE in ${LST}
   do
     clear
     VAR=`echo $F_VALUE | sed 's/ $//'| sed 's/^ //'`
     if [ "x-$VAR" = "x-" ];then
        break
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
     #if [ $TO_CUT -gt 24 ];then
     #   head -$MARKB $FILE |tail -$TO_CUT | grep -v "#-#" | more
     #else
        head -$MARKB $FILE |tail -$TO_CUT | grep -v "#-#"
     #fi
     echo " "
     echo " "
done
