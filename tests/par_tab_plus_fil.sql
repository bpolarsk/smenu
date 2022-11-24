drop table T3;

CREATE TABLE CUST(i number,  p number,sp number)
PARTITION BY RANGE(p)
SUBPARTITION BY HASH(sp) SUBPARTITIONS 2 
(PARTITION q1 VALUES LESS THAN(3) TABLESPACE DATA01,
 PARTITION q2 VALUES LESS THAN(MAXVALUE) TABLESPACE DATA01
);

declare 
  i number; 
begin 
  for i in 1..100000 loop 
    insert into CUST values(i,mod(i,7), mod(i,8)); 
    if( mod(i, 1000) = 0) then commit; end if; 
  end loop; 
for i in 1..50000 loop 
    insert into CUST values(i,mod(i,7), mod(i,8)+5); 
    if( mod(i, 1000) = 0) then commit; end if; 
  end loop; 
end; 
/
