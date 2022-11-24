# also available
#alter session set events '10704 trace name context forever, level 15';
#Event 10704 is documented as below:

#10704, 00000, "Print out information about what enqueues are being obtained"
#// *Cause:  When enabled, prints out arguments to calls to ksqcmi and
#//          ksqlrl and the return values.
#// *Action: Level indicates details:
#//   Level: 1-4: print out basic info for ksqlrl, ksqcmi
#//          5-9: also print out stuff in callbacks:  ksqlac, ksqlop
#//          10+: also print out time for each line
#
spool call_eng_hw1.lst
REM Test cases #1 through #6
 @enq_hw1 "autoallocate segment space management auto"
 @enq_hw1 "uniform size 15M segment space management auto"
 @enq_hw1 "uniform size 16M segment space management auto"
 @enq_hw1 "uniform size 17M segment space management auto"
 @enq_hw1 "uniform size 18M segment space management auto"
 @enq_hw1 "uniform size 19M segment space management auto"
 @enq_hw1 "uniform size 20M segment space management auto"
 @enq_hw1 "uniform size 21M segment space management auto"
 @enq_hw1 "uniform size 22M segment space management auto"
 @enq_hw1 "uniform size 23M segment space management auto"
 @enq_hw1 "uniform size 24M segment space management auto"
 @enq_hw1 "uniform size 25M segment space management auto"
 @enq_hw1 "uniform size 26M segment space management auto"
 @enq_hw1 "uniform size 27M segment space management auto"
 @enq_hw1 "uniform size 28M segment space management auto"
 @enq_hw1 "uniform size 29M segment space management auto"
 @enq_hw1 "uniform size 30M segment space management auto"
 @enq_hw1 "uniform size 31M segment space management auto"
 @enq_hw1 "uniform size 32M segment space management auto"
 @enq_hw1 "uniform size 33M segment space management auto"
 @enq_hw1 "uniform size 34M segment space management auto"
 @enq_hw1 "uniform size 35M segment space management auto"
 @enq_hw1 "uniform size 36M segment space management auto"
 @enq_hw1 "uniform size 37M segment space management auto"
 @enq_hw1 "uniform size 38M segment space management auto"
 @enq_hw1 "uniform size 39M segment space management auto"
 @enq_hw1 "uniform size 30M segment space management auto"
-- @enq_hw1 "uniform size 5M segment space management manual"
-- @enq_hw1 "uniform size 5M segment space management auto"
-- @enq_hw1 "uniform size 40K segment space management manual"
-- @enq_hw1 "uniform size 40K segment space management auto"
-- @enq_hw1 "autoallocate segment space management manual"
drop tablespace TS_LMT_HW including contents and datafiles;
spool off

