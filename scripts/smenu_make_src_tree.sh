#!/usr/bin/sh
set -xv

cd $SBIN/..
TBIN=`pwd`/tbin
if [ ! -d $TBIN ];then
   mkdir $TBIN
fi
FLIST=$TBIN/flist.txt
> $FLIST
# tree to scan

TREE="scripts module1 module2 module3"
 
cd $SBIN/tmp
if [ -d $TBIN ];then
   cd $TBIN
   rm -rf ./scripts ./module1 ./module2 ./module3 
fi
cd $SBIN
du $TREE | awk '{print $2'} > $FLIST
cd $TBIN
while read a
  do
   if  [ ! -d $a ];then
       mkdir -p $a
   fi
done<$FLIST

cd $SBIN
#----- list of indepant file to take -----
# --
for i in $TREE
  do
    find ./$i -name "*.txt" -print >> $FLIST
    find ./$i -name "*.hlp" -print >> $FLIST
    find ./$i -name "*.sh" -print >> $FLIST
    find ./$i -name "*.ksh" -print >> $FLIST
    find ./$i -name "*.sql" -print >> $FLIST
    find ./$i -name "*.pl" -print >> $FLIST
done

cat $FLIST | grep "^./" > xx
mv xx $FLIST
cat $FLIST | sed 's/\.\///' | sort > xx
mv xx $FLIST

while read a
  do
   if [ -f $a ];then
      BASE=`basename $a`
      DIR=`dirname $a`
      #DIR=`dirname $a| sed 's/\.//`
      TARGET=`echo $BASE |sed 's/\.sql/_sql.txt/'`
      TARGET=`echo $TARGET |sed 's/\.sh/_sh.txt/'`
      TARGET=`echo $TARGET |sed 's/\.pl/_pl.txt/'`
      TARGET=`echo $TARGET |sed 's/\.hlp/_hlp.txt/'`
      cp $a ${TBIN}/$DIR/$TARGET
   fi
done<$FLIST
for i in 1 2 3 
  do
   cp $SBIN/module_$i.sh $TBIN/module_${i}_sh.txt
done
