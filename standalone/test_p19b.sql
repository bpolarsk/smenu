-- the object p19 must be unique in DB or adapt this script with ownership
set serveroutput on size unlimited
set timing on
truncate table test_p19 ;
set timing on
declare
nbr_rows number ;
v_var varchar2(512) ;
v_date date ;
v_cmd varchar2(512);
minutes_in_month number ;
nbr_cust number:=5000 ;
begin
  for i in 1..20
  loop
     nbr_rows:=10000 + trunc(dbms_random.value(1,10000) );              -- number of transaction per partitions to create
     dbms_output.put_line('stating partition ' ||to_char(i) || ' rows : ' || to_char(nbr_rows) ) ;
     for j in 1..nbr_rows
     loop
         select high_value into v_var 
                from all_tab_partitions
                where table_name = 'TEST_P19' and partition_position = i ;
         minutes_in_month:=dbms_random.value(1,43200);   -- shift of minutes from start of month
         v_cmd := 'select '||v_var|| ' - 30  from dual' ;
         execute immediate v_cmd into v_date;
         v_date :=  v_date  + minutes_in_month/1440 ;
         --dbms_output.put_line('date=' ||to_char(v_date,'YYYY-MM-DD HH24:MI:SS') );
         insert into test_p19 values (trunc(dbms_random.value(1,nbr_cust)) +1 ,    -- cust_id
                                      v_date,                                      -- tx date 
                                      p19_seq.nextval,                             -- tx_id
                                      trunc(dbms_random.value(1,1000)),            -- amount 
                                      trunc(dbms_random.value(1,10000))            -- object_id, for futur use FK 
                                      ) ;
         if  mod (j,500) = 0 then
             commit ;
         end if ;
     end loop;
     commit ;
  end loop;
  commit ;
end;
/
         --dbms_output.put_line('v_var=' ||v_var ||'  v_cmd='|| v_cmd);
         --dbms_output.put_line('date=' ||to_char(v_date,'YYYY-MM-DD HH24:MI:SS') );
