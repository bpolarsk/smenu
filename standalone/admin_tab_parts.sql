create or replace
PACKAGE   ADMIN_TAB_PARTS AS
/******************************************************************************
   NAME:       ADMIN_TAB_PARTS
   PURPOSE:    Managing partitions
   REVISIONS:
   Version    Date        Author            Description
   ---------  ----------  ---------------  ------------------------------------
   1.6        2011-09-31  Bernard Polarski Manage partition based on a date column

History:

    2008_10_22  -  First Production release
    2008_12_08  -  Fix bug in 'get_period_to_quarter' as it returned wrong period for month 12.
    2009_12_09  -  Added rolling days partitions
    2009_09_01  -  Added Template tablespace for index. This will allow to create
                   specific rolling tablepsaces for indexes
    2011_02_16  -  Improved the detection of existing partitioned table (init_table)
                   Added 'part_name_radical' to allow further customize partition name.
    2011_09_21  -  Added a check on exitence of the table in add_partitions to avoid
                   the stop processing of a chain of tables. The missing table is now
                   simply skipped with a warning message.
                   
Managing partitioning based on a date column
==================
Package overview
==================
What this package do:
The package deals with automation of partitioning on date column. It manages
the `add' and 'drop'  functions based on a series of parameters.
It will creates new tablespace and add datafiles. On daily basis it may also add
datafiles when free space falls below a given thresholds.
What this package does not do:

1.  There is no built-in support for sub-partitioning. How ever sub-partitioning
    may be easily added by adding code for sub-partitioning in function

2.  Add_partitions?. Search key word 'sub-partitions' in the body source.

3.  There is not support for partition granularity less that a day. The day start
    at 00:00:00 and ends at 23:59:59. Thus midnight always belongs to the next day.

Assumption: This package assume the separator for path is '/'.
             There is no logic to process windows style path AKA "x:\"
==============
Package tasks
==============
Package ADMIN_TAB_PARTS performs the following tasks:
-    Add new amounts of table partitions for a given period.
     This amount is a parameter.
-    Add new datafile in the tablespace of the partition when it is full
     or will become full.
-    Create new tablespace if there is a template tablespace name associated
     with the partition
-    Move the indexes to another tablespace if an index tablespace is mentioned
-    Copy the statistics of the last complete equivalent period, or copy
     the stats of the last period if there is no equivalent
-    Drop oldest partitions if total number is over a given max partitions
-    Drop the oldest partitions that are below a given cut_off_date or cut_off number

Beside these classic functionalities, the package also offer the capability
to launch a stand-alone check of the tablespaces  free space. The level of free
space requested is based on the values of the column 'admin_tablespaces.daily_size'
which is expressed in Mb.

=====================
Package Installation
=====================

1) Installation:

-    Import or create the 3 tables :
          . admin_tab_partitions
          . admin_ind_partitions
          . admin_tablespaces
-    The table 'admin_log' will be created in the package owner schema
     the first time that this function is called, so it is not necessary
     to creates it. However you may create it in advance also.
-    Import or create the package 'admin_tab_parts'. The sources of the package
    and the package body are given in the annex A.

2) Setup:

Insert the name of every partitioned table that you want to manage. For every
unique identifier that appears in the column tablespace_name, there must be
a row into the tables -admin_tablespaces?. The tablespace name may contain
a template. If it does not then the tablespace name is a fixed named. A template
is a set of consecutive characters like 'YYYY'.

Thus you cannot name a fixed tablespace TBS_YYYY for it will be automatically
identified as a template and name will be translate to TBS_2009
(if you are in 2009).

Table ADMIN_TABLESPACES:
.......................
Datafile for a tablespace are created into the path given by the column
'admin_tablespace.current_data_file_path'. The table admin_tablespace contains
all the relevant information to creates new datafiles:

CREATE TABLE ADMIN_TABLESPACES
(
TABLESPACE_NAME           VARCHAR2 (30 BYTE),       -- name or template name
                                            -- (see same comment for ADMIN_TAB_PARTITIONS
DAILY_SIZE                NUMBER,                                 -- expected size in mb per day work load (optional)
CURRENT_DATAFILE_PATH     VARCHAR2(512 BYTE), -- where to create new datafile
ASSM_AUTO                 VARCHAR2(1 BYTE),
UNIFORM_SIZE_MB           NUMBER(6,3),
AUTOEXTEND_ON             VARCHAR2(3 BYTE) DEFAULT 'YES',   -- self explanatory
DATAFILE_INITIAL_SIZE_MB  NUMBER       DEFAULT 64,      -- self explanatory
DATAFILE_NEXT_SIZE_MB     NUMBER       DEFAULT 64,        -- self explanatory
DATAFILE_MAX_SIZE_MB      NUMBER       DEFAULT 10240,   -- self explanatory
ASSM_IN_USE               VARCHAR2(1 BYTE),         -- new datafiles created with ASSM
                                      -- only Y or N accepted. Null means N
ASSM_UNIFORM_SIZE_MB      NUMBER(6,3),  -- if ASSM is in use and want uniform size.
                                      -- scale is Mb, so express K with decimal
ASSM_MANUAL               VARCHAR2(1 BYTE)  -- if ASSM is in use, AUTO will be the default
) TABLESPACE USERS ;

ALTER TABLE ADMIN_TABLESPACES ADD CONSTRAINT ADMIN_TBS_PK
       PRIMARY KEY (TABLESPACE_NAME)    USING INDEX         TABLESPACE USERS;

ALTER TABLE ADMIN_TABLESPACES ADD ( CONSTRAINT CHECK_ASSM_IN_USE
      CHECK (ASSM_IN_USE='Y' or ASSM_IN_USE='N'));

ALTER TABLE ADMIN_TABLESPACES ADD
   (CONSTRAINT CHECK_ASSM_MANUAL_YN CHECK (ASSM_MANUAL='Y' or ASSM_MANUAL='N'));

COMMENT ON COLUMN ADMIN_TABLESPACES.ASSM_MANUAL IS
 'if ASSM_IN_USE  and ASSM_MANUAL is not set to ''Y'' then it equals to ASSM in AUTO mode';

COMMENT ON COLUMN ADMIN_TABLESPACES.ASSM_IN_USE IS 'This set the ASSM';

alter table admin_tablespaces  add constraint ON_OFF
       check(AUTOEXTEND_ON  in ('ON','OFF',NULL) ) ;

Datafile new names are made by concatenating CURRENT_DATAFILE_PATH + lower case
of tablespace_name + '_' + sequence number + '.dbf'
The sequence number is obtained through a regexp that extract the max of
the last 2 digit from all datafiles in this tablespace. Default will be '01'.

ie) The third datafile of tablespace=DATA with value
  current_datafile_path='/app/oradata/ORADEV'  will be ==> '/app/oradata/ORADATA/DATA_03.dbf'.

Note that if tablespace name is DATA_YYYY_MM  (name with a template into it),
     then the datafile name becomes:   ==>  '/app/oradata/ORADATA/DATA_2007_06_03.dbf'.
     (datafile for a tablespace holding a partionned period June 2007).

TABLE ADMIN_TAB_PARTITIONS:
...........................
This table describes the management of table partitions: The comment of each
column provides the information on its usage.

(Cut and paste the creation scripts, do not hesitate to stript comments on the left)

CREATE TABLE ADMIN_TAB_PARTITIONS
(
TABLESPACE_NAME VARCHAR2(30 BYTE),  -- Tablespace name or template TBS with
                                    -- string in it like YYYY_MM, YYYY_QQ, YYYY_YY
TABLE_OWNER               VARCHAR2(30 BYTE),    -- Owner of the partitioned table
TABLE_NAME                VARCHAR2(30 BYTE),    -- partitioned table
PART_TYPE                 VARCHAR2(1 BYTE),     -- Type of partitions (period) : values are
                                    -- D (Rolling daily) M (monthly),Q (quarterly) ,Y (yearly)
PART_COL                  VARCHAR2(30 BYTE),  -- col name used to partition the table
                                    -- ( currently this info is not used)
INITIAL_PART_SIZE       NUMBER  DEFAULT 64, -- if ASSM is not in use, the good old sizing way
NEXT_PART_SIZE          NUMBER  DEFAULT 64,  -- if ASSL is not in use, the good old sizing way
IS_PARTIONNING_ACTIVE   VARCHAR2(3 BYTE) -- to disable table processing
         DEFAULT 'YES', -- by admin tabl parts without deleting the row
PARTS_TO_CREATE_PER_PERIOD  NUMBER -- how much partitions to create each period
            DEFAULT 1,
TABLESPACE_INDEX           VARCHAR2(30 BYTE),   -- referencing a tablespace index will
                                    -- move there by default, new local indexes
DROP_AFTER_N_PERIOD  NUMBER -- drop partition after n period.
            DEFAULT 24,     -- it refers to nbr period of type PART_TYPE
DROP_WHEN_N_PARTS_EXISTS    NUMBER(3), -- drop partitions in excess of this number (oldest first)
USE_DATE_MASK_ON_PART_COL   VARCHAR2(30 BYTE),-- part col is number then 'JULIAN'.
                                     -- Type varchar2 then date format maskie: YYYYMMDD
COPY_STATS                  VARCHAR2(3),       -- If set to YES copy the stats of previous
                         -- complete partitions into the  new created partition
DAYS_AHEAD                  NUMBER, -- Only used by PARTITION_TYPE=D. Number of daily
                         --partitions to create in advance after today
DAYS_TO_KEEP              NUMBER, -- Only used by PARTITION_TYPE=D.
                         -- Number of daily partitions to keep before today
PART_NAME_RADICAL          VARCHAR2(18) -- Customized radical partition name
) TABLESPACE USERS;

COMMENT ON COLUMN ADMIN_TAB_PARTITIONS.INITIAL_PART_SIZE IS
    'initial value in meg of the firsr partition';

COMMENT ON COLUMN ADMIN_TAB_PARTITIONS.NEXT_PART_SIZE IS
    'size in mega for each extents. next_part_size*part_max_nbr_Extents is the max size';

COMMENT ON COLUMN ADMIN_TAB_PARTITIONS.PARTS_TO_CREATE_PER_PERIOD IS
     'number of new partitions to create each period';

COMMENT ON COLUMN ADMIN_TAB_PARTITIONS.TABLESPACE_INDEX IS
     'Tablespace for indexes of partitions';

COMMENT ON COLUMN ADMIN_TAB_PARTITIONS.DROP_AFTER_N_PERIOD IS
      'drop partitions when N is reached';

COMMENT ON COLUMN ADMIN_TAB_PARTITIONS.DROP_WHEN_N_PARTS_EXISTS IS
      'drop when there are at least N others partitions';

COMMENT ON COLUMN ADMIN_TAB_PARTITIONS.USE_DATE_MASK_ON_PART_COL IS
    'date Mask of partition column if it is not in format data.
     Number and column will be treated as julian date (put the string  JULIAN)
     while varchar2 put the string up to  YYYYMMDD HH24:MI:MM.FFFFFF.
     May be less and MM maybe MON';

CREATE UNIQUE INDEX PK_ADMIN_TAB_PARTS ON ADMIN_TAB_PARTITIONS
           (TABLE_OWNER, TABLE_NAME) TABLESPACE USERS ;

ALTER TABLE ADMIN_TAB_PARTITIONS ADD  CONSTRAINT PK_ADMIN_TAB_PARTS
           PRIMARY KEY (TABLE_OWNER, TABLE_NAME)  USING INDEX   TABLESPACE USERS ;

ALTER TABLE ADMIN_TAB_PARTITIONS ADD  CONSTRAINT ADMIN_TBS_FK
  FOREIGN KEY (TABLESPACE_NAME) REFERENCES ADMIN_TABLESPACES (TABLESPACE_NAME);

alter table admin_tab_partitions  add constraint YESNO
        check(IS_PARTIONNING_ACTIVE in ('YES','NO',NULL) ) ;

Rolling daily partitions (TYPE=>'D') keeps DAYS_TO_KEEP partitions below current
day and creates DAYS_AHEAD partitions above current day. If you run it after
a break or first time, all missing daily partitions from the highest old high
value up to today will be created.

Next if you run the delete partitions sub, then all excess partitions below
DAYS_TO_KEEP will be dropped.

NOTE :Use only fixed tablespace for rolling partitions.
-- You must create admin_tablespace first or add the constraint admin_tbs_fk later

TABLE ADMIN_IND_PARTITIONS:
...........................
This table describes the management of index partitions:
  Rows in this table are optional. It is used to move local indexes into
  the location reference by `tablespace_name?. Use this only if there are
  multiple indexes for the same table and they have different target tablespaces.
  The default location of indexes- if you want to be moved - is given
  by `admin_tab_partitions 'TABLESPACE_INDEX'.

 This is the default location where an index will be moved. Index name with
 an entry in 'ADMIN_IND_PARTITIONS' will override the default location for
 the `INDEX_NAME' only.

 Note that moving index is optional and will not occur if columns are null
 (in admin_tab_partitions) or inexistent (in 'admin_ ind_partitions').

CREATE TABLE ADMIN_IND_PARTITIONS
(
  TABLE_OWNER                   VARCHAR2(30 BYTE),
  TABLE_NAME                    VARCHAR2(30 BYTE),
  INDEX_NAME                    VARCHAR2(30 BYTE),
  TABLESPACE_NAME               VARCHAR2(30 BYTE),
  REBUILD_INDEX_AFTER_N_PERIOD  NUMBER(4)       DEFAULT NULL
)   TABLESPACE USERS;

COMMENT ON COLUMN ADMIN_IND_PARTITIONS.TABLESPACE_NAME IS
    'tablespace location of index';

Notes: Partition naming convention

The naming of the created table partition will done using the following convention:
-    By default, prefixed by 'P' but may be customized using
     admin_tab_parts.part_name_radical
-    The period will be appended to the prefix
-    If partitions count > 1 then the partitions count in period otherwise
     just the period.    Ie : P20008 or P2008_01 etc..
     if more than one partitions is requiered for period 2008
-    partitions of type daily are always named P_<YYYYMMDD>

==============
Package usage
==============
About tablespace template name:
Tablespace template are stored in the column ADMIN_TABLESPACE.tablespace_name
and ADMIN_TAB_PARTS.tablespace_name. When you add a new partition, the package
get the tablespace associated with table name.

If you omit to add into the column 'admin_tab_parts.tablespace_name',
one of those strings below, then the value in tablespace_name is
a fixed tablespace name:

    YYYYMM       <-- Monthly
    YYYY_MM      <-- Monthly
    YYYY_Q       <-- Quarterly
    YYYYQ        <-- Quarterly
    YYYY         <-- Yearly

If one of the 5 strings is present in the name, then the tablespace name is
a template and the string is translated into the equivalent period:

For instance, with tablespace_name value of `DATA_YYYY_MMZ?, the 06 June 2007,
3 new partitions are requested for next month (July). The package translates
'DATA_YYYY_MMZ' into 'DATA_2007_06Z' and checks if this tablespace exists.
If it does not, then the tablespace is created altogether with at least one datafile.

Note: don't use variable tablespace_name when the type date is 'D'.
Rolling partitions should be put in a fixed named tablespace.

Additional feature are:
o    -Many tables may share the same tablespace name or template name.
o    The 5 strings are checked in the Month/Quarter/yearly order as they appear
     just above. The first to match in this order will be taken as templatetype.
     Only if none of the 5 strings is present, is the tablespace name considered
     as static name. In consequence you cannot have a fixed tablespace.

     with 4 subsequent `Y' in it and you cannot have a yearly template with
     a fixed `_Q' nor can you have a yearly template with `_MM' behind.

In June 2008  package will translate template names like that :

DATA_YYYY_M                # read a DATA_2008_M
DATA_YYYYMM                # read a DATA_200806
DATA_YYYY_MM               # read a DATA_2008_06
DATA_YYYYQ                 # read a DATA_20082
DATA_YYYY_Q                # read a DATA_2008_2
DATA_YYYY_QQ               # read a DATA_2008_2Q
DATA_YYYY                  # read a DATA_2008
DATAYYYYY     (5*Y)        # read a DATA2008Y
DATA_YYYY_Y                # read a DATA_2008_Y

====================
Adding partitions
====================
Each row in admin_tab_partitions describes a table partitions and its frequency
of additional partitions. Partitions will always obey to the template
'Pyyyymmdd': ie P20080623

====================
Dropping partitions
====================
Period based dropping (Month,Quarter,Year):
-------------------------------------------
There are 2 methods to purge old partitions: by date (DROP_AFTER_N_PERIOD)
or by number (DROP_WHEN_N_PART_EXISTS).

Setting a value into one of these 2 columns will trigger the purge check.
You can also set both columns to check over two criteria's or set none to perform
no purge. The drop by date is expressed in terms of period to keep. If your
period is the month, setting it to 2 will drop all partitions belonging
to 2 periods  back, current period is included.

ie: Mid June I set DROP_AFTER_N_PERIOD=3 then I run the package :

   all periods below April will be dropped : 6 (inclusive) -3 => 4

Partition based on daily type dropping:
---------------------------------------
When part_type=D then number of partitions to drop is calculated from today date.
All partitions older than DAYS_TO_KEEP are dropped.

If no value was given then the Default is 5 days

===============================
Checking tablespace free space
===============================
The package admin_tab_parts rely on the values in table 'admin_tablespaces.daily_size'
to check if there will be enough space for the next day.

If the free space + the space left to auto extend is inferior to this value,
then a new datafile is added. Note : There is no check on the filesytsem  for
the space left to autoxetend. This process is left to the database monitoring
 system ( if you have one).

====================
Running the package
====================
It may sound complicated but in fact we provide default behavior so that all
you have to do is to fill 3 tables and call one of the available entry method.
All 4 methods read the 3 configuration tables, take into account current date
and decide what to check and if the check is positive and, if the action has not
yet been done, then the action is performed.

In consequence the package can be launched every day and it will decide by itself
if there is something to do.

SQL> exec admin_tab_parts.do_main                       # Default check to see if new partitions are needed

SQL> exec admin_tab_parts.do_main CHECK_DROP_PARTS      # will only look after partitions to drop

SQL> exec admin_tab_parts.do_main CHECK_ADD_DROP_PARTS  # Will check add and drop of partitions

SQL> exec admin_tab_parts.do_main CHECK_ALL_TBS_FS      # will only check if there is a need to add datafiles

A draw back of this method, is that there is no way to request a partitions
just using only commands. You need to fill the admin_xxx tables and run
the package.

The actions     are decided by comparing:

-    Current date to requested period
-    Existing objects state versus requested objects

For this last, be aware that partial executions may lead to problems. The package
does not automatically rollback broken executions. You will have to deal with
an eventual mess manually.

-- Examples of insert:

-- create a tablespace, no autoextend, 512 m per day
insert into admin_tablespaces values ('TABLESPACE', 512, '/datafiile/path' , 'Y', 1,'N', null,null,null,'Y', null,'N' ) ;

-- insert monthly, 5 partition per month, retention 12 full months
insert into admin_tab_partitions  values ( 'TABLESPACE','OWNER','TABLE', 'M', 'COLUMN# ',
                 64, 64, 'YES', 5, null, 13, null, null, 'Y', null, null, null ) ;

*/

/*
-- grants givent to user that will run the package admin_tab_parts:
define ADMIN_USER="SYSTEM";      -- this is pckg and admin table owner.
grant connect to SYSTEM ;
grant resource to SYSTEM ;
grant select on v_$parameter  to SYSTEM ;
grant select on v_$instance  to SYSTEM ;
grant select on v_$tablespace to SYSTEM ;
grant select on v_$datafile to SYSTEM ;
grant select on dba_tablespaces  to SYSTEM ;
grant select on dba_free_space to SYSTEM ;
grant select on dba_data_files to SYSTEM ;
grant select on dba_segments to SYSTEM ;
grant select on dba_indexes to SYSTEM ;
grant select on dba_ind_partitions to SYSTEM ;
grant select on dba_tab_partitions to  SYSTEM ;
grant select on dba_tables to  SYSTEM ;
grant select on dba_part_key_columns to  SYSTEM ;
grant select on dba_tab_columns to  SYSTEM ;
grant alter user to SYSTEM ;
grant ALTER TABLESPACE to SYSTEM ;
grant ALTER DATABASE to SYSTEM ;
grant ALTER any table to SYSTEM ;
grant ALTER any INDEX to SYSTEM ;
grant alter any index TO  SYSTEM ;
grant analyze any to SYSTEM ;
grant drop any table to SYSTEM ; -- needed if you are not the owner of the target table, grant all is not enought
grant execute on dbms_stats to SYSTEM ;
grant create any table to  SYSTEM ;
grant create any index to  SYSTEM ;
grant create tablespace to SYSTEM ;
grant UNLIMITED TABLESPACE to SYSTEM ;
grant update any table to SYSTEM ;
grant delete any table to SYSTEM ;
grant insert any table to SYSTEM ;
grant select any table to SYSTEM ;
grant execute on sys.dbms_lock to  SYSTEM ;
GRANT execute ON sys.dbms_stats TO  SYSTEM ;
*/
/* !Dont forget the 'grant all on table' from table owner to package owner! */

procedure do_main(P_PAR1 varchar2:=null);
procedure set_variables_values ;
procedure check_add_partitions_needed;
procedure check_stat_table (P_OWNER in varchar2);
procedure check_drop_partitions_needed;
procedure add_partitions( P_OWNER  VARCHAR2, P_TABLE VARCHAR2 ) ;
procedure fout ( msg in varchar2 );
procedure create_tablespace(P_TBS varchar2, P_OWNER varchar2, P_OBJECT varchar2,
               P_TYPE varchar2);
procedure add_datafile (P_TBS varchar2:=null, P_OWNER varchar2:=null,
                           P_TABLE varchar2:=null, P_PERIOD varchar2);
procedure move_index_part(P_OWNER varchar2,P_TABLE varchar2,P_PARTITION varchar2);
procedure move_stat ( P_OWNER varchar2, P_TABLE  varchar2,
                             P_PART_SOURCE varchar2, P_PART_TARGET varchar2);
procedure move_stat_daily(P_OWNER varchar2, P_TABLE varchar2, V_PART_NAME varchar2);
procedure drop_partition_older_than(P_OWNER varchar2,
                             P_TABLE  varchar2, P_DATE varchar2);
procedure set_tbs_read_write(P_RET_TBS NUMBER, P_TBS varchar2 );
procedure check_all_tbs_free_space ;
procedure init_table (P_OWNER varchar2);
procedure rebuild_old_index;
function calc_new_high_value(P_START varchar2, P_END varchar2, P_TOT_PARTS number,
          P_THIS_POS number ) return varchar2;
function check_index_exists(P_OWNER varchar2, P_INDEX_NAME varchar2) return number;
function check_tbs_exists(P_TBS in varchar2) return number;
function check_tbs_free_space(P_TBS in varchar2, P_OWNER varchar2, P_TABLE varchar2,
        P_FREE_SPACE_MB number:=null)   return number;
function check_tbs_status(P_TBS varchar2) return number;
function days_in_month(P_PERIOD in varchar2) return number;
function days_in_next_quarter(P_PERIOD in varchar2) return number;
function days_in_year(P_PERIOD in varchar2) return number;
function drop_partition(P_OWNER in varchar2,P_TABLE in varchar2,
         P_PARTITION_NAME in varchar2) return number ;
function drop_oldest_partition(P_OWNER in varchar2,P_TABLE in varchar2) return number;
function extract_hv_date(P_OWNER in varchar2,P_TABLE in varchar2,
          P_PARTITION_NAME in varchar2) return varchar2 ;
function get_next_datafile_num(P_TBS in varchar2) return varchar2;
function get_new_part_num(POS in number) return varchar2 ;
function get_next_quarter_start (Q number) return varchar2 ;
function get_period_to_quarter (P_PERIOD varchar2) return varchar2 ;
function get_rad_part_name ( P_OWNER varchar2, P_TABLE varchar2 ) return varchar2;
function get_itablespace_name(P_OWNER in varchar2, P_TABLE in varchar2,
         P_INDEX in varchar2, P_PERIOD in varchar2 ) return varchar2;
function get_tablespace_name (P_OWNER varchar2,P_TABLE varchar2,
          P_PERIOD varchar2) return varchar2;
function get_previous_period_part_name(P_OWNER varchar2, P_TABLE varchar2,
        P_PART_NAME varchar2, P_YYYY_MM_DD varchar2, P_PART_TYPE varchar2 )
                 return varchar2;
function get_table_lock(P_OWNER in varchar2, P_TABLE in varchar2) return number;
function get_cutoff_date( P_NBR_PERIOD number,P_TYPE in varchar2) return varchar2;
function get_min_high_value(P_OWNER in varchar2,P_TABLE in varchar2,
                P_PARTITION_HV out varchar2) return varchar2 ;
function long_to_str( P_OWNER varchar2, P_TABLE varchar2, P_PART_NAME varchar2 )
                          return varchar2 ;
function get_col_type ( P_OWNER varchar2, P_TABLE varchar2 ) return varchar2 ;
function get_col_mask ( P_OWNER varchar2, P_TABLE varchar2 ) return varchar2 ;
V_PREV_MONTH           varchar2(6);          -- 200804
V_THIS_MONTH           varchar2(6);          -- 200805
V_NEXT_MONTH_START     varchar2(8) ;         -- 20080601
V_THIS_MONTH_HV        varchar2(8);          -- 20080601
V_NEXT_MONTH_HV        varchar2(8);          -- 20080701
V_NEXT_QUARTER         varchar2(2);
V_NEXT_QUARTER_HV      varchar2(8);
V_THIS_QUARTER_START   varchar2(8);         -- 20080401
V_NEXT_QUARTER_START   varchar2(8);         -- 20080701
V_PREV_QUARTER_START   varchar2(8);         -- 20080101
V_YYYY                 varchar2(4);
V_NEXT_YYYY            varchar2(4);
V_PREV_YYYY            varchar2(4);
V_NEXT_YYYY_START      varchar2(8);         -- 20090101
V_NEXT_YYYY_HV         varchar2(8);         -- 20100101
V_THIS_PERIOD          varchar2(8);
V_NEXT_PERIOD_START    varchar2(8);         -- 2008????
V_THIS_PERIOD_START    varchar2(8);         -- 2008????
V_NEXT_PERIOD_HV       varchar2(8);         -- 2008????
V_MAX_LOCK_ATTEMPT     number:=60;
V_ORA_VERSION          number;
V_UNDERSCORE           varchar2(1):='_';
END admin_tab_parts;
/
create or replace PACKAGE BODY  admin_tab_parts IS
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
/*  +            MAIN               + */
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
/*
   execution for procedure tree is       Functions called in the procedure
   -------------------------------------- -------------------------------------
     DO_MAIN                  get_next_quarter_start
        check_partitions_needded          days_in_month, get_current_high_value
             add_partitions          days_in_month, calc_new_high_value,get_new_part_num,
                                       check_tbs_exists,
                           check_tbs_free_space, get_tablespace_name , get_previous_period_name
                 create_tablespace          -
                 add_datafile          get_tablespace_name, get_next_datafile_num
                 move_index_part      check_index_exists
                 move_statx
        check_drop_partition_needd
            drop_partitions               get_table_lock, drop_oldest_partition    ,
                          check_talespace_status; set_tbs_read_write
        check_all_tbs_free_space
*/
procedure do_main(P_PAR1 varchar2:=null) is
begin
  set_variables_values;
  if P_PAR1 is null then
       check_add_partitions_needed;          -- Default: check of add partitions
       --check_drop_partitions_needed;
       --check_all_tbs_free_space;
  elsif P_PAR1 = 'CHECK_DROP_PARTS' then
     check_drop_partitions_needed;
  elsif P_PAR1 = 'CHECK_ADD_DROP_PARTS' then
     check_add_partitions_needed;
     check_drop_partitions_needed;
   elsif P_PAR1 = 'CHECK_ALL_TBS_FS' then
     check_all_tbs_free_space;
   elsif P_PAR1 = 'REBUILD_OLD_INDEX' then
     rebuild_old_index;
  end if;
end;
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
/*  +           Init  tables                     + */
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
procedure init_table (P_OWNER in varchar2)
is
  -- This procedure automatically populates admin tables for all partitioned
  -- table of the given user that are not already managed by admin_tab_partitions.
  -- New rows in 'admin_tab_partitions' uses auto-calculated/default values.
  -- This procedure also tries to detect templates into tablespace name.
  -- Current recognized templates are YYYY_MM, YYYY_N and YYYY (Yearly).
  -- The procedure assume  :
  --    if there is two digit after 'YYYY_' then it represent a monthly template
  --    if there is one digit after 'YYYY_' then it represents quarterly template
  --    if there is no underscore followed by a  digit after 'YYYY'
  --         then it represents a yearly template

  v_part_col       varchar2(30);
  v_col_type       varchar2(20);
  v_tbs            varchar2(30);
  v_tbs_pattern    varchar2(30);
  v_pattern_type   varchar2(1):='M' ; -- default
  v_curr_file_name varchar2(512);
  v_YYYY_ZZ        varchar2(50);
  v_PATTERN        varchar2(7) ;   -- default no pattern
  v_iot_type       varchar(12) ;
  pos              number;
  v_count          number :=0;
begin
   fout(chr(10) || '*********************************' );
   fout( '*   Init User ' || P_OWNER ) ;
   fout( '*********************************' );

   -- loop on all partitioned table and try to detect pattern
   for t in (select distinct table_name from all_tab_partitions a
          where
             table_owner = UPPER(P_OWNER) and
                    table_name not in
                         ( select table_name
                                  from admin_tab_partitions
                                      where table_owner = upper(P_OWNER) )
              )
   loop
      fout (chr(10)||'Found a partition table to init : ' || t.table_name ) ;

      -- for each partitioned table, get the first partition column
      select column_name into v_part_col
                   from all_part_key_columns
            where owner = UPPER(P_OWNER)
              and name = t.table_name
              and column_position = 1
              and object_type = 'TABLE' ;

      -- determine column type
      select data_type  into v_col_type from all_tab_columns
             where owner = upper(P_OWNER)
              and table_name = t.table_name
                    and column_name = v_part_col ;
      -- get the tablespace name from the latest partitions
      -- Get the current datafile name for this TBS. the tbs will be the one
      -- with latest created datafile of latest partitions. The sub-query
      --  (table alias c) retrieve the latest tbs associated to the latest
      --  partition. it then cross the tbs id with tbs id in v$datafile and
      --  we take file name  of the latest creation in this ts#:
      select iot_type into v_iot_type from dba_tables
             where owner = upper(P_OWNER) and table_name = t.table_name ;
      if ( v_iot_type = 'IOT' or v_iot_type = 'IOT_OVERFLOW' ) then
               --  first get the tablespace name
               fout('t.table_name is type :' || v_iot_type );

         -- Get the tablespace name
         select a.tablespace_name  into v_tbs
         from
              all_ind_partitions a ,
             ( select index_name from all_indexes
                where table_owner = upper(P_OWNER) and table_name = t.table_name
              ) b
         where a.index_owner    = upper(P_OWNER)
             and a.INDEX_name = b.index_name
             and partition_position = (select max(partition_position)
                from all_IND_partitions
                where index_owner = upper(P_OWNER)and INDEX_name= b.index_name);

          -- get the datafile name :
          select
              substr( a.name,1,instr( a.name,'/',-1)-1 ) into  v_curr_file_name
          from
             sys.v_$datafile  a,
             sys.v_$tablespace b ,
             (
          select max(creation_time) creation_time
          from
               ( select index_name from all_indexes
                 where table_owner = upper(P_OWNER) and table_name=t.table_name
               ) a0,
               sys.v_$datafile aa,
               sys.v_$tablespace bb,
               all_ind_partitions p
          where aa.ts# = bb.ts#
            and p.tablespace_name = v_tbs
            and bb.name = p.tablespace_name
            and p.index_name = a0.index_name
            and partition_position = (
                     select max(partition_position) partition_position
                        from all_ind_partitions x, all_indexes y
                           where  y.table_name =  t.table_name
                           and y.table_owner = upper(P_OWNER)
                           and x.index_name = y.index_name
                           and x.index_owner = upper(P_OWNER)
                           and x.tablespace_name=p.tablespace_name
                  )
            ) c
           where
             a.ts#  = b.ts#
        and  b.name = v_tbs
        and     a.creation_time = c.creation_time ;

     else        -- normal table : first tbs name
             select
                  tablespace_name into v_tbs
             from
                  all_tab_partitions
              where
                        table_owner       = upper(P_OWNER)
                    and table_name = t.table_name
                    and partition_position = (select max(partition_position)
                    from all_tab_partitions
                        where table_owner = upper(P_OWNER)
                          and table_name = t.table_name) ;

          -- now the datafile name
               select  substr(a.name,1,instr(a.name,'/',-1)-1 )
                       into v_curr_file_name
               from
                 sys.v_$datafile  a,
                 sys.v_$tablespace b ,
                 ( select max(creation_time) creation_time
                   from  sys.v_$datafile aa,
                         sys.v_$tablespace bb,
                         all_tab_partitions p
                   where
                     aa.ts# = bb.ts#
                 and p.tablespace_name = v_tbs and bb.name = p.tablespace_name
                 and    table_name = t.table_name and table_owner = P_OWNER
                 and    partition_position = (
                       select max(partition_position) partition_position
                          from all_tab_partitions
                          where  table_name = t.table_name
                            and table_owner = P_OWNER
                            and tablespace_name = p.tablespace_name  )
              ) c
               where
                    a.ts#  = b.ts# and b.name = V_TBS
                and a.creation_time = c.creation_time ;
     end if;

     if (v_tbs is null ) then
        -- we should not be here or object type is not supported by this routine
              fout('+++++ ERRORR : v_tbs is null for table :' || t.table_name );
              GOTO end_loop;
     end if;

     fout('type=' || v_col_type || ' tbs=' || v_tbs || ' curr name='
                  || v_curr_file_name);
     -- try to detect the presence of a pattern into the TBS name
      v_YYYY_ZZ := substr(translate(V_TBS,
            '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz.',
            '0123456789') , 1) ;
    fout(' raw pattern v_yyyy_ZZ='|| v_YYYY_ZZ);
    -- If there is a pattern we assume that it starts with 20yy
    pos:=instr(v_YYYY_ZZ,'20',1) ;
    if pos > 0 then
       v_YYYY_ZZ:=substr(v_YYYY_ZZ,instr(v_YYYY_ZZ,'20',1));
    end if;
    fout(' polished pattern v_yyyy_ZZ='|| v_YYYY_ZZ);
    -- remove trailing '_' if any remain for a name like SCY_DATA_2000_4Q
    -- will give after translate __2008_4Q
    pos:=0;
    while ( substr(v_yyyy_zz,pos,1) = '_'  )
    loop
       pos:=pos +1;
    end loop ;
    v_yyyy_zz:=substr(v_yyyy_zz,pos);
    fout('v_yyyy_zz=' || v_yyyy_zz || ' len=' || to_char(length(v_yyyy_zz)) );
    -- if v_YYYY_ZZ is of type 2008 or 2008_1 or 2008_07
    -- then we think we found a pattern

    -- the following code need to be modified in 2100 AD :p
    if length(v_YYYY_ZZ) = 4 and substr(v_YYYY_ZZ,1,2) = '20' then
       V_PATTERN:='YYYY';
       V_PATTERN_TYPE:='Y';
    elsif length(v_YYYY_ZZ) = 6 and substr(v_YYYY_ZZ,1,2) = '20'
                                and substr(v_YYYY_ZZ,5,1) = '_' then
       V_PATTERN:='YYYY_Q';
             V_PATTERN_TYPE:='Q';
    elsif length(v_YYYY_ZZ) = 6 and substr(v_YYYY_ZZ,1,2) = '20'
                                and substr(v_YYYY_ZZ,5,1) != '_' then
       V_PATTERN:='YYYYMM';
       V_PATTERN_TYPE:='M';
    elsif length(v_YYYY_ZZ) = 7 and substr(v_YYYY_ZZ,1,2) = '20'
                                and substr(v_YYYY_ZZ,5,1) = '_' then
       V_PATTERN:='YYYY_MM' ;
             V_PATTERN_TYPE:='M';
    elsif length(v_YYYY_ZZ) = 0 then
              V_PATTERN_TYPE:='M';
              V_PATTERN:=null;
    end if;
    if V_PATTERN is not null  then
       -- Create the name of the TBS with a pattern
       pos:=instr(V_TBS,v_YYYY_ZZ) ;
       v_tbs_pattern := substr(v_Tbs,1,pos-1) || v_pattern
                        || substr(v_tbs,pos+length(v_yyyy_zz)) ;
       fout ( 'v_pattern=' || V_PATTERN
                    || '  The tbs pattern name will be : ' || v_tbs_pattern );
    else
       fout('No pattern found in the name of the tbs holding'
               ||' the last created datafile' );
             v_tbs_pattern:=v_tbs;
    end if;
    -- check if tbs already exists in admin_tablespaces
    select count(*) into v_count from admin_tablespaces
            where tablespace_name = v_tbs_pattern ;
    if v_count > 0 then
      -- skip the entry creation since it already exists
       fout('tbs ' || v_tbs_pattern || ' already exists' );
    else
      -- Now insert rows into admin_tablespaces
      fout('inserting ' ||v_tbs_pattern || ' using curr path file '
                        ||v_curr_file_name );
      insert into admin_tablespaces (
           TABLESPACE_NAME, DAILY_SIZE, CURRENT_DATAFILE_PATH, AUTOEXTEND_ON,
           DATAFILE_INITIAL_SIZE_MB, DATAFILE_NEXT_SIZE_MB,DATAFILE_MAX_SIZE_MB,
           ASSM_IN_USE,ASSM_UNIFORM_SIZE_MB,ASSM_MANUAL)
       values
                 (v_tbs_pattern,
                                null,              -- daily size : unkonw
                                    v_curr_file_name,
                                   'ON',                   -- autoextend on
                                   64,           -- initial_size_mb
                                   64,           -- datafile next size mb
                                   32001,               -- a datafile max size mb
                                   null,null,null);    -- ASSM Support not yet done at init
    end if;

    -- insert the rows into admin_tab_partitions
    fout('inserting into admin_tab_partitions for ' || t.table_name
          || ' using tbs pattern ' || v_Tbs_pattern
          || ' partitionon col =' ||v_part_col
          || ' part type='       ||v_pattern_type );

    insert into admin_tab_partitions values
      (v_tbs_pattern,P_OWNER,t.table_name,v_pattern_type,v_part_col,64,64,
                'YES',1,null,24,null,null, 'YES',null,null, substr(t.table_name,1,18));
    -- check now for each index if the local index is not in the table
    -- partition tablespace.If it is different then we must add info into
    -- admin_ind_indexes, so that new indexes will be moved there.
    for i in ( SELECT  u.index_name,u.partition_name,u.tablespace_name
                 FROM
                          all_ind_partitions U, all_indexes idx
                 WHERE
                         idx.owner = P_OWNER and
                         idx.table_name = t.table_name and
                         idx.index_name = u.index_name and
                         U.index_owner  = P_OWNER            and
                         u.tablespace_name <> v_tbs and
                         partition_position =  (select
             max(partition_position) partition_position from all_ind_partitions
             where  index_name = idx.index_name and index_owner = P_OWNER ))
    loop
       fout('adding index ' ||i.index_name ||' from table'
               || t.table_name|| ' tbs = ' || i.tablespace_name );
             v_count:=0;
             select count(*) into v_count from admin_ind_partitions
               where index_name = i.index_name and table_owner = P_OWNER ;
             if v_count = 0 then
                begin
                  insert into admin_ind_partitions
               values(P_OWNER,t.table_name,i.index_name,i.tablespace_name,null);
                        commit ;
              exception
              when others then
                 fout ('error : the insert into admin_ind_partitions did not worked.'
                 ||' Check why and do it manually');
                 fout('code : insert into admin_ind_partitions values ('''
                 || P_OWNER||''','''||t.table_name||''','''
             ||i.index_name||''','''||i.tablespace_name||''',null' );
              end ;

      end if ;
    end loop;
    commit ;
    -- reset variables to default values before we process next table/partition:
    <<end_loop>>
    v_pattern := null ;
    v_pattern_type := 'M';
    v_pattern_type:=null;
    v_tbs:=null;
    v_tbs_pattern:=null;
    v_part_col:=null;
    v_col_type:=null;
    v_curr_file_name :=null ;
   end loop ;    -- next partitioned table of the given user
end ;
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
/*  +           Set variables values           + */
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
procedure set_variables_values is
  N_THIS_QUARTER number(1);
begin
 -- general variables
  select substr(version,1,instr(version,'.',1)-1)
             into V_ORA_VERSION from v$instance ;
  fout (  'ora_version='||to_Char(v_ora_version) );

  V_YYYY              :=to_char(sysdate,'YYYY');                        -- this year
  V_NEXT_YYYY     :=to_char(add_months(trunc(sysdate),12),'YYYY') ;     -- next year
  V_PREV_YYYY     :=to_char(add_months(trunc(sysdate),-12),'YYYY') ;    -- last_year
  V_NEXT_YYYY_START  :=V_NEXT_YYYY||'0101';
  V_NEXT_YYYY_HV:= to_char(add_months(
               to_date(V_NEXT_YYYY_START,'YYYYMMDD'),12),'YYYYMMDD') ;
  fout('This year='|| V_YYYY || ' Next Y='
               ||V_NEXT_YYYY|| ' V_NEXT_YYYY_START='|| V_NEXT_YYYY_START ||
         ' V_NEXT_YYYY_HV=' || V_NEXT_YYYY_HV );
  -- month variables
  V_THIS_MONTH          := to_char(sysdate,'YYYYMM');
  V_NEXT_MONTH_START  := to_char(add_months(sysdate,1),'YYYYMM')||'01';
  V_PREV_MONTH          := to_char(add_months(sysdate,-1),'YYYYMM');
  V_THIS_MONTH_HV := to_char(add_months(sysdate,1),'YYYYMM')||'01';

  /* it is +2 and not +1 for condition on table partitioned by month'*/
  V_NEXT_MONTH_HV := to_char(add_months(sysdate,2),'YYYYMM')||'01';

    /* uses "row < (current month+1)" for the current month. So to check */
    /* next month we check on M+2                          */
  fout('Last month=' ||V_PREV_MONTH ||'This month=' || V_THIS_MONTH
      || ' Next MONTHr='|| V_NEXT_MONTH_START ||' next_month_hv ='
      || V_NEXT_MONTH_HV );
  -- quarter variables
  N_THIS_QUARTER    :=  ceil(to_number(to_char(sysdate,'MM'))/3);
  fout(' This Quarter '|| to_char(N_THIS_QUARTER));
  if ( N_THIS_QUARTER = 4 ) then
      V_THIS_QUARTER_START    :=  V_YYYY
             ||to_char((N_THIS_QUARTER*3)-2)||'01';      --  yyyy1001
  else
   V_THIS_QUARTER_START    :=  V_YYYY||'0'
             ||to_char((N_THIS_QUARTER*3)-2)||'01';  -- yyyy0701
  end if;
  fout('This Quarter start ' || V_THIS_QUARTER_START );
  V_PREV_QUARTER_START    := to_char(add_months(
           trunc(to_date(V_THIS_QUARTER_START,'YYYYMMDD')),-3) ,'YYYYMMDD');
  fout( 'Prev Q start ' || V_PREV_QUARTER_START );
  V_NEXT_QUARTER    := '0'||to_char(ceil(
         to_number(substr(get_next_quarter_start(N_THIS_QUARTER),5,2))/3));
  fout('Next Quarter '|| V_NEXT_QUARTER);
  V_NEXT_QUARTER_START    :=  get_next_quarter_start(N_THIS_QUARTER)||'01';
  fout('Next Q start '|| V_NEXT_QUARTER_START);
  V_NEXT_QUARTER_HV     := to_char(add_months(
              to_date(V_NEXT_QUARTER_START,'YYYYMMDD'),3),'YYYYMM')||'01';
  fout ('Next Q hv ' || V_NEXT_QUARTER_HV    );
end ;
/*+++++++++++++++++++++++++++++++++++++++++++++*/
/*        check all tbs free space           */
/*+++++++++++++++++++++++++++++++++++++++++++++*/
procedure check_all_tbs_free_space
is
  v_owner     varchar2(30);
  v_table     varchar2(30);
  v_tablespace     varchar2(30);
  v_part_type     varchar2(1);
  ret         number:=0;
begin
   fout(chr(10)||'Starting to check space for all tablespaces' );
   for t in (select tablespace_name,
                   sum(daily_size) tsize
                   from admin_tablespaces group by tablespace_name )
   loop
       -- extract one table name
       begin
       select table_owner,table_name into V_owner,v_table from
         (select table_owner,table_name
            from admin_tab_partitions where tablespace_name = t.tablespace_name)
      where rownum=1;
       select part_type into v_part_type
               from admin_tab_partitions
               where table_owner = v_owner and table_name = v_table ;
       if v_part_type    = 'M' then
         V_THIS_PERIOD_START       :=V_THIS_MONTH||'01';
      elsif    v_part_type = 'Q' then
         V_THIS_PERIOD_START       :=V_THIS_QUARTER_START;
      elsif    v_part_type = 'Y'  then
         V_THIS_PERIOD_START       := V_YYYY||'01';
      end if;
      fout('V_THIS_PERIOD_START='|| V_THIS_PERIOD_START
           || 'v_owner:'||v_owner|| ' v_table=' || v_table) ;
      v_tablespace:=get_tablespace_name(v_owner,v_table,V_THIS_PERIOD_START);
      fout('v_tablespace=' || v_tablespace );
      -- check if this tablespace already exists. if not,
      -- then create otherwise check if enough space
     ret:= check_tbs_exists(V_TABLESPACE);
     if ret = -1  then
         fout(chr(10)||'!! Tablespace ' || V_TABLESPACE
                  ||' does not exists !!         aborting process:');
     else
       ret:=check_tbs_free_space(V_TABLESPACE, V_OWNER, V_TABLE);
       if ret > 0 then
           fout(chr(10)||'We need to add a datafile to ' || V_TABLESPACE );
           add_datafile (null, v_owner, v_table, V_THIS_PERIOD_START);
        else
            fout('We have enough space for ' || v_tablespace );
        end if ;
     end if;
      exception when no_data_found then
            fout('no data found for t.tablespace_name = ' || t.tablespace_name );
     end ;
   end loop;
end;
/*..................................................*/
/*           extract_date                */
/*..................................................*/
/* return the date from the high_value in format YYYYMMDD */
function extract_hv_date(P_OWNER in varchar2,
             P_TABLE in varchar2, P_PARTITION_NAME in varchar2) return varchar2
is
  v_hv          varchar2(10) ;

  -- Possible values are : Date (date) Number (Julian date)
  -- varchar2 (date in char) Integer (Another form of Julian date)
  v_col_type  varchar2(10) ;

  v_hv_num    number ;
  v_mask      varchar2(30):='';
  v_hv_char   varchar2(30) ;
  sqlcmd      varchar2(4000);
  ret           varchar2(30);
 begin
     v_col_type:=get_col_type(P_OWNER,P_TABLE);
   -- fout('v_col_type=' ||v_col_type);
     if v_col_type = 'DATE' or v_col_type = 'TIMESTAMP' then
    -- in 9i we don't have regexp but high_value do not take values
    -- out of to_timestamp neither :p
    if v_ora_version = 9 then
           select substr(long_to_str(table_owner,table_name,partition_name),11,10 )
             into v_hv
              from all_tab_partitions
               where TABLE_OWNER    = P_OWNER and
             TABLE_NAME        = P_TABLE and
             PARTITION_NAME = P_PARTITION_NAME;
        else
       -- version 10 and above
                 sqlcmd:='select regexp_replace(
                                 admin_tab_parts.long_to_str(
                                        table_owner, table_name, partition_name),
          ''.*([[:digit:]][[:digit:]][[:digit:]][[:digit:]]'
          ||'.[[:digit:]][[:digit:]].[[:digit:]][[:digit:]]).*'', ''\1'')
                              from all_tab_partitions
                            where TABLE_OWNER    = '''||P_OWNER||'''          and
                                  TABLE_NAME     = '''||P_TABLE || '''        and
                                  PARTITION_NAME = '''||P_PARTITION_NAME || '''';
                 --  fout(sqlcmd); --bpa eventually comment if its spam the log
               execute immediate sqlcmd into v_hv ;
        end if;
    return substr(v_hv,1,4)||substr(v_hv,6,2)||substr(v_hv,9,2);-- return YYYYMMDD
    elsif v_col_type = 'NUMBER' or v_col_type = 'INTEGER' then
         select high_value into v_hv_num
               from all_tab_partitions
               where TABLE_OWNER    = P_OWNER and
                     TABLE_NAME        = P_TABLE and
             PARTITION_NAME  = P_PARTITION_NAME;
          return to_char(to_date(v_hv_num,'J'),'YYYYMMDD');
    elsif v_col_type = 'VARCHAR2' or v_col_type = 'CHAR' then
            select high_value into v_hv_char
               from all_tab_partitions
               where TABLE_OWNER    = P_OWNER and
                     TABLE_NAME        = P_TABLE and
             PARTITION_NAME  = P_PARTITION_NAME;
             v_mask:=get_col_mask(P_OWNER,P_TABLE);
             if length(v_mask) = length(v_hv_char) + 1 then
                v_hv_char:='0' || v_hv_char ;
             end if ;
             if length(v_mask) <1 then
                fout('!!!!!! WARNING : Table ' || P_TABLE
       ||' is partitionned by a varchar (may be date) and no mask was provided');
                fout('Fill in the date mask (ie : YYYYMMDD)'
         ||' ADMIN_TAB_PARTITIONS.USE_DATE_MASK_ON_PART_COL' );
fout('If the field is a real numeric given in VARCHAR, put NNN  as mask (3xN)');
             end if ;
             if ( V_MASK = 'NNN' ) then
                 ret := v_hv_char ;
             else
                sqlcmd:='select to_char(to_date('||v_hv_char||','''
              ||v_mask||'''),''YYYYMMDD'') from dual';
                --fout('spec1 sqlcmd='|| sqlcmd);
                execute immediate sqlcmd into ret ;
             end if;
             return ret ;
    end if;
end ;
/*..................................................*/
/*           get_min_high_value            */
/*                                        */
/*  return the lowest high_value of partitons in    *
/*  format YYYY-MM-DD                    */
/*..................................................*/
function get_min_high_value(P_OWNER in varchar2,
         P_TABLE in varchar2, P_PARTITION_HV out varchar2) return varchar2 is
  v_min_hv varchar2(18) ;
begin
       select partition_name, high_value into P_PARTITION_HV, v_min_hv from
          (
           select partition_name,
            extract_hv_date(P_OWNER,P_TABLE,partition_name) high_value
              from all_tab_partitions
               where TABLE_OWNER   = P_OWNER and
                     TABLE_NAME    = P_TABLE order by 2 asc
      ) where rownum=1 ;
     return v_min_hv;
end ;
/*..................................................*/
/*          long to str                    */
/*                            */
/*  Convert the high_value long into a varchar2     */
/*..................................................*/
function long_to_str( P_OWNER varchar2,
                P_TABLE varchar2, P_PART_NAME varchar2 ) return varchar2
is
     var all_tab_partitions.high_value%type;
begin
     select high_value into var
            from
                all_tab_partitions
            where
                     TABLE_OWNER    = P_OWNER
                and  TABLE_NAME     = P_TABLE
                and  PARTITION_NAME = P_PART_NAME ;
     return var;
end;
/*..................................................*/
/*           set tablespace status read write     */
/*..................................................*/
procedure set_tbs_read_write(P_RET_TBS in NUMBER, P_TBS in varchar2)
is
   sqlcmd varchar2(128);
begin
  if P_RET_TBS = 1 then
     sqlcmd:= 'alter tablespace ' || P_TBS || ' read write ';
     execute immediate sqlcmd;
  end if;
end ;
/*............................................................*/
/*          Check tablespace status                  */
/*
/*   return code value    : -1 could not set tbs in read write
/*               0 nothing to do
/*                         1 could set it to read write,
/*  you will have to reset to read only after your operation */
/*...........................................................*/
function check_tbs_status(P_TBS varchar2) return number
is
  v_status varchar2(9);
  sqlcmd varchar2(128);
begin
  select status into v_status from dba_tablespaces
         where tablespace_name = P_TBS ;
  if v_status = 'READ ONLY' then
     sqlcmd:= 'alter tablespace ' || P_TBS || ' read only ';
     fout(sqlcmd);
     execute immediate sqlcmd ;
     return 1;
  end if;
  return 0;
  exception
     when no_data_found then
          fout('tbs ' ||P_TBS || ' does not exists' );
          return -1 ;
     when others then
          return -1;
end;
function get_period_to_quarter (P_PERIOD varchar2) return varchar2 is
   p    integer;
   padd number;
begin
   p:=to_number(substr(P_PERIOD,5,2));
   if (mod(p,3) != 0 ) then
        padd:=1;
   else
        padd:=0;
   end if;
   return to_char(trunc(p/3)+padd);
end;
/*..................................................*/
/*.............. Get col type ......................*/
/*..................................................*/
function get_col_type ( P_OWNER varchar2, P_TABLE varchar2 ) return varchar2 is
  var varchar2(20);
begin
  select data_type into var from dba_part_key_columns a, dba_tab_columns b
     where a.owner = P_OWNER and a.name = P_TABLE and
               b.OWNER = a.OWNER and
               b.table_name = a.name and a.COLUMN_POSITION = 1
   and a.COLUMN_NAME = b.COLUMN_NAME ;
  if instr(var,'(') > 0 then
     return substr(var,1,instr(var,'(')-1) ;
  else
     return var ;
  end if;
end;
/*..................................................*/
/*.............. Get col mask ......................*/
/*..................................................*/
function get_rad_part_name ( P_OWNER varchar2, P_TABLE varchar2 )
   return varchar2 is
  var varchar2(30);
begin
  select part_name_radical into var from admin_tab_partitions
     where table_owner = P_OWNER and table_name = P_TABLE ;
  return var ;
  exception
    when no_data_found then
      return null;
end;
/*..................................................*/
/*.............. Get col mask ......................*/
/*..................................................*/
function get_col_mask ( P_OWNER varchar2, P_TABLE varchar2 ) return varchar2 is
  var varchar2(10);
begin
  select use_date_mask_on_part_col into var from admin_tab_partitions
     where table_owner = P_OWNER and table_name = P_TABLE ;
  return var ;
end;
/*..................................................*/
/*.............. Get table lock ....................*/
/*                                          */
/* Many time when you try to drop a partition, you get a library cache lock
   on the table definition.  This procedure try to obtain a full table lock on
   the table before DDL Cycle V_MAX_LOCK_ATTEMPT trying to get the lock table.
   return ok immediatly when succesfull otherwise it re-sleep V_MAX_LOCK_ATTEMP
   time. if still unssucessful after V_MAX_LOCK_ATTEMP, it return a skip this
   file message todo : in 11g use rather the new parameter DDL_WAIT
/*..................................................*/
function get_table_lock( P_OWNER in varchar2, P_TABLE in varchar2) return number
is
   resource_busy  exception;
   deadlock          exception;
   pragma exception_init (resource_busy, -00054);
   pragma exception_init (deadlock, -60);
   cpt              number:= 0;
   sqlcmd         varchar2(128);
begin
   sqlcmd:= 'lock table '|| P_OWNER ||'.'||P_TABLE|| ' in exclusive mode nowait';
   fout(sqlcmd);
   -- we give ourselves 60 seconds to obtain the lock
   while cpt <= V_MAX_LOCK_ATTEMPT
   loop
      begin
    execute immediate sqlcmd;
    fout('lock obtained');
    return 0;
      exception
     when resource_busy then
          fout('Lock attempt ; ' ||to_char(cpt) || ' failed,'
               ||'  in exception busy 00054: sleeping 1 second at '||
                 to_char(sysdate,'YYYY-MM-DD HH24:MI:SS') );
          dbms_lock.sleep(1);
         when     deadlock then
          fout('in exception  dead lock : sleeping 1');
          dbms_lock.sleep(1);
         when others then
               fout('errors in get_lock_table : ' || chr(10)||chr(10)
                                    ||SQLCODE||chr(10)|| SQLERRM);
               return -1;
      end;
      cpt:=cpt + 1 ;
   end loop;
   return -1;
end;
/*..................................................*/
/*.............. Drop partition ....................*/
/*..................................................*/
function drop_partition(P_OWNER in varchar2,P_TABLE in varchar2,
                     P_PARTITION_NAME in varchar2) return number is
   sqlcmd        varchar2(4000);
   v_tbs        varchar2(30);
   ret_tbl        number ;
   ret_tbs        number := 0;
begin
    select tablespace_name into  v_tbs from all_tab_partitions
           where partition_name= P_PARTITION_NAME
      and  table_owner=P_OWNER and table_name=P_TABLE;
    sqlcmd:='ALTER TABLE ' || P_OWNER||'.'||P_TABLE || ' drop partition '
                         || P_PARTITION_NAME || ' update global indexes' ;
    fout(sqlcmd);
    -- check the tablespace status
    ret_tbs:= check_tbs_status(v_tbs);
    if ret_tbs = -1 then
       fout('problem with the tablepsace ' || v_tbs || ' status' ) ;
       return -1;
    end if;
    -- get table lock
    ret_tbl:= get_table_lock(P_OWNER,P_TABLE);
    if ret_tbl = 0 then
        begin
           execute immediate sqlcmd;
             set_tbs_read_write(ret_tbs, v_tbs);
        return 0;
        exception
            when others then
                 fout('drop partition NOT DONE ' || chr(10)||chr(10)
                     ||SQLCODE||chr(10)|| SQLERRM);
                    set_tbs_read_write(ret_tbs,v_tbs);
                 return -1 ;
    end ;
    else
        fout('Could not obtain the table lock of ' || P_OWNER||'.'||P_TABLE);
        fout('drop partition NOT DONE');
        set_tbs_read_write(ret_tbs,v_tbs);
        return -1;
    end if ;
    set_tbs_read_write(ret_tbs,v_tbs);
    return 0;        -- should never arrive here
end ;
/*..................................................*/
/*.............. Drop oldest partition .............*/
/*..................................................*/
function drop_oldest_partition(P_OWNER in varchar2,
         P_TABLE in varchar2) return number is
   sqlcmd        varchar2(4000);
   v_partition_name varchar2(30);
   ret            number ;
begin
    select partition_name into v_partition_name from all_tab_partitions
           where
              table_owner=P_OWNER and
                  table_name=P_TABLE  and
          partition_position=1;
    ret:=drop_partition(P_OWNER,P_TABLE,v_partition_name);
    return ret;
end ;
/*..................................................*/
/* .............. Get previous period name .........*/
/*..................................................*/
function get_previous_period_part_name(P_OWNER varchar2,
           P_TABLE varchar2, P_PART_NAME varchar2, P_YYYY_MM_DD varchar2,
                P_PART_TYPE varchar2 ) return varchar2
is
    ret            varchar2(30):='bleehh';
    v_days_diff number;
    v_date        date;
begin
    for t in (select partition_name,
                extract_hv_date(P_OWNER,P_TABLE,partition_name) high_value
                 from all_tab_partitions
                where TABLE_OWNER   = P_OWNER and
                TABLE_NAME    = P_TABLE order by 2 desc)
    loop
       v_date:=to_date(t.high_value,'YYYYMMDD');
       if ( P_PART_TYPE = 'M' ) then

           v_days_diff:=to_date(V_NEXT_MONTH_START,'YYYYMMDD')
                  - to_date(V_PREV_MONTH,'YYYYMM') ;  -- 2 months back not one
       elsif ( P_PART_TYPE = 'Q' ) then
           v_days_diff:=to_date(V_NEXT_QUARTER_START,'YYYYMMDD')
       - to_date( V_PREV_QUARTER_START,'YYYYMMDD')-1 ; -- -1 offset the last day

       elsif ( P_PART_TYPE = 'Y' ) then

           v_days_diff:=to_date(V_NEXT_YYYY,'YYYY')
              - to_date( V_YYYY,'YYYY')-1 ; /* -1 to offset the last day */
       end if;

       -- spam : fout('P_YYYY_MM_DD='||P_YYYY_MM_DD
        --                   || ' t.high_value='||t.high_value);
       if (to_date(P_YYYY_MM_DD,'YYYY-MM-DD HH24:MI:SS')
                   - to_date(t.high_value,'YYYYMMDD')) >= v_days_diff then
           -- fout('couple is ' || P_PART_NAME || '  ' || t.partition_name );
           -- fout('partition='||t.partition_name||'  diff = ' ||to_char(v_days_diff)
     --|| 'curr diff=' ||to_char(to_date(P_YYYY_MM_DD) - to_date(t.high_value)));
           return t.partition_name;
       else
           ret:=t.partition_name;      -- we must at least return one partition_name
       end if ;
    end loop ;
    return ret;
end;
/*..................................................*/
/* .............. get_next_quarter .................*/
/*..................................................*/
/* return 6 characters : 200810 */
function get_next_quarter_start( Q in number) return varchar2 is
  var number ;
begin
  if q+1 > 4 then
     return V_NEXT_YYYY||'01';
  else
     var:=(q+1)*3-2;
     if var > 9 then
       return V_YYYY||to_char(var);
     else
    return V_YYYY||'0'||to_char(var);
     end if ;
   end if;
end;
/*..................................................*/
/* ............... days in quarter .................*/
/*..................................................*/
function days_in_year(P_PERIOD in varchar2) return number is
begin
  return to_date(V_NEXT_YYYY_HV,'YYYYMMDD')
                - to_date( V_NEXT_YYYY_START,'YYYYMMDD')-1 ;
end;
/*..................................................*/
/* ............... days in quarter .................*/
/*..................................................*/
function days_in_next_quarter (P_PERIOD in varchar2) return number is
begin
   return to_date(V_NEXT_QUARTER_HV,'YYYYMMDD')
                 - to_date(V_NEXT_QUARTER_START,'YYYYMMDD');
end;
/*..................................................*/
/* ............... days in month ...................*/
/*..................................................*/
function days_in_month(P_PERIOD in varchar2) return number is
begin
   return  to_number(to_char(last_day(to_date(P_PERIOD,'YYYYMMDD')),'DD'));
end;
/*..................................................*/
/* ......... Check if index exists .................*/
/*..................................................*/
function check_index_exists(P_OWNER in varchar2, P_INDEX_NAME in varchar2)
           return number is
  ret number;
  v_index_name varchar2(30);
begin
  select index_name into v_index_name from all_indexes
          where owner=P_OWNER and index_name = P_INDEX_NAME;
  return 0;
exception
   when others then return -1;
end;
/*..................................................*/
/* ......... get last datafile sequence nummber ....*/
/*..................................................*/
function get_next_datafile_num( P_TBS in varchar2) return varchar2 is
var varchar2(5);
nn number := 0;
sqlcmd varchar2(4000);
begin
  if v_ORA_VERSION=10 then
     sqlcmd:='select '
      ||' max( regexp_replace(FILE_NAME,''.*([[:digit:]][[:digit:]]).*'',''\1''))'
      ||'from dba_data_files where tablespace_name = '''|| P_TBS ||'''' ;
       fout(sqlcmd); --bpa eventually comment if its spam the log
       execute immediate sqlcmd into var;
  else
      -- this extract the last part of a path and the last 2 digit out of this
      -- part. Note that windows X: path or '\' is not explicitly supported.
      -- one day maybe....
      -- I don't think it works on windows, so apdapt yourself if need be

        select
     max(substr(translate(
           substr(FILE_NAME,instr(FILE_NAME,'/',-2)+1,instr(FILE_NAME,'/',-1) ),
            '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz.'
       ,'0123456789'),-2))
           into var
         from dba_data_files where tablespace_name = P_TBS ;
   end if;
   nn:=to_number(var) +1;
   if nn < 10 then
      var:='0'||to_char(nn);
   else
      var:=to_Char(nn);
   end if;
   return var;
   exception             -- always return something in this function.
                 -- If file does not exists then it will be treated elsewhere.
      when others then
         return '00';
end;
/*..................................................*/
/*          Check tablespace free space        */
/*                                        */
/*   return : 1 not enough free space left        */
/*          0  enough free space            */
/*..................................................*/
function check_tbs_free_space(P_TBS in varchar2, P_OWNER varchar2,
                              P_TABLE varchar2, P_FREE_SPACE_MB in number:=null)
        return number is
  var                        number:=0;
  v_tbs_free_size_mb        number:=0;
  v_tbs_max_frag_size_mb    number:=0;
  v_current_files_size_mb   number:=0;
  v_daily_size_mb            number:=0;
  v_autoextend_free_size_mb number:=0;
begin
   fout('Checking tbs free space') ;
   -- Free space in existing datafiles
   -- Possible no data found if tbs has no free space left
   -- then there is no entry in dba_free_space
   begin
   select sum(BYTES)/1048576 into v_tbs_free_size_mb
          from dba_free_space where tablespace_name = P_TBS;
   -- max frag size
   select max(bytes)/1048576 into v_tbs_max_frag_size_mb
          from dba_free_space where tablespace_name = P_TBS group by tablespace_name;
--   exception when no_data_found then
             -- no data found means either TBS does not exists or no free space.
             -- But at this stage we have already assert that P_TBS exists
             -- Then we are certain here that there is no space left in P_TBS.
--             fout('no more space free in TBS, we will have to add a datafile');
--             return 1 ;
   exception
      when no_data_found then
          fout('no entry for ' || P_TBS ||' in dba_free_space' );
          v_tbs_free_size_mb:=0;
          v_tbs_max_frag_size_mb:=0;
   end ;
   select sum(bytes)/1048576 into v_current_files_size_mb
          from dba_data_files where tablespace_name = P_TBS;
   select sum(maxbytes)/1058576-sum(bytes)/1058576 into v_autoextend_free_size_mb
          from dba_data_files where tablespace_name = P_TBS and autoextensible='YES';
   fout('Space : ' || P_TBS || ' Free : ' || to_char(v_tbs_free_size_mb,'999990.9')
                   || ' |Max frag size :' ||
         to_char(v_tbs_max_frag_size_mb,'999990.9') ||' |Current files size : '
                             ||to_char(v_current_files_size_mb,'999990.9')||
         ' |Left to autoextend    : ' ||to_char(v_autoextend_free_size_mb,'999990.9') );
   if P_FREE_SPACE_MB is not null then
       -- the min free space was given as agurment
       v_daily_size_mb:=P_FREE_SPACE_MB ;
   else
      -- no min free space given, we check that we have at least
      -- the min free space for the table for one day.
      --         begin
          select a.daily_size into v_daily_size_mb
           from admin_tablespaces a, admin_tab_partitions b
             where  b.table_owner = P_OWNER and b.table_name = P_TABLE and
                a.tablespace_name = b.tablespace_name ;
       if ( v_daily_size_mb is null or v_daily_size_mb < 1   ) then
/*           select (next_extent*5)/1048576 into v_daily_size_mb
                  from
                      dba_tab_partitions
                  where
                      table_name = P_TABLE
                  and table_owner = P_OWNER
                  and partition_position = (select max(partition_position)
         from  dba_tab_partitions
                       where table_name = P_TABLE and table_owner = P_OWNER );
 */
    -- we must take into account the IOT partitioning.
    select max(siz)    into v_daily_size_mb  from
               (select (nvl(next_extent,initial_extent)*5)/1048576 siz
                       from dba_tab_partitions
                       where table_name = P_TABLE
                         and table_owner =  P_OWNER
                         and partition_position = (select max(partition_position)
               from     dba_tab_partitions
               where table_name = P_TABLE and table_owner =  P_OWNER )
                union
                select (nvl(next_extent,initial_extent)*5)/1048576 siz
                       from dba_ind_partitions
                       where (index_name,index_owner) =
                                  (select index_name,owner
                                      from dba_indexes
                                      where table_name = P_TABLE
                                        and owner =  P_OWNER
                                         and INDEX_TYPE like ('IOT%')
                                )
                          and partition_position =
                              (select max(partition_position)
                                 from dba_ind_partitions
                                     where (index_name,index_owner) =
                                       (select index_name,owner
                                          from dba_indexes
                                            where table_name =P_TABLE
                                               and owner =  P_OWNER
                                                 and INDEX_TYPE like ('IOT%'))
                                            )
                  );
           fout('No daily size given, I am using 5*next_exent ( 5*'||v_daily_size_mb
                                     ||' mb) of this partitions as daily_size');
       end if ;
       fout('Max+xt:=' || to_char(v_tbs_free_size_mb
                    + v_autoextend_free_size_mb ,'9999990.0')
                    ||' Daily requested mb  : ' ||
             to_char(v_daily_size_mb));
        --     calculate how much free space we need to call for a new datafile.
    --  end ;
   end if;
   if ( v_tbs_free_size_mb +  v_autoextend_free_size_mb ) < v_daily_size_mb then
       return 1 ;  -- need a new datafile
   else
       return 0 ;  -- no need a new datafile
   end if;
      exception when no_data_found then
      fout('exception : In no data_found exception, so I abort this process '
                  ||'and you will have to rely on TBS monitoring ');
      return 0 ;   -- we don't know, so we rely on the TBS monitoring to awake
                   -- a DBA case off. No new datafile reqested here
end;
/*..................................................*/
/* ............... Check if tablespace exists ......*/
/*..................................................*/
function check_tbs_exists(P_TBS in varchar2) return number is
   var varchar2(30);
begin
   select tablespace_name into var from dba_tablespaces
        where tablespace_name = P_TBS ;
   return 0;
exception
    when no_data_found then
   return -1;
end ;
/*..................................................*/
/* ............... Get datefile num_extend .........*/
/*..................................................*/
/* convert a number into varchar2 with lpad '0'     */
/* it is equivalent to lpad(to_char(num),'0',2)     */
/* it is made as a function so that the algorithm   */
/* may be adapted.                        */
/*..................................................*/
function get_new_part_num(POS in number) return varchar2 is
  var varchar2(5);
begin
   if POS <= 9 then
      var:='0'||to_char(POS);
   else
      var:=to_char(pos);
   end if;
   return var;
end;
/*..................................................*/
/*................ Get tablespace name for index ...*/
/*..................................................*/
/* P_PERIOD is in format YYYYMM(DD)  only the first 6 charcters will be used */
function get_itablespace_name(P_OWNER in varchar2,
               P_TABLE in varchar2, P_INDEX in varchar2, P_PERIOD in varchar2 )
   return varchar2 is
  V_TBS      varchar2(30);
  V_TYPE     varchar2(1);
  ret         number ;
  R_TBS      varchar2(130);
  var number:=0;
  V_UND varchar2(1);
  V_EXT varchar2(130);
begin
  fout('For index ' || P_INDEX
              || ' : Fetching real index tbs name if it is a template');
   -- get the  partition type from admin_table
   select  part_type into V_TYPE
       from admin_tab_partitions
            where table_owner = P_OWNER and table_name=P_TABLE;
   -- get the ind tbs name from admin_ind_parts
   select tablespace_name into V_TBS
          from admin_ind_partitions
                where table_owner = P_OWNER
      and table_name = P_TABLE and index_name = P_INDEX;
   fout('Index Tablespace name is  '||V_TBS || ' of Type='|| V_TYPE);
   --if V_TYPE = 'M' then
     select instr(V_TBS,'YYYY_MM',1) into ret from dual;
     if ret > 0 then
            V_EXT:='_'||substr(p_period,5,2)||substr(V_TBS,ret+7);
     else
     -- end if;
  -- elsif V_TYPE = 'Q' then
        select instr(V_TBS,'YYYY_Q',1) into ret from dual;
        if ret > 0 then
            V_EXT:='_'||get_period_to_quarter(P_PERIOD)||substr(V_TBS,ret+6);
        else
   --  end if;
   --elsif V_TYPE = 'Y' then
   -- Specific: we got tbs names DATA_Y2007 with the 'Y' before the numbers
           select instr(V_TBS,'YYYYY',1) into ret from dual;
           if ret > 0 then                  -- template should be DATA_YYYYY
                            -- but this would give DATA_2007Y with
              V_EXT:=substr(V_TBS,ret+5);   -- with the 'Y' behind. This code is a hack
                                      -- to keep the 'Y' before numbers.
              ret:=ret + 1 ;                -- ugly but correct
           else                             -- End specific
              select instr(V_TBS,'YYYY',1) into ret from dual;
              if ret > 0 then
                    V_EXT:=substr(V_TBS,ret+4);
              end if;
           end if;
        end if;
     end if;
   if ret > 0 then
      fout('V_TBS='|| V_TBS ||' ret='||to_char(ret)|| ' var='||to_char(VAR)
                   || ' Und=' || V_UND || ' V_EXT='|| V_EXT);
      R_TBS:=substr(V_TBS,1,ret-1)|| substr(P_PERIOD,1,4)|| V_EXT;
      fout('Real tablespace name will be ' || R_TBS);
   else
      fout('No tablespace template name found in get_itablespace_name for table '
            || P_OWNER||'.'|| P_TABLE)  ;
      fout('returning tablespace_name to use as target = ' ||V_TBS);
      R_TBS:=V_TBS;
   end if;
   return (R_TBS );
 exception when
    no_data_found then
              Raise_Application_Error(-20001,'No tablespace name : stop location 1');
end;
/*..................................................*/
/*................ Get tablespace name .............*/
/*..................................................*/
/* P_PERIOD is in format YYYYMM(DD)  only the first 6 charcters will be used */
function get_tablespace_name(P_OWNER in varchar2,
                             P_TABLE in varchar2, P_PERIOD in varchar2 )
         return varchar2 is
  V_TBS      varchar2(30);
  V_TYPE     varchar2(1);
  R_TBS      varchar2(130);
  V_EXT      varchar2(130);
  ret       number;
begin
   V_EXT:='';
   select tablespace_name , part_type into V_TBS, V_TYPE
       from admin_tab_partitions
       where table_owner = P_OWNER and table_name = P_TABLE;
   fout('Tablespace name is  '||V_TBS || ' V_TYPE='
                              || V_TYPE || ' period=' ||P_Period);
    --  V_TYPE is monthly
   ret:=instr(V_TBS,'YYYY_MM',1) ;
   if  ret > 0 then
              V_EXT:='_'||substr(p_period,5,2)||substr(V_TBS,ret+7);
   elsif instr(V_TBS,'YYYYMM',1) > 0 then
        ret:=instr(V_TBS,'YYYYMM',1);
        V_EXT:=substr(p_period,5,2)||substr(V_TBS,ret+6);
   --  V_TYPE is yearly
         elsif instr(V_TBS,'YYYY_Q',1) > 0 then
         ret:=instr(V_TBS,'YYYY_Q',1);
               V_EXT:='_'||get_period_to_quarter(P_PERIOD)||substr(V_TBS,ret+6);
         elsif instr(V_TBS,'YYYYY',1) > 0 then
         ret:=instr(V_TBS,'YYYYY',1);
         -- V_TYPE = 5Y this is a specific: we got tbs names DATA_Y2007 with
         -- the 'Y' before the numbers template should be DATA_YYYYY
         -- but this would give DATA_2007Y with
         V_EXT:=substr(V_TBS,ret+5);   -- the 'Y' behind. This code is a hack
                                 -- to keep the 'Y' before numbers.
               ret:=ret + 1 ;    -- ugly but correct
   elsif instr(V_TBS,'YYYY',1) > 0 then
         -- End specific
         ret:=instr(V_TBS,'YYYY',1);
                     V_EXT:=substr(V_TBS,instr(V_TBS,'YYYY',1)+4);
   else
      fout('No tablespace template name found in get_tablespace_name for table '
                    || P_OWNER||'.'|| P_TABLE)  ;
      fout('returning tablespace_name = ' ||V_TBS);
      R_TBS:=V_TBS;
   end if;
         if length(V_EXT) > 0 then
      fout('V_TBS='|| V_TBS || ' V_EXT='|| V_EXT);
      R_TBS:=substr(V_TBS,1,ret-1)|| substr(P_PERIOD,1,4)|| V_EXT;
      fout('Real tablespace name will be ' || R_TBS);
   end if ;
   return (R_TBS );
 exception when
    no_data_found then
    Raise_Application_Error(-20001,'No tablespace name : stop location 1');
end;
/* ........... get_cutoff_date     ......*/
function get_cutoff_date ( P_NBR_PERIOD IN number,P_TYPE in varchar2 )
         return varchar2 IS
ret varchar2(8);
BEGIN
          if p_type = 'M' then

             ret:=to_char(add_months(trunc(to_date(V_THIS_MONTH,'YYYYMM')),
                     -P_NBR_PERIOD),'YYYYMM')|| '01';

          -- now we must drop every partition with high_value > to this cut off date
          elsif p_type = 'Q' then
                      ret:=to_char(add_months(to_date(V_THIS_QUARTER_START,'YYYYMMDD'),
                                -(P_NBR_PERIOD*3)),'YYYYMM') || '01';
          elsif p_type = 'Y' then
                   ret:=to_char(add_months(to_date(V_YYYY||'0101','YYYYMMDD'),
                                    -(P_NBR_PERIOD*12)),'YYYYMM')|| '01';
          end if;
          return ret ;
END ;
/*..................................................*/
/*................ check_rebuild index .............*/
/*..................................................*/
-- This number of period are all partitions between the current date and
-- the high value of the partitions. The rebuild will be effectively performed
-- only if the index is not in the indicated tablespace in ADMIN_IND_PARTITIONS
procedure rebuild_old_index
is
 P_CUTOFF_DATE varchar2(8);
 P_PREV_CUTOFF_DATE varchar2(8);
 sqlcmd varchar2(200);
 V_EXP_TBS_NAME varchar2(30);
 V_PERIOD_START varchar2(8);
begin
  fout('****************************');
  fout('Start of Rebuild_old_index  ' );
  fout('****************************');
  for i in (select a.REBUILD_INDEX_AFTER_N_PERIOD, a.table_name,
                   b.part_type, a.index_name, b.TABLE_OWNER
                    from admin_ind_partitions a, admin_tab_partitions b
                    where
                             a.table_name = b.table_name
                         and b.table_owner =a.TABLE_OWNER
                         and b.IS_PARTIONNING_ACTIVE = 'YES'
                  )
  loop
      fout('Considering rebuild_index for ' || i.index_name
                                  || ' rebuild when older than '
            ||to_char(i.rebuild_index_after_n_period) || ' period(s)' );
      if i.REBUILD_INDEX_AFTER_N_PERIOD is not null
               or i.REBUILD_INDEX_AFTER_N_PERIOD > 0 then
          -- get begin and end period for this index partition
          P_CUTOFF_DATE:=get_cutoff_date(i.REBUILD_INDEX_AFTER_N_PERIOD-1, i.part_type);
          P_PREV_CUTOFF_DATE:=get_cutoff_date
                   (i.REBUILD_INDEX_AFTER_N_PERIOD,  i.part_type ) ;
          fout('tbl=' ||i.table_name || ' idx=' || i.index_name
                ||' date=' || P_PREV_CUTOFF_DATE);
          -- Index tbs for index partition should be now the tbs of the tbl partitiont
          V_EXP_TBS_NAME:=get_tablespace_name
                      (i.table_owner,i.table_name, P_PREV_CUTOFF_DATE );
          fout('P_CUTOFF_DATE=' || P_CUTOFF_DATE || '  P_PREV_CUTOFF_DATE='
             || P_PREV_CUTOFF_DATE || ' v_EXP_TBS_NAME=' ||V_EXP_TBS_NAME);
          FOR r IN ( SELECT u.index_name, u.partition_name,
                       u.tablespace_name, idx.table_name,u.index_owner
                 FROM
                   all_ind_partitions U, all_indexes idx
                 WHERE
                    idx.owner = i.table_owner              and
                    idx.table_name = i.table_name          and
                    idx.index_name = i.index_name          and
                    U.index_owner  = i.table_owner         and
                    U.index_name  = idx.index_name         and
                    U.tablespace_name <> V_EXP_TBS_NAME    and
                    to_date(extract_hv_date(i.table_owner,i.table_name,u.partition_name) ,
                         'YYYYMMDD') > to_date( P_PREV_CUTOFF_DATE,'YYYYMMDD') and
                      to_date(extract_hv_date(i.table_owner,i.table_name,u.partition_name),
                      'YYYYMMDD') <= to_date( P_CUTOFF_DATE,'YYYYMMDD')
           )
          LOOP
             fout('Moving index ***** '|| r.index_name||'.'||r.partition_name
                                 || ' from '|| r.tablespace_name||' =====> '
                                 ||v_EXP_TBS_NAME||' *****');

               sqlcmd:='ALTER INDEX ' ||r.index_owner || '.' || r.index_name
                                || ' REBUILD PARTITION ' || r.partition_name
                                ||' STORAGE (INITIAL 1M NEXT 1M) TABLESPACE '
                                || v_EXP_TBS_NAME ||  ' COMPUTE STATISTICS ';
                  fout(sqlcmd||chr(10));
                 execute immediate sqlcmd ;
          END LOOP;
        end if ;
     end loop;
 exception
    when no_data_found then
         fout('no data found in rebuild old index')  ;
   -- if no data found or value is null then move index location
     when others then
        fout('error in rebuild old index'
      ||chr(10)||chr(10)||SQLCODE||chr(10)|| SQLERRM);
end ;
/*..................................................*/
/*.............. calc high value ...................*/
/*..................................................*/
/* return the date part of the high_value string for a new partition.  */
/* Partitons are counted one to the number of partition to create.     */
/* The partition name currently worked on is in variable P_THIS_POS    */
/* If you are requested 7 new partitions in a period (P_TOT_PARTS) and */
/* you have done already 2 and now want to make the third, P_THIS_POS  */
/* will be = 3, P_START and P_END are the beg and end date for           */
/* the whole period. This procedure will calculate the high value for  */
/* each of the 7 partitions                           */
/*.....................................................................*/
function calc_new_high_value(P_START in varchar2, P_END in varchar2,
                             P_TOT_PARTS in number, P_THIS_POS in number )
  return varchar2 is
  ddays       number;
  avg_days    number;
  ret          varchar2(22);
  mod_rest    number:=0;
  smooth_days number:=0;
  abs_days    number;
  V_TOT_PARTS    number;
begin
--fout('p_end=' || P_END || ' p_start='|| P_START );
  ddays:=to_date(P_END,'YYYYMMDD')-to_date(P_START,'YYYYMMDD');
  if P_TOT_PARTS > ddays then
     V_TOT_PARTS:=ddays ;
  else
     V_TOT_PARTS:=P_TOT_PARTS  ;
  end if;
  avg_days:=round(ddays/V_TOT_PARTS);            -- ie 29/10 we want 3 rather than 2,
  abs_days:=trunc(ddays/V_TOT_PARTS);    -- that's why we use ceil
  mod_rest:=mod(ddays,V_TOT_PARTS);
  if P_THIS_POS < V_TOT_PARTS then

     /* we need to smooth the partitions with the remaining days of the period:
        If you have 31 days and you are requested 7 partitons in this period you will
  have 31 modulo 7 = 3 days left. You can either put the left days into the
  first partition or    the last partition or spread the 3 days one into each
  first or last partition. This current algorithm add one day to each first
  partitions until the modulo is exhausted making it : 5 5 5 4 4 4 4.     */

     if P_THIS_POS < mod_rest then
              smooth_days:=mod_rest-(mod_rest-P_THIS_POS) ;
     else
              smooth_days:=mod_rest;
     end if;
     ret:=to_char(to_date(P_START,'YYYYMMDD')+(P_THIS_POS * abs_days)
                  + smooth_days,'YYYY-MM-DD HH24:MI:SS');
     fout('ddays='|| to_char(ddays)|| ' delta='
                  || to_char((abs_days*P_THIS_POS)+smooth_days)
                  ||' P_THIS_POS=' || to_char(P_THIS_POS)|| ' P_TOT_PARTS='
                  || to_char(P_TOT_PARTS) || ' Mod_rest:=' || to_char(mod_rest)
                  ||' abs_days=' ||to_char(abs_days)
                  ||' smooth_days='|| to_char(smooth_days)
               ||' V_TOT_PARTS='|| to_char(V_TOT_PARTS) );
  else
     ret:= substr(P_END,1,4)||'-'||substr(P_END,5,2)||'-01 00:00:00';
  end if;
  fout('Number of days := ' || to_char(ddays) || ' mean days : '
                            || to_char(avg_days) || ' ret=' || ret);
  return ret;
end ;
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
/*  +         Check partitions needed next month  */
/*  +    Default behaviour will check if we have  */
/*  +    partitions set for next month         */
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
procedure check_add_partitions_needed  is
     V_TABLE_NAME          varchar2(30);
     V_CURRENT_HIGH_VALUE varchar2(500);
     V_PART_NAME          varchar2(30);
       CURR_HV          varchar2(8);
     cpt              number ;
     tbl_count          number:=0 ;
     v_day_diff       number:=0 ;
begin
  -- report some info
  fout('===========================================' ||chr(10)
         ||'Starting tables partitions check'||chr(10)
         || '===========================================' );
  fout('Current month is      : ' || V_THIS_MONTH);
  select count(*)
        into cpt from  admin_tab_partitions where IS_PARTIONNING_ACTIVE = 'YES';
  fout('Number of tables to checks: ' || to_char(cpt)
                       || chr(10)||chr(10)||'..................'|| chr(10));
  -- start process each candicate table to see if new partition is needed
  for t in (select * from  admin_tab_partitions
           where IS_PARTIONNING_ACTIVE = 'YES')
  loop
      tbl_count:=tbl_count+1;
      -- v 1.6 Add check to se if table exists or the chain is broken
      select count(*) into cpt from dba_tables 
          where owner=t.table_owner and table_name=t.table_name ;
      if cpt = 0 then
         fout ('Warning : the table '||t.table_owner||'.'||t.table_name
                           || ' does not exists --> skipping' ) ;
         goto TO_NEXT ;
      end if ;   
      -- get the current hivh value for the table
      select partition_name into V_PART_NAME from dba_tab_partitions
         where table_owner=t.table_owner and table_name=t.table_name
          and PARTITION_POSITION = (select max(PARTITION_POSITION)
                                          from dba_tab_partitions
                                          where table_owner=t.table_owner
                                           and table_name=t.table_name);

      select extract_hv_date(t.table_owner,t.table_name, v_part_name)
                 into V_CURRENT_HIGH_VALUE   from dual;
     -- select max(extract_hv_date(t.table_owner,t.table_name, partition_name))
     --      into V_CURRENT_HIGH_VALUE
     --    from dba_tab_partitions
     --              where table_owner = t.table_owner and
     --                table_name = t.table_name;
      fout( chr(10) ||' ------>' || to_char(tbl_count)||'  Checking '
             ||t.table_owner ||'.'||t.table_name ) ;
      CURR_HV := substr(V_CURRENT_HIGH_VALUE,1,8);
      fout ('Current table high value  : ' || CURR_HV ) ;
      -- ....................................................
      -- ................. Month processing .................
      -- ....................................................
      if t.part_type = 'D' then
        v_day_diff:=trunc(to_date(V_CURRENT_HIGH_VALUE,'YYYYMMDD') - trunc(sysdate)) ;
        fout('Days diff:=' ||to_char(v_day_diff) );
        if t.days_ahead is null  then
           cpt:=5;
        else
           cpt:=t.days_ahead;
        end if;
        fout('Partition to maintain ahead : ' || to_char(cpt) );
        if v_day_diff < 0
        then
           v_day_diff:=trunc((v_day_diff)*-1)+cpt;
        else
           v_day_diff:=cpt-trunc(v_day_diff);
        end if;
        fout('Number of days partitions to create = ' ||to_char(v_day_diff) );
        for  i in 1..v_day_diff
        loop
           add_partitions ( t.table_owner, t.table_name);
        end loop;
        goto TO_NEXT ;
      -- ....................................................
      -- ................. Month processing .................
      -- ....................................................
      elsif t.part_type = 'M' then
            V_NEXT_PERIOD_HV      := V_NEXT_MONTH_HV;
            V_NEXT_PERIOD_START := V_NEXT_MONTH_START;
      fout('Current month HIGH_VALUE  : ' || V_THIS_MONTH_HV);
      fout('Requested HIGH_VALUE is   : ' || V_NEXT_PERIOD_HV);
      if to_number(CURR_HV) < to_number(V_NEXT_PERIOD_HV) then

                fout( t.table_owner ||'.'||t.table_name
                 ||' with current highest parts := ' || CURR_HV
                 || ' Requested ' || to_char(t.PARTS_TO_CREATE_PER_PERIOD)
                 || ' new partition for a period type '''||t.part_type
                 ||''' and next period start is '|| V_NEXT_PERIOD_START ) ;
          if t.PARTS_TO_CREATE_PER_PERIOD > days_in_month(V_NEXT_PERIOD_START)
          then
                   fout( 'Partitions count must no be over days in month'
              ||' (1 partitions per day) : new requested ==> '
                          ||to_char(days_in_month(V_NEXT_PERIOD_START) ) );
                end if;

                add_partitions ( t.table_owner, t.table_name);

                fout( chr(10) ||          chr(10)||'..................'|| chr(10) );
            end if ;
      -- ....................................................
      -- ................. Quarter processing ...............
      -- ......................................................
      elsif t.part_type='Q' then

               V_NEXT_PERIOD_START := V_NEXT_QUARTER_START;
               V_NEXT_PERIOD_HV := V_NEXT_QUARTER_HV;
               fout('Current QUARTER HIGH_VALUE  : ' || V_NEXT_QUARTER_START);
               fout('Requested HIGH_VALUE is    : ' || V_NEXT_PERIOD_HV);

               if to_number(CURR_HV) < to_number(V_NEXT_PERIOD_HV)
         then
                  fout( t.table_owner ||'.'||t.table_name
             ||' with current higest parts := ' || CURR_HV || ' Requested '
             || to_char(t.PARTS_TO_CREATE_PER_PERIOD)
             || ' new partition for a period type '''||t.part_type
                   ||''' and next period start is'|| V_NEXT_PERIOD_START ) ;
                  if t.PARTS_TO_CREATE_PER_PERIOD > days_in_next_quarter(V_NEXT_QUARTER)
            then
                    fout( 'Partitions count must no be over days in month '
                     ||'(1 partitions per day) : new requested ==> '
                                 ||to_char(days_in_next_quarter(V_NEXT_QUARTER) ) );
                  end if;

                  add_partitions ( t.table_owner, t.table_name);

                  fout( chr(10) || chr(10)||'..................'|| chr(10) );
         end if;
      -- ....................................................
      -- ................. YEARLY processing ...............
      -- ......................................................
      elsif t.part_type='Y' then

               V_NEXT_PERIOD_START := V_NEXT_YYYY_START;
               V_NEXT_PERIOD_HV := V_NEXT_YYYY_HV ;
               fout('Current YEAR HIGH_VALUE  : ' || V_NEXT_YYYY_START);
               fout('Requested HIGH_VALUE is    : ' || V_NEXT_PERIOD_HV);

               if to_number(CURR_HV) < to_number(V_NEXT_PERIOD_HV)
         then
                   fout( t.table_owner ||'.'||t.table_name
                     ||' with current higest parts := ' || CURR_HV
                           || ' Requested ' || to_char(t.PARTS_TO_CREATE_PER_PERIOD)
                     || ' new partition for a period type '''||t.part_type
                                 ||''' and next period start is'|| V_NEXT_PERIOD_START ) ;

                   if t.PARTS_TO_CREATE_PER_PERIOD > days_in_year(V_NEXT_YYYY)
            then
                       fout( 'Partitions count must exceeds days in month '
                   ||'(1 partitions per day) : new requested ==> '
                               ||to_char(days_in_year(V_NEXT_YYYY) ) );
                  end if;

                  add_partitions ( t.table_owner, t.table_name);

                   fout( chr(10) || chr(10)||'..................'|| chr(10) );
       end if;
      end if ;
      <<TO_NEXT>>
      null ;
  end loop ;
end;
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
/*  +         Add partitions for next period    + */
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
procedure add_partitions (P_OWNER IN VARCHAR2, P_TABLE IN VARCHAR2 ) is
   ret           number;
   cpt                       number;
   V_PART_EXT            varchar2(5):=null;
   sqlcmd                    varchar2(4000) ;
   V_PART_NAME   varchar2(80);
   V_YYYY_MM_DD  varchar2(22);
   V_TABLESPACE  varchar2(30);
   v_col_type            varchar2(10);
   v_jul_date            varchar2(30);
   v_col_mask            varchar2(30);
   v_hv_char       varchar2(30);
   v_rad_part_name   varchar2(30);
   V_LAST_HIGH_VALUE varchar2(30);
   V_NEW_HIGH_VALUE  varchar2(30);
   v_previous_part_name      varchar2(30);
   v_limit_to_days_in_period number;
begin
   fout(chr(10) || '** Start add_partititons **' );
    v_col_mask:=get_col_mask(P_OWNER,P_TABLE);
    v_col_type:=get_col_type(P_OWNER,P_TABLE);
    v_rad_part_name:=get_rad_part_name(P_OWNER,P_TABLE);

    -- fout('v_col_type=' || v_col_type || ' v_col_mask='
    --                  || v_col_mask|| ' v_rad_name=' || v_rad_part_name);
    for t in ( select * from admin_tab_partitions
                  where table_owner = P_OWNER and table_name = P_TABLE )
    loop
    /* this is a trick to load all value in 't'for there is only one row to load
             loop on the number of partitions to create onver the period */

      -- The least value fro function 'days_in_month' or 'days_in_next_quarter'
      --  ensure that parts_to_create_per_period,the number of partitons
      -- requested to be created, does not exceed the number of days available
      -- in the period.
      -- ...................................
      --           Months
       -- ...................................
       if t.part_type = 'D'     then

                v_limit_to_days_in_period:=1;

                select partition_name into V_PART_NAME
             from dba_tab_partitions
                    where table_owner=t.table_owner and table_name=t.table_name
                      and PARTITION_POSITION = (select max(PARTITION_POSITION)
                          from dba_tab_partitions
                          where table_owner=t.table_owner
                               and table_name=t.table_name);

          select extract_hv_date(t.table_owner,t.table_name, v_part_name)
           into V_LAST_HIGH_VALUE   from dual;

          V_NEW_HIGH_VALUE:=to_char(to_date(V_LAST_HIGH_VALUE,'YYYYMMDD')+1,'YYYYMMDD');
          V_PART_NAME:='P_'||V_NEW_HIGH_VALUE ;
      -- ...................................
      --           Months
       -- ...................................
      elsif t.part_type = 'M'      then
                v_limit_to_days_in_period :=least(t.parts_to_create_per_period,
                                         days_in_month(V_NEXT_MONTH_START) );
               V_NEXT_PERIOD_START     :=V_NEXT_MONTH_START;
               V_NEXT_PERIOD_HV        :=V_NEXT_MONTH_HV;
      -- ...................................
      --          Quarter
       -- ...................................
      elsif     t.part_type = 'Q'      then

               v_limit_to_days_in_period :=least(t.parts_to_create_per_period,
                                     days_in_next_quarter(V_NEXT_PERIOD_START) );
               V_NEXT_PERIOD_START       :=V_NEXT_QUARTER_START;
               V_NEXT_PERIOD_HV          :=V_NEXT_QUARTER_HV ;
      -- ...................................
      --          YEARS
       -- ...................................
      elsif     t.part_type = 'Y'      then

               v_limit_to_days_in_period :=least(t.parts_to_create_per_period,
                                                  days_in_year(V_NEXT_YYYY) );
               V_NEXT_PERIOD_START        := V_NEXT_YYYY_START;
               V_NEXT_PERIOD_HV       := V_NEXT_YYYY_HV ;
      end if;
      fout('Number of partitions to create : '
              || to_char(v_limit_to_days_in_period) || ' next_period_start='
                    ||v_NEXT_PERIOD_START || ' next_hv='|| V_NEXT_PERIOD_HV );
      FOR cpt in  1..v_limit_to_days_in_period   -- we could read here :
      loop                                   -- for each partition to create ...

         fout(chr(10)||'++++ Starting creation process of partition ' || to_char(cpt));
   -- more than one partition on the period to create
         if v_limit_to_days_in_period > 1 THEN
                                                    -- or
            V_PART_EXT:='_'||get_new_part_num(cpt); -- get partition  number
            V_YYYY_MM_DD:=calc_new_high_value(  V_NEXT_PERIOD_START, -- Start period
            V_NEXT_PERIOD_HV,                      -- End period
            t.parts_to_create_per_period,   -- Total number of partitions
                                            -- in this period
            cpt );            -- partition number whose date to return
         else    -- There is only one partition
           if  t.part_type = 'D' then
               V_YYYY_MM_DD:= substr(V_NEW_HIGH_VALUE,1,4)||'-'
                           ||substr(V_NEW_HIGH_VALUE,5,2)||'-'
                                 ||substr(V_NEW_HIGH_VALUE,7,2)||' 00:00:00' ;
           else
               V_YYYY_MM_DD:=substr(V_NEXT_PERIOD_HV,1,4)||'-'
                              ||substr(V_NEXT_PERIOD_HV,5,2)||'-01 00:00:00';
           end if ;
         end if ;
        fout('partiton extention='||V_PART_EXT || ' V_YYYY_MD_DD=' || V_YYYY_MM_DD) ;
         -- let's give a name to the partition
        if t.part_type = 'M' then
           -- code valid but not used : just question of opinion on naming convention
           -- if v_limit_to_days_in_period = days_in_month(V_NEXT_MONTH_START) then
           -- if the total requested partitions is equal to days in month then we have
           -- a daily partition in month otherwise it is just a month split in some parts
           -- V_PART_NAME:='PD'||substr(V_NEXT_PERIOD_START,1,4)
     --                  ||'_'||substr(V_NEXT_PERIOD_START,5,2) || V_PART_EXT ;
           -- else
     if v_rad_part_name is null then
       V_PART_NAME:='PM'||substr(V_NEXT_PERIOD_START,1,4)
                  ||'_'||substr(V_NEXT_PERIOD_START,5,2) || V_PART_EXT ;
     else
       V_PART_NAME:=v_rad_part_name||'_'||substr(V_NEXT_PERIOD_START,1,4)
                  ||'_'||substr(V_NEXT_PERIOD_START,5,2) || V_PART_EXT ;
     end if;
           --        end if;
         elsif t.part_type = 'Q' then
         if v_rad_part_name is null then
                    V_PART_NAME:= 'PQ' ||substr(V_NEXT_PERIOD_START,1,4)
                        ||'_'||substr(V_NEXT_QUARTER,2,1) || 'Q'||V_PART_EXT ;
         else
                    V_PART_NAME:=v_rad_part_name||'_'||substr(V_NEXT_PERIOD_START,1,4)
                    ||'_'||substr(V_NEXT_QUARTER,2,1) || 'Q'||V_PART_EXT ;
         end if;
         elsif t.part_type = 'Y' then
            if v_rad_part_name is null then
                     V_PART_NAME:='PY'||substr(V_NEXT_PERIOD_START,1,4)||V_PART_EXT ;
         else
                    V_PART_NAME:=v_rad_part_name||'_'||substr(V_NEXT_PERIOD_START,1,4)
                   ||V_PART_EXT ;
         end if;
         end if;
        -- get the tablespace_name as it should be for Next period
        V_TABLESPACE:=get_tablespace_name(t.table_owner,
                     t.table_name, V_NEXT_PERIOD_START);
        -- check if this tablespace already exists. if not, thne create otherwise
  -- check if enough space
        ret:= check_tbs_exists(V_TABLESPACE);
        if ret = -1  then
           fout(chr(10)||'!! Tablespace ' || V_TABLESPACE
                        ||' does not exists !! Creating it:');
           create_tablespace(V_TABLESPACE, P_OWNER, P_TABLE,'TABLE');
        else
           ret:=check_tbs_free_space(V_TABLESPACE, P_OWNER, P_TABLE);
           if ret > 0 then
              fout(chr(10)||'We need to add a datafile to ' || V_TABLESPACE );
              add_datafile (null, P_OWNER, P_TABLE, V_NEXT_PERIOD_START);
           end if ;
        end if;

        -- column partition key is date is of type date
        if v_col_type = 'DATE' or v_col_type = 'TIMESTAMP' then
            sqlcmd:= 'ALTER TABLE ' || t.table_owner||'.'|| t.table_name
               || ' ADD PARTITION ' || V_PART_NAME
               ||' VALUES LESS THAN (TO_DATE('''||V_YYYY_MM_DD
               ||''', ''YYYY-MM-DD HH24:MI:SS'')) TABLESPACE ' || V_TABLESPACE;

            -- column partition key is date is of number representing a Julian date
        elsif v_col_type = 'NUMBER' or v_col_type = 'INTEGER' then
           if v_col_mask = 'JULIAN' then
               v_jul_date:=to_char(to_date(V_YYYY_MM_DD,'YYYY-MM-DD HH24:MI:SS'),'J');
               sqlcmd:= 'ALTER TABLE ' || t.table_owner||'.'|| t.table_name
                  || ' ADD PARTITION ' || V_PART_NAME ||' VALUES LESS THAN ('
                  || v_jul_date|| ') TABLESPACE    ' || V_TABLESPACE;
              end if;
-- column partition key is a string representing a date. Yup I have seen this :p
        elsif v_col_type = 'VARCHAR2' or v_col_type = 'CHAR'
  then
               v_hv_char:=to_char(to_date(V_YYYY_MM_DD,'YYYY-MM-DD HH24:MI:SS'),
                       v_col_mask);

               sqlcmd:= 'ALTER TABLE ' || t.table_owner||'.'|| t.table_name
                     || ' ADD PARTITION ' || V_PART_NAME
                     ||' VALUES LESS THAN ('''||v_hv_char||''') TABLESPACE '
                     || V_TABLESPACE;
        end if;
        fout(chr(10)|| '---> Adding now the partition:');
        fout ( sqlcmd );
        begin
          execute immediate sqlcmd;
          move_index_part(P_OWNER, P_TABLE, V_PART_NAME);
          if t.copy_stats = 'YES' then
             v_previous_part_name:= get_previous_period_part_name
                 (P_OWNER, P_TABLE, V_PART_NAME, V_YYYY_MM_DD, t.part_type );
             fout('Move stats from previous partition '|| v_previous_part_name
                 ||' to new partition ' || V_PART_NAME);
             if t.part_type = 'D' then
                move_stat_daily(P_OWNER, P_TABLE, V_PART_NAME);
             else
               move_stat(P_OWNER, P_TABLE, v_previous_part_name, V_PART_NAME);
             end if;
          end if ;
        exception when others then
           fout ( 'big badaboum: location stop 2' || chr(10)||chr(10)
                  ||SQLCODE||chr(10)|| SQLERRM);
           Raise_Application_Error(-20001, SQLCODE    || SQLERRM);
        end ;
      end loop ;  /* end while loop cpt*/
   end loop; /* for t */
end;
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
/*  +           Move index  partition       + */
/*  ++++++++++++++++++++++++++++++++++++++++++++ */

/* Sometime you need to move the index away from the table, in order to rebuild
   them later into the definitive partitions whenever the partitions will be
   closed. This procedure allows you to instruct the move the local indexes
   which are automatically located in same partitions, into another tablespace,
   when the partition is closed the indexes will be rebuild togother with
   the table.  If you leave the indexes and tables in the same tablespace,
   then the rebuild index will use twice space and when you have finished
   rebuild the indexes, you end with empty space.  */

procedure move_index_part(P_OWNER in varchar2,P_TABLE in varchar2,
                                       P_PARTITION in varchar2) is
   ret       number;
   V_INDEX_NAME varchar2(30);
   sqlcmd varchar2(500);
   V_EXP_TBS_NAME varchar2(30);
 begin
    -- find each indexe of the table check the table_partition.
    for t in (select index_name,tablespace_name from admin_ind_partitions
                   where table_owner = P_OWNER and Table_name = P_TABLE)
    loop
       -- get  the expected tablespace_name
       V_EXP_TBS_NAME:=get_itablespace_name(P_OWNER,
                            P_TABLE, t.index_name, V_NEXT_MONTH_START );
       fout('Expected Index tablespace_name : ' || V_EXP_TBS_NAME ) ;
       ret:=check_tbs_exists(V_EXP_TBS_NAME);
       if  ( ret != 0 ) then
                -- attentmpt to create missing TBS
                fout(chr(10)||'!! Tablespace ' || V_EXP_TBS_NAME
                    ||' does not exists !!      Creating it:');
                create_tablespace(V_EXP_TBS_NAME, P_OWNER, t.index_name, 'INDEX');
                ret:=check_tbs_exists(V_EXP_TBS_NAME);
       end if ;
       if ( ret = 0 )
       then
                fout('This Tablespace exists ' );
                ret:=check_index_exists(P_OWNER, t.index_name);
                if ret = 0
          then   -- if we have any problem with this index then ignore the index
                   fout('Index '||t.index_name || ' is found in data dictionary');
                   fout(' ');
                   FOR r IN ( SELECT    index_name,partition_name,tablespace_name
                 FROM all_ind_partitions U
                      where  U.index_owner   = P_OWNER and
                             U.index_name  = t.index_name
                         and U.tablespace_name <> V_EXP_TBS_NAME
                         and U.partition_name    = P_PARTITION)
                    LOOP
                       fout ('Current index location for ' || r.index_name
                            || ' is ' || r.tablespace_name );
                       fout ('We will move it to ' || V_EXP_TBS_NAME );
                       fout ('Moving index ***** '|| r.index_name||'.'
                       ||r.partition_name || ' from '
                       || r.tablespace_name||' =====> '
                       || V_EXP_TBS_NAME||' *****');

                            sqlcmd:='ALTER INDEX ' ||P_OWNER || '.' || r.index_name
                          || ' REBUILD PARTITION ' || r.partition_name
                          || ' STORAGE (INITIAL 1M NEXT 1M) TABLESPACE '
                          || V_EXP_TBS_NAME ||  ' COMPUTE STATISTICS ';

                      execute immediate sqlcmd ;

                      fout('move successful');
                      fout(sqlcmd||chr(10));
                   END LOOP;
                else
                  fout('!!! **** There is a problem to move index ' || t.index_name);
                  fout(sqlcmd||chr(10));
                end if;
      else
               fout(' !!! **** tablespace does not exists : skiping this operation');
      end if;
    end loop;
exception
       --if the index name is not in the table admin_ind_partition
       -- then the index partition is not moved.
    when NO_DATA_FOUND then
       fout('NO_DATA_FOUND : problem while trying to move partition'
             || P_PARTITION|| ' of table '    || P_TABLE) ;
end;
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
/*  +           Create tablespace           + */
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
procedure  create_tablespace(P_TBS varchar2, P_OWNER varchar2,
                                   P_OBJECT varchar2, P_TYPE varchar2) is
   V_TBS          varchar2(30);
   sqlcmd          varchar2(4000);
   V_PATH          varchar2(512);
   V_ON           varchar2(5);
   V_INIT_SIZE          number;
   V_NEXT_SIZE          number;
   V_MAX_SIZE          number;
   V_AUTO     varchar2(1);
   V_UNIFORM_SIZE_MB  number ;
begin
  -- retrieve the template name

  begin
     if P_TYPE = 'TABLE' then
              select tablespace_name into V_TBS from admin_tab_partitions
            where TABLE_OWNER=P_OWNER and TABLE_NAME=P_OBJECT ;
     elsif P_TYPE = 'INDEX' then
        select tablespace_name into V_TBS
              from admin_ind_partitions
                  where TABLE_OWNER=P_OWNER and INDEX_NAME=P_OBJECT ;
     end if ;

  exception when no_data_found then
     fout ('no tablespace found in admin_tab_parts for '
            || P_OWNER||'.'||P_OBJECT);
    Raise_Application_Error(-20001,'no tablespace found in admin tab parts for '
                     || P_OWNER||'.'||P_OBJECT );
  end ;

  -- check if the template name exists, retrieve all relevant info for datafile
  begin
    select CURRENT_DATAFILE_PATH, AUTOEXTEND_ON, DATAFILE_INITIAL_SIZE_MB,
           DATAFILE_NEXT_SIZE_MB,  DATAFILE_MAX_SIZE_MB,
                 ASSM_AUTO,     UNIFORM_SIZE_MB
     into
              V_PATH, V_ON, V_INIT_SIZE, V_NEXT_SIZE, V_MAX_SIZE,
              V_AUTO,  V_UNIFORM_SIZE_MB
     from
              ADMIN_TABLESPACES
     where
              tablespace_name = V_TBS;

  exception when no_data_found then
    fout ('no tablespace found in admin_tablespaces for ' || V_TBS);
   Raise_Application_Error(-20001,'no tablespace found in admin_tablespaces for '
             || V_TBS );
  end ;
    sqlcmd:='create tablespace ' || P_TBS || ' datafile '''||V_PATH||'/'
                ||lower(P_TBS) ||'_01.dbf'' size ' || to_char(V_INIT_SIZE)
                || 'm autoextend ' || V_ON || ' next ' || to_char(V_NEXT_SIZE)
                || 'm maxsize ' || to_char(V_MAX_SIZE) ||'m' ;

  if  V_UNIFORM_SIZE_MB is null then
     null ;
  elsif  V_UNIFORM_SIZE_MB = 0 then
     sqlcmd:=sqlcmd || 'extent management local autoallocate' ;
  elsif V_UNIFORM_SIZE_MB > 0 then
     sqlcmd:=sqlcmd || ' extent management local uniform size '
                    || to_char(v_uniform_size_mb) || 'm';
  end if;
  if V_AUTO is null or V_AUTO = 'Y' then
     sqlcmd := sqlcmd || ' segment space management auto ';
  else
    sqlcmd := sqlcmd || ' segment space management manual' ;
  end if ;
  fout (SQLCMD);
  execute immediate sqlcmd ;
  sqlcmd:='alter user ' || P_OWNER || ' quota unlimited on ' || P_TBS ;
  fout(sqlcmd);
  execute immediate sqlcmd ;
  exception when others then
    Raise_Application_Error(-20001, SQLCODE  || SQLERRM);
        fout ( 'big badboum' || chr(10)||chr(10)||SQLCODE||chr(10)|| SQLERRM);
end;
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
/*  +           Add datafiles                                  + */
/*  ++++++++++++++++++++++++++++++++++++++++++++ */

/*  Give the name of the table, from admin_tab_partitions you retrieve from
    admin_tablespace the values relevant to add the data file but the tablespace
    name itself is a template with a date in it : ie DATAYYYY_MM where
    YYYY_MM vary.  to retrieve the real name
*/

procedure add_datafile (P_TBS in varchar2:=null,P_OWNER in varchar2:=null,
                             P_TABLE in varchar2 :=null,P_PERIOD in varchar2 )
is
   sqlcmd    varchar2(4000);
   V_PATH    varchar2(512);
   V_ON      varchar2(5);
   V_TABLESPACE varchar2(30);
   V_INIT_SIZE  number;
   V_NEXT_SIZE  number;
   V_MAX_SIZE     number;
   V_FILE_NN      varchar2(5);
   V_PERIOD     varchar2(8);
begin
  if P_TBS is not null then  -- overload not yet used
     null;
  else
     begin
     select
         CURRENT_DATAFILE_PATH, AUTOEXTEND_ON,
              DATAFILE_INITIAL_SIZE_MB,
              DATAFILE_NEXT_SIZE_MB,
              DATAFILE_MAX_SIZE_MB
           into  V_PATH, V_ON, V_INIT_SIZE, V_NEXT_SIZE, V_MAX_SIZE
     from
           admin_tablespaces a,
                 admin_tab_partitions b
     where
              b.table_owner = P_OWNER   and
                    b.table_name = P_TABLE  and
                    a.tablespace_name = b.tablespace_name ;

     -- P_PERIOD = V_NEXT_PERIOD_START
           v_tablespace:=get_tablespace_name(P_OWNER,P_TABLE, P_PERIOD );
           V_FILE_NN:=get_next_datafile_num(v_tablespace);

           sqlcmd:='alter tablespace '|| V_TABLESPACE || ' add datafile '''
                             ||V_PATH||'/'||lower(V_TABLESPACE) ||'_'
                             || to_char(V_FILE_NN)||'.dbf'' size '
                             || to_char(V_INIT_SIZE)
                             || 'm autoextend ' || V_ON || ' next '
                             || to_char(V_NEXT_SIZE)|| 'm maxsize '
                             || to_char(V_MAX_SIZE) ||'m' ;

     fout (chr(10)||SQLCMD);
     execute immediate sqlcmd ;

    exception when others then
        Raise_Application_Error(-20001, SQLCODE  || SQLERRM);
              fout ( 'big badboum' || chr(10)||chr(10)||SQLCODE||chr(10)|| SQLERRM);
    end ;
  end if ;
end;
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
/*  +           Check stats    table exists       + */
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
procedure check_stat_table(p_owner varchar2) is
 var           varchar2(30):='';
begin
   select table_name into var
       from all_tables
          where owner=P_OWNER and table_name = 'MYSTATTAB';
exception
   when NO_DATA_FOUND then
       fout('dbms_stats.create_stat_table( '''||P_OWNER||''',''MYSTATTAB'');') ;
       dbms_stats.create_stat_table( P_OWNER,'MYSTATTAB');
end;
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
/*  +           Move stats                                       + */
/*  ++++++++++++++++++++++++++++++++++++++++++++ */

/*  When you add a new partition, you copy the statistics of same partitions
    but 2 periods before. This procedure may not be absolutely deterministic
    as  you may vary the number of partitions from one period to another. ie )
     Period      Number of partitions
     ---------- ---------------------
       A   5    partitions
       B   7    partitions
             C   10   partitions
      What is the previous period for C(10)? there is not A10 and no B10
      So the rule is as follow:
      C[1-5] --> A[1-5]
      C[6-10]--> A5
 It is normal to take the period A for as previous to C and not B. ie, say that
 you are filling B5  when you decide to creates period C. Partition B6, B7 have
 no stats while B5 is not complete.
 The first complete period is A, 2 period back in comparison to C.
*/

/*  ++++++++++++++++++++++++++++++++++++++++++++ */
/*  Procedure move stats                         */
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
procedure move_stat ( P_OWNER varchar2, P_TABLE  varchar2,
                            P_PART_SOURCE varchar2, P_PART_TARGET varchar2)
is
  sqlcmd       varchar2(256);
  n           number:=-1 ;
  W_USER       varchar2(30);
  V_METHOD_OPT varchar2(40);
begin
  -- step 1 : initialize stats with default method native to the oracle version
   if V_ORA_VERSION=9 then
     V_METHOD_OPT:='FOR ALL INDEXED COLUMNS SIZE 1' ;
   else
     V_METHOD_OPT:='FOR ALL INDEXED COLUMNS SIZE AUTO';
   end if;

--if P_PART_TARGET IS NOT NULL AND P_PART_SOURCE IS NOT NULL THEN
--   dbms_stats.gather_table_stats( ownname=> P_OWNER, tabname=> P_TABLE,
--                      partname=> P_PART_SOURCE, method_opt=> V_METHOD_OPT,
--                      granularity=> 'PARTITION', cascade=> TRUE ) ;
-- end if;
-- step 2 : check if stat table MYUSERSTAT exists, if not create it

   check_stat_table(p_owner);

-- step 3 : Purge the user stat table

   sqlcmd:='delete from '||P_OWNER||'.MYSTATTAB';
   fout(sqlcmd);
   execute immediate sqlcmd;
   commit ;

-- step 4 : fill the user stat table with the partition stats
   dbms_stats.export_table_stats(ownname =>P_OWNER,
            tabname=> P_TABLE,
            partname=> P_PART_SOURCE,
            stattab=> 'MYSTATTAB',
            statid=>null,
            cascade  => TRUE,
            statown=> null);
-- step 5 : put in the user stat table the target partition

  sqlcmd:='update '||P_OWNER||'.MYSTATTAB set c2 = UPPER('''
                   ||P_PART_TARGET||''')';
  fout(sqlcmd);
  execute immediate sqlcmd;
  commit;
-- step 6 : move the statistics from the user stat table to the dictionnary
   dbms_stats.import_table_stats(P_OWNER,P_TABLE,P_PART_TARGET,'MYSTATTAB',
                       null, TRUE, null);
EXCEPTION
   WHEN OTHERS THEN
     fout('Sqlcode = "' || SQLCODE ||'"');
     fout('Error   = "' || SQLERRM ||'"');
           dbms_output.put_line('Sqlcode = "' || SQLCODE ||'"');
           dbms_output.put_line('Error   = "' || SQLERRM ||'"');
     --Raise_Application_Error(-20001,
     fout('Error when transfering stats for Table '||P_OWNER||'.'||P_TABLE
                       ||' from '||P_PART_SOURCE ||' to ' || P_PART_TARGET);
end;

procedure move_stat_daily(P_OWNER varchar2,
                 P_TABLE varchar2, V_PART_NAME varchar2)is

 pos             number;
 v_part_source varchar2(30);
 v_col_part    varchar2(30);

begin

  check_stat_table(p_owner);

  select partition_position into pos
        from all_tab_partitions
        where table_owner = P_OWNER
                and table_name = P_TABLE
          and PARTITION_NAME = V_PART_NAME;

  -- if there is more than 8 past partitions available then grab the stats
  -- of one week ago. This is done to avoid loading Wee k-end days
  -- with week-day stats  ;  fout('pos=' ||to_char(pos) );
   if pos >= 8 then
      select partition_name into v_part_source
            from all_tab_partitions
       where partition_position = pos - 7
               and table_name = P_TABLE
         and TABLE_OWNER = P_OWNER;

     fout ('a) Found stats 8 days old : copying stats from '
                 || V_PART_NAME  || ' to ' ||V_PART_SOURCE ) ;
     move_stat (P_OWNER , P_TABLE, v_part_source, V_PART_NAME );
   else

     -- Not enough days, then grab the last analyzed.
     -- if none found then grab the last one with stats
     select part_col into v_col_part
         from admin_tab_partitions
            where table_owner = P_OWNER and TABLE_NAME = P_TABLE ;

     begin
     fout('b) No stats found dating one week back : '
               ||' looking for the last analyzed day') ;
      select partition_name into v_part_source
        from (
                  select partition_name
                         from all_tab_partitions
                   where
                       table_owner      = P_OWNER    and
                       table_name       = P_TABLE    and
                       GLOBAL_STATS     = 'YES'
                   order by  LAST_ANALYZED desc,
                       partition_position desc
             ) where rownum = 1 ;

        fout ('b) Copying stats from ' || V_PART_NAME  || ' to '
                   ||V_PART_SOURCE ) ;
        move_stat (P_OWNER , P_TABLE, v_part_source, V_PART_NAME );

     exception

              when others then
                 fout('c) no stats from analyzed' || chr(10)||chr(10)
                 ||SQLCODE||chr(10)|| SQLERRM ) ;
                 fout('c) Checking for generated stats and if exists will copy them');
                select partition_name into v_part_source
            from (
                             select partition_name
                             from all_tab_partitions
                             where
                                 table_owner = P_OWNER
                 and table_name = P_TABLE
                             order by LAST_ANALYZED desc, partition_position desc
                       ) where rownum = 1 ;

                 fout ('c) Copying stats from ' || V_PART_NAME
                || ' to ' ||V_PART_SOURCE ) ;
                 move_stat (P_OWNER , P_TABLE, v_part_source, V_PART_NAME );
     end;
  end if;
exception
  when others then
      fout ('***** ERRORS in copy stat for partitions ' || P_OWNER
                                        ||'.'||P_TABLE||'.'||V_PART_NAME);
      fout('this partition is added without stats!');
end ;
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
/*     drop partition older than given date     */
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
/* P_DATE is in the format YYYYMMDD         */
procedure drop_partition_older_than(P_OWNER varchar2,
                                    P_TABLE  varchar2, P_DATE varchar2) is
ret number;
begin
   for t in (select partition_name,
                    extract_hv_date(P_OWNER,P_TABLE, partition_name) hv_date
                from dba_tab_partitions
                         where table_owner = P_OWNER and table_name  = P_TABLE )
    loop
       if to_date(t.hv_date,'YYYYMMDD') <= to_date(P_DATE,'YYYYMMDD') then
              fout('Partition ' || t.partition_name || ' with high_value '
                          || t.hv_date || ' is older or equal to '||P_DATE);
              ret:=drop_partition(P_OWNER,P_TABLE,t.partition_name);
           if ret=0 then
              fout('Partition is gone ! '|| chr(10));
           end if;
       end if;
    end loop;
end;
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
/*        check if we need to drop partitions  */
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
procedure check_drop_partitions_needed is
  v_drop_after_period number;
  cpt              number;
  diff              number;
  ret              number ;
  v_min_high_value    varchar2(18);
  v_partition_name    varchar2(30);
  v_cut_off_date      varchar2(10);  -- YYYYMM
  v_curr_part_POS     number;
begin
   fout('++++ start of check drop partition needed ');
   for t in (select table_owner,table_name,drop_after_n_period,
              drop_when_n_parts_exists, part_type, days_to_keep
            from  admin_tab_partitions where IS_PARTIONNING_ACTIVE = 'YES')
   loop
    -- if the column was field we will drop partition according to this rule
    fout(chr(10) || 'Considering ' ||          t.table_owner||'.'||t.table_name);
    if t.part_type = 'D' then
       select count(*) into cpt from dba_tab_partitions
            where table_owner = t.table_owner and table_name = t.table_name;

       if cpt = 1 then
                 return ;        -- only one partition remaining
       end if;
       select max(partition_position) into V_CURR_PART_POS
              from dba_tab_partitions
              where table_owner=t.table_owner and table_name = t.table_name
              and to_date(extract_hv_date(t.table_owner,t.table_name,partition_name),
                    'YYYYMMDD') <trunc(sysdate+1) ;

       fout('v_curr_part='|| to_char(v_curr_part_pos)) ;

       diff:=v_curr_part_pos - t.days_to_keep - 1;

       fout('Number of partition to drop : '|| to_char(diff) );

       for i in 1..diff
       loop
                  fout('Dropping partition ' || to_char(i) );
                  ret:= drop_oldest_partition(t.table_owner,t.table_name);
                  if ( ret <> 0 ) then
                     return ;     -- we got a problem then we stop here
                  else
                     fout('Partition is gone !' ||chr(10) ) ;
                  end if ;
              end loop ;
    else
    if t.drop_when_n_parts_exists is not null then
           begin
                    select count(*) into cpt from dba_tab_partitions
            where table_owner = t.table_owner
              and table_name = t.table_name;
              if cpt = 1 then
                        return ;         -- only one partition remaining
              end if;
              fout('Current number of partitions is '
               || to_char(cpt) || ' Maximum should be '
               || to_char(t.drop_when_n_parts_exists) || chr(10));
              diff:=cpt-t.drop_when_n_parts_exists;
              fout('Number of partition to drop : '|| to_char(diff) );
              for i in 1..diff
              loop
                        fout('Dropping partition ' || to_char(i) );
                        ret:= drop_oldest_partition(t.table_owner,t.table_name);
                        if ( ret <> 0 ) then
                           return ;         -- we got a problem then we stop here
                        else
                           fout('Partition is gone !' ||chr(10) ) ;
                        end if ;
               end loop ;

            exception when no_data_found then
                     fout('no more partitions exists for table '
                  || t.table_owner||'.'||t.table_name);
           end ;
        end if;
       -- if the column was field we will drop partition according to this rule
       -- we will 'drop t.drop_after_n_period' period before the current and
       -- the current is non inclused
       -- ie) the 3rd June; t.drop_after_n_period = 2 we drop month 01,02,03

        if t.drop_after_n_period is not null
  then
            fout(chr(10)||'Maximum period to keep '||to_char(t.drop_after_n_period));
            v_min_high_value:=get_min_high_value(t.table_owner,
                                   t.table_name, v_partition_name);
            v_cut_off_date:= get_cutoff_date(t.drop_after_n_period, t.part_type) ;

            -- optionaly remove this check if you want to be able to remove
      -- partitions in the future relative to now
            if to_date(v_cut_off_date,'YYYYMMDD') > sysdate
            then
               fout('!!!! Warning !!!!      Skipped section on drop '
                      ||' per max number of partitions:' );
               fout('Value of t.drop_after_n_period is '|| to_char(t.drop_after_n_period)
         || ' Cannot remove partitions when cut off date is > to sysdate' ) ;
               fout('cut_off_date : ' ||v_cut_off_date);
               return;
            end if;

            fout(' lowest high_value in table is ' || v_min_high_value
                             || ' for partition ' || v_partition_name
                             || ' and cut_off_date=' || v_cut_off_date
                             || chr(10) );

            drop_partition_older_than(t.table_owner,t.table_name,v_cut_off_date);

          end if;
 end if;
 end loop ; /* end  t */
exception
   when no_data_found then
      fout('nothing to do');
end;
/*  ++++++++++++++++++++++++++++++++++++++++++++ */
/*  +           fout                + */
/*  ++++++++++++++++++++++++++++++++++++++++++++ */

/*
  Procedure 'fout' uses default user context with the namespace attribute
  client_info. if it is not set, then the procedure sets it and uses the value
  until the end of the current session as a key to access the row in admin_log
  that contains the CLOB log. The Clob contains the log of the session while
  the temporary log created in this procedure is only to convert the text
  to be appended into CLOB format if the table admin_log does not exists
  it is created using the defaults of the current schema.
*/

procedure fout ( msg in varchar2 ) is
PRAGMA AUTONOMOUS_TRANSACTION;
  v_key      varchar2(22);
  p_lob      clob;
  v_log      clob;
  var_lob    clob;
  var_out    varchar2(4000);
  var         varchar2(30);
  sqlcmd     varchar(2048);
begin
  if msg is null then
     var_out:='errors ; a null msg was sent' ;
  else
    var_out:=msg;
  end if;
   select SYS_CONTEXT ('USERENV', 'CLIENT_INFO') into v_key from dual ;
   if  v_key is null then
    -- v_key is null then it is first time in this session
    -- we want to put a msg into admin_log
      begin
        select table_name into var
            from USER_tables where table_name = 'ADMIN_LOG' ;
      exception

      when no_data_found then
                sqlcmd:='CREATE TABLE ADMIN_LOG (
                      LOG_CREATION    DATE,
                      KEY        VARCHAR2(22 BYTE),
                      LOG        CLOB
               ) TABLESPACE USERS';
          begin
         execute immediate sqlcmd;
           exception when others then
           Raise_Application_Error(-20001, SQLCODE    || SQLERRM);
          end ;
        end ;
        v_key:='MRG_PART'||to_char(sysdate,'YYYYMMDDHH24MISS') ;
        DBMS_APPLICATION_INFO.SET_CLIENT_INFO (v_key );
    select SYS_CONTEXT ('USERENV', 'CLIENT_INFO') into v_key from dual ;
        -- dbms_output.put_line('new v_key=' || v_key );
        dbms_lob.createtemporary(p_lob, TRUE);
        DBMS_LOB.WRITEAPPEND (p_lob,34,'start of log : '
        ||to_char(sysdate,'YYYY-MM-DD HH24:MI:SS') );
        sqlcmd:='insert into admin_log values(:1,:2,:3)';
        begin
        execute immediate sqlcmd using sysdate,v_key,p_lob ;
        commit ;
        exception when others then
         Raise_Application_Error(-20001, SQLCODE  || SQLERRM);
        end ;
   -- else
     -- dbms_output.put_line('v_key is set=' || v_key );
   end if ;
  /* get the lob locator in admin_log */
   begin
   sqlcmd:= 'select log from admin_log where key = :1 for update';
   execute immediate sqlcmd into v_log using v_key;
   exception
    when others then
       dbms_output.put_line('Erreur there is not rows with key='||v_key  );
       dbms_output.put_line(sqlcmd);
       return ;
   end ;
   /*  convert the varchar2 message into a temporary clob */
   dbms_lob.createtemporary(var_lob, TRUE);
   dbms_lob.writeappend(var_lob,length(var_out)+1,chr(10)||var_out) ;
   /* Append the temporary clob to the    lob locator */
   begin
     dbms_lob.append(v_log,var_lob);
     commit ;
   exception
      when others then
           dbms_output.put_line('Humm... lobby loggy polly humfy lob :'
                      ||' could not update the log');
   end ;
end;
END admin_tab_parts;
/
