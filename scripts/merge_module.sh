#!/bin/sh
#set -xv
# this script copy the local module to the repository of smenu and create a new
# 'smenu_tar.last file'. You will have the oportunity to update 'history.txt'
# the local module is in MOD_DIR while the repository module is on NET_MOD_DIR.

cd $SBIN
if [ "x-$1" = "x-" ];then
   echo $NN "  Module to merge ==> $NC"
   read MODULE
else
   MODULE=$1
fi
. smenu.env
if [ "x-$NET_SBIN" = "x-" ];then
   echo "NET_SBIN not defined, review $SBIN/smenu.env."
   exit 1
fi
HOST=`hostname`
case $MODULE in
 s ) MOD_DIR=$SBIN/scripts
     NET_MOD_DIR=$NET_SBIN/scripts ;;

 d ) MOD_DIR=$SBIN/data
     NET_MOD_DIR=$NET_SBIN/data ;;

 *)  MOD_DIR=$SBIN/module$MODULE
     NET_MOD_DIR=$NET_SBIN/module$MODULE;;
esac
if [ ! -d $MOD_DIR ];then
    echo "Module $MODULE does not exists ! "
    exit
fi
# ------------- Add comments in history --------------
echo 
if $SBIN/yesno.sh "add comments in history file" DO
  then
    vi $SBINS/history.txt
    cp $SBINS/history.txt $NET_SBIN/scripts/history.txt
fi
# ------------- take a backup before -----------------

echo "Taking a backup of Repository smenu before : "
cd $NET_SBIN
$NET_SBINS/mk_tar_last.sh

# ------------- Perform the merge now ----------------

echo "Merging now the Module $MODULE "
cd $SBIN/tmp
if [  -d $NET_MOD_DIR ];then
   rm -r $NET_MOD_DIR
fi
cd $SBIN
VAR_MOD_DIR=`basename $MOD_DIR`
tar cvf module_$MODULE.tar ./$VAR_MOD_DIR
cd $NET_SBIN
if [ -f $NET_SBIN/smenu_tar.last ];then
   rm $NET_SBIN/smenu_tar.last
fi
$NET_SBIN/sripts/change_version.sh
tar xvf $SBIN/module_$MODULE.tar
# --------- re-generating the last tar file ---------
if [ -f $SBIN/module_$MODULE.sh ];then
   cp $SBIN/module_$MODULE.sh $NET_SBIN
fi
LAST=$NET_SBIN/smenu_tar.last
cd $NET_SBIN/../
tar cvf $LAST ./smenu
mv $LAST ./smenu
rm $SBIN/module_$MODULE.tar
cp $NET_SBIN/scripts/version.txt $SBINS/version.txt
echo
echo "....Done !"
