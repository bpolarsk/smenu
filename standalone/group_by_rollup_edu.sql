drop table test ;
create table test ( 
 YEAR NUMBER(4),
 REGION  CHAR(7),
 DEPT    CHAR(2),
 PROFIT  NUMBER );

insert into test values (    1995, 'West',    'A1',        100);
insert into test values (       1995, 'West' ,  'A2',        100 );
insert into test values (       1996, 'West' ,  'A1' ,       100);
insert into test values (       1996, 'West',    'A2' ,       100);
insert into test values (      1995, 'Central', 'A1'   ,     100);
insert into test values (      1995, 'East',    'A1'    ,    100);
insert into test values (      1995, 'East',    'A2'     ,   100);

prompt select * from test order by year;;
select * from test order by year;

prompt select year,region,sum(profit) from test group by year , region order by year ;;
select year,region,sum(profit) from test group by year , region order by year;

prompt select year,region,sum(profit) from test group by  rollup(year , region) order by year ;;
select year,region,sum(profit) from test group by rollup(year , region ) order by year ;


prompt select year, region, sum(profit), count(*) from test group by cube(year, region)  order by year ;;
select year, region, sum(profit), count(*) from test group by cube(year, region)  order by year ;

prompt select year, region, sum(profit), grouping(year) "Y", grouping(region) "R" from test group by cube (year, region) order by year;;
select year, region, sum(profit), grouping(year) "Y", grouping(region) "R" from test group by cube (year, region) order by year;


drop table test ;





