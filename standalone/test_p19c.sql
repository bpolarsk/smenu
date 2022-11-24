-- This query count the customer active this last month and also active last year
with v1 as -- this view list customers active the last month
(
select distinct cust_id  from test_p19 where TRX_DATE > TO_DATE(' 2009-08-01 00:00:00','YYYY-MM-DD HH24:MI:SS')
)
select  /*+ unnest(@subq) */
   count(cust_id) 
from 
   test_p19 
where  
    TRX_DATE < TO_DATE(' 2009-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')
    and cust_id in ( select /*+ qb_name(subq) */ cust_id from v1 )
/
