#!/usr/local/bin/perl 

use DBI;



# -------------------------------------------------------------------
sub flush {
   my $FILE_TO_FLUSH = @_ ;
   my $ofh = select $FILE_TO_FLUSH;
   $| = 1;                    # Make SPL_WAIT socket hot
   print $FILE_TO_FLUSH "";         # print nothing
   $| = 0;                    # SPL_WAIT socket is no longer hot
   select $ofh;
}
# -------------------------------------------------------------------
sub f_localtime {
   my ($a,$b,$c,$d,$e,$f,$g,$h,$i)=localtime(time);
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
   $sec=sprintf("%02d",$a);
   $min=sprintf("%02d",$b);
   $hour=sprintf("%02d",$c);
   $mday=sprintf("%02d",$d);
   $mon=sprintf("%02d",$e+1);
   $year=$f+1900;
   $sec=$g;
   $sec=sprintf("%03d",$h);
   $sec=$i;
   return $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst;
   
}
# -------------------------------------------------------------------
sub check_params {
   my $ret=1;
   if ( length($user) == 0 ) { 
        print "No user defined for connection" ;
        $ret=0;
   }
   if ( length($passwd) == 0 ) { 
        print "No passwd defined for connection" ;
        $ret=0;
   }
   return $ret;
}
# -------------------------------------------------------------------
#  -------------- variable declaration ------------------------------
# -------------------------------------------------------------------


my $max_len=1800;
my $sql_wait_interval=1;
my $delta_max_interval=180;
my $delta_curr_len=1;
my $dir_out='./';
my $curr_len=0 ;
my $SID=$ENV{'ORACLE_SID'};
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=f_localtime();
my ($sid,$seqn,$eventn,$evn,$wt,$siw,$p1,$p1r,$p1text,$p2,$p2r,$p2text,$p3,$p3text,$shv,$phv,$rwo) ;
#
#  --------------------  my getopts ----------------------------------
#
my $i=0;
while ($i <= $#ARGV){

  if ( $ARGV[$i] eq "-l" ){
     $max_len=$ARGV[++$i];
  }

  if ( $ARGV[$i] eq "-i" ){
     $sql_wait_interval=$ARGV[++$i];
  }

  if ( $ARGV[$i] eq "-d" ){
     $dir_out=$ARGV[++$i];
  }

  if ( $ARGV[$i] eq "-s" ){
     $delta_max_interval=$ARGV[++$i];
  }

  if ( $ARGV[$i] eq "-u" ){
     $user=$ARGV[++$i];
  }

  if ( $ARGV[$i] eq "-p" ){
     $passwd=$ARGV[++$i];
  }

  if ( $ARGV[$i] eq "-o" ){
     $SID=$ARGV[++$i];
  }

  $i++;
}
print "SID=$SID user=$user passwd=$passwd\n" ;

my $dbh = DBI->connect( 'dbi:Oracle:'.$SID, $user, $passwd) || die "Database connection not made: $DBI::errstr";
#   $dbh->{AutoCommit}    = 0;
$dbh->{RaiseError}    = 1;  # When turned on (off by default) it sends an exception to your script and terminates it
$dbh->{ora_check_sql} = 0;  # Decreases the number of the needed database calls, by bundling "parse" and "execute"
$dbh->{RowCacheSize}  = 16; # create a local pre-fetch cache and defines its size.

# uncomment to test
my $sql_i=qq(select version from v\$instance);
my $sth=$dbh->prepare($sql_i);
$sth->execute;
$sth->bind_columns(\$x);
$sth->fetch ;
$version=substr($x,0,1);

print $version ;
if (check_params == 0 ) {
     exit 1  ;
}

if (check_params == 0 ) { 
     printf "Checck params failed\n";
     exit 1  ; 
}

#
# --------------------------- Define and  open output files --------------------------
#
$sampler_txt=$dir_out.'/'.'sample_txt_w_'.$SID.'.'.$mon.$mday.$hour.$min ;
$sampler_delta=$dir_out.'/'.'sample_delta_w_'.$SID.'.'.$mon.$mday.$hour.$min ;
$sampler_sys=$dir_out.'/'.'sample_sys_w_'.$SID.'.'.$mon.$mday.$hour.$min ;
$sampler_wait=$dir_out.'/'.'sample_sql_w_'.$SID.'.'.$mon.$mday.$hour.$min ;
$sampler_evt=$dir_out.'/'.'sample_evt_w_'.$SID.'.'.$mon.$mday.$hour.$min ;
$semaphore=$dir_out.'/'.'sem_sql_w_'.$SID.'.txt' ;
# Create the 5 files
if (! open(SPL_TXT,">$sampler_txt") )   { die "Can't open output file $sampler_txt\n";   }
if (! open(SPL_SYS,">$sampler_sys") )  { die "Can't open output file $sampler_sys\n";  }
if (! open(SPL_DEL,">$sampler_delta"))  { die "Can't open output file $sampler_delta\n"; }
if (! open(SPL_WAIT,">$sampler_wait") )   { die "Can't open output file $sampler_wait\n";   }
if (! open(SPL_EVT,">$sampler_evt") )   { die "Can't open output file $sampler_evt\n";   }
# create the 4 SQ

#
# --------------------------- Create the text for the SQL sampler -------------------
#
my $sql_t0=qq(select to_char(hash_value) hv, to_char(piece) pi, sql_text st from v\$sqltext order by piece);
my $sql_t1=qq{select to_char(hash_value) hv, to_char(piece) pi, sql_text st from v\$sqltext 
                   where hash_value=:hv order by piece};

my $sql_d;
if ( $version == 8 ){
     $sql_d=qq{select to_char(HASH_VALUE) hv, to_char(ROWS_PROCESSED) rp,to_char(DISK_READS) dr,
                 '0' fe, to_char(EXECUTIONS) ex, to_char(loads) lo,
                 to_char(PARSE_CALLS) pa, to_char(BUFFER_GETS) bg, to_char(SORTS) so,
                 '0' ct, FIRST_LOAD_TIME fl, '0' phv, to_char(child_number) chn, module md from v\$sql};
printf( "sql_d=%s\n",$sql_d);
} else {
     $sql_d=qq{select to_char(HASH_VALUE) hv, to_char(ROWS_PROCESSED) rp,to_char(DISK_READS) dr,
                  to_char(FETCHES) fe, to_char(EXECUTIONS) ex, to_char(loads) lo,
                  to_char(PARSE_CALLS) pa, to_char(BUFFER_GETS) bg, to_char(SORTS) so,
                  to_char(CPU_TIME) ct, FIRST_LOAD_TIME fl, to_char(PLAN_HASH_VALUE) phv,
                  to_char(child_number) chn, module md from v\$sql};
}
my $sql_s=qq{select to_char(STATISTIC#) stn, name,to_char(value) value from v\$sysstat};

my $sql_w=qq{select to_char(w.SID) sid,to_char(w.SEQ#) seqn, n.event# evn, w.EVENT,
        to_char(w.WAIT_TIME) wt, to_char(w.SECONDS_IN_WAIT) siw,
       to_char(w.p1) p1, to_char(rawtohex(w.p1raw)) p1r, w.p1text,
       to_char(w.p2) p2, to_char(rawtohex(w.p1raw)) p2r, w.p2text,
       to_char(w.p3) p3, w.p3text, to_char(s.sql_hash_value)shv,to_char(s.prev_hash_value)phv,
       to_char(ROW_WAIT_OBJ#) rwo
   from v\$session_wait w, v\$session s, v\$event_name n
       where w.sid = s.sid (+)                      and
           w.event = n.name                       and
           w.event != 'pmon timer'                  and
           w.event != 'rdbms ipc message'           and
           w.event != 'PL/SQL lock timer'           and
           w.event != 'SQL*Net message from client' and
           w.event != 'client message'              and
           w.event != 'pipe get'                    and
           w.event != 'Null event'                  and
           w.event != 'wakeup time manager'         and
           w.event != 'slave wait'                  and
           w.event != 'smon timer' };

my $sql_evt=qq{select to_char(a.sid) sid,to_char(b.serial#) serial,a.EVENT, to_char(a.TOTAL_WAITS) TOTAL_WAITS,
                      to_char(a.TOTAL_TIMEOUTS) TOTAL_TIMEOUTS, to_char(a.TIME_WAITED) TIME_WAITED,
                      to_char(a.AVERAGE_WAIT) AVERAGE_WAIT, to_char(a.MAX_WAIT) MAX_WAIT,
                      to_char(a.TIME_WAITED_MICRO) TIME_WAITED_MICRO,b.program,b.module,b.action,b.username
                 from v\$session_event a, v\$session b where a.sid=b.sid};
my $sql_m=qq{ select hash_value from v\$sqltext minus select hash_value hash_value from tbl_hv };
my $sql_y=qq{insert into tbl_hv values(:hv)};

# --------------------------- Check for HV global table  and insert init rows ---------
  my $fsql=qq{select count(1) cpt from all_tables where table_name = 'TBL_HV'};
  my $sth = $dbh->prepare( $fsql );
  $sth->execute();
  $sth->bind_columns(\$cpt) ;
  $sth->fetch();
  if ( $cpt == 0 ) {
     print "creating tbl_vh\n";
     if ( $version == 8 ) {
         $fsql=qq{create table tbl_hv ( HASH_VALUE NUMBER) }; 
     } else {
         $fsql=qq{create global temporary table tbl_hv (HASH_VALUE NUMBER) on commit preserve rows};
     }
     $sth = $dbh->prepare( $fsql );
     $sth->execute();
  }else {
     if ( $version == 8 ) {
         $fsql=qq{truncate table tbl_hv }; 
         $sth = $dbh->prepare( $fsql );
         $sth->execute();
     }  # for versiont 9i+ no need to truncate since we use temp table
  } 
  $fsql=qq{insert into tbl_hv select distinct hash_value from v\$sqltext};
  $sth = $dbh->prepare( $fsql );
  $sth->execute();

  $fsql=qq(select count(1) cpt from tbl_hv);
  $sth = $dbh->prepare( $fsql );
  $sth->execute();
  $sth->bind_columns(\$cpt) ;
  $sth->fetch();

# --------------------------- initial dump ------------------------------------------

  # ................ Dump text .................................
  $sth = $dbh->prepare($sql_t0);
  $sth->execute();
  $sth->bind_columns(\$hv, \$pi ,\$st) ;
  while( $sth->fetch() ) {
     print SPL_TXT "$hv\{$pi\{$st\n";
  }

  # ................ Dump Delta ...................................
  $sth = $dbh->prepare( $sql_d );
  $sth->execute();
  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=f_localtime();
  my $DDATE=$year.$mon.$mday.$hour.$min.$sec;
  $sth->bind_columns(\$hv, \$rp ,\$dr, \$fe, \$ex, \$lo, \$pa, \$bg, \$so, \$ct, \$fl, \$phv, \$chn, \$md ) ;
  while( $sth->fetch() ) {
      print SPL_DEL "$DDATE\{$hv\{$rp\{$dr\{$fe\{$ex\{$lo\{$pa\{$bg\{$so\{$ct\{$fl\{$phv\{$chn\{$md\n" ;
  }

  # ................ Dump sys Waits ...................................
  $sth = $dbh->prepare($sql_s);
  $sth->execute();
  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=f_localtime(); 
  $DDATE=$year.$mon.$mday.$hour.$min.$sec;
  $sth->bind_columns(\$stb,\$name,\$value);
  while( $sth->fetch() ) {
      print SPL_SYS "$DDATE\{$stb\{$name\{$value\n" ;
  }

  # ................ Dump session_event ...................................
  $sth = $dbh->prepare($sql_evt);
  $sth->execute();
  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=f_localtime(); 
  $DDATE=$year.$mon.$mday.$hour.$min.$sec;
  $sth->bind_columns(\$sid,\$se,\$ev,\$tow,\$tt,\$tiw,\$avw,\$mw,\$twm,\$prg,\$mod,\$act,\$usr);
  while( $sth->fetch() ) {
      print SPL_EVT "$DDATE\{$sid\{$se\{$ev\{$tow\{$tt\{$tiw\{$avw\{$mw\{$twm\{$prg\{$mod\{$act\{$usr\n" ;
  }

# --------------------------- Start main loop -------------------------------------------
$cpt_flush=0;  
$sth_w = $dbh->prepare($sql_w);

while ($curr_len <= $max_len)
{

#  printf( "curr_len=%s delta_curr_len=%s delta_max_interval=%s max_len=%s\n", $curr_len, $delta_curr_len, $delta_max_interval, $max_len) ;
  # ................ check sth_w is parsed and execute it ....................
  if (! defined $sth_w) {
        $sth_w = $dbh->prepare($sql_w) 
                 or die "Couldn't prepare statement: " . $dbh->errstr; }
  $sth_w->execute() 
          or die "execute w: " . $dbh->errstr();;

  # ................ retrieve and print stw_w ...................................
  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=f_localtime(); 
  $DDATE=$year.$mon.$mday.$hour.$min.$sec;
  $sth_w->bind_columns( \$sid, \$seqn, \$eventn, \$evn, \$wt, \$siw, \$p1, \$p1r, \$p1text, \$p2, \$p2r,
                        \$p2text, \$p3, \$p3text, \$shv, \$phv, \$rwo);
  while( $sth_w->fetch() ) {
      print SPL_WAIT "$DDATE\{$sid\{$seqn\{$eventn\{$evn\{$wt\{$siw\{$p1\{$p1r\{$p1text\{$p2\{$p2r\{$p2text\{$p3\{$p3text\{$shv\{$phv\{$rwo\n" ;
  }
  # ................ Check delta and new text ..............................
  if ( $delta_curr_len > $delta_max_interval )
  {
       $delta_curr_len=1;
       if (! defined $sth_m) {
          $sth_m= $dbh->prepare($sql_m)
                  or die "Couldn't prepare statement: " . $dbh->errstr; 
       }
       $sth_m->execute() 
               or die "execute w: " . $dbh->errstr();;

       # ............ Check new text and them into into tbl_hv .............
       $sth_m-> bind_columns(\$hv);
       while( $sth_m->fetch() ) 
       {
          if (! defined $sth_y ){
              $sth_y = $dbh->prepare($sql_y);}
          $sth_y->bind_param(":hv",$hv);
          $sth_y->execute ;

          # Dump these new text values
          if (! defined $sth_t1 ){
              $sth_t1 = $dbh->prepare($sql_t1);}
          $sth_t1->bind_param(":hv",$hv);
          $sth_t1->execute ;
          $sth_t1-> bind_columns(\$hv,\$pi,\$st);
          while ( $sth_t1->fetch() ) {
             print SPL_TXT "\{$hv\{$pi\$st\n";
          }
       }
       flush 'SPL_TXT';
       # ................ Dump Delta ...................................
       if (! defined $sth_d) {
           $sth_d = $dbh->prepare($sql_d);}
       $sth_d->execute();
       ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=f_localtime(); 
       $DDATE=$year.$mon.$mday.$hour.$min.$sec;
       $sth_d->bind_columns(\$hv, \$rp ,\$dr, \$fe, \$ex, \$lo, \$pa, \$bg, \$so, \$ct, \$fl, \$phv, \$chn, \$md ) ;
       while( $sth_d->fetch() ) {
           print SPL_DEL "$DDATE\{$hv\{$rp\{$dr\{$fe\{$ex\{$lo\{$pa\{$bg\{$so\{$ct\{$fl\{$phv\{$chn\{$md\n" ;
       
       }
       flush 'SPL_DEL';
       # ................ Dump session event ..........................
       if (! defined $sth_evt) {
           $sth = $dbh->prepare($sql_evt);}
       $sth->execute();
       ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=f_localtime(); 
       $DDATE=$year.$mon.$mday.$hour.$min.$sec;
       $sth->bind_columns(\$sid,\$se,\$ev,\$tow,\$tt,\$tiw,\$avw,\$mw,\$twm,\$prg,\$mod,\$act,\$usr);
       while( $sth->fetch() ) {
           print SPL_EVT "$DDATE\{$sid\{$se\{$ev\{$tow\{$tt\{$tiw\{$avw\{$mw\{$twm\{$prg\{$mod\{$act\{$usr\n" ;
       }
       flush 'SPL_EVT';
       # ................ Check the semaphore file ...................
       if ( open(SEM,"$semaphore") )   {
            $LINE=<SEM>;
            chomp($LINE);
            if ( $LINE eq 'stop' ) {
                printf("Last called from semaphore file\n");
                last ;
            }
       }
       clos(SEM);
            
  }
  sleep($sql_wait_interval);
  $delta_curr_len++;
  $curr_len++;
  $cpt_flush++;
  if ($cpt_flush > 10 ){
      $cpt_flush=0;
      flush 'SPL_WAIT';
  }
}
close(SPL_DEL);
close(SPL_WAIT);
close(SPL_TXT);
close(SPL_SYS);
$sth->finish();
$sth_d->finish();
$sth_w->finish();
$sth_m->finish();
$dbh->disconnect();
