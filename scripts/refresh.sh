:
set -xv
cd $SBIN/../
TARFILE=./smenu_tar.tar
if [ !  -f $TARFILE ];then
     echo " I do not find smenu_tar in $SBIN/.. " 
     exit 0
fi
if [ -d /tmp/smenu_data ];then
   rm -rf /tmp/smenu_data
fi
if [ -f /tmp/.passwd ];then
   rm -f /tmp/.passwd
fi
mkdir /tmp/senv /tmp/smenu_data


#---------- check_par function ----------------------------------
check_par()
{
set -xv
par=$1
   var=`grep "^${par}=" $SBIN/smenu.env | cut -f1 -d'='`
   if [ ! $? -eq 0 ] ;then
      echo "I did not found $par parameter in you SBIN/smenu.env"
      echo "Add it manually "
  else
     case $par in
          SBIN | SBINS | NAWK | S_USER | MAIL_PRG | HOST |  GET_PASSWD | COMPRESS_PRG | CRYPT_PASSWD | TR  )  var1=`grep "${par}=" $SBIN/smenu.env | cut -f2 -d'='`  
          if [ "x-$var1" = "x-" ] ;then
              echo " Oops...! Parameter $par is not set in SBIN/env : edit and correct "
              echo " Do not hesitate to send your insults to the developper for this crap routine ! "
          fi
     esac
  fi
}
#---------- copy section ----------------------------------------
cp $SBIN/data/.smenu_mail_list.txt /tmp
if [ -f $SBIN/data/smenu_default_user.txt ];then
    cp $SBIN/data/smenu_default_user.txt /tmp
fi
cp $SBIN/scripts/.passwd /tmp
cp ./smenu/data/* /tmp/smenu_data
cp ./smenu/scripts/addpar.sh ./smenu/scripts/addpar.sh.`date +%m:%d`
#----------Uncompress section

tar xvf $TARFILE ./smenu
#----------Restore section
echo
echo
if [ -f /tmp/smenu_default_user.txt ];then
     mv /tmp/smenu_default_user.txt ./smenu/data/smenu_default_user.txt
fi


if [ -f ./smenu/data/smenu_what_is_it.txt ];then
      rm /tmp/smenu_data/smenu_what_is_it.txt
fi
echo $NN " restoring smenu/data files : $NC"
for i in `ls /tmp/smenu_data/*`
   do
     f_file=`basename $i`
     rad=`echo $f_file | cut -c1-9`
     if [ "x-$rad" = "x-v_comment" ];then
        if [ ! -f ./smenu/data/$f_file ];then
           if [  -f ./smenu/data/$f_file ];then
              mv /tmp/smenu_data/$f_file ./smenu/data/$f_file
           fi
        fi
     else
        if [  -f ./smenu/data/$f_file ];then
           mv /tmp/smenu_data/$f_file ./smenu/data/$f_file
        fi
     fi
done
rm /tmp/smenu_data/*
echo "ok"

echo $NN " restoring smenu.env : $NC"
VERSION=`cat ./smenu/scripts/version.txt`
if [ -f  /tmp/smenu.env ];then
   var=`grep -n "VERSION=" /tmp/smenu.env | cut -f1 -d':'`
   if [ $? -eq 0 ] ;then
      max=`cat /tmp/smenu.env | wc -l`
      var1=`expr $var - 1`
      to_cut=`expr $max - $var`
      head -$var1 /tmp/smenu.env > ./smenu/smenu.env
      echo "VERSION=$VERSION" >> ./smenu/smenu.env
      tail -$to_cut /tmp/smenu.env >>./smenu/smenu.env
      rm /tmp/smenu.env
   else
      mv /tmp/smenu.env ./smenu
      echo "VERSION=$VERSION" >> ./smenu/smenu.env
   fi
fi
echo "ok"

echo $NN " restoring passwd file : $NC"
rm ./smenu/scripts/.passwd
mv /tmp/.passwd ./smenu/scripts/.passwd
echo "ok"
echo " Restoring SBIN in new addpar.sh"
var=`grep -n "^SBIN=" ./smenu/scripts/addpar.sh | cut -f1 -d':'`
if [ $? -eq 0 ] ;then
   max=`cat ./smenu/scripts/addpar.sh | wc -l`
   var1=`expr $var - 1`
   to_cut=`expr $max - $var`
   head -$var1 ./smenu/scripts/addpar.sh > /tmp/addpar.txt
   echo "SBIN=$SBIN" >> /tmp/addpar.txt
   tail -$to_cut ./smenu/scripts/addpar.sh >>  /tmp/addpar.txt
   mv  /tmp/addpar.txt ./smenu/scripts/addpar.sh
   chmod 755   ./smenu/scripts/addpar.sh
else
   cat <<EOF
   
   Ouch ! I did not find SBIN in ./smenu/scripts/addpar.sh
   It is a disater. edit addpar.sh and type at the beginning
   of this file : SBIN=<smenu_root_dir>
   Check also ./smenu/smenu.env
   If SBIN is not there, then smenu will not work!
   Do not forget to type 'rgs' to regen all your shortcuts
 
                                        The S-man

EOF
fi
echo "ok"
echo "Your Old addpar is ./smenu/scripts/addpar.sh.`date +%m:%d`"
echo " If you have added Some shortcuts then transfer them now"


echo " "
echo "   Checking presence of your 11 parameters defined : "
echo " "


check_par SBIN
check_par SBINS
check_par NAWK
check_par S_USER
check_par HOST
check_par GET_PASSWD
check_par VERSION
check_par COMPRESS
check_par TR
check_par NN
check_par NC


