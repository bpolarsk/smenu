#!/usr/bin/ksh
set -x
NN=
NC=
if echo "\c" | grep c >/dev/null 2>&1; then
    NN='-n'
else
    NC='\c'
fi
cd $SBIN/..

if [ -n "$SITE_DIR" ];then
  TBIN=$SITE_DIR
else
  TBIN=/tmp
fi
if [ ! -d $TBIN/shct ];then
   mkdir $TBIN/shct
else
   rm -rf $TBIN/shct
fi
FINDEX=$TBIN/cat.txt
echo "FINDEX=$FINDEX"
> $FINDEX
#
## first part
#mk1=`grep -n mk1 $FINDEX | cut -f1 -d:`
#head -$mk1 $FINDEX > $FINDEX.1
# generated part
cat >> $FINDEX.1 <<EOF

<table border="1"  bgcolor="#adc1fe">
  <tbody><tr><td>/home/oracle> sp

<table border="0" cellpadding="2">
<tbody>
<tr><br></tr>

<br>
EOF

# reading shortcut list from addpar.sh
$SBINS/smenu_list_shortct_cat.ksh |grep -v '|'| sed '/^$/d'|
while read line
do
  TDIR=shct
  if [ ! -d  $TBIN/$TDIR ];then
     mkdir -p $TBIN/$TDIR
  fi
  title=`echo $line | cut -f1 -d:`
  shct=`echo $line | cut -f2 -d:`
  echo 
  echo " <tr> <td>$title </td> <td>:"  >> $FINDEX.1

 
 for i in `echo $shct`
 do
    FILE=`grep  "^alias $i=" $SBINS/addpar.sh | sed 's@.*=\(.* \)#.*@\1@' | tr -d "'"|awk '{print $1}'`
    BASE_FILE_NAME=`basename $FILE|tr '.' '_'`
    TARGET_FILE=$TBIN/shct/$BASE_FILE_NAME.txt
    eval cp $FILE $TARGET_FILE
    REASON=`grep "^alias $i=" $SBINS/addpar.sh | cut -f3 -d#`
    echo -n "$FILE $i  $REASON\n "
    echo "       <a href=\"/$TDIR/$BASE_FILE_NAME.txt\">$i</a>"  >> $FINDEX.1
 done
 echo "</td></tr>" >> $FINDEX.1
done

cat >> $FINDEX.1 <<EOF
  </tbody>
</table>
   </td></tr>
  </tbody>
</table>
EOF
cp $FINDEX.1 $TBIN/shct/sp_tag_html.txt
#DDATE=`date +%d-%B-%Y`
#upd5_6="Last Update : $DDATE<br>"
#version=`cat $SBINS/version.txt`
#upd3_4="smenu_tar v$version (9i &amp; 10g)"
#if [ ! -f $FINDEX ] ;then
#   echo "error : did not find $FINDEX"
#   exit 1
#fi
#mk2=`grep -n mk2 $FINDEX | cut -f1 -d:`
#mk3=`grep -n mk3 $FINDEX | cut -f1 -d:`
#mk4=`grep -n mk4 $FINDEX | cut -f1 -d:`
#mk5=`grep -n mk5 $FINDEX | cut -f1 -d:`
#mk6=`grep -n mk6 $FINDEX | cut -f1 -d:`
#
#
# before version part
#diff_2_3=`expr $mk3 - $mk2`
#diff_2_3=`expr $diff_2_3 + 1`
#tail +$mk2 $FINDEX | head -$diff_2_3 >> $FINDEX.1

# before last update part
#echo $upd3_4 >> $FINDEX.1
#iff_4_5=`expr $mk5 - $mk4`
#iff_4_5=`expr $diff_4_5 + 1`
#ail +$mk4 $FINDEX | head -$diff_4_5 >> $FINDEX.1

# remaining part
#cho $upd5_6 >> $FINDEX.1
#ail  +$mk6 $FINDEX >> $FINDEX.1
