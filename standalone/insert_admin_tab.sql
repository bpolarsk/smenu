insert into admin_tablespaces
  (TABLESPACE_NAME,DAILY_SIZE,CURRENT_DATAFILE_PATH,ASSM_AUTO,UNIFORM_SIZE_MB,AUTOEXTEND_ON,DATAFILE_INITIAL_SIZE_MB,
   DATAFILE_NEXT_SIZE_MB,DATAFILE_MAX_SIZE_MB,ASSM_IN_USE,ASSM_UNIFORM_SIZE_MB,ASSM_MANUAL)
 values ('DATA02',1024,'/oradata/d02/rsktst','Y',10,'YES',1024,50,32001,'Y',10,'N' )
/

insert into system.admin_tab_partitions 
     ( TABLESPACE_NAME,TABLE_OWNER,TABLE_NAME,PART_TYPE,PART_COL,
       INITIAL_PART_SIZE,NEXT_PART_SIZE,IS_PARTIONNING_ACTIVE,PARTS_TO_CREATE_PER_PERIOD,
       DROP_AFTER_N_PERIOD, DROP_WHEN_N_PARTS_EXISTS ,USE_DATE_MASK_ON_PART_COL,COPY_STATS,
       DAYS_AHEAD,DAYS_TO_KEEP,PART_NAME_RADICAL )
values ('DATA01','WLS_RSS', 'TRX_MESSAGE', 'M' , 'ID_DATE' , 
         64 , 64, 'YES', 1 , 120, null,  'YYYY-MM-DD', 'YES', null, null, null)
/