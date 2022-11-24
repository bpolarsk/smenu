HOST=`hostname`
mv $SBINS/.passwd $SBIN/data/.passwd
mv $SBIN/smenu.env $SBIN/data/smenu.env
TARGET_FIL=$SBIN/../smenu_tar_$HOST.`date +%m%d%H%M`
if [ -f $TARGET_FILE ];then
  rm $TARGET_FIL
fi
cd $SBIN/../
touch  $SBIN

tar cvf $TARGET_FIL ./smenu
gzip $TARGET_FIL
ls -l $TARGET_FIL.gz
echo
mv $SBIN/data/.passwd $SBINS/.passwd
mv $SBIN/data/smenu.env $SBIN/smenu.env
echo "....Done !"
