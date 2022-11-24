drop table TEST_BPA ;
set linesize 132 pagesize 66
create table TEST_BPA ( 
                 fkey number not null, 
                 name varchar2(20) , 
                 payload varchar2(100))
partition by range (fkey)
( 
partition p1 values less than (1000) ,
partition p2 values less than (2000) ,
partition p3 values less than (3000) ,
partition p4 values less than (4000) ,
partition p5 values less than (5000) ,
partition p6 values less than (MAXVALUE)
	) 
;
set time on
insert into TEST_BPA select level , DBMS_RANDOM.STRING('U',20) ,  DBMS_RANDOM.STRING('a',100) from dual connect by level <=10000;
commit;
create index idx_t on TEST_BPA ( fkey ) ;
exec dbms_stats.gather_table_stats(user,'TEST_BPA',cascade=>true);
exec dbms_stats.gather_index_stats(user,'idx_t');
exit 
explain plan for select * from TEST_BPA where fkey = :b1;
select * from table(dbms_xplan.display);
set serveroutput on size unlimited
declare
  v_var number := 0 ;
begin
   while 1=1
   loop
   select max(t.fkey)  into v_var from t;
   insert into TEST_BPA values (v_var+1,  DBMS_RANDOM.STRING('U',20) , DBMS_RANDOM.STRING('a',100)  );
   commit ;
   dbms_output.put_line(to_char(sysdate,'YYYY-MM-DD HH24:MI:SS') ||' inserted row=s' || to_char(v_var+1)   );
   sys.dbms_lock.sleep(1) ;
   end loop ;
end;
/
rem drop table TEST_BPA ;

