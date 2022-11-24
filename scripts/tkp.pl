#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  10046_events.pl
#
#        USAGE:  ./10046_events.pl  
#
#  DESCRIPTION: Provides statistical report of 10046 wait events from
#               raw trace file.
#
#               For pre Oracle 10.2 trace files the breakdown and histogram
#               sections of the report are based on unique P1 and event
#               combinations. For tracefiles produced from 10.2 onwards
#               these sections are reported for each unique combination 
#               of obj# and event.
#
#      OPTIONS:  -h -t trace_file.trc
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Clive Bostock (Oracle ACS)
#      COMPANY:  
#      VERSION:  1.2
#      CREATED:  17/04/2011 11:14:22
#     REVISION:  19/05/2011 Kyle Hailey (Oracle ACE) - modified parsing event names 
#===============================================================================
use strict;
use warnings;
use File::Basename;
use Getopt::Std;

my @trace_file;
my @events;
my %event_records;
my %tot_sort;
my %tot_objn_sort;
my $ver = '1.2';
my $trace_file;
our $opt_t;
our $opt_h;
our $prog     = basename($0);
my $event_line;
my $event_rec;
my $aggr_rec;
my $er;
my %event_stat;
my %event_aggr;
my $event;
my $elapsed;
my $tot_ela = 0;
my $ela_ms;
my $objid;
my $objid_event;
my $pre_10_2    = 0;
my $obj_header  = 'Object Id';
my $e1    = 0;
my $e2    = 0;
my $e4    = 0;
my $e8    = 0;
my $e16   = 0;
my $e32   = 0;
my $e64   = 0;
my $e128  = 0;
my $e256  = 0;
my $e512  = 0;
my $e1024 = 0;

our $SD="\/";
our $SP=":";
our $os = $ENV{'OS'}; 
if ( ! $os )
  { $os = $ENV{'OSTYPE'}; }
if ( ! $os )
  { 
     $os = `uname`;
     chomp $os;  
  }
if ( ! $os )
  { 
     $os = 'Unknown';
  }

$SD="\\" if($os  =~ /Win/i);
$SP=";" if($os   =~ /Win/i);

getopts('ht:') or 
    die "\nInvalid options specified, use $prog -h.\n$prog: Deploying chute and bailing out!!!\n";

if (defined($opt_t))
{
    $trace_file = $opt_t;
}
if (defined($opt_h))
{
    print "\nUsage:  $prog -t trace_file.trc\n\n";
    exit;
}

if (! defined($opt_t))
{
    print "\nUsage:  $prog -t trace_file.trc\n\n";
    exit;
}

open(TRACEFILE, $trace_file) || die "Failed to open trace file ($trace_file)\n";

printf "$prog: 10046 traces events analyser ver $ver\n\n";
@trace_file = <TRACEFILE>;
close(TRACEFILE);

print "*** Trace file header details ***\n\n";
foreach $event_line (@trace_file)
{
    chomp $event_line;
    if (length($event_line))
         { printf("$event_line\n"); }
    else { last; }
}
print "Trace input file : $trace_file\n";
                                       #**************************************/
                                       #* Load only the WAIT event lines     */
                                       #* into @events                       */
                                       #**************************************/
@events = grep(/WAIT/, @trace_file);
chomp @events;

foreach $event_line (@events)
{

    $event = $elapsed = $objid = $event_line;
    # $event =~ s/^.*nam='([\\:\w\s\d-]+)'.*/$1/;
    $event =~ s/^.*nam='//;
    $event =~ s/' ela=.*//;
    $elapsed  =~ s/^.*ela=[\s]*([\d]+) .*/$1/;
    if ( $pre_10_2 == 0 )
    {
        if ( $event_line !~ m/obj#/ )
        { 
            print "\n\n***********************************************\n";
            print "*** Trace file format looks pre Oracle 10.2 ***\n";
            print "***********************************************\n\n";
            $pre_10_2 = 1; 
        }
    }

    if ($pre_10_2 )
    {
        $objid  =~ s/^.*p1=[-\s]*([\d]+) .*/$1/;
        $obj_header = 'P1';
    }
    else
    {
        $objid  =~ s/^.*obj#=[-\s]*([\d]+) .*/$1/;
    }

    $objid_event = sprintf("%-19s: %-45s", $objid, $event);
#   printf ("%s %s %s\n", $event, $elapsed, $objid);

                                       #**************************************/
                                       #*  We maintain this (simple) hash    */
                                       #* as a method of sorting by total    */
                                       #* elapsed time per event             */
                                       #**************************************/
    if (exists $tot_sort{$event})
    {    
      $tot_sort{$event} = $tot_sort{$event} + $elapsed;
    }
    else
    {
      $tot_sort{$event} = $elapsed;
    }

                                       #**************************************/
                                       #*  Get histogram counts              */
                                       #**************************************/
    $ela_ms = $elapsed / 1000;
    $tot_ela = $tot_ela + $elapsed;
    $e1 = $e2 = $e4 = $e8 = $e16 = $e32 = $e64 = $e128  = $e256 = $e512 = $e1024 = 0;
    if ( $ela_ms < 1 )
    { $e1 = 1 }
    elsif ( $ela_ms < 2  &&  $ela_ms >= 1 )
    { $e2 = 1 }
    elsif ( $ela_ms < 4  &&  $ela_ms >= 2 )
    { $e4 = 1 }
    elsif ( $ela_ms < 8  &&  $ela_ms >= 4 )
    { $e8 = 1 }
    elsif ( $ela_ms < 16  &&  $ela_ms >= 8 )
    { $e16 = 1 }
    elsif ( $ela_ms < 32  &&  $ela_ms >= 16 )
    { $e32 = 1 }
    elsif ( $ela_ms < 64  &&  $ela_ms >= 32 )
    { $e64 = 1 }
    elsif ( $ela_ms < 128  &&  $ela_ms >= 64 )
    { $e64 = 1 }
    elsif ( $ela_ms < 256  &&  $ela_ms >= 128 )
    { $e128 = 1 }
    elsif ( $ela_ms < 512  &&  $ela_ms >= 256 )
    { $e256 = 1 }
    else 
    { $e1024 = 1 };


                                       #**************************************/
                                       #*  Build an anonymous record         */
                                       #* structure containing our event     */
                                       #* data.                              */
                                       #**************************************/
    $event_rec = {OBJ_EVENT => $objid_event
               , TOT_ELA => $elapsed
               , COUNT => 1
               , E1    => $e1
               , E2    => $e2
               , E4    => $e4
               , E8    => $e8
               , E16   => $e16
               , E32   => $e32
               , E64   => $e64
               , E128  => $e128
               , E256  => $e256
               , E512  => $e512
               , E1024 => $e1024
                 };
    if ($er = $event_stat{$objid_event})
        { 
            $er->{COUNT}   = $er->{COUNT} + 1;
            $er->{TOT_ELA} = $er->{TOT_ELA} + $event_rec->{TOT_ELA};
            $er->{TOT_ELA} = $er->{TOT_ELA} + 1;
            $er->{E1}      = $er->{E1}      + $event_rec->{E1};
            $er->{E2}      = $er->{E2}      + $event_rec->{E2};
            $er->{E4}      = $er->{E4}      + $event_rec->{E4};
            $er->{E8}      = $er->{E8}      + $event_rec->{E8};
            $er->{E16}     = $er->{E16}     + $event_rec->{E16};
            $er->{E32}     = $er->{E32}     + $event_rec->{E32};
            $er->{E64}     = $er->{E64}     + $event_rec->{E64};
            $er->{E128}    = $er->{E128}    + $event_rec->{E128};
            $er->{E256}    = $er->{E256}    + $event_rec->{E256};
            $er->{E512}    = $er->{E512}    + $event_rec->{E512};
            $er->{E1024}   = $er->{E1024}   + $event_rec->{E1024};
            $event_stat {$er -> {OBJ_EVENT}} = $er;
            $er->{E1} = $er->{E1} + $event_rec->{E1};
            $tot_objn_sort{$objid_event} = $tot_objn_sort{$objid_event} + $elapsed;
        }
    else
        { 
            $event_stat {$event_rec -> {OBJ_EVENT}} = $event_rec;
            $tot_objn_sort{$objid_event} = $elapsed;
        }

    $aggr_rec = {EVENT => $event, TOT_ELA => $elapsed,  COUNT => 1};
    if ($er = $event_aggr{$event})
        { 
            $er->{COUNT}   = $er->{COUNT} + 1;
            $er->{TOT_ELA} = $er->{TOT_ELA} + $aggr_rec->{TOT_ELA};
            $er->{TOT_ELA} = $er->{TOT_ELA} + 1;
            $event_aggr {$er -> {EVENT}} = $er;
        }
    else
        { 
            $event_aggr {$aggr_rec -> {EVENT}} = $aggr_rec;
        }
}

print "\nEVENT AGGREGATES\n";
print "================\n\n";
printf ("Wait Event %s Count        Elapsed (ms)     Avg Ela (ms)  %%Total \n",' ' x 34);
printf ("~~~~~~~~~~~%s ~~~~~~~~~~~~ ~~~~~~~~~~~~     ~~~~~~~~~~~~  ~~~~~~\n",'~' x 34);
foreach $objid_event (sort {$tot_sort{$b} <=>  $tot_sort{$a} } keys %event_aggr)
{
    my $ev = $event_aggr{$objid_event};
    printf("%45s %12d %12d     %12d  %6.2f\n",$ev->{EVENT}, $ev->{COUNT}, $ev->{TOT_ELA}/1000, ($ev->{TOT_ELA}/$ev->{COUNT})/1000, ($ev->{TOT_ELA}*100/$tot_ela) ); 
}
printf("           %s              ~~~~~~~~~~~~                         \n",' ' x 34);
printf ("         %s Total Elapsed: %12d                                   \n",' ' x 34,$tot_ela / 1000);
print "\nEVENT AGGREGATE BREAKDOWN\n";
print "=========================\n\n";
printf ("%-9s          : Wait Event %s Count        Tot Ela (ms) %%Total Avg Ela (ms)\n",$obj_header, ' ' x 34);
printf ("~~~~~~~~~~~~~~~~~~ : ~~~~~~~~~~~%s ~~~~~~~~~~~~ ~~~~~~~~~~~~ ~~~~~~ ~~~~~~~~~~~~\n",'~' x 34);
foreach $objid_event (sort {$tot_objn_sort{$b} <=>  $tot_objn_sort{$a} } keys %event_stat)
{
    my $ev = $event_stat{$objid_event};
    printf("%57s %12d %12d  %5.2f %12d\n",$ev->{OBJ_EVENT}, $ev->{COUNT}, $ev->{TOT_ELA}/1000
                                       , $ev->{TOT_ELA}*100/$tot_ela, ($ev->{TOT_ELA}/$ev->{COUNT})/1000); 
}
print "\nEVENT HISTOGRAM BREAKDOWN\n";
print "===========================\n\n";
print "This section splits the event counts into elapsed time\n";
print "buckets so that we can see if there are any suspiciousn\n";
print "or anomalous response time / frequency patterns.\n\n";
printf("%-9s          : Wait Event %s <1ms    <2ms    <4ms    <8ms    <16ms   <32ms   <64ms   <128ms  <256ms  <512ms  >=1024ms\n",$obj_header, ' ' x 34);
printf("~~~~~~~~~~~~~~~~~~ : ~~~~~~~~~~~%s ~~~~~~~ ~~~~~~~ ~~~~~~~ ~~~~~~~ ~~~~~~~ ~~~~~~~ ~~~~~~~ ~~~~~~~ ~~~~~~~ ~~~~~~~ ~~~~~~~~\n",'~' x 34);
foreach $objid_event (sort {$tot_objn_sort{$b} <=>  $tot_objn_sort{$a} } keys %event_stat)
{
    my $ev = $event_stat{$objid_event};
    printf("%60s ", $ev->{OBJ_EVENT});
    printf("%7s %7s %7s ", $ev->{E1},    $ev->{E2},    $ev->{E4}); 
    printf("%7s %7s %7s ", $ev->{E8},    $ev->{E16},   $ev->{E32});
    printf("%7s %7s %7s ", $ev->{E64},   $ev->{E128},  $ev->{E256});
    printf("%7s %8s\n", $ev->{E512},  $ev->{E1024} ); 
}
printf("\n\n*** End of report ***\n");

