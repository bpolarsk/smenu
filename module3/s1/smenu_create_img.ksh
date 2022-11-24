#!/usr/bin/bash
#
# This script will run properly only unser Cygwin or Linux bash. Other environment
# may have a different implementation of the 'read' command
#
# Author  : B. Polarski
# date    : 2006 April 3
# Program : Create image from a report
#
# set -x
ARGS="$@"
FTMP=$SBIN/tmp/img_wrk$$.txt
IMG_FILE=$SBIN/tmp/img_$$.png
VIEW=YES
if echo "\c" | grep c >/dev/null 2>&1; then
    NN='-n'
    unset NC
else
    NC='\c'
    unset NN
fi
FSAVE=$SBIN/data/sampler_$ORACLE_SID.ini
if [ -f $FSAVE ];then
   COLOR=`grep ^COLOR $FSAVE | cut -f2 -d=`
fi
COLOR=${COLOR:-lblue lred lyellow green}

# ------------------------------------------------------------------------------------
function help
{
 more <<EOF

                    .............................................
                    . Create image from ascii report            .
                    ........................................... .
        
           img -f <FILE> -de -cl <color list>


           -de  : Change label informations
           -cl  : COLOR list are  white, lgray, gray, dgray, black, lblue, blue, dblue, gold, lyellow, yellow, dyellow,
                                  lgreen, green, dgreen, lred, red, dred, lpurple, purple, dpurple, lorange, orange, pink,
                                  dpink, marine, cyan, lbrown, dbrown.

           Color order will determine the following :

                1st : ROWS_PROCESSED
                2nd : DISK_READS
                3rd : BUFFER GETS
                4th : EXECUTIONS


EOF
 exit
}
# ------------------------------------------------------------------------------------
function format_perl_GDgraph {

#set -x

FTMP1=$SBIN/tmp/img_dr.pl
LABEL_VERTICAL=0
VALUES_VERTICAL=0
if [ $ROWNUM -gt 4 ];then
     VALUES_VERTICAL=1
     if [ $ROWNUM -gt 7 ];then
        LABEL_VERTICAL=1    
     fi
fi
if [ "$MODE" = "TIME" ];then
   SQL_HASH_VALUE=`grep '^End date' $FLOG | awk '{ print $7}'`
   FDATE=`grep '^Start date' $FLOG | awk '{ print substr($4,1,4)"/"substr($4,5,2)}'`
   STR_TIME=`grep '^Start date' $FLOG | awk '{ print substr($4,7,2)":"substr($4,9,2)":"substr($4,11,2) }'`
   END_TIME=`grep '^End date' $FLOG | awk '{ print substr($4,7,2)":"substr($4,9,2)":"substr($4,11,2) }'`
   TITLE_IMAGE="SQL $SQL_HASH_VALUE : `echo "$FDATE $STR_TIME $END_TIME $SQL_HASH_VALUE" | awk '{print $1" "$2"-->"$3 }'`"
else
   VAR=`cat $FLOG | grep ^From | cut -f2- -d'-'| awk '{print substr($1,6,5)" "$2"->"$4}'`
   TITLE_IMAGE="$TITLE_IMAGE : $VAR"
fi
   
while read fline 
do
  if [ -z "$fline" ];then 
     continue
  fi
  if [ -z "$TITLE" ];then
     TITLE=ok
     unset VIRG

     cat > $FTMP1 <<EOF
#!/usr/bin/perl -w
use strict;
use GD::Graph::bars3d;
use GD::Text;
EOF

   echo "my @legend_key = ( $fline );" >> $FTMP1
   echo "my @data = (" >> $FTMP1
   continue
   fi
   if [ -n "$VIRG" ] ;then
        echo  "$VIRG" >> $FTMP1
   fi
   echo $NN "   $fline$NC" >> $FTMP1
   VIRG=" ," 
done<$FTMP
  echo " );" >> $FTMP1
 
echo "COLOR=$COLOR"
 
cat >> $FTMP1 <<EOF
my \$graph = new GD::Graph::bars3d( 900, 500 );
\$graph->set(
                x_label           => '$X_LABEL',
                y_label           => 'Values',
                title             => '$TITLE_IMAGE',
                show_values => 1,
                dclrs => [qw($COLOR)],
                l_margin =>10,
                r_margin =>10,
                bar_depth => 9,
                x_labels_vertical=>$LABEL_VERTICAL,
                box_axis=>0,
                overwrite=>0,
                values_space=>15,
                values_vertical => $VALUES_VERTICAL,
                legend_placment=> 'BC',
        );

\$graph->set_legend(@legend_key);
\$graph->set_legend_font(GD::gdMediumBoldFont) ;
\$graph->set_title_font(GD::Font->Giant) ;
\$graph->set_x_axis_font(GD::Font->MediumBold);
\$graph->set_y_axis_font(GD::Font->MediumBold);
\$graph->set_x_label_font(GD::Font->MediumBold);
\$graph->set_y_label_font(GD::Font->MediumBold);
my \$gd = \$graph->plot( \\@data );

open(OUTF, '>$IMG_FILE');
binmode OUTF;
print OUTF \$gd->png;
close(OUTF);
printf "$IMG_FILE done\\n" ;
EOF

}
# ------------------------------------------------------------------------------------
function format_perl_script {
# Deprecated function : I keep the code here case I use again DBix one day
FTMP1=$SBIN/tmp/img_dr.pl
NBR_COLUMN=`head -3 $FTMP | tail -1 | wc -w`

case $NBR_COLUMN in
   2 ) LLIST="1 2"
       COLOR_LIST="${USER_COLOR_LIST:-green}" ;;
   3 ) LLIST="1 2 3"
       COLOR_LIST="${USER_COLOR_LIST:-lblue lyellow}" ;;
       
   4 ) LLIST="1 2 3 4" 
       COLOR_LIST="${USER_COLOR_LIST:-lblue lyellow lred}" ;;

   5 ) LLIST="1 2 3 4 5 " 
       COLOR_LIST="${USER_COLOR_LIST:-lblue lyellow lred green}" ;;

   6 ) LLIST="1 2 3 4 5 6" 
       COLOR_LIST="${USER_COLOR_LIST:-lblue lyellow lred green grey}" ;;
esac


while read fline 
do
  if [ -z "$fline" ];then 
     continue
  fi
  echo $fline | grep -q '^---'
  if [ $? -eq 0 ];then
      continue
  fi

  if [ -z "$TITLE" ];then
     TITLE=ok
     unset VIRG
     cat > $FTMP1 <<EOF
#!/usr/bin/perl -w
use DBI;
use DBD::Chart;

\$dbh = DBI->connect('dbi:Chart:');
EOF
     # first fline
     echo $NN "\$dbh->do('Create table bars ("      >> $FTMP1
     for i in $LLIST
     do 
        echo $NN "$VIRG`echo $fline | cut -f${i} -d' '` integer$NC"      >> $FTMP1
        VIRG=', '
     done
     echo ")');"      >> $FTMP1

     # second fline
     unset VIRG
     echo $NN "\$sth = \$dbh->prepare('INSERT INTO bars VALUES($NC"      >> $FTMP1
     for i in $LLIST
     do
         echo $NN "$VIRG ?$NC"      >> $FTMP1
         VIRG=','
     done
     echo ")');"      >> $FTMP1
     continue
  fi

  # data fline
  unset VIRG
  echo $NN "\$sth->execute("      >> $FTMP1
  for i in $LLIST
  do
     echo $NN "$VIRG`echo $fline | cut -f${i} -d' '`$NC"      >> $FTMP1
     VIRG=','
  done
  echo ");"      >> $FTMP1

done < $FTMP


cat >> $FTMP1 <<EOF

\$rsth = \$dbh->prepare('SELECT BARCHART FROM bars ' .
'WHERE WIDTH=920 AND HEIGHT=580 AND X-AXIS=\'HASH_VALUE\' AND Y-AXIS=\'Value\' AND ' .
'TITLE = \'$TITLE_IMAGE\' AND 3-D=1 AND SHOWVALUES=1 AND ' .
'COLOR=($COLOR_LIST) AND SIGNATURE=\'Smenu\' AND X-ORIENT=\'HORIZONTAL\' ');
\$rsth->execute;
\$rsth->bind_col(1, \\\$buf);
\$rsth->fetch;
open(OUTF, '>$IMG_FILE');
binmode OUTF;
print OUTF \$buf;
close(OUTF);
print "$IMG_FILE OK\n";

EOF

}
# ------------------------------------------------------------------------------------
function get_titles {

 pos=`grep -n "^\-\-\-" $FLOG| head -1 | cut -f1 -d':'`
 pos=`expr $pos - 1`
 TLINE=`head -$pos $FLOG | tail -1`
 NBR_COLUMN=`echo  $TLINE | wc -w`
 if [ $NBR_COLUMN -gt 5 ] ;then
       NBR_COLUMN=5
 fi
 # maximum usable column we are going to render in bars chart. 
 # first one is discarted since it is  the hash_value. 
 NCOL=`expr $NBR_COLUMN - 1`

 # First column is hash values so we start with $2
 TITLE1=`echo $TLINE | awk '{print $2}'`
 TITLE2=`echo $TLINE | awk '{print $3}'`
 TITLE3=`echo $TLINE | awk '{print $4}'`
 TITLE4=`echo $TLINE | awk '{print $5}'`

}
# ------------------------------------------------------------------------------------
function get_color {
#
  if [ -z "$NCOL" ];then
     exit
  fi

   #    1st : ROWS_PROCESSED
   #    2nd : DISK_READS
   #    3rd : BUFFER GETS
   #    4th : EXECUTIONS
  COLOR=${USER_COLOR_LIST:-$COLOR}
  COLOR1=`echo $COLOR | awk '{print $1}'`
  COLOR2=`echo $COLOR | awk '{print $2}'`
  COLOR3=`echo $COLOR | awk '{print $3}'`
  COLOR4=`echo $COLOR | awk '{print $4}'`
  cpt=0
  while [ ! $cpt -gt $NCOL ]
  do
    cpt=`expr $cpt + 1`
    eval VAR=\$TITLE$cpt
    case $VAR in
        ROWS_PROCESSED ) FCOLOR="$FCOLOR $COLOR1" ;;
        "DISK_READS"  | "DISK_READS/ROWS"  | " DISK_READS/EXE" ) FCOLOR="$FCOLOR $COLOR2" ;;
        "BUFFER_GETS" | "BUFFER_GETS/ROWS" | "BUFFER_GETS/EXEC" ) FCOLOR="$FCOLOR $COLOR3" ;;
        EXECUTIONS     ) FCOLOR="$FCOLOR $COLOR4" ;;
    esac
  done
  if [  -n "$FOCOLOR" ];then
      COLOR=`echo $FCOLOR |  sed 's/^[ ]//'`
  fi
}
# ------------------------------------------------------------------------------------
if [ -z "$1" ];then
    help
fi

ROWNUM=10
NCOL=2
MODULE=GENERAL
X_LABEL="SQL_HASH_VALUE"
while [ -n "$1" ]; do
   case "$1" in

     -rn ) ROWNUM=$2
           shift ;;
     -de ) MODE=TIME
           X_LABEL="TIME"
           ;;

      -f ) FLOG=$2 
           shift ;;
     -cl ) USER_COLOR_LIST="$2"; shift ;;
       * ) : ;;
   esac
   shift
done

if [ -z $FLOG ];then
   echo "I need a logfile"
fi
get_titles
get_color
VAR="SQL sorted by $TITLE1"
TITLE_IMAGE=${TITLE_IMAGE:-$VAR}

# .................................................................
if [ "$MODULE" = "DELTA" ];then
   if [ -z "$HV" -a -z "$SORT" ];then
      echo "I need a hash value "
      exit 1
   fi

   # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   #  Delta between begin and end sorted by $FIELD1
   # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# .................................................................
elif [ "$MODULE" = "GENERAL" ];then

awk  -v rownum=$ROWNUM -v t1=$TITLE1 -v t2=$TITLE2 -v t3=$TITLE3 -v t4=$TITLE4 -v ncol=$NCOL ' BEGIN { flag=0 ; cpt=1 }
       {
        if (length($1) == 0 )
            next ;
        if  (substr($1,1,6) == "Sample") 
             flag=0;
   
        if  (substr($1,1,8) == "-------#") {
                cpt=1 ;
                next ;
        }
         
         if ( flag > 0 ) {
            COL1[cpt]=$1;
            COL2[cpt]=$2;

            if ( ncol > 1 )
               COL3[cpt]=$3;

            if ( ncol > 2 )
               COL4[cpt]=$4;

            if ( ncol > 3 )
               COL5[cpt]=$5;

            cpt=cpt+1;
         }
         if (substr($1,1,3) == "---" ) {
             flag=NR
            }
      }
      END {  
            if ( ncol > 3 )
              printf "\\\"%s\\\",\\\"%s\\\",\\\"%s\\\",\\\"%s\\\"\n", t1,t2,t3,t4; 
            else if (ncol > 2 )
              printf "\\\"%s\\\",\\\"%s\\\",\\\"%s\\\"\n", t1,t2,t3; 
            else if (ncol > 1 )
              printf "\\\"%s\\\",\\\"%s\\\"\n", t1,t2; 
            else
              printf "\\\"%s\\\"\n", t1; 
      
             if (cpt>rownum+1)
                 cpt=rownum+1;
             space="[\\\"";
             for ( i=1; i <cpt ; i++){
                 printf  "%s%s", space,COL1[i] ;
                 space="\\\",\\\"\\\",\\\"";
             }
             print "\\\"]";
             space="[";
             for (i=1; i <cpt ; i++){
                 printf "%s%s", space,  COL2[i] ;
                 space=",undef,";
             }
             print "]";

             if ( ncol > 1 ) {
                space="[";
                for (i=1; i <cpt ; i++){
                    printf "%s%s",  space, COL3[i] ;
                    space=",undef,";
                 }
                 print "]";
             }

             if ( ncol > 2 ) {
                  space="[";
                  for (i=1; i <cpt ; i++){
                      printf "%s%s", space, COL4[i] ;
                      space=",undef,";
                 }
                  print "]";
             }

             if ( ncol > 3 ) {
                 space="[";
                 for (i=1; i <cpt ; i++){
                     printf  "%s%s", space,COL5[i] ;
                     space=",undef,";
                  }
                  print "]";
            
              }
}' $FLOG>$FTMP
  format_perl_GDgraph 
# .................................................................
fi
if [ -f $FTMP ];then
    #cp $FTMP $SBIN/tmp/wrk
    rm $FTMP
fi
if [ "$VIEW"  = "YES" ];then
     perl $FTMP1 
     $SBINS/smenu_img_viewer.ksh $IMG_FILE
fi
