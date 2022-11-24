#!/bin/ksh
# set -x
# Author : B. Polarski
# date   : 22 June 2000
# modify : 18 Avril 2005
#          05 July 2006 : replaced a sed with tr due to Solaris weird behaviour when sed is evaluated with quotes
# Alias in Lunix may add ". " in front
if [ "x-$1" = "x-." ];then
   shift
fi
if [ "x-$1" = "x-" ];then
   cat <<EOF





       Usage : 
    
          vsh -l <string>
          vsh <alias>


          vsh -l list all shortcuts starting with <string>
          vsh <alias> vill edit the file referenced by the alias
              if the alias is in fact a substring of many alias then
              vsh list all possibilities

         try : 
                vsh  -l sl
                vsh  sl


                vsh -l pa
                vsh pa


EOF
   exit
fi
if [ -f $1 ];then
   vi $1
   exit
fi 
     
if [ "x-$1" = "x--l"  ];then
         echo
         echo "   List of Shortcuts starting with '$2' : " 
         echo "   ========================================" 
         echo
         echo
         grep "^alias $2" $SBINS/addpar.sh | sed  "s/'//g" | sed "s/=/  /" | sed 's/^alias/     /'
         echo
         echo
         exit
fi

LST="eval ls \`grep \"^alias ${1}=\" $SBINS/addpar.sh |awk  ' {print \$2 }' | tr -d \"'\"  | cut -f2 -d= | cut -f1 -d'#'\`"
var=`eval $LST`
cpt=`echo $var | wc -w`

if [ $cpt -gt 1 ];then 
     file_in_dir=`ls | wc -w`
     if [ $file_in_dir -eq $cpt ];then
         echo
           echo "No alias match found"
         echo
           exit
     else
         echo
         echo
         echo "  More than 1 match found : " 
         echo "  ===========================" 
         echo
         echo
         grep "^alias $1" $SBINS/addpar.sh | cut -f1 -d'#' | tr -d"'" | sed "s/=/  /" | sed 's/^alias/     /'
         echo
         echo
         exit
     fi
fi
a="eval vi \`grep \"^alias ${1}=\" $SBINS/addpar.sh |awk  ' {print $2 }' | tr -d \"'\" | cut -f2 -d=\`"
eval $a
