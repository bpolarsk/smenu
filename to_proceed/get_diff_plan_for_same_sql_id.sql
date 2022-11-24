select first_snap, a.sql_id, opv, npv, PARSING_SCHEMA_NAME,substr(vs.SQL_TEXT,1,40) sql_text
from (
select min(snap_id) first_snap ,ws.sql_id, ws.plan_hash_value opv,  s.plan_hash_value  npv,
case
 when ws.plan_hash_value = s.plan_hash_value then 0
 when ws.plan_hash_value = s.plan_hash_value then 1
 else 2
end  cpt_type
from
  wrh$_sql_plan ws,
  (select sql_id,plan_hash_value from  v$sql_plan group by sql_id,plan_hash_value ) s
where
   ws.sql_id = s.sql_id
group by ws.sql_id, ws.plan_hash_value, s.plan_hash_value
) a,
v$sql vs
where cpt_type = 1 and vs.sql_id=a.sql_id
/
