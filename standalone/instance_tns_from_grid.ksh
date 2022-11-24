#!/bin/sh
set -x
export ORACLE_SID=OEMPRD1DA2

CONNECT_STRING=$DAS/"$PWA@(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=spgfr0002db-vip.frm.meshcore.net)(PORT=1531)))(CONNECT_DATA=(SID=OEMPRD1DA2)))"

sqlplus -s $CONNECT_STRING > $SBIN/data/tnsnames.ist2 <<EOF

set lines 1024 feed off pages 0

 select
 instance_name||','|| instance_name || '.'||host_name ||'=' || chr(10)||
           '     (DESCRIPTION = (ADDRESS_LIST = ' || chr(10) ||
           '          (ADDRESS = (PROTOCOL = TCP)(HOST = '||machine||')(PORT = '||port||')))' || chr(10) ||
           '          (CONNECT_DATA = (SID = '||instance_name||')))' tnsnames
from
(
select
     t2.value as instance_name,
     port.property_value port, srv.property_value service_name, t4.host_name, machine.property_value machine,
       rank() over (partition by t1.aggregate_target_guid order by member_target_name asc) as rnk
from sysman.MGMT\$TARGET_MEMBERS t1,
     sysman.mgmt\$db_init_params t2,
     sysman.mgmt_target_properties t3,
     sysman.mgmt\$target t4,
     sysman.mgmt_target_properties t5,
     sysman.mgmt_target_properties port,
     sysman.mgmt_target_properties srv,
     sysman.mgmt_target_properties machine
where
     t1.AGGREGATE_TARGET_GUID = t4.target_guid -- 'BC36C4A864A08D415628AEE6811F4709'
and (t4.target_type = 'oracle_database' or t4.target_type = 'rac_database' )
and t4.type_qualifier3 = 'DB'
and t4.type_qualifier2 not in ('Physical Standby')
and t1.member_target_type = 'oracle_database'
and t2.target_guid = t1.member_target_guid
and t2.name = 'instance_name'
and t3.target_guid = t1.aggregate_target_guid
and t3.property_name = 'SID'
and machine.target_guid = t2.target_guid
and machine.property_name='MachineName'
and port.target_guid = t4.target_guid
and port.property_name='Port'
and srv.target_guid = t4.target_guid
and srv.property_name='ServiceName'
and t5.TARGET_GUID = t4.TARGET_GUID
and t5.property_name = 'udtp_1'
and t5.property_value='DBT2'
) where rnk <= 2
order by 1
/
EOF

echo "ifile=/home/oracle/smenu/data/tnsnames.add" >> $SBIN/data/tnsnames.ist2
