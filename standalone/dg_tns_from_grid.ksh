#!/bin/sh

CONNECT_STRING=$DAS/"$PWA@$ORACLE_SID"

sqlplus -s "$CONNECT_STRING" > tnsnames.dg <<EOF

set lines 1024 feed off pages 0

 select
 db_name||',' || db_name|| '.'|| host_name||'=' || chr(10)|| 
           '     (DESCRIPTION = (ADDRESS_LIST = ' || chr(10) ||
           '          (ADDRESS = (PROTOCOL = TCP)(HOST = '||machine||')(PORT = '||port||')))' || chr(10) ||
           '          (CONNECT_DATA = (service_name = '||service_name||')))' tnsnames
from
(
select
    t2.value as db_name, port.property_value port, srv.property_value service_name, t4.host_name, machine.property_value machine,
        --t3.property_value as db_unique_name,
        rank() over (partition by t1.aggregate_target_guid order by member_target_name asc) as rnk
from sysman.MGMT\$TARGET_MEMBERS t1,
     sysman.mgmt\$db_init_params t2,
     sysman.mgmt_target_properties t3,
     sysman.mgmt\$target t4,
     sysman.mgmt_target_properties port,
     sysman.mgmt_target_properties srv,
     sysman.mgmt_target_properties machine,
     sysman.mgmt_target_properties t5
	 --, sysman.mgmt_target_properties t6
where
     t1.AGGREGATE_TARGET_GUID = t4.target_guid -- 'BC36C4A864A08D415628AEE6811F4709'
and (t4.target_type = 'oracle_database' or t4.target_type = 'rac_database' )
and t4.type_qualifier3 = 'DB'
and t4.type_qualifier2  in ('Physical Standby')
and t4.TARGET_GUID = t5.TARGET_GUID
and t5.property_name = 'udtp_1'
and t5.property_value='DBT2'
and t1.member_target_type = 'oracle_database'
and t2.target_guid = t1.member_target_guid
and t2.name = 'db_name'
and t3.target_guid = t1.aggregate_target_guid 
and t3.property_name = 'DBName'
-- and t3.property_name = 'InstanceName'
and port.target_guid = t4.target_guid
and port.property_name='Port'
and srv.target_guid = t4.target_guid
and srv.property_name='ServiceName'
and t5.TARGET_GUID = t4.TARGET_GUID   
and t5.property_name = 'udtp_1' 
and t5.property_value='DBT2'
and machine.target_guid = t4.target_guid 
and machine.property_name = 'MachineName'
) where rnk = 1
order by 1
/
EOF
