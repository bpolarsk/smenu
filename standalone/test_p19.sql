drop table TEST_P19 ;
drop sequence p19_seq ;
set linesize 132 pagesize 66
create table TEST_P19 ( 
                 CUST_ID number not null,
                 TRX_DATE date not null, 
                 TX_ID number not null,
                 AMOUNT number ,
                 OBJECT_ID number 
) tablespace TXNLOG01
partition by range (TRX_DATE)
( 
partition p1 values less than (to_date('2008-02-01','YYYY-MM-DD') ) tablespace TXNLOG01, 
partition p2 values less than (to_date('2008-03-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p3 values less than (to_date('2008-04-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p4 values less than (to_date('2008-05-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p5 values less than (to_date('2008-06-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p6 values less than (to_date('2008-07-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p7 values less than (to_date('2008-08-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p8 values less than (to_date('2008-09-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p9 values less than (to_date('2008-10-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p10 values less than (to_date('2008-11-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p11 values less than (to_date('2008-12-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p12 values less than (to_date('2009-01-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p13 values less than (to_date('2009-02-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p14 values less than (to_date('2009-03-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p15 values less than (to_date('2009-04-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p16 values less than (to_date('2009-05-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p17 values less than (to_date('2009-06-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p18 values less than (to_date('2009-07-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p19 values less than (to_date('2009-08-01','YYYY-MM-DD') ) tablespace TXNLOG01,
partition p20 values less than (to_date('2009-09-01','YYYY-MM-DD') )tablespace TXNLOG01,
partition p21 values less than (to_date('2009-10-01','YYYY-MM-DD') ) tablespace TXNLOG01
) 
;
create sequence p19_seq start with 1 increment by 1 ;
