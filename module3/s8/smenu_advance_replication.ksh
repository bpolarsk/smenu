#!/bin/sh
# program : smenu_advance_replication.ksh
# author  : B. Polarski
# Date    : 16 Oct 2006

function conflict_resolution
{
more <<EOF

                     Setup conflict resolutions

   If you don't use synchronious replication (secure but very slow) you need to use to use the Oracle conflict resolution
   methods to deal with update conflicts. You must designate the column over which your method will apply when you define 
   your conflict resolution method.

      The type of automated conflict resolution method comprise :

          1) Overwrite or discard conflict resolution methods
          2) Minimum and Maximum Conflict Resolution Methods
          3) Timestamp Conflict Resolution Methods
          4) Additive and Average Conflict Resolution Methods
          5) Priority Groups Conflict Resolution Methods
          6) Site Priority Conflict Resolution Methods
          7) Uniqueness Conflicts Resolution Methods
          8) Avoidance Methods for Delete Conflicts


   Package used :

                DBMS_REPCAT.SUSPEND_MASTER_ACTIVITY           # 1 2
                DBMS_REPCAT.MAKE_COLUMN_GROUP                 # 1
               |DBMS_REPCAT.ADD_UPDATE_RESOLUTION             # 1
 same level -->|DBMS_REPCAT.ADD_DELETE_RESOLUTION             #
               |DBMS_REPCAT.ADD_UNIQUE_RESOLUTION             #
                DBMS_REPCAT.ALTER_MASTER_REPOBJECT            #
                  DBMS_REPCAT.EXECUTE_DDL                     #
                  DBMS_REPCAT.DEFINE_PRIORITY_GROUP           #
                  DBMS_REPCAT.DEFINE_SITE_PRIORITY            #
                  DBMS_REPCAT.ADD_SITE_PRIORITY_SITE          #
                  DBMS_REPCAT.DO_DEFERRED_REPCAT_ADMIN        #
                DBMS_REPCAT.GENERATE_REPLICATION_SUPPORT      # 1
                DBMS_REPCAT.RESUME_MASTER_ACTIVITY            # 1

   
   details: connect as repadmin/[passwd]
 
 2) We give the reason of an exec only if it is new, otherwise see point 1

       exec DBMS_REPCAT.SUSPEND_MASTER_ACTIVITY( gname => 'hr_repg');
       exec DBMS_REPCAT.MAKE_COLUMN_GROUP ( sname => 'hr', oname => 'jobs', column_group => 'job_minsal_cg',
                                            list_of_column_names => 'min_salary');

       exec DBMS_REPCAT.ADD_UPDATE_RESOLUTION ( sname => 'hr', oname => 'jobs', column_group => 'job_minsal_cg',
                                                sequence_no => 1, method => 'MINIMUM', 
                                                parameter_column_name => 'min_salary');

 1) Quiesce the master group that contains the table to which you want to apply the conflict resolution 

       SQL> exec DBMS_REPCAT.SUSPEND_MASTER_ACTIVITY( gname => 'hr_repg');

    All Oracle conflict resolution methods are based on logical column groupings called column groups    

       SQL> exec DBMS_REPCAT.MAKE_COLUMN_GROUP (sname => 'hr', oname => 'departments', column_group => 'dep_cg',
                                               list_of_column_names => 'manager_id,location_id');

    Define the conflict resolution method:Type of conflict resolution routine that you want to create.
    possible values are for :
               -update conflict     : "minimum, maximum, latest timestamp, earliest timestamp, additive, average,
                                       priority group, site priority, overwrite, discard, [function name]"
               -uniqueness conflict : "append site name, append sequence,discard"
               -delete conflict     :  -  # There are no built-in (Oracle supplied) methods for delete conflicts

       SQL> exec DBMS_REPCAT.ADD_UPDATE_RESOLUTION ( sname => 'hr', oname => 'departments', column_group => 'dep_cg',
                                                sequence_no => 1, method => 'DISCARD', 
                                                parameter_column_name => 'manager_id,location_id');

    Regenerate replication support for the table that received the conflict resolution method
 
       SQL> exec DBMS_REPCAT.GENERATE_REPLICATION_SUPPORT ( sname => 'hr', oname => 'departments', type => 'TABLE',
                                                      min_communication => TRUE); 
    Resume master activity after replication support has been regenerated.

      SQL> exec DBMS_REPCAT.RESUME_MASTER_ACTIVITY ( gname => 'hr_repg');


  





more <<EOF
EOF
}
function rep_untrusted
{
more <<EOF

                     Setup a UNTRUSTED replication using materialized views

   With the untrusted security model, the proxy snapshot administrator and
  receiver are only granted the privileges required to work with specific
  master groups. This is the recommended configuration for updateable
  snapshot replication systems, because it protects data that is not common
  to snapshot sites from being accessed by other snapshot sites. Customers
  may wish to use this architecture if they have a replication configuration
  similar to :

    Master Site 1                    Master Site 2 
    --------------        -----------------------------------
    Master Group A <----> Master Group A       Master Group B
                            ^     ^                  ^
                            |     |                  |
                +-----------+     |                  |
                |                 |                  |
         Snapshot Site 1  Snapshot Site 2      Snapshot Site 3

a) Master Site users and privileges
   =================================
   procedure to setup advance replication:
   .......................................
    CONNECT system/manager
    CREATE USER repadmin IDENTIFIED BY repadmin DEFAULT TABLESPACE REPADMIN_TBS TEMPORARY TABLESPACE temp;
    GRANT connect, resource TO repadmin;
    EXECUTE dbms_repcat_admin.grant_admin_any_schema('repadmin');
    GRANT comment any table TO repadmin;
    GRANT lock any table TO repadmin;
    GRANT select any dictionary to repadmin ;


EOF
}
# -------------------------------------------------------------------------------------------
function multi_master
{

more <<EOF

                    Setup MULTI-MASTER replication using materialized views

    For each master, follow section a) from trusted replication:
    ............................................................
   
  Remarks: 
   1) Here we don't had support for materialized view site. so line 7 and 9 are removed.
   2) on each master site you add the db link link and scheduled push
 
          Connect as system at master site
          create replication administrator
          grant privilege to replication administrator
          register propagator
          register receiver
          schedule purge at master site
          create public database link
          create schedule push             # see simulate continuous replication below
          create master group
                 add objects to master group
                 add additional master site
                     configure conflict resolution methods
          generate replication support
          resume replication

  Create database link and schedule push:
  .......................................
  on master 1
      CREATE PUBLIC DATABASE LINK master2.world USING 'master1.world';
      CREATE DATABASE LINK  master2.world CONNECT TO repadmin IDENTIFIED BY repadmin;
      Execute DBMS_DEFER_SYS.SCHEDULE_PUSH(destination => 'master2.world', interval => 'SYSDATE + (1/144)',
                                          next_date => SYSDATE, parallelism => 1, execution_seconds => 1500,
                                          delay_seconds => 1200);

  on master 2
      CREATE PUBLIC DATABASE LINK master1.world USING 'master1.world';
      CREATE DATABASE LINK  master1.world CONNECT TO repadmin IDENTIFIED BY repadmin;
      Execute DBMS_DEFER_SYS.SCHEDULE_PUSH(destination => 'master1.world', interval => 'SYSDATE + (1/144)',
                                          next_date => SYSDATE, parallelism => 1, execution_seconds => 1500,
                                          delay_seconds => 1200);


  Simulate continuous replication:
  ................................
  You can configure a scheduled link to simulate continuous, real-time replication in  DBMS_DEFER_SYS.SCHEDULE_PUSH 
  by specifying a value for delays_seconds > interval

          delay_seconds 1200            # 20 minutes. spefiy how long the queue will be active
          interval  = sysdate + (144)   # 10 minutes
          parallelism 1 or higher       # this is not serial! Each parallel process that is used when pushing the deferred 
                                        # transaction queue is not available for other parallel activities until 
                                        # the propagation job is complete.
          execution_seconds 1500        #


  With this configuration, Oracle continues to push transactions that enter the deferred transaction queue for the duration 
  of the entire interval. If the deferred transaction queue has no transactions to propagate for the amount of time 
  specified by the delay_seconds parameter, then Oracle releases the resources used by the job and starts fresh when 
  the next job queue process becomes available.

  If you are using serial propagation by setting the parallelism parameter to 0 (zero), then you can simulate continuous 
  push by reducing the settings of the delay_seconds and interval parameters. However, if you are using serial propagation, 
  simulating continuous push is costly when the push job must initiate often.

  The following is an example that simulates continual pushes:

   excute DBMS_DEFER_SYS.SCHEDULE_PUSH (destination => 'master1.world', interval => 'SYSDATE + (1/144)',
                                 next_date => SYSDATE, parallelism => 1, execution_seconds => 1500, delay_seconds => 1200);

 
  Create master group:
  ....................
  You create the master group in the schema that exist in all master site, usually it is 'repadmin':

      execute DBMS_REPCAT.CREATE_MASTER_REPGROUP ( gname => 'hr_repg');

  Add an object to your master group:
  ...................................
  To add on object we use CREATE_MASTER_REPOBJECT and type is usually TABLE or INDEX.

     exec DBMS_REPCAT.CREATE_MASTER_REPOBJECT ( gname => 'hr_repg', type => 'TABLE', oname => 'countries',
                                                sname => 'hr', use_existing_object => TRUE, copy_rows => FALSE);
  Add a master site:
  ..................
     exec DBMS_REPCAT.ADD_MASTER_DATABASE ( gname => 'hr_repg', master => 'orc2.world', use_existing_objects => TRUE,
                                            copy_rows => FALSE, propagation_mode => 'ASYNCHRONOUS');

    Note: When adding a master site to a master group that contains tables with circular dependencies or a table that 
          contains a self-referential constraint, you must precreate the table definitions and manually load the data at 
          the new master site. The following is an example of a circular dependency: Table A has a foreign key constraint 
          on table B, and table B has a foreign key constraint on table A. 

  Generate replication support.
  .............................
  For each obect we need a support command:
     exec DBMS_REPCAT.GENERATE_REPLICATION_SUPPORT ( sname => 'hr', oname => 'countries', type => 'TABLE',
                                                     min_communication => TRUE); 



EOF
}

function rep_trusted
{
more <<EOF

                     Setup a TRUSTED replication using materialized views

  With the trusted security model, the proxy snapshot administrator and
  receiver are  granted all privileges required to work with master groups:

                              Master Site 
        --------------------------------------------------------
                           Master Group A   
                            ^     ^    ^
                            |     |    |
                +-----------+     |    +-------------+ 
                |                 |                  |
         Snapshot Site 1  Snapshot Site 2      Snapshot Site 3


  Forewords notes to help further:
 
   Dblink are only created from client site to master site. It is the client site that connect to the master
   site to check and fetch new data. The connection on master site is done by the client snapshot refresher
   which connects to a corresponding account on master site, named proxy refresher.
 

a) Master Site users and privileges
   =================================
   procedure to setup advance replication:
  
     List of packages used in this procedure: 
     ----------------------------------------
        dbms_repcat_admin.grant_admin_any_schema
        dbms_repcat_admin.register_user_repgroup
        DBMS_DEFER_SYS.SCHEDULE_PURGE 
        DBMS_DEFER_SYS.SCHEDULE_PUSH

     Steps:
     ------

          Connect as system at master site
          create replication administrator
          grant privilege to replication administrator
          register propagator
          register receiver
          schedule purge at master site
          add support for materialized view site
              create proxy master site users

  Create replication administrator user:
  ......................................

    CONNECT system/manager
    CREATE USER repadmin IDENTIFIED BY repadmin DEFAULT TABLESPACE REPADMIN_TBS TEMPORARY TABLESPACE temp;
    GRANT connect, resource TO repadmin;
    EXECUTE dbms_repcat_admin.grant_admin_any_schema('repadmin');
    GRANT comment any table TO repadmin;
    GRANT lock any table TO repadmin;
    GRANT select any dictionary to repadmin ;

 Create schedule purge:
 ......................

  In order to keep the size of the deferred transaction queue in check, you should purge successfully completed 
  deferred transactions.

    exec  DBMS_DEFER_SYS.SCHEDULE_PURGE ( next_date => SYSDATE, interval => 'SYSDATE + 1/24', delay_seconds => 0);

 Create proxy receiver/administrator/refresher:
 ..............................................
  It is usual to have a single user who performs the roles : proxy snapshot administrator, receiver and proxy refresher 
  at the master site on behalf of ALL snapshot sites. The proxy master site users correspond to users at the materialized 
  view site

    CREATE USER proxy_mviewadmin IDENTIFIED BY proxy_mviewadmin DEFAULT TABLESPACE repadmin_tbs TEMPORARY TABLESPACE temp ;
    grant SELECT_CATALOG_ROLE to proxy_mviewadminst_of_gnames =>  NULL);;


 Grant snapshot administrator:
 .............................
  The proxy snapshot administrator is used when creating snapshot replication groups and objects at the snapshot site:

    exec dbms_repcat_admin.register_user_repgroup( username => 'proxy_mviewadmin',
                                                   privilege_type => 'proxy_snapadmin',
                                                   list_of_gnames =>  NULL);
 Grant master receiver:
 ......................
  The receiver is responsible for applying transactions forwarded from the snapshot site by the propagator 
  to the master site

     exec dbms_repcat_admin.register_user_repgroup( username =>       'proxy_mviewadmin',
                                                    privilege_type => 'receiver',
                                                    list_of_gnames =>  NULL);

 Grants Proxy refresher privileges:
 ..................................
  The proxy refresher allows the snapshot site refresher to see data in the master tables and refresh the snapshots.
  This user is just the correspondant of the remote client proxy

      GRANT create session TO proxy_mviewadmin;
      GRANT select any table TO proxy_mviewadmin;

 Schema Owner(s) (referred to here as REPDBA)
 ...........................................
  This user or these users are usually responsible for the day to day administration of the schema that replication 
  objects are created upon. A schema of the same name must exist at each snapshot site that will create a snapshot upon
  one of its tables. 


b) Snapshot Site users and privileges
   ==================================

  steps:

         Connect as system
         create materialized view site users 
         create database link to master
         schedule purge at materialized view site
         schedule push at materialiezed view site
         create proxy user
  
 Create Snapshot administrator / Propagator / Refresher (SNAPADMIN):
 ...................................................................

    CREATE USER snapadmin IDENTIFIED BY snapadmin DEFAULT TABLESPACE repadmin_tbs TEMPORARY TABLESPACE temp ;

 Grant Snapshot administrator privileges:
 .........................................
    The propagator user is used to push deferred transactions queued at 
    the snapshot site through updates to the snapshots, to the master site.

      EXECUTE dbms_repcat_admin.grant_admin_any_schema('snapadmin');
      GRANT comment any table TO snapadmin;
      GRANT lock any table TO snapadmin;

 Grant Propagator privileges:
 ............................
   The propagator user is used to push deferred transactions queued at 
   the snapshot site through updates to the snapshots, to the master site.  
   
      EXECUTE DBMS_DEFER_SYS.REGISTER_PROPAGATOR('snapadmin');   

 Grant refresher privilege:
 ..........................
   The refresher user is used to pull changes made at the master site down
   to the snapshot site as part of a snapshot / snapshot group refresh,

      GRANT create any snapshot TO snapadmin;
      GRANT alter any snapshot TO snapadmin;

   for each schema at the master site that will have an updateable snapshot
   created against it, a schema of the same name must exist at the snapshot site. 

 Create public db link:
 ......................

   CREATE PUBLIC DATABASE LINK target.world USING 'target.world';
   CREATE DATABASE LINK target.world 
         CONNECT TO proxy_mviewadmin IDENTIFIED BY proxy_mviewadmin;


 Create schedule push:
 .....................

     Execute DBMS_DEFER_SYS.SCHEDULE_PUSH(destination => 'master.world', interval => 'SYSDATE + (1/144)',
                                          next_date => SYSDATE, parallelism => 1, execution_seconds => 1500,
                                          delay_seconds => 1200);

 Create schedule purge:
 ......................

  In order to keep the size of the deferred transaction queue in check, you should purge successfully completed 
  deferred transactions.

    exec  DBMS_DEFER_SYS.SCHEDULE_PURGE ( next_date => SYSDATE, interval => 'SYSDATE + 1/24', delay_seconds => 0);
EOF
exit
}
# -----------------------------------------------------------------------------------
function help
{
      cat <<EOF

       All about advance replication using Materialized view:

       Extended helps:
           rep  -h1                  # Extended help, describe set up   TRUSTED replication
           rep  -h2                  # Extended help, describe set up UNTRUSTED replication
           rep  -h3                  # Extended help, describe set up MULTI-MASTER  replication

       Commands:
 
           rep -u <OWNER> -gra            # Grant the dbms_repcat_admin.grant_admin_any_schema to -u <OWNER>
           rep -u <OWNER> -reg <px|rec>   # Register user repgroup px=proxy_snapadmin, rec=receiver
           rep -sched_purge               # Set the schedule purge (default to 1/day)
                -delay <secs>           # delay in seconds
                -intrv <delay>          # can be string quoted like : 'sysdate + 1/1440' 
                -pm_quick               # use quick method for purge
                -pm_precise             # use precise method for purge
          rep -sched_push               # Create the schedule push to upload/retriev new data from master
                -delay <secs> -intrv <interval>
                -t <TARGET> -par <deg> # par=parallel degree TARGET=db_link name 
                -sec <seconds>         # -sec number of seconds the queue scanning remains active
                                        
       parameters:
EOF
exit
}
# -----------------------------------------------------------------------------------
typeset -u OWNER    
TITTLE="Display MV info from DBA_MVIEWS"
if [ -z "$1" ];then
   help
fi

while [ -n "$1" ]
do
  case "$1" in
            -rn) ROWNUM=$2 ; shift ;; 
           -h1 ) rep_trusted ; exit ;;
           -h2 ) rep_untrusted ; exit ;;
           -h3 ) multi_master ; exit ;;
           -h4 ) conflict_resolution ; exit ;;
          -gra ) ACTION=GR_AD_OPT;;
          -reg ) if [ "$2" = "rec" ];then
                      ACTION=REGISTER_USER_GROUP_REC
                  else
                      ACTION=REGISTER_USER_GROUP_PROX
                 fi
                 shift;;
  -sched_push  ) ACTION=SCHED_PUSH ;;
          -par ) PARALLEL=$2 ; shift ;;
          -sec ) EXEC_IN_SECS=$2;shift ;;
            -t ) TARGET=$2;shift ;;
  -sched_purge ) ACTION=SCHED_PURGE ;;
     -pm_quick ) METHOD=dbms_defer_sys.purge_method_quick;;
   -pm_precise ) METHOD=dbms_defer_sys.purge_method_precise;;
        -delay ) DELAY=$2 ; shift ;;
        -intrv ) INTERVAL="$2";shift;;
            -u ) OWNER=$2 ; shift ;;
             * ) "echo $@" ; help ;;
  esac
  shift
done

if [ -n "$OWNER"  ];then
     WHERE=" WHERE owner = '$OWNER'"
fi

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID

if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# ------------------------------
#  
# ------------------------------

if [ "$ACTION" = "GET_DDL" ];then
SQL="set pagesize 0 linesize 124 long 99999 head off"
# +++++++++++++++++++++++++++++++++++
# create schedule push
# +++++++++++++++++++++++++++++++++++
elif [ "$ACTION" = "SCHED_PUSH" ];then
  DELAY=${DELAY:-1200}
  EXEC_IN_SECS=${EXE_IN_SEC:-1500}
  INTERVAL=${INTERVAL:-'SYSDATE + 1/24'}
  PARALLEL=${PARALLEL:-1}
  SQL="prompt exec DBMS_DEFER_SYS.SCHEDULE_PUSH(destination => '$TARGET', interval => '$INTERVAL', next_date => SYSDATE, parallelism => $PARALLEL, execution_seconds => $EXEC_IN_SECS, delay_seconds => $DELAY)
   exec DBMS_DEFER_SYS.SCHEDULE_PUSH(destination => '$TARGET', interval => '$INTERVAL', next_date => SYSDATE, parallelism => $PARALLEL, execution_seconds => $EXEC_IN_SECS, delay_seconds => $DELAY); "
# +++++++++++++++++++++++++++++++++++
# create schedule purge
# +++++++++++++++++++++++++++++++++++
elif [ "$ACTION" = "SCHED_PURGE" ];then
  DELAY=${DELAY:-0}
  INTERVAL=${INTERVAL:-'SYSDATE + 1/24'}
  METHOD=${METHOD:-dbms_defer_sys.purge_method_quick}
SQL="prompt exec  DBMS_DEFER_SYS.SCHEDULE_PURGE ( next_date => SYSDATE, interval => '$INTERVAL', delay_seconds => $DELAY, purge_method=>$METHOD)
exec  DBMS_DEFER_SYS.SCHEDULE_PURGE ( next_date => SYSDATE, interval => '$INTERVAL', delay_seconds => $DELAY, purge_method=>$METHOD);"
# +++++++++++++++++++++++++++++++++++
# Register user repgroup for receiver
# +++++++++++++++++++++++++++++++++++
elif [ "$ACTION" = "REGISTER_USER_GROUP_REC" ];then
SQL=" prompt exec dbms_repcat_admin.register_user_repgroup( username => '$OWNER',privilege_type => 'receiver',list_of_gnames =>  NULL)
exec dbms_repcat_admin.register_user_repgroup( username => '$OWNER',privilege_type => 'receiver',list_of_gnames =>  NULL);"

# +++++++++++++++++++++++++++++++
# Register user repgroup for proxy
# +++++++++++++++++++++++++++++++
elif [ "$ACTION" = "REGISTER_USER_GROUP_PROX" ];then
SQL=" prompt exec dbms_repcat_admin.register_user_repgroup( username => '$OWNER',privilege_type => 'proxy_snapadmin',list_of_gnames =>  NULL)
exec dbms_repcat_admin.register_user_repgroup( username => '$OWNER',privilege_type => 'proxy_snapadmin',list_of_gnames =>  NULL);"

# +++++++++++++++++++++++++++++++
# Grant admin on any schema 
# +++++++++++++++++++++++++++++++
elif [ "$ACTION" = "GR_AD_OPT" ];then
TITTLE="Grant admin on $OWNER"
SQL="prompt exec dbms_repcat_admin.grant_admin_any_schema('$OWNER')
exec dbms_repcat_admin.grant_admin_any_schema('$OWNER');"
elif [ "$ACTION" = "LPROP" ];then
SQL="prompt If none defined : exec DBMS_DEFER_SYS.REGISTER_PROPAGATOR(username =>'<owner>'); 
prompt"
elif [ "$ACTION" = "DO_REFRESH" ];then
 :
fi
$SETXV

sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '      'Page:' format 999 sql.pno skip 1
column nline newline
set pause offset pagesize 66 linesize 80 heading off embedded on termout on verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline , '$TITTLE (help : mw -h)  ' from sys.dual
/
set linesize 124 head on pagesize 66
col MNAME format a28 head "Name"

$BREAK
$SQL
EOF
