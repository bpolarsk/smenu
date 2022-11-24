#!/bin/sh
# program : smenu_seg.ksh
# author  : B. Polarski
# Date    : 10 Oct 2006
# set -xv
ROWNUM=30
function xhelp
{
more <<EOF

        DBA_MVIEWS : addition columns info


          REFRESH_METHOD Default method used to refresh the materialized view (can be overridden through the API): 
          -------------
                    COMPLETE (C) - Materialized view is completely refreshed from the masters
                       FORCE (?) - Performs a fast refresh if possible, otherwise a complete refresh
                        FAST (F) - Performs an incremental refresh applying changes that correspond to changes 
                                   in the masters since the last refresh
                       NEVER (N) - User specified that Oracle should not refresh this materialized view
                 PCT_REFRESH (P) - Partition change track refresh method (11g)

         Notes :    You request a FORCE method (method => '?'), Oracle will choose the refresh method based 
                  on the following attempt order: log-based fast refresh, PCT refresh, and complete refresh. 
                  Alternatively, you can request the PCT method (method => 'P'), 
                  and Oracle will use the PCT method provided all PCT requirements are satisfied.
  
         BUILD_MODE         Indicates how the materialized view was populated during creation: 
         ----------
                        IMMEDIATE - Populated from the masters during creation
                         DEFERRED - Not populated during creation. Must be explicitly populated later by the user.
                         PREBUILT - Populated with an existing table during creation. 

         FAST_REFRESHABLE   Indicates whether the materialized view is eligible for incremental (fast) refresh. 
         ----------------   The DB calculates this value statically, based on the materialized view definition query: 

                             NO - Materialized view is not fast refreshable, and hence is complex
                        DIRLOAD - Fast refresh is supported only for direct loads
                            DML - Fast refresh is supported only for DML operations
                    DIRLOAD_DML - Fast refresh is supported for both direct loads and DML operations
             DIRLOAD_LIMITEDDML - Fast refresh is supported for direct loads and a subset of DML operations


      LAST_REFRESH_TYPE    Method used for the most recent refresh: 
      -----------------
                      COMPLETE - Most recent refresh was complete
                          FAST - Most recent refresh was fast (incremental)
                            NA - Materialized view has not yet been refreshed (for example, if it was created DEFERRED)

             STALENESS   Relationship between the contents of the materialized view and the contents of the materialized 
             ---------   view's masters: 

                         FRESH - Materialized view is a read-consistent view of the current state of its masters
                         STALE - Materialized view is out of date because one or more of its masters has changed. 
                                 If the materialized view was FRESH before it became STALE, then it is a read-consistent 
                                 view of a former state of its masters.
                      UNUSABLE - Materialized view is not a read-consistent view of its masters from any point in time
                       UNKNOWN - Oracle does not know whether the materialized view is in a read-consistent view 
                                 of its masters from any point in time (this is the case for materialized views created 
                                 on prebuilt tables)
                     UNDEFINED - Materialized view has remote masters. The concept of staleness is not defined for such 
                                 materialized views.

       AFTER_FAST_REFRESH    Specifies the staleness value that will occur if a fast refresh is applied to this 
       ------------------    materialized view. Its values are the same as for the STALENESS column, plus the value NA, 
                             which is used when fast refresh is not applicable to this materialized view. 

 
EOF
exit
}
# -----------------------------------------------------------------------------------
function help
{
      cat <<EOF

       Display all about materialized view

        mw -l   [-u <OWNER>]           # List all Materialised views, list for all user if -u is omitted
        mw -t -u <OWNER>  <MWNAME>  # List query text of MV
        mw -p -u <OWNER>            # List type of MV
        mw -lt -u <OWNER>           # List type of snapshot logs
        mw -lp -u <OWNER>           # List refresh of snapshot logs primary key
        mw -lr -u <OWNER>           # List refresh of snapshot logs rowid
        mw -ddl -u <OWNER> -n <MV_name> # get the MV ddl
        mw -r                       # list refresh group
        mw -c -u <owner>            # list refresh group members

      MV refresh:

        mw -lr -u <OWNER>            # List refresh schedule for materialized view
        mw -rf  <OWNER.MV_name> -m <f|c|?|a|p>   -deg <n>

                                    # Perform a refresh (f=fast,c=complete,?=force (see notes help), a=always, p=pct)
                                    # -rf can be alist, comma delimited of <owner.mview,..>
                                    # -deg : parallelism of refresh 

        mw -lprop                   # list default propagtor
        mw -xh                      # Extended help
        mw -mlog -n <mlog>          # List mlog meta data
        mw -reg                     # List mlog refresh status
        mw -ldate  [-mt <MASTER>]     # List mlog date
        mw -run                     # List Materialize view currently refreshing

EOF
exit
}
# -----------------------------------------------------------------------------------
function do_xpl
{
VAR=`echo $XPL |tr -d '"'`
if [ -n "$OWNER" ];then
  typeset -u S_USER
  S_USER=$OWNER
fi
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID

if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
sqlplus -s "$CONNECT_STRING" <<EOF
set serveroutput on size 999999
truncate table mv_capabilities_table;
execute dbms_mview.explain_mview('$VAR');
set pagesize 333 linesize 124
col CAPABILITY_NAME format a30
col RELATED_TEXT format a15
col MSGTXT format a70
SELECT capability_name, possible, related_text, msgtxt
FROM mv_capabilities_table;
EOF
}
# -----------------------------------------------------------------------------------
if [ -z "$1" ];then
   help
fi

typeset -u OWNER    
typeset -u MV_NAME    
TITTLE="Display MV info from DBA_MVIEWS"

while [ -n "$1" ]
do
  case "$1" in
        -rn) ROWNUM=$2 ; shift ;; 
        -rf) ACTION=DO_REFRESH ; MV_NAME=$2;shift
             TITTLE="Perfom a Mview refresh";; 
        -m)  METHOD=$2;shift;;
       -deg) DEG=$1;;
        -u ) OWNER=$2; shift;;
        -l ) ACTION=DEFAULT ;;
        -t ) ACTION=TEXT 
             MV_NAME=$2;shift;;
        -n ) MV_NAME=$2 ; shift ;;
      -ddl ) ACTION=GET_DDL  ;;
    -lprop ) ACTION=LPROP ; TITTLE="List default propagator";;
       -lt ) ACTION=LOG_TYPE ; TITTLE="List materialized view logs type";;
       -ldate ) ACTION=LDATE ; TITTLE="List key date" ;;
       -lp ) ACTION=LIST_REFRESH
             TITTLE="List materialized view logs (by pk) refresh time"
             FIELD=oldest_pk; TIT_FIELD="Oldest |Primary Key";;
       -lr ) ACTION=LOG_REFRESH
             TITTLE="List materialized view logs (by rowid) refresh time"
             FIELD=oldest;TIT_FIELD="Oldest Rowid" ;;
     -mlog ) ACTION=LIST_MLOG; TITTLE="List mlog" ;;
       -mt ) MASTER=$2;;
        -p ) ACTION=TYPE_MV 
             TITTLE="List type of materialized view ";;
        -r ) ACTION=LIST_REFRESH 
             TITTLE="List refresh schedule for materialized view ";;
        -reg ) ACTION=REGISTERED ;; 
        -run ) ACTION=RUNNING ; TITTLE="List session running a refresh";; 
        -c ) ACTION=LIST_REFRESH_MEMBER
             TITTLE="List refresh members for refresh group";;
        -l ) ACTION=SN_LOG 
             TITTLE="List statistics name and number";;
        -v ) SETXV="set -xv" ;;
       -xpl) ACTION=XPL_MV; shift ; XPL="$@" ;do_xpl ; exit ;;
       -xh ) xhelp;;
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
if [ "$ACTION" = "RUNNING" ];then
SQL="
  column owner format a15
column username format a15
column mview format a15
select o.owner, o.object_name mview, username, s.sid
from v\$lock l, dba_objects o, v\$session s
where o.object_id=l.id1 and
l.type='JI' and
l.lmode=6 and
s.sid=l.sid and
o.object_type='TABLE'
/
"
# ------------------------------
elif [ "$ACTION" = "LDATE" ];then
 if [ -n "$MASTER" ];then
      WHERE="where master=upper('$MASTER')"
 fi
SQL="
col master for a40
col OLDEST_PK for a19
col YOUNGEST for a19
select mowner||'.'|| master master, 
    to_char(oldest_pk,'YYYY-MM-DD hh24:mi:ss') OLDEST_PK,
    to_char(youngest,'YYYY-MM-DD hh24:mi:ss') YOUNGEST 
from sys.mlog\$ $WHERE
/
"
# ------------------------------
elif [ "$ACTION" = "REGISTERED" ];then
SQL="
col owner for a30
col name for a30
col snapshot_site for a30
col snapshot_id 9999999
col refresh_method for a20
set lines 190 pages 100
select owner,name ,snapshot_site, snapshot_id, refresh_method --, query_txt
 from 
  dba_registered_snapshots order by owner, name
/
"
# ------------------------------
elif [ "$ACTION" = "LIST_MLOG" ];then
SQL="
 set lines 210 pages 66

 col Master for a45
 col LOG_TABLE for a30 head 'Mat. view log' 
 col LOG_TRIGGER for a20
 col ROWIDS for a3 head 'Row|id' justify c
 col OBJECT_ID for a3 head 'Obj|id' justify c
 col FILTER_COLUMNS for a3 head 'Fil|col' justify c
 col SEQUENCE for a3 head 'Seq' justify c
 col INCLUDE_NEW_VALUES for a3 head 'New|val' justify c
 col PURGE_ASYNCHRONOUS for a3 head 'Pur|ged|Asy' justify c
 col PURGE_DEFERRED for a3 head 'Pur|ged|Def' justify c
 col PURGE_START for a19 head 'Purged start' justify c
 col PURGE_Interval for a12 head 'interval' justify c
 col LAST_PURGE_DATE for a19 head 'Last Purged' justify c
 col LAST_PURGE_STATUS for 99999 head 'status'
 col NUM_ROWS_PURGED for 99999999 head 'Purged| rows'  justify c
 col COMMIT_SCN_BASED for a3 head 'com|mit|Scn' justify c
 col STAGING_LOG for a3 head 'sta|ged|Log' justify c
 select 
     LOG_OWNER ||'.'|| MASTER as master, LOG_TABLE, 
     ROWIDS, PRIMARY_KEY pk, OBJECT_ID, FILTER_COLUMNS, SEQUENCE,
     INCLUDE_NEW_VALUES, PURGE_ASYNCHRONOUS, PURGE_DEFERRED, 
     to_char(LAST_PURGE_DATE,'YYYY-MM-DD HH24:MI:SS') LAST_PURGE_DATE,
     LAST_PURGE_STATUS, NUM_ROWS_PURGED, COMMIT_SCN_BASED, STAGING_LOG,
     to_char(PURGE_START,'YYYY-MM-DD HH24:MI:SS') PURGE_START,
     PURGE_INTERVAL,
     LOG_TRIGGER
 from dba_mview_logs
/
"
# ------------------------------
elif [ "$ACTION" = "GET_DDL" ];then
SQL="set pagesize 0 linesize 124 long 99999 head off
select dbms_metadata.get_ddl('MATERIALIZED_VIEW','$MV_NAME','$OWNER') from dual;"
# ------------------------------
elif [ "$ACTION" = "LPROP" ];then
SQL="prompt If none defined : exec DBMS_DEFER_SYS.REGISTER_PROPAGATOR(username =>'<owner>'); 
prompt
select username,userid,status,to_char(created,'DD-MM-YYYY HH24:MI') created from defpropagator; "
# ------------------------------
elif [ "$ACTION" = "DO_REFRESH" ];then
DEG=${DEG:-1}
SQL="execute dbms_mview.refresh(LIST=>'$MV_NAME',method=>'$METHOD',parallelism=>$DEG);"
echo "Doing $SQL"
# ------------------------------
elif [ "$ACTION" = "LIST_REFRESH_MEMBER" ];then
SQL="col owner format a15
col name format a29
col rname format a11
col interval format a15
col fdate format a18 head 'Date'
col rbls format a10
select owner,name,rname,IMPLICIT_DESTROY IP,REFRESH_AFTER_ERRORS RE,ROLLBACK_SEG RBLS,
       JOB,to_char(NEXT_DATE,'DD-MM-YY HH24:MI:SS') fdate,interval,broken BRK	
       from dba_refresh_children $WHERE order by owner,rname ; "

# ------------------------------
elif [ "$ACTION" = "LIST_REFRESH" ];then
SQL="col interval format a20
col purge_option head 'Purge|option'
col broken format a4 head 'brok'
col job format 99999
select rowner owner,rname name,IMPLICIT_DESTROY,PUSH_DEFERRED_RPC,REFRESH_AFTER_ERRORS,
    JOB,to_char(NEXT_DATE,'DD-MM-YY HH24:MI:SS')next_run,INTERVAL,broken,
    decode(purge_option,1,'Quick',2,'Precise','Unknown')purge_option
   from DBA_REFRESH;
"
# ------------------------------
elif [ "$ACTION" = "LOG_REFRESH" ];then
SQL="select m.mowner||'.'|| m.master tname,
         m.log Logname, to_char(m.youngest,'DD-MM-YY HH24:MI:SS')Youngest ,
         s.snapid , s.snaptime , to_char($FIELD,'DD-MM-YY HH24:MI:SS') Oldest
  from sys.mlog\$ m, sys.slog\$ s
  WHERE s.mowner (+) = m.mowner
  and s.master (+) = m.master;
"
# ------------------------------
elif [ "$ACTION" = "LOG_TYPE" ];then
SQL="col log_trigger format a10
col master format a38
col log_table format a28
col include_new_values head 'Inc|new|val'
col log_trigger head 'Log|trigger'
select log_owner||'.'||master master,log_table,log_trigger,rowids,primary_key,include_new_values,
       to_char(CURRENT_SNAPSHOTS,'DD-MM-YY HH24:MI:SS') snap_date,SNAPSHOT_ID snap_id from DBA_SNAPSHOT_LOGS;
"
# ------------------------------
elif [ "$ACTION" = "TYPE_MV" ];then
SQL="col name format a40
col refresh_method format a20 head 'Refresh method'
select owner, name, refresh_method from dba_snapshots $WHERE; "

# ------------------------------
elif [ "$ACTION" = "TEXT" ];then
if [ -n "$WHERE" ];then
    WHERE="$WHERE and mview_name = '$MV_NAME'"
else
   WHERE="where mview_name = '$MV_NAME'"
fi
SQL="set long 32000
col query format a88
col mname format a35
select owner||'.'||mview_name mname  ,query from dba_mviews $WHERE;"

# ------------------------------
elif [ "$ACTION" = "DEFAULT" ];then
SQL="select owner,mview_name mname ,updatable,refresh_mode,refresh_method,
    decode(fast_refreshable,'DIRLOAD_DML','DIR_DML','DIRLOAD_LIMITEDDML' ,'DR_LMDML',fast_refreshable) fr
    ,last_refresh_type, to_date(last_refresh_date,'DD-MM-YY HH24:MI:SS') lrd,staleness,
     to_char(stale_since,'DD-MM-YY HH24:MI:SS') stale_since , to_char(LAST_REFRESH_END_TIME,'DD-MM-YY HH24:MI:SS')last_time
    from dba_mviews $WHERE;
"
# ------------------------------
fi
$SETXV

sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '      'Page:' format 999 sql.pno skip 1
column nline newline
set pause offset pagesize 66 linesize 80 heading off embedded on termout on verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline , '$TITTLE (help : mw -h)  ' from sys.dual
/
set linesize 194 head on pagesize 66
col MNAME format a40 head "Name"
col TNAME format a40 head "Table Name"
col owner format a16 head "Owner"
col updatable format a1 head "U|P|D"
col refresh_method format a8 head "Refrh|method"
col refresh_mode format a6 head "Refrh| Mode"
col fr format a8 head "  Fast|Refresh"
col last_refresh_type format a8 head "Last|refresh|type" justify c
col lrd format a17 head "Last|refresh|date" justify c
col staleness format a14
column Youngest format a18
column "Last Refreshed" format a18
column "Last Refreshed" heading "Last|Refreshed"
column "MView ID" format 99999
column "MView ID" heading "Mview|ID"
column Oldest format a18 head "$TIT_FIELD"
col logname for a30

$BREAK
$SQL
EOF
