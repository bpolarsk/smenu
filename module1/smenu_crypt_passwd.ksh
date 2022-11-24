#!/usr/bin/sh
# This is not used anymore but I keep it case I decide to  reactivate this feature
# Author : Polarski Bernard 2/12/1999
SBIN=${SBIN}
YT=OR
nt=New
X=AC
top=mod
dat=date
hy=fy
pu=u${il}pd${m}${dat}
lp=ply
ds=${top}${er}
o=r
K=User
er=i
ra=d
Ku=me
H1="    $K "
L1="na${Ku} :   \c " 
FG=LE
s=\>
yh=f
MIN=Z
ds=${ds}${fy}
ex=mv
li==
lam=${ra}${l}i
ap="ap${lp} $pu"
ob=f
il=ec
ili=pas
l=${YT}${X}
MAX=A
p="${MAX}-${MIN}"
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
lam=${lam}${ob}${op}${yh}
D=SID
op=ho
TPF1=$SBIN/tmp/zzgg_passwd1.txt
eval l=${l}${FG}
MM="$l"_"$D"
NR=Pas
eval MM_1=\$$MM
ls=t
hz=a
lu=-
luu=z
R1=" $l $D  [$MM_1] ==> \c"
TPF2=$SBIN/tmp/zzgg_passwd2.txt
T4=swd
ul=-
za=a
OLD_TPF=$SBIN/tmp/zzgg_passwd_old.txt
pk=${T4}
eval pf=$SBINS/.${ili}${T4}
cat $pf | grep -v "^#" > $TPF2
cat $TPF2 | sort > $TPF1
F1="$H1 $L1" 
T2="echo \"    $R1  "\"
ln="${il}${op} \" $nt ${NR}${pk}  $li$li$s \c\""
F2="echo \"    ${NR}$T4 :  \c"\"
cp $pf $OLD_TPF
fcp(){
eval 
echo $1| ${ls}${o}${m} $p ${hz}${lu}${luu}  | 
${m}${ls}${o} ${za}${ul}${luu}  m${ul}${luu}${za}-l
}
while true
 do
clear
   max=`cat $TPF1 | wc -l`
   cpt=1
cat << EOF


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/1.5
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                   Maintain Password                       *
   *                                                           *
   *************************************************************

                                        Password 
               SID         User         defined
     ==================================================

EOF
   while read LIGN
     do
       USR=`echo $LIGN | cut -f2 -d':' | awk '{printf("%-12.12s",$1)}'` 
       SID=`echo $LIGN | cut -f1 -d':' | awk '{printf("%12.12s",$1)}'` 
       F3=`echo $LIGN | cut -f3 -d':'` 
       if [ "x-$F3" = "x-" ];then
          PASS_F=N
       else
          PASS_F=Y
       fi
       echo "      $cpt ) $SID  :  $USR   : $PASS_F"
       cpt=`expr $cpt + 1`
   done<$TPF1
   echo " "
   echo " "
   echo "    Press 'a' to add a user."
   echo "    Append 'd' to the number to delete a user."
   echo "    Append 't' to test connection of a user."
   echo "    Select a user to change passwd or 'e' exit ==> \c"
   read SEL_CH
#set -xv
   if [ "x-$SEL_CH" = "x-e" ];then
      eval ${lam} $TPF1 $OLD_TPF >/dev/null
      if [ ! $? -eq 0 ];then
         if $SBINS/yesno.sh "$ap " DO Y
            then
             eval $ex $TPF1 $pf 1>/dev/null 2>&1
         fi
      fi
      rm $TPF1 $TPF2 $OLD_TPF 1>/dev/null 2>&1
      exit
   elif [ "x-$SEL_CH" = "x-" ];then
      echo
      echo
   elif [ "x-$SEL_CH" = "x-a" ];then
        eval $T2
        U1=
        read U1  
        if [ "x-$U1" = "x-" ];then
            eval df=\$${l}_${D}
        fi
        echo "$F1"
        S1=
        read  S1
        eval $F2
        stty echo 
        stty -echo
        read F3
        stty echo 
      #  FF2=`fcp $F3`
         FF2=$F3
        eval echo "$df:$S1:$FF2" >> $TPF1
        #eval echo "$df:$S1:$FF2" 
   else
     var=`echo $SEL_CH | grep 'd'`
if [ $? -eq 0 ];then
     SEL_CH=`echo $SEL_CH | sed 's/d//'`
     var=`head -$SEL_CH $TPF1 |tail -1 `
     if $SBINS/yesno.sh " to remove $var " DO Y
     then
        var0=`expr $SEL_CH - 1`
        head -$var0 $TPF1 > $TPF2
        to_cut=`expr $max - $SEL_CH`
        tail -$to_cut $TPF1 >> $TPF2
        mv $TPF2 $TPF1
     fi
     continue
     var=`echo $SEL_CH | grep 't'`
     if [ $? -eq 0 ];then
        SEL_CH=`echo $SEL_CH | sed 's/t//'`
        LIGN=`head -$SEL_CH $TPF1 | tail -1`
        SID=`echo $LIGN | cut -f1 -d':'` 
        USR=`echo $LIGN | cut -f2 -d':'` 
        F3=`echo $LIGN | cut -f3 -d':'` 
        ksh $SBINS/smenu_check_connect1.sh $USR $F3 $SID
        echo "press Any key to continue .... \c"
        read ff
        continue
     fi
     if [ $SEL_CH -gt $max ];then
          echo " Invalid selection. "
          echo "press Any key to continue .... \c"
          read ff
     fi
     LIGN=`head -$SEL_CH $TPF1 | tail -1`
     SID=`echo $LIGN | cut -f1 -d':'` 
     S3=`echo $LIGN | cut -f2 -d':'` 
     if $SBINS/yesno.sh "${ls}o $ds $S3 $NR$T4 $D ${li} $SID " DO Y
        then 
          eval $ln
          read F3
          FF2=`fcp $F3`
          var0=`expr $SEL_CH - 1`
          head -$var0 $TPF1 > $TPF2
          eval echo "$SID:$S3:$FF2" >> $TPF2
          to_cut=`expr $max - $SEL_CH`
          tail -$to_cut $TPF1 >> $TPF2
          mv $TPF2 $TPF1
          
     fi
   fi
#read titi
done
rm $TPF1 $TPF2 $OLD_TPF 1>/dev/null 2>&1
