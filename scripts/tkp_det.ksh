#!/usr/bin/ksh

usage()
{
cat << EOF
   usage: $0 [options] trace_file

   analyses trace files from Oracle created with 10046 event or with waits=true
   
OPTIONS:
    -h       Show this message

EXAMPLE
   
     $0  sid_ora_29908.trc

EOF
exit
}

argn=0
while getopts hba:v OPTION
do
     case $OPTION in
         h)
             usage
             ;;
         a)
             # not used yet
             argn=$(expr $argn + 2 )
             ARGVALUE=$OPTARG
             ;;
         v)
             # not used yet
             argn=$(expr $argn + 1 )
             verbose=1
             ;;
         ?)
             usage
             ;;
     esac
done

shift $argn
[[ $# -lt 1 ]] && usage
[[ $# -gt 1 ]] && usage

file=$1
if [ ! -f $file ]; then
  echo "ERROR: "
  echo "    file:$1, doesn't exist"
  echo " "
  usage
fi

cat $file | perl -e '

  # debugging, look at max read speeds that are too fast
  $fastread=-1;

  $blocksize=32*1024;

  $bucketmin=6;
  $bucketmax=18;

  @buckett[0]="1u ";
  @buckett[1]="2u ";
  @buckett[2]="4u ";
  @buckett[3]="8u ";
  @buckett[4]="l6u ";
  @buckett[5]="32u ";
  @buckett[6]="64u ";
  @buckett[7]=".1m ";   # 128 
  @buckett[8]=".2m ";   # 256 
  @buckett[9]=".5m ";   # 512 
  @buckett[10]="1m ";   # 1024 
  @buckett[11]="2m ";   # 2048
  @buckett[12]="4m ";   # 4096
  @buckett[13]="8m ";   # 8192
  @buckett[14]="16m ";  # 16384
  @buckett[15]="33m ";  # 32768
  @buckett[16]="65m ";  # 65536
  @buckett[17]=".1s";   # 131072
  @buckett[18]=".3s";   # 262144
  @buckett[19]=".5s";   # 524288
  @buckett[20]="1s";    # 1048576
  @buckett[21]="2s";    # 2097152
  @buckett[22]="4s";    # 4194304
  @buckett[23]="8s";    # 8388608
  @buckett[24]="17s";   # 16777216
  @buckett[25]="34s";   # 33554432
  @buckett[26]="67s";   # 67108864

sub lines {

       my ($string) = @_[0];


      #$debug_lines=1; 
      
      printf("-->lines1 ,input :%s: \n",$string) if defined ($debug_lines);
       
      while ( length($string) > 80  &&   $string =~ m/(.{0,80}\s)(.*)/ ) {
            printf("-->lines2, \$1 :%s:  \n",$1) if defined ($debug_lines);
            printf("-->lines3, \$2 :%s:  \n",$2) if defined ($debug_lines);
            print "$1\n";
            $string=$2;
      }
      if  ( length($string) > 0 )  {
            if (  $string =~ m/^ *$/  ) {
              printf("-->lines4, blanks :%d: \$string :%s:  \n",length($string),$string) if defined ($debug_lines);
            } else {
              printf("-->lines5, length:%d: \$string :%s:  \n",length($string),$string) if defined ($debug_lines);
              print "$string\n";
            }
      }
             
  }

sub sqlplan {
    #
    # list children indented just below parent
    # if multiple children at same level, order
    # those children by thier id, smallest to largest
    #
        my ($curnum) = @_[0];
        my ($parent) = @_[1];
        my ($depth) = @_[2];
        my ($child, $pads);
      # increase depth, get pad
        $depth=$depth + 2;

      printf("%3s %${depth}s %-30s \n",$parent,"",$curplan{$curnum}{$parent})  if defined ($debug);
      printf("%${depth}s %-30s \n","",$curplan{$curnum}{$parent}) ;
 
      #foreach $event  ( sort {$sum{$b} <=> $sum{$a} } keys %sum ) {
      #foreach $child (  sort keys %{$curchild{$curnum}{$parent}} ) {
      foreach $child (  sort {$curchild{$curnum}{$parent}{$a} <=> $curchild{$curnum}{$parent}{$b} } keys %{$curchild{$curnum}{$parent}} ) {
          $nchild=$curchild{$curnum}{$parent}{$child};
          printf("%s%${depth}s ->    child:%s:parent:%s:nchild:%s:%-30s \n",$depth," ",$child,$parent, $nchild, $curplan{$curnum}{$child}) if defined ($debug);
          sqlplan($curnum,$child,$depth);
       }
}

sub hist_header {
  printf("%2s  %7s ","","0");
  for ($bucket = $bucketmin; $bucket < $bucketmax; $bucket++) {
     printf ("%7s", $buckett[$bucket] );
  }
  printf ("%7s+", $buckett[$bucketmax-1] );
  printf("\n");
}

sub print_hist {

         $sum_min=0;
         $sum_max=0;

         # sum up all the buckets below the minimum bucket
         for ($bucket = 0; $bucket <= $bucketmin; $bucket++) {
             $sum_min+= $hist{$event,$bucket} ;
             printf("sum_min: %d, bucket %d value %d\n",  $sum_min,  $bucket, $hist{$event,$bucket} )  if defined($debug) ;
         }

         # sum up all the buckets above the maximum bucket
         for ($bucket = $bucketmax; $bucket <= $cur_max_bucket{$event}; $bucket++) {
             $sum_max+= $hist{$event,$bucket} ;
             printf("sum_max: %d, bucket %d value %d\n",  $sum_max,  $bucket, $hist{$event,$bucket} )  if defined($debug) ;
         }

         # if maxbucket eq min bucket add the max and min
         if ( $bucketmin < $bucketmax ) {
              printf ("%7d",  $sum_min  );              printf("\nfinal sum_min: %d \n",  $sum_min )  if defined($debug) ;
         } else  {
              printf ("%7d",  $sum_min + $sum_max  );
              printf("\n sum_max + sum_min : %d \n",  $sum_min + $sum_max )  if defined($debug) ;
         }

         # iterate through all the buckets between max and min bucket
         for ($bucket = $bucketmin+1; ( $bucket <= $cur_max_bucket{$event} && $bucket < $bucketmax ) ; $bucket++) {
             printf ("%7d",  $hist{$event,$bucket}  );
             $total+=$hist{$event,$bucket};
         }

         # print out max bucket if its below the maximum seen so far
         if ( $bucketmax <= $cur_max_bucket{$event} &&  $bucketmin  < $bucketmax ) {
            printf ("%7d",  $sum_max  );
         }

         printf("\n");
  }

  $DEBUG=0;
  if  ( 1 == $DEBUG ) { $debug=1; }

  $| = 1;


# WAIT line looks like
# WAIT #47465081986048: nam=.db file sequential read. ela= 7001 file#=1 block#=26885 blocks=1 obj#=108 tim=1331658752363171
#

  while (my $line = <STDIN>) {
       # printf("line: %s\n",  $line);
       chomp($line);

       if ( $line =~ m/END OF STMT/ ) {
          $insql=0;
       }
       #if (/^PARSING IN CURSOR/../^END OF STMT/) {
       #
       if ( $insql ) {
           if ( $curn > 0 ) {
               $ct=$curct{$curn};
               $curln{$curn,$ct}++;
               $ln=$curln{$curn,$ct};
               $curtext{$curn,$ct,$ln}=$line;
               printf("curtext{%s,%s,%s}=%s\n",$curn,$ct,$ln,$line) if defined($debug) ;
               next;
           } else { 
               printf("cursornum 0 for: %s \n",$line);
           }
       }
       # PARSING IN CURSOR #47465081932728 len=819 dep=0 uid=622 oct=47 lid=622 tim=1331658752179921 hv=2798384009 ad=.1b61ce700. sqlid=.b2318dfmcrww9.
       if ( $line =~ m/PARSING IN CURSOR/ ) {
          $insql=1;
          $curn = $dep = $sqlid = $hv = $addr = $line;
          $curn =~ s/.*CURSOR #//;    
          $curn =~ s/ .*//;    
          $dep =~ s/.*dep=//;    
          $sqlid =~ s/.*sqlid=.//;    
          $sqlid =~ s/.$//;    
          $hv =~ s/.*hv=//;    
          $hv =~ s/ .*//;    
          $addr =~ s/.*ad=//;    
          $addr =~ s/ .*//;    
          printf("%s \n",  $dep) if defined($debug);
          $dep =~ s/ .*//;    
          printf("%s \n",  $dep) if defined($debug);

          # cursor numbers can  be resuse, tract a usage count for cursor number
          $curct{$curn}++;

          $curnum=$curn . "_" . $curct{$curn};

          #$dep{$curn,$curct{$curn}}=$dep;

          $dep{$curnum}=$dep+0;
          $sqlid{$curnum}=$sqlid;
          if ( $dep > $maxdep ) { $maxdep = $dep } 

          printf("%d %d \n",  $curnum,$dep{$curnum}) if defined ($debug);
          printf("curn:%s,%s\n",$curn,$curct{$curn})if defined($debug) ;
       }

       # STAT #47465081930872 id=1 cnt=1 pid=0 pos=1 obj=0 op=.FAST DUAL  (cr=0 pr=0 pw=0 time=1 us cost=3 size=0 card=1).
       if ( $line =~ m/^STAT/ ) {
          #printf("line:%s:\n",$line);
          $cursor = $parent  = $id = $line;

          $parent =~ s/.* pid=//;    
          $parent =~ s/ .*//;    
          $id =~ s/.* id=//;    
          $id =~ s/ .*//;    
          $plan=$line;
          $plan =~ s/.* op=//;    
          $cursor =~ s/.*STAT #//;    
          $cursor =~ s/ .*//;    

          $ct=$curct{$cursor};
          $curnum=$cursor . "_" . $ct;

          $curwaits{$curnum}=$curwaits{$curnum}||0;
          $curplan{$curnum}{$id}= $plan;
          $curchild{$curnum}{$parent}{$id} = $id;

          printf("curnum:%s: parent:%s: id:%s:\n",$curnum,$parent,$id) if defined($debug) ;
          if ( defined($debug) )  {
             foreach $child  ( keys %{$curchild{$curnum}{$parent}}  ) {
                printf("child: %s \n",  $child );
             }
             printf("\n");
          }
       }

       # WAIT #47465081986048: nam=.db file sequential read. ela= 7001 file#=1 block#=26885 blocks=1 obj#=108 tim=1331658752363171
       if ( $line =~ m/WAIT/ ) {

          $cursor=$event=$ela=$line;

         # WAIT #98: nam=.db file sequential read. ela= 7001 file#=1 ...
          $ela =~ s/.*ela=//;    # remove up to "ela"
          $ela =~ s/^\s+//;      # get rid of leading space
          $ela =~ s/\s.*//;      # get rid of line from space onward

         # WAIT #474: nam=.db file sequential read. ela= ....
          $event=~ s/.*nam=.//;  # remove up to "nam"
          $event=~ s/. ela.*//;  # remove up to "nam"

          $cursor =~ s/WAIT #//;    
          $cursor =~ s/:.*//;    
          $ct=$curct{$cursor};
          $curnum=$cursor . "_" . $ct;
          $curdep=$dep{$curnum};

          $sum{$event}+=$ela;
          $ct{$event}++;

          $curct{$curnum}{$event}++;
          $cursum{$curnum}{$event}+=$ela;

          printf("curnum:%s: dep:%d: wait:%d: event:%s:\n",  $curnum,$dep{$curnum},  $cursum{$curnum}{$event},  $event) if defined($debug) ;
	  ;

          #WAIT #7014: nam=.SQL*Net message from client. ela= 72413 
          if ( $event   ne "SQL*Net message from client" )  {
             $totalwaits+=$ela;
           # $totalwaits{$curnum}+=$ela;
             $curwaits{$curnum}+=$ela;
          } else {
             #printf("event idle:%s, ela:%d, total:%d:\n", $event,$ela,$idle;
            $idle+=$ela;
          }

          if ( $ela > 0 ) {
             $bucket=int(log($ela)/log(2)+1);
             $hist{$event,$bucket}++;
             if ( $bucket >  $cur_max_bucket{$event}  ) {
                $cur_max_bucket{$event} =$bucket;
             }
          } else  {
             $zeros{$event}++;
          }

         # WAIT #4746: nam=..... ela= 7001 file#=1 block#=26885 blocks=1 obj#=108 tim...
          if ( $line =~ m/obj#/ ) {
             $obj = $line;
             $obj =~ s/.*obj#=//; # remove up to "nam"
             $obj =~ s/^\s+//;    # get rid of leading space
             $obj =~ s/ .*//;     # 
             printf("%-30s %10d %10d\n", $event, $ela,$obj ) if defined($debug) ;
          } else {
             printf("%-30s %10d \n", $event, $ela ) if defined($debug) ;
          }

        # WAIT #47: nam=.db.... ela= 7001 file#=1 block#=26885 blocks=1 obj#=108 tim=1331658752363171
          $tim=$line;
          $tim =~ s/.*tim=//; # remove up to "blocks="
          # time is in microseconds, change to seconds to geth MB per second
          $tim = int($tim/(1000*1000));
          $min = int($tim/60);

                                $ct{$event},
                       $sum{$event}/(1000*1000),
                       ($sum{$event}/$ct{$event}/1000 );
      }
      $row++;
  }


#
#  HISTOGRAMS , one line per event
#
#

# this level of detail is unneccessaryin most cases 
# add as a command line flag in the future

if ( 1 == 0 ) {
 printf("\n\n----------------------------------------------------------------------------\n");
 printf("           Histogram of latencies for each above event\n");
 printf("----------------------------------------------------------------------------\n");

  hist_header();
  $row=1;
  foreach $event  ( sort {$sum{$b} <=> $sum{$a} } keys %sum ) {
      #printf("%s\n",$event);
      printf("%2d) %7d ",$row,$zeros{$event});
      print_hist;
      $row++;
  }
} 

 printf("\n\n----------------------------------------------------------------------------\n");
 printf("Histogram of latencies  for:  \n");
 printf("                                 db file sequential read \n");
 printf("----------------------------------------------------------------------------\n");

  hist_header();
  $event="db file sequential read";
  printf("%2s  %7d ","", $zeros{$event});
  print_hist;


if ( 1 == 0 ) {
 printf("\n\n----------------------------------------------------------------------------\n");
 printf("Histogram of latencies  for:  \n");
 printf("                                 log file sync \n");
 printf("----------------------------------------------------------------------------\n");

  hist_header();
  $event="log file sync";
  printf("%2s  %6d ","", $zeros{$event});
  print_hist;
}


#
#  HISTOGRAMS  by I/O sizes
#
#
 printf("\n\n----------------------------------------------------------------------------\n");
 printf("Histogram of latencies by I/O size in # of blocks for:  \n");
 printf("                                 db file scattered read \n");
 printf("                                 direct path read       \n");
 printf("                                 direct path read temp  \n");
 printf("----------------------------------------------------------------------------\n");

      hist_header();
  foreach $iotype  ( "db file scattered read", "direct path read", "direct path read temp") {
    if ( $ct{$iotype} > 0 ) {
      printf("%s\n",$iotype);
      foreach $size  ( reverse sort keys %{$iotype} ) {
        $event="$iotype" . "$size";
        printf("%3d  %6d ",$size, $zeros{$event});
        print_hist;
      }
    }
  }

 printf("\n\n----------------------------------------------------------------------------\n");
 printf("Breakdown by SQL Statement\n");
 printf("----------------------------------------------------------------------------\n");
#
#  SQL SUMMARY
#
#          $curnum=$cursor . "_" . $ct;
#          $cursum{$curnum}{$event}+=$ela;
#          $curct{$curnum}{$event}++;
#          $curwaits{$curnum}++;

  $row=1;

  #foreach $curnum  ( sort keys %curwaits  ) {
  #}
  printf("%16s %16s %10s %10s %10s %10s %10s\n", "SQL ID", "PLAN HASH", "ELAPSED", "CPU", "WAITS", "MISSING", "CURN" );
  foreach $curnum  ( sort {$curwaits{$b} <=> $curwaits{$a} } keys %curwaits  ) {
     #($curn,$ct)=split("_",$curnum); 
     printf("%16s %16s %10d %10d %10d %10d %20s\n",$sqlid{$curnum} ,
                                          $plh{$curnum},
                                          $curela{$curnum}/(1000*1000),
                                          $curcpu{$curnum}/(1000*1000),
                                          $curwaits{$curnum}/(1000*1000),
                                          ($curela{$curnum} - ( $curcpu{$curnum} + $curwaits{$curnum} ))/(1000*1000), 
                                          $curnum
    );
  }
  foreach $curnum  ( sort {$curwaits{$b} <=> $curwaits{$a} } keys %curwaits  ) {
     ($curn,$ct)=split("_",$curnum); 
     printf("curn:%s:ct:%s:curnum:%s:\n",$curn,$ct,$curnum) if defined($debug) ;
     printf(" \n--------------------------- \n");
     #
     # SQL TEXT
     #
     printf("  SQL ID:   %s\n",$sqlid{$curnum});
     printf("  PLAN HASH:%s\n",$plh{$curnum});
     printf("  CURSOR # :%s\n",$curnum);
     for ( $ln=1;$ln<=$curln{$curn,$ct}; $ln++ ) {
          #printf("debug: %s\n",$curtext{$curn,$ct,$ln});
          lines( $curtext{$curn,$ct,$ln});
     }
     #
     # STATISTICS
     #
     printf("    -------------------------------------------------------------\n" );
     printf("          events for quyery                                \n" );
     printf("    -------------------------------------------------------------\n" );
     printf("    %-30s %10s %10s %9s\n","event", "count", "total secs","avg ms" );
     printf("    %-30.30s %-10.10s %-10.10s %-9.9s\n", "---------------------------------", 
                                         "---------------------------------", 
                                         "---------------------------------", 
                                         "---------------------------------"
     );
#    $curela{$curnum}/(1000*1000),
#    $curcpu{$curnum}/(1000*1000),
#    $curwaits{$curnum}/(1000*1000),
#
#    ($curela{$curnum} - ( $curcpu{$curnum} + $curwaits{$curnum} ))/(1000*1000), 
     foreach $event  ( sort {$cursum{$curnum}{$b} <=> $cursum{$curnum}{$a} } keys %{$cursum{$curnum}}  ) {
       if ( $curct{$curnum}{$event} > 0 ) {
           printf("    %-30s %10d %10d %9.3f \n",
                   $event,
                   $curct{$curnum}{$event},
                   $cursum{$curnum}{$event}/(1000*1000),
                   ($cursum{$curnum}{$event}/$curct{$curnum}{$event})/1000 );
                   #0,0,0);
       } else {
           printf("    %-30s %10s %10d %9s \n",
                   $event,
                   "",
                   $cursum{$curnum}{$event}/(1000*1000),
                   "");
       }
     }

     # id=1 pid=0 SORT ORDER BY (cr=22 pr=0 pw=0 time=347 us cost
     # id=2 pid=1 NESTED LOOPS OUTER (cr=22 pr=0 pw=0 time=530 u
     # id=3 pid=2 TABLE ACCESS BY INDEX ROWID DEPENDENCY$ (cr=3
     # id=4 pid=3 INDEX RANGE SCAN I_DEPENDENCY1 (cr=2 pr=0 pw
     # id=5 pid=2 TABLE ACCESS BY INDEX ROWID OBJ$ (cr=19 pr=
     # id=6 pid=5 INDEX RANGE SCAN I_OBJ1 (cr=12 pr=0 pw=0 t

     # for each plan row thats parent is 0, ie root
     printf("    -------------------------------------------------------------\n" );
     printf("        execution plan for quyery                                \n" );
     printf("    -------------------------------------------------------------\n" );
     foreach $id (  keys %{$curchild{$curnum}{0}} ) {
        #printf("sqlplan, id:%s:\n",$id);
        sqlplan($curnum,$id,6);
     }

  }

#
#  I/O per seconds
#
#      
#    multi-block reads           min MB/s
#                                    MB/s
#                                max MB/s
#    sequential , single block,  min MB/s
#                                    MB/s
#                                max MB/s
#                              block size
#
 printf("----------------------------------------------------------------------------\n");
 printf("      I/O throughput per second (includes any files system cache reads) \n");
 printf("----------------------------------------------------------------------------\n");
      printf("%10s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s\n",
               "time",
               "min mult",
               "MB/s ",
               "max mult",
               "blocks ",
               "mn single",
               "MB/s ",
               "mx single",
               "MB/s dpr",
               "mx dpr",
               "MB/s dprt",
               "mx dprt"
       );

  foreach $tim  ( sort keys %bps ) {
      printf("%10d %8.1f %8.1f %8.1f %8d %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f \n",$tim,
               $min_bps{$tim}    /(1024*1024) ,
               $bps_scat{$tim}        /(1024*1024) , 
               $max_bps_scat{$tim}    /(1024*1024) ,
               $max_bps_sz{$tim}              ,
               $min_bps_seq{$tim}/(1024*1024) ,
               $bps_seq{$tim}    /(1024*1024) , 
               $max_bps_seq{$tim}/(1024*1024) , 
               $bps_dpr{$tim}    /(1024*1024) , 
               $max_bps_dpr{$tim}/(1024*1024) ,
               $bps_dprt{$tim}    /(1024*1024) , 
               $max_bps_dprt{$tim}/(1024*1024) ) ;
       if ( $tim == $fastread ) { 
               print "XXX max end $tim $max_bps_dprt{$tim} \n";
       }
       # alternative calculation of per minute
       #$min=int($tim/60);
       #$permin_sm_tmp{$min}+= $bps_scat{$tim} +  $bps_seq{$tim} + $bps_dpr{$tim} + $bps_dprt{$tim};
       #$permin_ct_tmp{$min}++;
  }
  #foreach $min ( sort keys %permin_ct_tmp ) {
  #	    printf("%10d %10.2f  %10d\n",$min, ($permin_sm_tmp{$min}/60)/(1024*1024), $permin_ct_tmp{$min});
  #} 

  printf("%10s %10s  %10s\n", "minute", "MB/s", "count" );
  foreach $tim  ( sort keys %permin_tm ) {
	    #printf("tmp %10.2f  %10d, real ", ($permin_sm_tmp{$tim}/60)/(1024*1024), $permin_ct_tmp{$tim});
	    printf("%10d %10.2f  %10d\n",$tim, ($permin_sm{$tim}/60)/(1024*1024), $permin_ct{$tim});
    #if ( $permin_ct{$tim} > 0 ) {
    #   printf("%10d %10.2f  %10d\n",$tim, ($permin_tm{$tim}/$permin_ct{$tim})/1000, $permin_ct{$tim});
    #} else {
    #   printf("%10d %10.2f  %10d\n",$tim, "", $permin_ct{$tm});
    #}
  }

  if ( 1 == 0 ) {
  foreach $curn  ( sort keys %curct  ) {
      printf("cursor number:%s:\n",$curn);
      for ( $ct=1;$ct<=$curct{$curn}; $ct++ ) {
        printf("    cursor count:%s:\n",$ct);
        for ( $ln=1;$ln<=$curln{$curn,$ct}; $ln++ ) {
          printf("         cursor line:%s:\n",$ln);
          printf("         ");
          printf("curtext{%s,%s,%s}=%s\n",$curn,$ct,$ln, $curtext{$curn,$ct,$ln});
        }
      }
  }
  }
'
