#!/bin/sh
#  set -xv
# author  : B. Polarski
# program : smenu_stream_resync.ksh
# date    : 28 Jully 2009

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
# -------------------------------------------------------------------------------------
function get_q_fowner
{
  var=`sqlplus "$CONNECT_STRING"<<EOF
 set head off pagesize 0 feed off verify off
 select owner from dba_queues where name = upper('$par1' )
        and owner not in ( 'SYS','SYSTEM','WMSYS');
EOF`
ret=`echo $var | tr -d '\n' | awk '{print $1}'`
echo $ret
}
# -------------------------------------------------------------------------------------
function help
{

  cat <<EOF

     rsy  -cpt    [-t <list_tables>] [-so<source owner>] [-tn <target table>] [-to <target owner>] [-x] [-sq ] [-v ] [-w <"add to clause">][-cn <capture>]
     rsy  -cpt_s  [-t <list_tables>] [-so<source owner>] [-tn <target table>] [-to <target owner>] [-x] [-sq ] [-v ] [-w <"add to clause">][-cn <capture>]
     rsy  -cpt_t  [-t <list_tables>] [-so<source owner>] [-tn <target table>] [-to <target owner>] [-x] [-sq ] [-v ] [-w <"add to clause">][-cn <capture>]
     rsy  -source [-t <list_tables>] [-so<source owner>] [-tn <target table>] [-to <target owner>] [-x] [-sq ] [-v ] [-w <"add to clause">][-cn <capture>]
     rsy  -target [-t <list_tables>] [-so<source owner>] [-tn <target table>] [-to <target owner>] [-x] [-sq ] [-v ] [-w <"add to clause">][-cn <capture>]
     rsy  -both   [-t <list_tables>] [-so<source owner>] [-tn <target table>] [-to <target owner>] [-x] [-sq ] [-v ] [-w <"add to clause">][-cn <capture>]
     rsy  -glt -so <source_owner>

           -x : Effectively perform the resync, default is not to do it
          -sq : Show the SQL generated for the resync
          -cn : Restrict to a capture name
         -cpt : count differences on both sites
       -cpt_s : Show count of rows that are on target site but not on source site
       -cpt_t : Show count of rows that are on source site but not on target site
           -t : comma separated list of tables or a single table
          -to : a single target table name. Default is same single source table name. Use this when table change name
          -so : Source owner, if not given then all table that matchs table_name will be considered
          -to : target owner, if not given default to Source owner
         -glt : Generate list of table, comma separated to be used by -cpt
           -w : Optional argument to add to the where clause to refine count or resync conditions. the predicate to add to the where cluase
                should be encapsulated into doubles quotes. the first 'and' is added by default. check with option -sq first to view the
                sql generated, before issuing the -x that execute this command
           -v : Show the procedure to generated the SQL's

         -adv : some advices and examples on 'rsy'


    To list counts diff of a list of tables mad of table EMP and DEP for same schema on both sites:

        rsy -cpt -t EMP,DEP -u SCOTT
EOF

exit
}
# -------------------------------------------------------------------------------------
function  advice_usage
{

        more <<EOF

   How to use 'rsy' to display all differences for a whole schema
   how to make it run and produce report from the log.

   Unless you intentd to use 'rsy' with a giant list of tables, use 'rsy' in order to split the load into the workers.
   For that you need to feed each workers with differents list of tables and to produce the list of tables do:

       rsy -u <schema> -glt > tbl_list.txt

   tbl_list.txt will be a long list of table_name comma separated, it will look like :

"ACCEPTOR,ACC_CALENDAR,ACC_CNTRCT,ACC_CNTRCT_ITEM,ACC_CNTRCT_USG,...."

   Next edit tbl_list.txt and remove tables that are too big (in rows), you will process then later alone.
   Alternatively you may split this file in many small input files, each one will be the source for a 'worker'
   that you may launch on separate sessions.


   get the full path of 'rsy':

   alias rsy
   >  alias rsy='$SBIN/module3/s8/smenu_stream_resync.ksh'

   now create the script for the worker:

   cat tbl_list.txt | tr ',' '\n' |while read a
   do
     echo "$SBIN/module3/s8/smenu_stream_resync.ksh -t $a -cpt -so CUSTOMER_MAIN"
   done > doit.ksh

Content should be:
rsy -t ACCEPTOR -cpt -so CUSTOMER_MAIN
rsy  -t ACC_CALENDAR -cpt -so CUSTOMER_MAIN
rsy -t ACC_CNTRCT -cpt -so CUSTOMER_MAIN
rsy -t ACC_CNTRCT_ITEM -cpt -so CUSTOMER_MAIN
rsy -t ACC_CNTRCT_USG -cpt -so CUSTOMER_MAIN
rsy -t ACC_LIM -cpt -so CUSTOMER_MAIN
rsy -t ACC_LIM_OR1 -cpt -so CUSTOMER_MAIN

and you can split doit.ksh into many smaller files to run in parallel or you can launch it as it:

    ./doit.ksh > doit.log

   Ath the end of the run doit.log contain info like :


Date              -  Wednesday 29th July      2009  16:18:24

--> table=CUSTOMER_MAIN.ACCEPTOR
--> Pk cols=ACCEPTOR_ID len=11
--> capture used is : CAPTURE_CUSTOMER_MAIN
--> Queue name      : STRMADMIN.CUSTOMER_MAIN_CAP_Q
--> Dblink          : MYDOMAIN.COM

--> Missing in Local   : 1
--> Missing in target  : 0

PL/SQL procedure successfully completed.

Date              -  Wednesday 29th July      2009  16:18:31

--> table=CUSTOMER_MAIN.ACC_CALENDAR
--> Pk cols=CALENDAR_ID len=11
--> capture used is : CAPTURE_CUSTOMER_MAIN
--> Queue name      : STRMADMIN.CUSTOMER_MAIN_CAP_Q
--> Dblink          : MYDOMAIN.COM

--> Missing in Local   : 0
--> Missing in target  : 522

PL/SQL procedure successfully completed.
"

   You can extract all info from 'doit.log' using the following grep :

   >  cat doit.log | grep -e table= -e "Missing"  -e  skip | grep -v ": 0"

--> table=CUSTOMER_MAIN.SO_RULE
--> table=CUSTOMER_MAIN.SSE_B0_CT_JS
--> table=CUSTOMER_MAIN.SSE_BNT_STATIC_KEYS
--> no pk found --> skipping this table
--> table=CUSTOMER_MAIN.SSE_CONFIG
--> table=CUSTOMER_MAIN.TREE_NODE
--> Missing in Local   : 296
--> table=CUSTOMER_MAIN.TXN_ORIGIN

EOF
}
# -------------------------------------------------------------------------------------
function do_execute
{
if [ -n "$SETXV" ];then
   echo "$SQL"
fi

sqlplus -s "$CONNECT_STRING" <<EOF
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS')
 --      ,  'Username          -  '||USER  nline, '$TTITLE (aq -h for help)' nline
from sys.dual
/
set head on

$BREAK
set linesize 125

$SQL
EOF
}
# -------------------------------------------------------------------------------------
#                    Main
# -------------------------------------------------------------------------------------
if [ -z "$1" ];then
   help; exit
fi

# ............ some default values and settings: .................
typeset -u ftable_list
typeset -u ftable
typeset -u ftarget_table    # target table, only one table can be given
typeset -u fsrc_owner
typeset -u fowner           # this is the streams owner, usually strmadmin
typeset -u ftarget_owner    # target owner
typeset -u EXECUTE
EXECUTE=FALSE

while [ -n "$1" ]
do
  case "$1" in
       -t )  ftable_list=$2; shift;;
      -cn ) CAPTURE_NAME=$2 ; shift ;;
     -cpt ) CHOICE="COUNT_DIF" ;;
   -cpt_s ) CHOICE="COUNT_SOURCE" ;;
   -cpt_t ) CHOICE="COUNT_TARGET" ;;
  -source ) CHOICE="RESYNC_SOURCE" ;;
  -target ) CHOICE="RESYNC_TARGET" ;;
    -both ) CHOICE="BOTH" ;;
     -glt ) CHOICE="GENERATE_LST_TBL" ;;
      -so ) fsrc_owner=$2 ; shift ;;
      -to ) ftarget_owner=$2 ; shift ;;
      -tn ) ftarget_table=$2 ; shift ;;
       -w ) PREDICATE="$2" ; shift ;;
       -v ) VERBOSE=TRUE;;
      -sq ) SHOW_SQL=true;;   # lower case
       -x ) EXECUTE=TRUE;;
     -adv ) advice_usage; exit ;;
        * ) echo "Invalid argument $1"
            help ;;
 esac
 shift
done
   if [ -n "$STRMADMIN" ];then
      if [ -f "${GET_PASSWD}" ];then
         . $SBIN/scripts/passwd.env
         . ${GET_PASSWD} $S_USER $ORACLE_SID
      else
           # stand alone version of script
           CONNECT_STRING="/ as sysdba"
      fi
      if [  "x-$CONNECT_STRING" = "x-" ];then
         echo "could no get a the password of $S_USER"
         exit 0
      fi
      #echo "No queue owner given, fetching first username from dba_streams_administrator"
      var=`sqlplus -s "$CONNECT_STRING"<<EOF
      set head off pagesize 0 feed off verify off
      select username from dba_streams_administrator where rownum = 1;
EOF`
      STRMADMIN=`echo $var | tr -d '\n' | awk '{print $1}'`
      S_USER=$STRMADMIN
      fowner=${STRMADMIN:-STRMADMIN}
   else
      S_USER=${fowner:-strmadmin}
   fi
   if [ -f "${GET_PASSWD}" ];then
      . $SBIN/scripts/passwd.env
      . ${GET_PASSWD} $S_USER $ORACLE_SID
      if [  "x-$CONNECT_STRING" = "x-" ];then
         echo "could no get a the password of $S_USER"
         echo "Trying to complete request defaulting password to match username $STRMADMIN"
         Q_PASSWD=${Q_PASSWD:-$STRMADMIN}
         CONNECT_STRING="$fowner/$Q_PASSWD"
      fi
   else
           CONNECT_STRING="strmadmin/strmadmin"             # default, adapt if needed
   fi
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
if [ -x "$SBINS/smenu_get_ora_version.sh" ];then
   ora_vers=`$SBINS/smenu_get_ora_version.sh`
   if [ "$ora_vers" = "9" ];then
       SERVEROUTPUT_SIZE=99999
   else
       SERVEROUTPUT_SIZE=unlimited
   fi
fi
#$SETXV
# ......................................
#  Report differences in count tables
# ......................................
if [ "$CHOICE" = "RESYNC_TARGET" -o "$CHOICE" = "RESYNC_SOURCE"  -o "$CHOICE" = "BOTH" ];then
   # This resync method assumes that the tables structures are the same.
   # if it is not the case, then you need to resort at the resync method with creation of LCR
   # this last method with use transformation at apply site. If you have transformation function
   # on the capture site then none of the method will work.

   # define which site is to be processed : source, target, boths
   if [  "$CHOICE" =  "RESYNC_TARGET" ];then
       RESYNC_TARGET=true
   fi
   if [  "$CHOICE" =  "RESYNC_SOURCE" ];then
       RESYNC_SOURCE=true
   fi
   if [  "$CHOICE" =  "BOTH" ];then
       RESYNC_SOURCE=true
       RESYNC_TARGET=true
   fi
   if [ -n "$CAPTURE_NAME" ];then
      # restrict the choice to a given capture
      AND_STREAMS_NAME=" and streams_name = upper('$CAPTURE_NAME') "
      AND_STREAMS_NAME_A=" and a.streams_name = upper('$CAPTURE_NAME') "
   fi

   # list of table be processed
   ftable_list=`echo $ftable_list| sed 's/,/'\',\''/g`
   if [ -n "$ftable_list" ];then
      AND_TABLE_LIST=" and table_name in ('$ftable_list')"
   fi

   if [ -n "$fsrc_owner" ];then
       AND_OWNER=" and owner = '$fsrc_owner'"
   fi
#bpa

   ftarget_owner=${ftarget_owner:-$fsrc_owner}

   SQL="set lines 32000 trimspool on head off pages 0 pause off verify off feed off
set serveroutput on 

declare
 v_cpt          number ;            -- var
 v_cpt1         number ;            -- var
 v_cpt2         number ;            -- var
 v_col          varchar2(1024) ;    -- list of columns in that uniquely identify a row
 v_sep          varchar2(1) ;       -- separator of the list of columns
 v_capture      varchar2(30) ;      -- capture name
 v_cap_q        varchar2(30);
 v_cap_qo       varchar2(30);
 v_dblink       varchar2(512);
 v_cmd          varchar2(4000) ;
 v_col_a        varchar2(2000) ;
 v_col_b        varchar2(2000) ;
 v_target_owner varchar2(30):='$ftarget_owner';
 v_target_table varchar2(30):='$ftarget_table';
 v_show_sql     varchar2(5):='$SHOW_SQL';
 v_do_resync    varchar2(5):='$EXECUTE';
 v_resync_target varchar2(5):='$RESYNC_TARGET';
 v_resync_source varchar2(5):='$RESYNC_SOURCE';

begin
   for t in (select owner,table_name from all_tables where 1=1 $AND_TABLE_LIST $AND_OWNER )
   loop
     dbms_output.put_line(chr(10) || '--> table='|| t.owner||'.'||t.table_name);
     -- Check that the table is in SYS.DBA_CAPTURE_PREPARED_TABLES
     begin
        select 1 into v_cpt from DBA_CAPTURE_PREPARED_TABLES where table_owner = t.owner and table_name = t.table_name ;
     exception
        when others then
           dbms_output.put_line('Table ' || t.owner||'.'||t.table_name|| ' is not replicated ==> skipping ' );
           goto to_end;
     end;
     -- check that there is a PK
     v_col:='';
     v_col_a:='';
     v_col_b:='';
     v_sep:='';
     for col in (  select a.OWNER, a.TABLE_NAME ,  c.COLUMN_NAME
                       from
                             dba_constraints a,
                             DBA_CAPTURE_PREPARED_TABLES b ,
                             SYS.DBA_CONS_COLUMNS c
                       where  a.owner=t.owner and a.table_name = t.table_name
                         and a.owner = b.table_owner
                         and a.table_name = b.table_name
                         and a.constraint_type in ( 'P')
                         and c.owner=a.owner
                         and c.TABLE_NAME = a.table_name
                         and c.constraint_name = a.constraint_name
                         and position is not null
                    order by c.owner, c.table_name,c.COLUMN_NAME,c.POSITION)
      loop
         v_col:= v_col||v_sep|| col.column_name ;
         v_sep:=',' ;
         v_col_a:=v_col_a ||' and b.' || col.column_name  || '(+)=a.'||col.column_name || ' and b.' || col.column_name || ' is null ' ||chr(10);
         v_col_b:=v_col_b ||' and ' || col.column_name  || '=b.'||col.column_name ;
      end loop;
      dbms_output.put_line('--> Pk cols='|| v_col ||' len='||to_char(length(v_col))  );
      if v_col is null or length(v_col) = 0  then
         dbms_output.put_line('--> no pk found --> skipping this table');
         goto to_end;
      end if;
      ----------------------------------------
      --       retrieve the capture name    --
      ----------------------------------------

      v_capture:='';
      begin
      select a.streams_name into v_capture
             from DBA_STREAMS_SCHEMA_RULES a,  dba_streams_rules b
             where a.STREAMS_TYPE ='CAPTURE' $AND_STREAMS_NAME_A
                      and a.RULE_TYPE = 'DML' and a.SCHEMA_NAME = t.owner
                      and b.streams_name = a.streams_name
                      and b.rule_name = a.rule_name
                      and b.rule_owner = b.rule_owner
                      and b.rule_set_type='POSITIVE';
      exception
         when no_data_found then
             dbms_output.put_line('--> table '||t.owner||'.'||t.table_name|| ' is not part of a schema capture');
      end ;
      if v_capture is null or length(v_capture) = 0  then
         -- try  to get capture name from table rule
         begin
         select count(1) into v_cpt from dba_streams_table_rules
                where STREAMS_TYPE ='CAPTURE' $AND_STREAMS_NAME
                      and RULE_TYPE = 'DML' and table_owner = t.owner  and table_name = t.table_name
                      group by STREAMS_NAME, STREAMS_TYPE, TABLE_OWNER, TABLE_NAME, RULE_TYPE ;
         if v_cpt > 1 then
            dbms_output.put_line('--> Table ' || t.owner||'.'||t.table_name || ' is part of more than one replication');
            dbms_output.put_line('--> Please add the capture name to the command for this table' ) ;
            goto to_end ;
         else
          if v_cpt = 1 then
           select streams_name into v_capture from dba_streams_table_rules
                where STREAMS_TYPE ='CAPTURE' $AND_STREAMS_NAME
                      and RULE_TYPE = 'DML' and table_owner = t.owner  and table_name = t.table_name;
          else
             dbms_output.put_line('--> Problem with Table ' || t.owner||'.'||t.table_name || ' --> No found in capture ' );
             goto to_end ;
          end if ;
         end if;
         exception
           when others then
              dbms_output.put_line('--> Problem with Table ' || t.owner||'.'||t.table_name || ' --> skipping it ' );
              dbms_output.put_line('--> SQLCODE: '||SQLCODE);
              dbms_output.put_line('--> Message: '||SQLERRM);
         end ;
     end if ; -- end of try to get v_capture by rules tables
     dbms_output.put_line('--> capture used is : '||v_capture);

      ----------------------------------------
      --       retrieve the dblink name    --
      ----------------------------------------

      select QUEUE_NAME, QUEUE_OWNER into v_cap_q,v_cap_qo from sys.dba_capture where CAPTURE_NAME = v_capture ;
      dbms_output.put_line(rpad('--> Queue name',20,' ')|| ': '||v_cap_qo||'.'||v_cap_q ) ;

      begin
         select
              DESTINATION_DBLINK into v_dblink
          from
              SYS.DBA_PROPAGATION
          where SOURCE_QUEUE_OWNER = v_cap_qo
            and SOURCE_QUEUE_NAME = v_cap_q;

         dbms_output.put_line(rpad('--> Dblink',20,' ')|| ': '||v_dblink ) ;
      exception
        when no_data_found then
         dbms_output.put_line(rpad('--> Dblink',20,' ')|| ': No dblink found' );
         goto to_end ;
      end;
      if v_target_owner is null or length(v_target_owner) = 0  then
         v_target_owner:=t.owner ;                                     -- this can be done once for all
      end if;
      if v_target_table is null or length(v_target_table) = 0  then
         v_target_table:=t.table_name ;                                -- this must be reset to null before next loop
      end if;
      ----------------------------------------
      --       Resync target section        --
      ----------------------------------------
      dbms_streams.set_tag(hextoraw('87'));                 -- hope you did not use 87 as tag for DB or adapt
      if v_resync_target = 'true' then
         dbms_output.put_line('--> Resync target with data from source:');
         v_cmd:=' insert into  ' ||v_target_owner||'.'||v_target_table||'@'||v_dblink ||   chr(10)||
             '     select * from '||t.owner||'.'||t.table_name|| ' b' ||chr(10) ||
             '              where not exists (select null ' || chr(10) ||
             '                                       from ' ||v_target_owner||'.'||v_target_table||'@'||v_dblink ||   chr(10)||
             '                                where 1=1 ' || v_col_b || ')'||chr(10) ;
         if v_show_sql = 'true' then
            dbms_output.put_line('--> sql :'||chr(10)||v_cmd);
         end if;
         if v_do_resync='TRUE' then
            execute immediate v_cmd  ;
         end if;
      end if;
      ----------------------------------------
      --       Resync local section        --
      ----------------------------------------
      if v_resync_source = 'true' then
         dbms_output.put_line(chr(10) ||'--> Resync local with data from target:');
         v_cmd:= ' insert into '|| t.owner||'.'||t.table_name|| ' select * from (' ||
             ' select    /*+ driving_site(b) */ ' ||chr(10) ||
             '     a.*  from '|| t.owner||'.'||t.table_name|| ' b, '  ||
                        v_target_owner||'.'||v_target_table||'@'||v_dblink || ' a ' ||  chr(10) ||
             '                                where  1=1 ' || v_col_a ||')'  ||chr(10) ;
         if v_show_sql = 'true' then
            dbms_output.put_line('--> sql :'||chr(10)||v_cmd);
         end if;
         if v_do_resync='TRUE' then
            execute immediate v_cmd  ;
         end if;
      end if;
      v_target_table:='';

    <<to_end>>    -- continue
    null;
   end loop;
end;
/
"
# ......................................
#  Report differences in count tables
# ......................................
elif [ "$CHOICE" = "GENERATE_LST_TBL" ];then
SQL="set lines 32000 trimspool on head off pages 0 pause off verify off feed off
select max(ltrim(sys_connect_by_path(table_name,','),',')) from (
    select table_name, DENSE_RANK () OVER ( ORDER BY table_name ) AS seq
          from dba_tables where owner='$fsrc_owner'  )
        START  WITH seq = 1
         CONNECT BY PRIOR seq + 1 = seq
     ORDER  BY table_name
/
"
# ......................................
#  Report differences in count tables
# ......................................
elif [ "$CHOICE" = "COUNT_DIF" -o  "$CHOICE" = "COUNT_TARGET" -o  "$CHOICE" = "COUNT_SOURCE" ];then
   # define which site is to be processed : source, target, boths
   if [  "$CHOICE" =  "COUNT_TARGET" ];then
       COUNT_TARGET=true
   fi
   if [  "$CHOICE" =  "COUNT_SOURCE" ];then
       COUNT_SOURCE=true
   fi
   if [  "$CHOICE" =  "COUNT_DIF" ];then
       COUNT_SOURCE=true
       COUNT_TARGET=true
   fi
   if [ -n "$CAPTURE_NAME" ];then
      # restrict the choice to a given capture
      AND_STREAMS_NAME=" and streams_name = upper('$CAPTURE_NAME') "
      AND_STREAMS_NAME_A=" and a.streams_name = upper('$CAPTURE_NAME') "
   fi

   # Check and process additional predicates:
   if [ -n "$PREDICATE" ];then
      PREDICATE=`echo $PREDICATE |  sed "s/'/'\'/g"`          # replace to_char(date,'YYYY-MM-DD') with to_char(date,''YYYY-MM-DD'')
      AND_PRED=" and $PREDICATE "
   fi
TTITLE="Count differences on tables"
   ftable_list=`echo $ftable_list| sed 's/,/'\',\''/g`
   if [ -n "$ftable_list" ];then
      AND_TABLE_LIST=" and table_name in ('$ftable_list')"
   fi
   if [ -n "$fsrc_owner" ];then
       AND_OWNER=" and owner = '$fsrc_owner'"
   fi
   ftarget_owner=${ftarget_owner:-$fsrc_owner}
   if [ -n "$ftarget_table" -a -z "${ftable_list%%*,*}"  ];then
      # prevent mixing mutlitple source table and one target table
      echo "I provide multiple source tables and one target table."
      echo "table name change is supported with only one source table"
      exit 0
   fi
   SQL="set serveroutput on 
set lines 1024 trimspool on
declare
 v_cpt          number ;            -- var
 v_cpt1         number:=0 ;         -- var default is count not performed
 v_cpt2         number:=0 ;         -- var default is count not performed
 v_col          varchar2(1024) ;    -- list of columns in that uniquely identify a row
 v_sep          varchar2(1) ;       -- separator of the list of columns
 v_capture      varchar2(30) ;      -- capture name
 v_cap_q        varchar2(30);
 v_cap_qo       varchar2(30);
 v_dblink       varchar2(512);
 v_cmd          varchar2(4000) ;
 v_col_a        varchar2(2000) ;
 v_col_b        varchar2(2000) ;
 v_target_owner varchar2(30):='$ftarget_owner';
 v_target_table varchar2(30):='$ftarget_table';
 v_show_sql     varchar2(4):='$SHOW_SQL';
 v_count_target varchar2(4):='$COUNT_TARGET';
 v_count_source varchar2(4):='$COUNT_SOURCE';

begin
   for t in (select owner,table_name from all_tables where 1=1 $AND_TABLE_LIST $AND_OWNER )
   loop
     dbms_output.put_line(chr(10) || '--> table='|| t.owner||'.'||t.table_name);

     -- Check that the table is in SYS.DBA_CAPTURE_PREPARED_TABLES
     begin
        select 1 into v_cpt from DBA_CAPTURE_PREPARED_TABLES where table_owner = t.owner and table_name = t.table_name ;
     exception
        when others then
           dbms_output.put_line('Table ' || t.owner||'.'||t.table_name|| ' is not replicated ==> skipping ' );
           goto to_end;
     end;
     -- check that there is a PK
     v_col:='';
     v_col_a:='';
     v_col_b:='';
     v_sep:='';
     for col in (  select a.OWNER, a.TABLE_NAME ,  c.COLUMN_NAME
                       from
                             dba_constraints a,
                             DBA_CAPTURE_PREPARED_TABLES b ,
                             SYS.DBA_CONS_COLUMNS c
                       where  a.owner=t.owner and a.table_name = t.table_name
                         and a.owner = b.table_owner
                         and a.table_name = b.table_name
                         and a.constraint_type in ( 'P')
                         and c.owner=a.owner
                         and c.TABLE_NAME = a.table_name
                         and c.constraint_name = a.constraint_name
                         and position is not null
                    order by c.owner, c.table_name,c.COLUMN_NAME,c.POSITION)
      loop
         v_col:= v_col||v_sep|| col.column_name ;
         v_sep:=',' ;
         v_col_a:=v_col_a ||' and b.' || col.column_name  || '(+)=a.'||col.column_name || ' and b.' || col.column_name || ' is null ' ||chr(10);
         v_col_b:=v_col_b ||' and ' || col.column_name  || '=b.'||col.column_name ;
      end loop;
      dbms_output.put_line('--> Pk cols='|| v_col ||' len='||to_char(length(v_col))  );
      if v_col is null or length(v_col) = 0  then
         dbms_output.put_line('--> no pk found --> skipping this table');
         goto to_end;
      end if;

      ----------------------------------------
      --       retrieve the capture name    --
      ----------------------------------------

      v_capture:='';
      begin
      select a.streams_name into v_capture
             from DBA_STREAMS_SCHEMA_RULES a,  dba_streams_rules b
             where a.STREAMS_TYPE ='CAPTURE' $AND_STREAMS_NAME_A
                      and a.RULE_TYPE = 'DML' and a.SCHEMA_NAME = t.owner
                      and b.streams_name = a.streams_name
                      and b.rule_name = a.rule_name
                      and b.rule_owner = b.rule_owner
                      and b.rule_set_type='POSITIVE';
      exception
         when no_data_found then
             dbms_output.put_line('--> table '||t.owner||'.'||t.table_name|| ' is not part of a schema capture');
      end ;
      if v_capture is null or length(v_capture) = 0  then
         -- try  to get capture name from table rule
         begin
         select count(1) into v_cpt from dba_streams_table_rules
                where STREAMS_TYPE ='CAPTURE'
                      and RULE_TYPE = 'DML' and table_owner = t.owner  and table_name = t.table_name $AND_STREAMS_NAME
                      group by STREAMS_NAME, STREAMS_TYPE, TABLE_OWNER, TABLE_NAME, RULE_TYPE;
         if v_cpt > 1 then
            dbms_output.put_line('--> Table ' || t.owner||'.'||t.table_name || ' is part of more than one replication');
            dbms_output.put_line('--> Please add the capture name to the command for this table' ) ;
            goto to_end ;
         else
          if v_cpt = 1 then
           select streams_name into v_capture from dba_streams_table_rules
                where STREAMS_TYPE ='CAPTURE' $AND_STREAMS_NAME
                      and RULE_TYPE = 'DML' and table_owner = t.owner  and table_name = t.table_name;
          else
             dbms_output.put_line('--> Problem with Table ' || t.owner||'.'||t.table_name || ' --> No found in capture ' );
             exit;
          end if ;
         end if;
         exception
           when others then
              dbms_output.put_line('--> Problem with Table ' || t.owner||'.'||t.table_name || ' --> skipping it ' );
              dbms_output.put_line('--> SQLCODE: '||SQLCODE);
              dbms_output.put_line('--> Message: '||SQLERRM);
         end ;
     end if ; -- end of try to get v_capture by rules tables
     dbms_output.put_line('--> capture used is : '||v_capture);

      ----------------------------------------
      --       retrieve the dblink name    --
      ----------------------------------------

      select QUEUE_NAME, QUEUE_OWNER into v_cap_q,v_cap_qo from sys.dba_capture where CAPTURE_NAME = v_capture ;
      dbms_output.put_line(rpad('--> Queue name',20,' ')|| ': '||v_cap_qo||'.'||v_cap_q ) ;

      begin
         select
              DESTINATION_DBLINK into v_dblink
          from
              SYS.DBA_PROPAGATION
          where SOURCE_QUEUE_OWNER = v_cap_qo
            and SOURCE_QUEUE_NAME = v_cap_q;

         dbms_output.put_line(rpad('--> Dblink',20,' ')|| ': '||v_dblink ) ;
      exception
        when no_data_found then
         dbms_output.put_line(rpad('--> Dblink',20,' ')|| ': No dblink found' );
         goto to_end ;
      end;
      if v_target_owner is null or length(v_target_owner) = 0  then
         v_target_owner:=t.owner ;                                     -- this can be done once for all
      end if;
      if v_target_table is null or length(v_target_table) = 0  then
         v_target_table:=t.table_name ;                                -- this must be reset to null before next loop
      end if;

      ----------------------------------------
      --       count target section        --
      ----------------------------------------

      if v_count_source = 'true' then
         v_cmd:=' select count(1) local_missing from ' ||v_target_owner||'.'||v_target_table||'@'||v_dblink ||  ' b ' || chr(10)||
             '              where not exists (select null ' || chr(10) ||
             '                                       from ' ||t.owner||'.'||t.table_name||chr(10) ||
             '                                where 1=1 $AND_PRED' || v_col_b || ') $AND_PRED'||chr(10) ;
         if v_show_sql = 'true' then
            dbms_output.put_line('--> Sql Count source:'||chr(10)|| v_cmd);
         end if;
         execute immediate v_cmd into v_cpt1 ;
      end if;

      ----------------------------------------
      --       Count local section        --
      ----------------------------------------

      if v_count_target = 'true' then
         v_cmd:= 'select    /*+ driving_site(b) */ ' ||chr(10) ||
             '      count(1) target_missing from '|| t.owner||'.'||t.table_name|| ' a, '  ||
                        v_target_owner||'.'||v_target_table||'@'||v_dblink || ' b ' ||  chr(10) ||
             '                                where  1=1 $AND_PRED ' || v_col_a   ||chr(10) ;
         execute immediate v_cmd into v_cpt2 ;
         if v_show_sql = 'true' then
            dbms_output.put_line('--> Sql Count target:'||chr(10)|| v_cmd);
         end if;
      end if;
      v_target_table:='';
      dbms_output.put_line('');
      if v_count_target = 'true' then
         dbms_output.put_line('--> Missing in target  : ' || to_char(v_cpt2) );
      end if;
      if v_count_source = 'true' then
         dbms_output.put_line('--> Missing in Local   : ' || to_char(v_cpt1) ) ;
      end if;

    <<to_end>>    -- continue
    null;
   end loop;
end;
/
"
fi
if [ "$VERBOSE" = "TRUE" ];then
  echo "$SQL"
fi
# ----------------------------------

   do_execute

