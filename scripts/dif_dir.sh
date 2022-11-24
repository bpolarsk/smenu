#!/usr/bin/ksh
#set -x
WORK_DIR=$PWD
DIR1=$1
DIR2=$2

cd $WORK_DIR
> dif_out.txt

cd $DIR1
if [ $? -ne 0 ];then
   echo " cd to dir1 failed"
      ls -l $DIR1/$b
   exit
fi
find . -print > $WORK_DIR/dir_f.txt

while read  b
 do
   if [ -d $b ];then
      continue
   fi
   if [ ! -f $DIR2/$b ];then
      echo " "
      echo "`basename $DIR2` : no file $b"
      echo " "
      echo " "                      >> $WORK_DIR/dif_out.txt
      echo "`basename $DIR2` : no file $b"  >> $WORK_DIR/dif_out.txt
      echo " "  >> $WORK_DIR/dif_out.txt
      continue
   fi
   a1=`ls -l $DIR1/$b |  awk '{print $5'}`
   a2=`ls -l $DIR2/$b |  awk '{print $5'}`
   if [ $a1 -ne $a2 ];then
      echo " "
      ls -l $DIR1/$b               
      ls -l $DIR2/$b               
      echo diff $DIR1/$b $DIR2/$b  
      echo " ">> $WORK_DIR/dif_out.txt
      ls -l $DIR1/$b               >> $WORK_DIR/dif_out.txt
      ls -l $DIR2/$b               >> $WORK_DIR/dif_out.txt
      echo diff $DIR1/$b $DIR2/$b  >> $WORK_DIR/dif_out.txt
      echo cp $DIR1/$b $DIR2/$b  >> $WORK_DIR/dif_out.txt
      echo cp $DIR2/$b $DIR1/$b  >> $WORK_DIR/dif_out.txt
   fi
done<$WORK_DIR/dir_f.txt

