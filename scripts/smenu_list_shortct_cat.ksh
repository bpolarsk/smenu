#!/bin/ksh
# program smenu_list_shortct_cat.ksh
# date   :  2006 Jun 30
# Author :  B. Polarski
# Change :  2014 Mar 11
# Author :  R. Rens
#           to escape blank in alias 
#             changed to check $2 using awk field separator -F '\#' 
#             match patern "alias [a-z]+=" in $1 field
#
# set -x
#
#  This program will read addpar.sh and generate the list of shortcuts per category

if [ ! -f $SBINS/addpar.sh ];then
     echo "Ach... addpar.sh is Missing in action !, calls the Marines"
     exit
fi


NAWK=${NAWK:-/bin/awk}
cat  $SBINS/addpar.sh | $NAWK -F '\#' 'BEGIN { i0=0 ; i1=0 ; i2=0 ; i3=0; i4=0 ; i5=0; i6=0; i7=0; i8=0; i9=0; ia=0; ib=0 ; pat="alias [a-z]+="}
{
     if ( $2 == "0" ) {
         if (match($1,pat)) {
             TB0[i0]=substr($1,RSTART+6,RLENGTH-7);
             i0++;
        }
     }
     else if ( $2 == "1" ) {
        if (match($1,pat)) {
             TB1[i1]=substr($1,RSTART+6,RLENGTH-7);
             i1++;
        }
     }
     else if ( $2 == "2" ) {
        if (match($1,pat)) {
            TB2[i2]=substr($1,RSTART+6,RLENGTH-7);
            i2++;
        }
     }
     else if ( $2 == "a" ) {
        if (match($1,pat)) {
           TBa[ia]=substr($1,RSTART+6,RLENGTH-7);
           ia++;
        }
     }
     else if ( $2 == "3" ) {
        if (match($1,pat)) {
           TB3[i3]=substr($1,RSTART+6,RLENGTH-7);
           i3++;
        }
     }
     else if ( $2 == "4" ) {
        if (match($1,pat)) {
           TB4[i4]=substr($1,RSTART+6,RLENGTH-7);
           i4++;
        }
     }
     else if ( $2 == "5" ) {
        if (match($1,pat)) {
           TB5[i5]=substr($1,RSTART+6,RLENGTH-7);
           i5++;
        }
     }
     else if ( $2 == "b" ) {
        if (match($1,pat)) {
           TB5b[ib]=substr($1,RSTART+6,RLENGTH-7);
           ib++;
        }
     }
     else if ( $2 == "6" ) {
        if (match($1,pat)) {
           TB6[i6]=substr($1,RSTART+6,RLENGTH-7);
           i6++;
        }
     }
     else if ( $2 == "7" ) {
        if (match($1,pat)) {
           TB7[i7]=substr($1,RSTART+6,RLENGTH-7);
           i7++;
        }
     }
     else if ( $2 == "8" ) {
        if (match($1,pat)) {
           TB8[i8]=substr($1,RSTART+6,RLENGTH-7);
           i8++;
        }
     }
     else if ( $2 == "9" ) {
        if (match($1,pat)) {
           TB9[i9]=substr($1,RSTART+6,RLENGTH-7);
           i9++;
        }
     }
}
 END {
    printf "            |-------------------------------------------------------- |\n" ;
    printf "            |    SMENU SHORTCUTS SUMMARY (vsl <shct> for more info)   |\n" ;
    printf "            |-------------------------------------------------------- |\n" ;

   printf "\n\nAdministrative and miscellanous     : "
   for (i=0;i<i0 ; i++) { 
       printf "%s  ",TB0[i] ;
   }

   printf "\n\nDatabase, jobs                      : "
   for (i=0;i<i1 ; i++) { 
       printf "%s  ",TB1[i] ;
   }

   printf "\n\nSGA                                 : "
   for (i=0;i<ia ; i++) { 
       printf "%s  ",TBa[i] ;
   }

   printf "\n\nStats, Logminer, statspack, trace   : "
   for (i=0;i<i2 ; i++) { 
       printf "%s  ",TB2[i] ;
   }

   printf "\n\nTablespaces, datafiles, transport.  : "
   for (i=0;i<i3 ; i++) { 
       printf "%s  ",TB3[i] ;
   }

   printf "\n\nTables, index and objects sources   : "
   for (i=0;i<i4 ; i++) { 
       printf "%s  ",TB4[i] ;
   }

   printf "\n\nSessions                            : "
   for (i=0;i<i5 ; i++) { 
       printf "%s  ",TB5[i] ;
   }

   printf "\n\nUsers and grants                    : "
   for (i=0;i<ib ; i++) { 
       printf "%s  ",TB5b[i] ;
   }

   printf "\n\nSQL and Undo                        : "
   for (i=0;i<i6 ; i++) { 
       printf "%s  ",TB6[i] ;
   }

   printf "\n\nLatch and enqueue                   : "
   for (i=0;i<i7 ; i++) { 
       printf "%s  ",TB7[i] ;
   }

   printf "\n\nRedo, Dataguard, Streams, Mview     : "
   for (i=0;i<i8 ; i++) { 
       printf "%s  ",TB8[i] ;
   }

   printf "\n\nWaits, events and stats             : "
   for (i=0;i<i9 ; i++) { 
       printf "%s  ",TB9[i] ;
   }
   print "\n";

 }'
