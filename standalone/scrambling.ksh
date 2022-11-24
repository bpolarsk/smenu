#!/bin/sh
# program      : scrambling.ksh
# Author       : Bernard Polarski
# Date         : 2011-01-12
# Version      : 1.0
# History      : 2011-04-07    :  Added function rule_long
#
# ===========================================================================
# Summary  : This routine scramble data in an Oracle DB
#            It target Dev/text DB, clone of production, with sensitive data.
#            It produces a master kornshell do_all_scrambling_worker.ksh
# ===========================================================================
# This program start by reading its ini file which contains 6 columns:
#    
# ID      OWNER      TABLE          COLUMN        RULE         VARIABLE FIELD
# -----  ---------- -------------  ------------  -----------  ------------ 
# 1       Scott      emp            department    rule1        
# 
# The program will create a temporary table to upload the content of the ini file
# so that a PL/SQL block can run without login/logout or define external table or utl_file_dir
#
# To each rule name must correspond a function_string with same name that encompass the code of the function
# These function will be created at start of this routine. Each function as a unique argument. put null if 
# you don't need it
#
# Every rows start with an unique identifier which determine the order of execution. you may insert rows afterward:
#  ID : 5
#  ID : 6
#
#  to insert a process between 5 and 6 create a row with ID 5.5
#
#  ID : 5
#  ID : 5.5
#  ID : 6
#  
# The general pattern behavior for each column is to apply the rule of the table column.
# The rule is in a fact a function that is called in an update of the table column. 
# The code used is of type:
# 
#   Update owner.table 
#            set column=rule(column)
#
# At the end of this routine, the temporary table and rule functions are dropped
#
# In the variable field you may add specifics processes.
# 
# Specifics processes
# ....................
#  
#   Keyword 'AFTER' or 'BEFORE'  : when these keyword are met in the VARIABLE field, the function is runned
#                                  one time BEFORE or AFTER all others rules. The col filed is passed as parameter
#                                  so put 'DUMMY' or anything else has placeholder if your rule will not use the 
#                                  column field
#
#  Example: to truncate  the TABLE 'CUSTOMER' we put:
#
# ID      OWNER      TABLE          COLUMN        RULE         VARIABLE FIELD
# -----  ---------- -------------  ------------  -----------  ------------
# 10      Scott      customer       DUMMY_COL     rule_cust     BEFORE
#
#     The rule for AFTER and BEFORE receive the owner, table and column name as arguments:
#         
#     SQL> execute rule_trunc('scott','customer', 'DUMMY_COL') ;
#
#  =======================
#  Detailed explanations:
#  =======================
# 1. The shell script used to scramble the database and the list of fields to scramble are given in SCRAMBLE.ini
# 
# 2. The scrambling functions are:
# o	For a string field: the original value is replaced by a string of the same length (random generated string). 
#       Note that NULL's are preserved (since this is important for the performance).
# o	For a zip code: if it is numerical, then a randomly generated number of the same length is used. 
#       If it is alpha-numeric, a random string of the same length is generated. Random number/strings are generated 
#       using the RANDOMIZE PL/SQL function (which generate pseudo-random number in the normal distribution).
# o	Some tables are completely deleted
# o	For a number, the value is replaced by a number of the same sign but the value is randomly mapped to a value in the range 1 to 10000.
# o	Numeric and varchar value may be set to fixed value
# o	Lob and CLOB may be obfuscate  or set to null
# 
# Functions used to scramble the data can be changed if needed. Those functions are themself parameters to the procedure. 
# This means that the scrambling procedure is in fact generic (can be used for other database as well).
# 
# 2.2.	The scrambling procedure
# 2.3.	High level description
#      A shell script shall be executed by IT-OPS DBA on a copy of the production database in the production environment. 
#      The main input parameter for the script is a file called scramble.ini that contains the list of columns to be scrambled 
#      plus the function to be applied.
#      The output of the script will be a set of SQL scripts that must be run against the source database, 
#      resulting in a scrambled database. 
# 2.4.	The technical procedure
# The procedure is mix of Korn shell and PL/SQL
# 
#   1)	We start with a korn shell that reads a text file (scramble.ini, delivered with the program).
#   2)	We  connect to the database to perform some queries on the target tables metadata 
#   3)	Running a PL/SQL procedure, we generate a set of SQL statements into an SQL file
#   4)	Disconnect from DB, we parse the SQL file and create a series of workers 
#       (Korn shell that will be launched in parallel and in background).
# 
# The scramble ini file contains the list of columns to be scrambled, and the list of tables to be truncated.
# The file scramble.ini is given as attachment.
# 
# 3.	LIST OF COLUMNS AND TABLES TO BE SCRAMBLED
#       The file scramble.ini contain all the fileds to be scrambled
# 4.	ANNEX: HOW TO USE SCRABLING.KSH
#       You need scrambling.ksh (this file) and the INI file, required to run the script. the ini file indicates 
#       what must be scrambled, is also given as attachment. Since this script is generic, it can be used to scramble other databases.
# 
# 4.1.	The ini file
# 
#       You need first to create the ini file that is read by scramling.ksh as the driving rules. 
#       The file name is 'scrambling.ini' and is expected in the same directory.
# 
#    The file has 6 columns: 
#  
#          Column name	Value	                            Descriptions
#          -----------    -------------------------------   ----------------------------------------------------------------- 
#           ID            Any numeric, can contain digit.  Use to order the execution of functions within the same categories
#           Owner name    String                           Owner of the table
#           Table name    String                           Table name. You may have multiple row in the ini file
#           Column name   String                           The column within the table. One row in the ini file per column
#           Function name String                           This is a tag name which is also present in 'scrambling.ksh' 
#                                                          and variable 'FUNC_LIST'. The value of the function name points also to a 
#                                                          PL/SQL function of the same name whose definition is in 'scrambling.ksh and 
#                                                          whose text is thoroughly  contained into a string variable.
#           Variable      'BEFORE' or  'AFTER'  	         When value is 'BEFORE or 'AFTER', the function rule will be executed either 
#                                                          before or after and will be executed only once. You may have as many as you want 
#                                                          of those, they will be executed following their type 'BEFORE' or 'AFTER' and 
#                                                          by the ID order. Function with the tag BEFORE are executed before the scrambling 
#                                                          process start for all tables and function with tag AFTER are executed after 
#                                                          the scrambling is done for all tables. Typical usage are truncate table, 
#                                                          report on cardinality, take statistics after scrambling on the given column.
#                         SPLIT_<nn>                       Split the table by max chunk of rows <nn>. the value set using 'SPLIT_<nn>'
#                                                          overload and supercede the value given by -split <nn> parameter. the scope is 
#                                                          the table only.
#                         <nn>                             any value given with function 'rule_fix{num|var}' is set into column_name
# 
# EXAMPLE OF TYPICAL SCAMBLING.INI FILE:
# 
# 1   BPA          ACCOUNTSGBYEBUSER      ALIAS                    rule_char
# 1.1 BPA          ACCOUNTSGBYEBUSER      /tmp/myprocd.sql         exec_sqlfile         BEFORE
# 2   BPA          ACCOUNTUSAGE           TXLIMITAMOUNT            rule_num
# 3   BPA          CUSTOMERXXBANK         DEFAULTAMOUNT            rule_clob
# 4   BPA          CUSTOMERXXBANK         DEFAULTMESSAGE           rule_fixnum          -1999
# 5   BPA          AUDITTRAIL             ACTIONDATA               rule_blob
# 5.5 BPA          BANKARCHIVE            ARCHIVEXHOLDERZIPCODE    rule_gather_stat_col BEFORE
# 5.6 BPA          BANKARCHIVE            ARCHIVEXHOLDERZIPCODE    rule_zip             BEFORE
# 6   BPA          BANKARCHIVE            ACCNTHOLDERCOUNTRYCODE   rule_fixvar          UK
# 7   BPA          BANKARCHIVE            ARCHIVEXHOLDERADDRESS1   rule_char
# 18  BPA          TEST                   DUMMY                    rule_trunc           BEFORE
# 19  BPA          BANKARCHIVE            ARCHIVEXHOLDERZIPCODE    rule_gather_stat_col AFTER
# 20  BPA          BANKARCHIVE            ARCHIVEXHOLDERZIPCODE    rule_report_stat_col AFTER
# 
# 4.2.	Adding line into the scramble.ini
# 
#       Each line in scramble.ini will have 5 or 6 fields. The 5 first fields are always mandatory, while the six fields is optional. 
#       This field alters the scope of the function to be run. If you add the key word 'BEFORE' then the function is a procedure 
#       and it is ran before all others, if you add the key word 'AFTER' than it is ran after all others.
#       Beside OWNER, TABLE_NAME and COLUMN fields which are self-explanatory's the ID column must be a unique number in the field. 
#       There is a constraint to enforce this. The table name do not need to be collated as the optimization on the update statement 
#       will create on single update per table with as many 'set values' as there are columns for the table in the ini file.
#  
# 4.3.	Script scrambling arguments
# 
# If you type 'scramble.ksh' without argument, you get the help:
#       scrambling.ksh  -install
#       scrambling.ksh  -run  -split <nn>
# 
#           -install  : Create the packages and populate the table scramble.ini based on the scramble.ini file delivered.
#           -run      : generate the scripts to run
#           -split    : split the updates max 'nn' rows at a time (it may be less but not more than 'nn' )
#           -worker   : Number of scripts worker to generates. Default is 3
#           -cs       : connect string used by the workers. Default is IBS6_EB_OWNER/IBS6_EB_OWNER
#          -uninstall : Remove scrambling table and functions from DB
# 
#   examples:  scrambling.ksh -run -split 500000 -worker 4 -cs bpa/bpa
# 
# 
# The following are further explanations: 
#     1)   -install:   create the table scramble_ini, upload all rows from scramble.ini into 
#                      the table and create all the functions that are referenced into FUNC_LIST. 
# 
#     2)    -run  :   process all the content of the scramble_ini and generate by default 3 scramble_worker<n>.ksh scripts. 
#                     Each script will contain all the sql statement to run.
# 
#     3)    -split : define the maximum size of the update before commit. The script will generated additional update 
#                    if the table is bigger using 3 different logics
# 
#                     1. Per rowid count
#                     2. Per partitions count
#                     3. Both per partition and per rowid count
# 
#    Note: You may refine the split pet table : Add in scramble.ini, at row level, in column variable 
#          the keyword 'SPLIT_<nn>'. Put it in all columns of the same table in the ini file (in fact, 
#          only the last one is  used, but after sorting mutlicriteria, which one is  last in the series?). 
# 
# Example force commit every 30k rows :
# ID   OWNER            TABLE_NAME      COLUMN_NAME       RULE NAME     VARIABLE 
# --  ----------------- -------------  ----------------- ------------  ------------
# 52  IBS6_EB_OWNER     DDTXTEMPLATE   MESSAGETODEBTOR    rule_fixnum   SPLIT_30000
# 
#    4)       -worker : change the default worker to another number than the default 3
#    5)       -cs     : change the connecting string (user/passwd) to be used. 
#                        Note  that this affect the target schema that is scramble. Default is IBS6_EB_OWNER
#    6)       -uninstall: remove all objects created by the scrambling process
# 
# 4.4.	Scrambling function
# 
#        Scrambling functions are the heart of the scrambling mechanism: you name a table column and define
#        function to apply on this column. 'scrambling.ksh' will optimize the SQL statement to perform the task.
#        There are more in scramble.ksh than just the scrambling. The script takes care of the rollback segments, 
#        by checking the size of the table to scramble. If the number of rows to scramble is superior to the threshold 
#        (default 1M rows) it will generate update statement that will commit before this count - split threshold - is reached. 
# 
#        To achieve this goal 3 case are possible and each one is treated accordingly:
# 
#                   1. Table is not partitioned, the update operation are cut by rowed with each chunk of rows 
#                      to process is < in count to the split threshold
# 
#                    2. Table is partitioned :  the update follow the partitions. one update statement is generated
#                       for each partition. 
# 
#                    3. Table is partitioned but one or many partitions row count are above the threshold: 
#                       each partitions above  the splt threshold is split also by rowed chunks according to the needs.
# 
#        The scrambling functions are function referenced into scrambling.ini file and defined into scrambling.ksh.  
#        The following shows where the rule function appears in the ini file.  By default a function apply to all rows 
#        and result in a update SQL statement: 
# 
#              15 BPA ARCHIVEX   ARCHIVEXHOLDERZIPCODE   rule_zip  BEFORE
# 
#        Notes: when there is the keyword 'BEFORE' or 'AFTER' on the same line at position six, the function is applied 
#               only once through an execute statement with the name of the function and 3 parameters: 
#                   function (owner,table_name,column_name)
# 
#                The function is then referenced in 'scrabling.ksh' into the variable FUNC_LIST which hold 
#                the name of all function to install:
# 
#         FUNC_LIST="rule_char rule_num1 rule_zip rule_trunc"
# 
#         When you run the install, all function that are in the FUNC_LIST are created. Alternatively, 
#         when you run the -uninstall all functions into the FUNC_LIST are dropped.
# 
#         The code of a function is put into a korn shell variable like a regular PL/SQL piece of code:
#         Here is the code for function rule_zip :
# 
#           rule_zip="create or replace function rule_zip( p_value IN varchar2) return varchar2
#                     is
#             ret varchar2(256);
#             begin
#               case
#                  when regexp_like(p_value,'[[:digit:]][[:digit:]][[:digit:]][[:digit:]]') then
#                                ret:=to_char(trunc(dbms_random.value(1000,9999)))  ;
#                  when regexp_like(p_value,'[[:digit:]][[:digit:]][[:digit:]][[:digit:]][[:digit:]]') then
#                                ret:=to_char(trunc(dbms_random.value(10000,99999)))  ;
#                  else
#                                ret:=dbms_random.string('A', length(p_value) );
#               end case ;
#               return ret ;
#             end;
#             /
#             "
# 
#           Note how the code is simply enclosed in double quotes and the whole string is assigned 
#           to a korn-shell variable with the same name as the function name.
# 
# 4.5.	Default scrambling functions
# 
#          There are a certain number of default function provide with the scripts. These functions are:
# 
#       Rule name         Description
#       -------------     ---------------------------------------------------------------------------------
#       rule_char         Scramble the varchar content into a string of equivalent length of random characters
#       rule_num          Convert the numeric value in the same sign but the value is random in 
#                         the range (1/100 to 100x). Thus a figure of 1000 may become  10 or 100,000 round down.
#       rule_zip          Postal code of 4 or 5 digit are replace by a random of 4 or 5 digit. Zip code with char
#                         in it (like UK zip) are hashed random string. (Note: we are aware that doing 
#                         this change radically the selectivity)
#       rule_trunc        Truncate the table. Add the keyword 'BEFORE' or 'AFTER' to run this only once. 
#                         The column field is not used but something must be put there to keep the ini file 
#                         coherence and code simplicity.
#    rule_gather_stat_col	This function takes the statistics on for the column (one time function)
#    rule_report_stat_col This function display the column statistics, to be use before or after.
#    rule_lob             Replace the lob with an obfuscated lob same size (warning: May be very slow)
#    rule_clob            Replace the clob with an obfuscated clob same size (warning: May be very slow)
#    rule_date            Replace the date with date '1970-01-01'
#    Rule_null            Replace the column with a null. If there is a not null constraint on the field, 
#                         the constraint is disable
#    rule_fixnum          Replace the column value with a fixed numeric value
#    rule_fixvar          Replace the column value with a fixed varchar2  value
#    exec_sqlfile         Execute the script whose path is set into the column_name value. don't forget 'BEFORE|AFTER'
#                         in variable column. Put DUAL as the table name
# 
# 4.6.	Adding Scrambling functions
# 
#         Adding a new function is rather easy:
# 
#            1) Generate in PL/SQL the function that will perform the transformation. Simply test it 
#               with a select on the column until you are happy of the transformation
# 
#            2) Cut and paste the function into the function section of scrambling.ksh. Enclose the code 
#               into double quotes and assign the whole to a korn-shell variable which has the same name 
#               as the function
# 
#            3) Add the korn-shell variable into the FUNC_LIST variable in scrambling.ksh
# 
#            4) Add the lines of the table to process, put the name of the function after 
#               the column name (in position 5).
# 
# 
# ------------------------------------------------
function help
{
  cat <<EOF

      scrambling.ksh  -install 
      scrambling.ksh  -run  -split <nn>

           -install : Create the packages and populate scramble.ini
           -run     : generate the scripts to run
                        -split : split the updates max 'nn' rows at a time (it may be less but not more than 'nn' )
           -worker  : Number of scripts worker to generates. Default is 3
           -cs      : connect string used by the workers. Default is IBS6_EB_OWNER/IBS6_EB_OWNER
         -uninstall : Remove scrambling table and functions from DB

  examples :  scrambling.ksh -run -split 500000 -worker 4 -cs bpa/bpa

EOF
exit
}
 
# ------------------------------------------------
# Start: parameter definition section
# ------------------------------------------------

SC_DIR=/home/oracle/scripts/bin/scrambling

# ini file that contains the table/columns to process
FINI=$SC_DIR/scrambling.ini

#CONNECT_STRING=$fowner/$fpass 
CONNECT_STRING=${CONNECT_STRING:-IBS6_EB_OWNER/IBS6_EB_OWNER}
#CONNECT_STRING=${CONNECT_STRING:-SIEBEL/SIEBEL}

# ------------------------------------------------
# End  : parameter definition section
# ------------------------------------------------

# ------------------------------------------------
# Start: Rule section
# ------------------------------------------------

# Append to FUNCTION LIST the name of new rule separated by space
#
#
FUNC_LIST="rule_char rule_num rule_float rule_zip rule_trunc rule_gather_stat_col rule_report_stat_col "
FUNC_LIST="$FUNC_LIST rule_lob rule_clob rule_date rule_null rule_fixnum exec_sqlfile rule_fixvar rule_long"
#

#
# exec_sqlfile
#
# this is a dummy function. the argument in VARIABLE will be called by this script as it is
#
exec_sqlfile="
prompt bpa said : Discard following SP2-0223 errors : nothing to compile, it is a dummy entry
prompt
"

#
# rule_fixvar
#
rule_fixvar="create or replace function rule_fixvar ( p_var IN varchar2 ) return varchar2
is
begin
  return  p_var;
end;
/
"
#
# rule_null
#
rule_null="create or replace function rule_null ( p_owner IN varchar2, p_table IN varchar2 , p_col in varchar2 ) return varchar2
is
begin
 return null ;
end ;
/
"

#
# rule_fixnum
#
rule_fixnum="create or replace function rule_fixnum ( p_value in number ) return number
is
begin
 if p_value is null then
    return -9999 ;
 else
   return p_value ;
 end if ;
end ;
/
"
#
# rule_report_stat_col
#
rule_report_stat_col="create or replace procedure rule_report_stat_col( p_owner IN varchar2, p_table IN varchar2 , p_col in varchar2 ) 
as
cmd varchar2(256) ;
   v_num_rows number ;
   v_column_name  varchar2(30) ;
   v_dtyp         varchar2(30) ;
   v_num_distinct number ;
   v_selectivity  number ;
   v_density      number ;
   v_num_nulls    number ;
   v_histogram    varchar2(30) ;
   v_num_buckets  number ;
   v_la           varchar2(26) ;
begin
    select num_rows into v_num_rows from all_tables where owner = p_owner    and  table_name = p_table;

    select a.column_name , a.data_type||'('||a.data_length||')', a.num_distinct,
           decode(nvl(a.num_distinct,0),0,0,(v_num_rows-num_nulls )/a.num_distinct) selectivity, 
           density*100,
           num_nulls,
           HISTOGRAM,
           (select count(*) from all_tab_histograms where
                       owner = p_owner   and table_name = p_table and column_name=upper(a.column_name)
           ) ,
           to_char(a.last_analyzed,'DD-MM-YY HH24:MI:SS') la 
           into v_column_name,v_dtyp, v_num_distinct,v_selectivity, v_density, v_num_nulls, v_histogram, v_num_buckets, v_la
    from   all_tab_columns a
    where  owner = p_owner  and  table_name = p_table and column_name=p_col ;

    dbms_output.put_line('.                                                                           Density:                                    Agv');
    dbms_output.put_line('.                                                  Num     Rows per key  eqjoin ret    Num                       Num    Col');
    dbms_output.put_line('COLUMN_NAME                    Data Type        distinct  (Selectivity)   % of rows   Nulls    Histogram        Bucket  Len Last Analysed'); 
    dbms_output.put_line('------------------------------ ---------------- --------- ------------- -----------  ---------- --------------- ------- ---- ------------------');
    dbms_output.put_line( rpad(v_column_name,31)
                          || rpad(v_dtyp,16)
                          || rpad(to_char(v_num_distinct),10)
                          || rpad(to_char(v_selectivity,'9999999999'),13)
                          || rpad(to_char(v_density,'990.999999'),16)
                          || rpad(to_char(v_num_nulls),12)
                          || rpad(v_histogram,15)
                          || rpad(to_char(v_num_buckets),7)
                          ||rpad(v_la,18) );
end;
/
show errors;
"
# to run this function the execution shema must have the system grants on dbms_stats
# Example :SQL> grant execute on dbms_stats to bpa ;   
# otherwise you have an error : 
# BEGIN rule_gather_stat_col('BPA','BANKACCOUNT','ACCOUNTHOLDERZIPCODE'); END;
#  ERROR at line 1:
#  ORA-00900: invalid SQL statement
#  ORA-06512: at "BPA.RULE_STAT_COL", line 6
#  ORA-06512: at line 1

#
# rule_gather_stat_col
#
rule_gather_stat_col="create or replace procedure rule_gather_stat_col( p_owner IN varchar2, p_table IN varchar2 , p_col in varchar2 ) 
as
cmd varchar2(256) ;
begin
   cmd:='begin dbms_stats.gather_table_stats( ownname=>''' || P_OWNER ||''', tabname=> '''|| P_TABLE  || ''', Degree=> 8, estimate_percent=> 100, granularity=>''ALL'', cascade=>FALSE '  || ' , method_opt => ''For columns ' || P_COL || ' size 1''); end;' ;
   dbms_output.put_line(cmd);
   execute immediate cmd ;
end;
/
show errors;
"
#
# rule_trunc
#
rule_trunc="create or replace procedure rule_trunc( p_owner IN varchar2, p_table IN varchar2 , p_col in varchar2 ) 
as
cmd varchar2(256) ;
begin
   cmd:='truncate table ' || p_owner||'.'|| p_table  ;
   execute immediate cmd ;
end;
/
show errors;
"

#
# rule_char
#
rule_char="create or replace function rule_char( p_len IN number) return varchar2
as
  ret varchar2(4000) ;
begin
   ret:=dbms_random.string('A', p_len) ;
   -- ret:=dbms_random.string('A', trunc(dbms_random.value(1,p_len))) ;
   return ret ;
end;
/
show errors;
"

#
# rule_long
#
# this rule is only good for long <=32000 bytes
#
rule_long="create or replace function rule_long( t_name IN varchar2, c_name in varchar2, frowid in rowid) return varchar2
is
  PRAGMA AUTONOMOUS_TRANSACTION ;
  v_string   varchar2(32000);
  sqlcmd   varchar2(4000);
  v_len    number;
begin
  sqlcmd:='select '||c_name||' from ' || t_name ||' where rowid = '''||frowid || '''';
  execute immediate sqlcmd into v_string ;
  v_len:=length(v_string) ;
  if v_len > 0 then
     v_string:=dbms_random.string('A',v_len) ; 
     return v_string;
  else
     return null ;
  end if ;
end;
/
"
#
# rule_clob
#
rule_clob="create or replace function rule_clob( p_value IN clob) return clob
is
  ret         clob;
  v_len       number;
  pos         number;
  buff_size   number;
  to_write    binary_integer;
  string      varchar2(32000);
begin
    buff_size:=dbms_lob.getchunksize( p_value) ;
    v_len:=dbms_lob.getlength(p_value) ;
    if v_len is null or v_len = 0 then
        return p_value ;
    end if ;
    pos:=1;
    dbms_lob.createtemporary(ret, true);
    if v_len <= buff_size then
       ret:=to_clob(dbms_random.string('A',v_len) ) ;
    else
       loop
         exit when pos >= v_len ;
         to_write:=v_len-pos+1 ;
         if to_write >= buff_size then
            to_write:=buff_size ;
         end if;
         string:=dbms_random.string('A',to_write) ;
         dbms_lob.write(ret, length(string), pos, string );
         pos:=pos+to_write;
      end loop ;
    end if;
    return ret;
end ;
/
"
#
# rule_lob
#
rule_lob="create or replace function rule_lob( p_value IN blob) return blob
is
  ret         blob;
  v_lob       clob;
  v_len       number;
  dest_offset number  := 1;
  src_offset  number  := 1;
  blob_csid   number  := dbms_lob.default_csid;
  amount      integer := dbms_lob.lobmaxsize;
  lang_ctx    integer := dbms_lob.default_lang_ctx;
  warning     integer;
  pos         number;
  buff_size   number;
  to_write    number;
begin
    if v_len is null or v_len = 0 then
        return p_value ;
    end if ;
    dbms_lob.createtemporary(ret, true);
    dbms_lob.createtemporary(v_lob, true);
    v_len:=dbms_lob.getlength(p_value) ; 
    buff_size:=dbms_lob.getchunksize( p_value) ;
    pos:=0;
    loop
        exit when pos >= v_len ;
        to_write:=v_len-pos ;
        if to_write >= buff_size then
            to_write:=buff_size ;
        end if;
        pos:=pos+buff_size ;
        DBMS_LOB.WRITEappend (v_lob, to_write,  dbms_random.string('A',to_write) );
    end loop ;
     dbms_lob.convertToBlob( ret, v_lob, v_len, dest_offset,src_offset,blob_csid,lang_ctx,warning);
    return ret;
end ;
/
"
#
# rule_float
#
rule_float="create or replace function rule_float( p_value IN number) return float
is
  ret float(22) ;
begin
  if p_value = 0 then
     return 0 ;
  end if ;
  ret:=dbms_random.value(p_value/100,100*p_value) ;
  return ret ;
end;
/
show errors;
"
#
# rule_num
#
rule_num="create or replace function rule_num( p_value IN number) return number
is
  ret number(20,2) ;
begin
  if p_value = 0 then
     return 0 ;
  end if ;
  ret:=dbms_random.value(p_value/100,100*p_value) ;
  return ret ;
end;
/
show errors;
"
#
# rule_date
#
rule_date="create or replace function rule_date( p_value IN date) return date
is
begin
  return to_date('1970-01-01','YYYY-MM-DD');
end ;
/
"

#
# rule_zip
#
rule_zip="create or replace function rule_zip( p_value IN varchar2) return varchar2
is
  ret varchar2(256);
begin
  case
    when regexp_like(p_value,'[[:digit:]][[:digit:]][[:digit:]][[:digit:]]') then
      ret:=to_char(trunc(dbms_random.value(1000,9999)))  ;
    when regexp_like(p_value,'[[:digit:]][[:digit:]][[:digit:]][[:digit:]][[:digit:]]') then
      ret:=to_char(trunc(dbms_random.value(10000,99999)))  ;
  else
      ret:=dbms_random.string('A', length(p_value) );
  end case ;
  return ret ;
end;
/
"
# ------------------------------------------------
# End  : Rule section
# ------------------------------------------------

# ------------------------------------------------
# Start: Function section
# ------------------------------------------------

#............................................................
function do_run
{
SPLIT_NR=${SPLIT_NR:-1000000}    # split updates default by max 1m rows
# cat > t.sql <<EOF
sqlplus -s $CONNECT_STRING <<EOF
  set serveroutput on size unlimited
  set lines 3200 pages 0
  declare
      type ttype_var is table of varchar2(256) index by binary_integer ;
      type ttype_num is table of number index by binary_integer ;
      tpred      ttype_var ; 
      tpred1     ttype_var ; 
      tpred2     ttype_num ; 
      cpt        number ; 
      flen       number ;
      v_first    number:=0 ;
      cmd        varchar2(32000);
      cmd_sql    varchar2(32000);
      tot_cmd_set varchar2(32000);
      cmd_set    varchar2(32000);
      cmd_where  varchar2(32000);
      v_def_split number:=$SPLIT_NR ;
      v_nr_split number ;
      -- .........................................................................................
      procedure add_prompt(p_arg in varchar2, p_when in varchar2 ) 
      is
         ret varchar2(200);
      begin 
        dbms_output.put_line('-- ...........................................................................................');
        ret:='prompt Doing ' || p_when || ' ' || p_arg  ;
        dbms_output.put_line(ret );
      end;
      -- .........................................................................................
      -- . sql_split generates predicates by cutting a table in a serie of rowid chunk
      -- . max size of v_nr_split. It is possible that other object tangle into our serie of blocks
      -- . resulting of less row returned by the diff (last-row-in-serie-rowid minus first-row-in-serie-rowid)
      -- . However we don't case, we wil just have some more 'update statement' but overall perf is neglectable
      -- .........................................................................................
      function sql_split ( p_owner in varchar2, p_table_name in varchar2, p_partition in varchar2 ) return varchar2 is
        ret varchar2(4000);
        var  varchar2(50):=' ';
      begin
         if  p_partition is not null then
             var:=' partition ('||p_partition||') '  ;
         end if ;
         ret:=q'{ select line  from (
                       with v as (select rn, mod, rownum frank from (
                                      select rowid rn ,  mod(rownum, }' ||to_char(v_nr_split)|| ') mod  
                                            from (select rowid rn from ' || p_owner||'.'|| p_table_name || var 
                                                  || ' order by rn) order by rn ) where mod = 0 ' || q'{),
                           v1 as (
                                   select rn , frank, lag(rn) over (order by frank) lag_rn  from v ),
                           v0 as (select count(*) cpt from v)
                              select 1, case when
                                             frank = 1 then ' and rowid  <  ''' ||  rn  || ''''
                                         when
                                             frank = cpt then ' and rowid >= ''' || lag_rn ||''' and rowid < ''' ||rn || ''''
                                         else
                                           ' and rowid >= ''' || lag_rn ||''' and rowid <'''||rn||''''
                                         end line
                              from v1, v0
                              union
                              select 2, case when
                                              frank =  cpt then   ' and rowid >= ''' || rn  || ''''
                                        end line
                              from v1, v0 order by 1) }';
          return ret;
     end ;
  -- .........................................................................................
  --                                          Main
  -- .........................................................................................
  begin
      dbms_output.put_line('-- ==================================================================================================' ); 
      dbms_output.put_line('-- =       Default split updates is set to: ' || to_char(v_nr_split,'999,999,999,990') || ' rows' ) ;
      dbms_output.put_line('-- ='||chr(10)||'-- =               use scramble.ksh -run -split <nn> to change  ' );
      dbms_output.put_line('-- ='||chr(10)||'-- =               Cut and paste the script, divide work in one or many workers.' ) ;
      dbms_output.put_line('-- ==================================================================================================' ); 
      cmd:='set lines 300 pages 60 head off timing on time on serveroutput on' ; 
      dbms_output.put_line(chr(10)||cmd );
      select 'spool doit' || to_char(sysdate,'YYYYMMDDHH24MI')||'.log' into cmd from dual ;
      dbms_output.put_line(cmd );

      -- Before processing : function and procedure to execute only one time
      for R in (select * from scramble_ini where VARIABLE='BEFORE' order by ID )
      loop
           if r.function_rule = 'exec_sqlfile' then
              add_prompt(' executing file ' || R.column_name , 'before' ) ;
              cmd:='@' || r.column_name ;
              dbms_output.put_line(cmd );
           else
              add_prompt(r.table_name || '  rule: ' || r.function_rule,'before') ;
              cmd:='execute ' ||  R.FUNCTION_RULE || '('''||R.owner||''','''|| R.table_name || ''','''||r.column_name|| ''');' ||chr(10) ;
              dbms_output.put_line(cmd );
           end if ;
      end loop ; 
   

      -- main body
      -- Not null constraints need to be disabled for column that are set to null
     
       for r in ( select owner, table_name, upper(column_name) column_name  from scramble_ini where function_rule  = 'rule_null' )
       loop
            if v_first=0 then
               v_first:=1 ; 
                dbms_output.put_line('-- ............................................................................................. ' ); 
                dbms_output.put_line('--  Disabling now NOT NULL constraints for they prevent request to set fields to null'  ) ;
                dbms_output.put_line('-- ' ); 
            end if;
           for c in ( select a.CONSTRAINT_NAME, a.SEARCH_CONDITION from all_constraints a, ALL_CONS_COLUMNS b
                           where
                                 a.OWNER = r.owner             and
                                 b.TABLE_NAME=r.table_name     and
                                 b.COLUMN_NAME = r.column_name and
                                 a.constraint_type = 'C'       and
                                 a.owner = b.owner             and
                                 a.table_name = b.table_name   and
                                 a.constraint_name = b.constraint_name )
            loop
                if c.SEARCH_CONDITION like '%IS NOT NULL' then
                   cmd:='alter table ' ||r.owner||'.'||r.table_name || ' disable constraint ' || c.CONSTRAINT_NAME ||';'  ;
                   dbms_output.put_line(cmd) ;
                end if ;
           end loop ;
       end loop;

      -- point to the last row in a serie for the last owner.table
      for R in ( select 
                   id, owner, table_name, upper(column_name) column_name, function_rule, variable,
                   min(to_char(id)) KEEP (DENSE_RANK FIRST ORDER BY owner, table_name, id ) over ( partition by owner, table_name ) first,
                   max(to_char(id)) KEEP (DENSE_RANK LAST  ORDER BY owner, table_name, id ) over ( partition by owner, table_name ) last
                 from 
                     scramble_ini 
                 where 
                     VARIABLE is null or VARIABLE not in ('BEFORE','AFTER') 
                 and function_rule != 'exec_sqlfile'
                 order by owner, table_name, id )
      loop
            
        -- just a small check:
        -- get the length of the column. If the column does not exists the cmd will not be written
        -- An execption we will be rised, trapped and we loop next row in scramble_ini
        begin
            select data_length into flen from all_tab_cols 
            where       R.owner=owner 
                    and R.table_name=table_name 
                    and R.column_name = column_name ;

           cmd_sql:='update ' || r.owner||'.'|| R.table_name ;
           if  upper(R.function_rule) = 'RULE_CHAR' then
               cmd_set:=R.column_name ||'=decode(' ||chr(10)|| '                      '
                         || r.column_name || ',null,null,'|| R.FUNCTION_RULE||
                          '(to_char(length('||r.column_name ||'))))' ;
           elsif  upper(R.function_rule) = 'RULE_NUM' or  upper(R.function_rule) = 'RULE_DATE' 
                  or upper(R.function_rule) = 'RULE_FLOAT'  then
               cmd_set:=R.column_name ||'=decode(' ||chr(10) || '                      '
                        || R.table_name||'.'||r.column_name || ',null,null,'|| R.FUNCTION_RULE
                        ||'(' || r.column_name ||'))' ;
           elsif upper(R.function_rule) = 'RULE_LONG'  then
               cmd_set:=R.column_name ||'= '|| R.FUNCTION_RULE|| '('''||r.table_name||''','''|| r.column_name||''',rowid ) ' ;
           elsif upper(R.function_rule) = 'RULE_FIXNUM'  then
               cmd_set:=R.column_name ||'= '|| R.FUNCTION_RULE|| '('||r.variable ||')' ;
           elsif upper(R.function_rule) = 'RULE_FIXVAR'  then
               cmd_set:=R.column_name ||'= '|| R.FUNCTION_RULE|| '('''||r.variable ||''')' ;
           elsif  upper(R.function_rule) = 'RULE_NULL' then
               cmd_set:=R.column_name ||'=null' ;
           elsif  upper(R.function_rule) like '%LOB' then
               cmd_set:=R.column_name ||'='|| R.FUNCTION_RULE|| '('||r.column_name ||')' ;
           else
               cmd_set:=R.column_name ||'=decode(' ||chr(10) || '                      '
                                      || r.column_name || ',null,null,'|| R.FUNCTION_RULE
                                      ||'( to_char('|| r.column_name ||')))' ;
           end if ; 
           -- if we are the first column in a serie of the same table
           if r.id = r.first then
              tot_cmd_set:=chr(10)||'           '||'set ' ||cmd_set ;
           else
              tot_cmd_set:=tot_cmd_set ||chr(10)||'           ,' ||cmd_set ;      -- accumulate the variouse 'SET col='
           end if ;
           -- if we are the last column in a serie of the same table, we will print the update command
           if r.id = r.last then

               -- Before printing, check if we do not need to split the update in order to preserve the rollbacks
               if substr(r.variable ,1,6) = 'SPLIT_' then
                   v_nr_split:=to_number(substr(r.variable,7)) ;
               else
                   v_nr_split:=v_def_split ;
               end if ;
               select num_rows into cpt from all_tables where table_name = r.table_name and owner = r.owner;           
               if  cpt > v_nr_split  then

                    -- ok the number of rows in  the partition is > to our thershold v_nr_split
                    -- check now if the table is not partitioned
                    select count(*) into cpt  
                           from dba_tab_partitions where table_owner=r.owner and table_name=r.table_name ;

                    if  cpt = 0 then

                       -- Table is NOT partitionned: we split it by row id
                       -- we cut the update in a series of update based on  maximum number of rowid - v_nr_split - at a time

                       -- let's grab the sql statement.
                       -- Note that 'sql_split' function received a null value for the partition parameter 
                       -- So there will be an FTS over all the table.
                       cmd:=sql_split (r.owner, r.table_name, null) ;

                       -- ... execute SQL and dump resultset into a varray of varchar
                       execute immediate cmd bulk collect into tpred  ;

                       -- we loop the v_array, each cell contains a ready-to-use predicate of the update where clause
                       for i in tpred.first..tpred.last
                       loop
                          if  length(tpred(i) ) > 0  then
                              add_prompt(r.table_name||'.'||r.column_name, '') ;
                              cmd_where:=chr(10)||q'{            where 1=1 }' || tpred(i) ;
                              cmd:=cmd_sql || tot_cmd_set || cmd_where ;
                              dbms_output.put_line(cmd || ';');
                              cmd:='commit ;' ;
                              dbms_output.put_line(cmd);
                           end if;
                        end loop;

                    else -- table IS partitioned
                       cmd:='select PARTITION_NAME, NUM_ROWS from all_tab_partitions ' ||
                                '  where table_owner='''||r.owner||''' and table_name='''||r.table_name ||'''';

                       -- dump all PARTITION_NAME and NUM_ROWS into tpred1, tpred2
                       execute immediate cmd bulk collect into tpred1,tpred2  ;
 
                       -- loop into the partitions and check if the num_rows is not bigger than our v_nr_split
                       -- we are still very wary of the rollbacks.
                       -- if a partitions is bigger than v_nr_split, we cut it into rowid chunks and commit them separatly
                   
                       for i in tpred1.first..tpred1.last
                       loop
                          if tpred2.exists(i) then
                              if tpred2(i) > v_nr_split then

                                   -- partition row count is > v_nr_split : we split the partition by rowid chunk of max v_nr_split size
                                   -- Note that 'sql_split' function received a partition parameter - tpred1(i) -
                                   -- that will limite the scope of the FTS to the partition
                                   cmd:=sql_split (r.owner, r.table_name, tpred1(i) ) ;
                                   execute immediate cmd bulk collect into tpred  ;
                                   
                                   -- row count told us that the partitions count was > v_nr_split, so our script
                                   -- ran trough it. If the stat were false and the partition is in fact empty
                                   -- then any operation on tpred will fail miserably.  
                                   -- So we check first rowid predicates were generated for this partition:
                                   if tpred.count > 0 then
                                      for j in tpred.first..tpred.last
                                      loop
                                         if  tpred.exists(j) then
                                             if  length(tpred(j) ) > 0  then

                                                  -- ok there is a rowid predicate: our update is complete--> we print it.
                                                  cmd_where:=chr(10)||q'{            where 1=1 }' || tpred(j) ;
                                                  cmd:=cmd_sql||' partition (' || tpred1(i)|| ')' || tot_cmd_set || cmd_where ;
                                                  add_prompt(r.table_name||'.'||r.column_name||' partition (' || tpred1(i)|| ')', '' ) ;
                                                  dbms_output.put_line(cmd || ';');
                                                  cmd:='commit ;' ;
                                                  dbms_output.put_line(cmd);
                                               end if;
                                          else -- statistics were false and the partition was empty
                                               add_prompt(r.table_name||'.'||r.column_name||' partition (' || tpred1(i)|| ')', '' ) ;
                                               dbms_output.put_line('-- WARNING statistics on ' ||r.owner||'.'||r.table_name
                                                                        ||'('||tpred(j)||') were faulty : partition seems empty ' );
                                               cmd:=cmd_sql || '  partition (' || tpred1(i)|| ')' || tot_cmd_set  ;
                                               dbms_output.put_line(cmd || ';');
                                               cmd:='commit ;' ;
                                               dbms_output.put_line(cmd);
                                          end if ;
                                      end loop;
                                   else
                                           add_prompt(r.table_name||'.'||r.column_name||' partition (' || tpred1(i)|| ')', '' ) ;
                                           cmd:=cmd_sql || ' partition (' || tpred1(i)|| ')' || tot_cmd_set  ;
                                           dbms_output.put_line(cmd || ';');
                                           cmd:='commit ;' ;
                                           dbms_output.put_line(cmd);
                                   end if;

                              else -- patrtition row count is lower than v_nr_split

                                 add_prompt(r.table_name||'.'||r.column_name||' partition (' || tpred1(i)|| ')', '' ) ;
                                 cmd:=cmd_sql || ' partition (' || tpred1(i)|| ')' || tot_cmd_set  ;
                                 dbms_output.put_line(cmd || ';');
                                 cmd:='commit ;' ;
                                 dbms_output.put_line(cmd);
                              end if ;

                          else -- there is no row count for this partitions

                                 add_prompt(r.table_name||'.'||r.column_name||' partition (' || tpred1(i)|| ')', '' ) ;
                                 cmd:=cmd_sql || ' partition (' || tpred1(i)|| ')' || tot_cmd_set  ;
                                 dbms_output.put_line(cmd || ';');
                                 cmd:='commit ;' ;
                                 dbms_output.put_line(cmd);
                          end if ;
                       end loop;
                    end if ;

                else

                   add_prompt(r.table_name||'.'||r.column_name, '' ) ;
                   cmd:=cmd_sql ||tot_cmd_set  ;
                   dbms_output.put_line(cmd || ';');
                   cmd:='commit ;' ;
                   dbms_output.put_line(cmd);

              end if ;
           end if;
           exception
               when no_data_found then
                  dbms_output.put_line(R.table_name ||'.'||R.column_name || ' not found');
           end;
      end loop;

      -- AFTER processing
      for R in (select * from scramble_ini where VARIABLE='AFTER' order by ID )
      loop
          if r.function_rule = 'exec_sqlfile' then
             add_prompt(' Executing file ' || R.column_name ,'after') ;
             cmd:='@' || r.column_name ;
             dbms_output.put_line(cmd );
          else
             add_prompt(r.table_name || '  rule: ' || r.function_rule,'after') ;
             cmd:='execute ' ||  R.FUNCTION_RULE || '('''||R.owner||''','''|| R.table_name || ''','''||r.column_name|| ''');' ||chr(10) ;
             dbms_output.put_line(cmd );
          end if;
      end loop ; 
           cmd:='spool off;' ;
           dbms_output.put_line(cmd );
  end;
/
EOF
}
#............................................................
function cr_table_scramble
{
sqlplus $CONNECT_STRING <<EOF
drop table scramble_ini ;
create table scramble_ini
 ( ID            number not null, 
   OWNER         varchar2(30) CHECK (OWNER       = upper(OWNER)),
   TABLE_NAME    varchar2(30) check (TABLE_NAME  = upper(TABLE_NAME)),
   COLUMN_NAME   varchar2(500) ,
   FUNCTION_RULE varchar2(30),
   VARIABLE      varchar2(30),
   constraint pk_scramble_ini primary key(id)
);
desc scramble_ini ;
exit ;
EOF
}
#............................................................
function cr_rule_functions
{
 for FUNCTION in `echo $FUNC_LIST`
 do
   eval A=$`echo "$FUNCTION"`
   sqlplus -s $CONNECT_STRING <<EOF
   $A;
   show errors ;
   exit ;
EOF
  done
}
#............................................................
function load_scramble_table {
cat $FINI |  while read id o t c r v
do
   if [ -z "$o" ];then
      continue
   fi
   l=${l:-null}
   CMD="insert into scramble_ini values ($id,'$o','$t','$c', '$r', '$v' ) ;"
   sqlplus -s $CONNECT_STRING <<EOF
   $CMD
   exit;
EOF
done

sqlplus $CONNECT_STRING <<EOF
     set lines 190 pages 66
     col OWNER for a26
     col id form 9990.99
     col function_rule for a20
     col COLUMN_NAME form a30
     select * from scramble_ini ;
     exec dbms_stats.gather_table_stats( ownname=>'$fowner',  \
            tabname=> 'SCRAMBLE_INI', Degree=> 8, estimate_percent=> 100,  \
            granularity=>'ALL', cascade=>TRUE );
     exit ;
EOF

}
#............................................................
function write_init_dest
{
DEST=$1
touch $DEST
cat >> $DEST <<EOF!
#!/bin/sh
      sqlplus -s $CONNECT_STRING <<EOF
whenever sqlerror continue;
prompt WORKER : $pos
set lines 190 pages 0 timing on time on
spool scrambling_$pos.log

select 'start ;'|| sysdate from dual;
EOF!
}
#............................................................
function gen_workers 
{
set -x
radical=scrambling_worker
WORKER=${WORKER:-3}
WORKER=`expr $WORKER + 1`
MAX_SEQ=4
SEQ=0
TASK_CPT=1
#radical=bpaw
if [ ! -f  scrambling.sql ];then
   echo "I do not find scrambling.sql"
   exit
fi
rm ${radical}*.ksh 
pos=bef
DEST_BEF=${radical}_bef.ksh
write_init_dest $DEST_BEF

pos=after
DEST_AFTER=${radical}_after.ksh
write_init_dest $DEST_AFTER

pos=1
while [ $pos -lt $WORKER ] 
do
  eval DEST=${radical}${pos}.ksh
  write_init_dest $DEST
  pos=`expr $pos + 1`
done

pos=1

cat scrambling.sql |  grep -v '^spool' | grep -v '^set' | grep -v '^PL/SQL' | while read  line
do 
  a=`echo $line | cut -f1 -d' '`
  if [ "$a" = 'prompt' ] ;then
      TASK_CPT=`expr $TASK_CPT + 1`
      ret=`echo $line | grep before`
      if [ $? -eq 0 ];then
         eval DEST=$DEST_BEF 
         pos=bef
      else
        ret=`echo $line | grep after`
        if [ $? -eq 0 ];then
            eval DEST=$DEST_AFTER
            pos=after
        else 
            SEQ=`expr $SEQ + 1`
            if [ $SEQ -eq $MAX_SEQ ];then
               pos=`expr $pos + 1`
               SEQ=0
            fi
            if [ "$pos" = "bef" -o "$pos" = "after" ];then
                pos=1
            fi
            if [ pos -eq $WORKER ];then
                pos=1
            fi
            # set new target file for next loop
            eval DEST=${radical}${pos}.ksh
         fi
      fi
      echo " " >> $DEST
      line=`echo "$line" | sed 's/^prompt Doing/prompt Worker_'$pos': task '$TASK_CPT' Doing/'`
      echo "$line" >> $DEST
  else
      if [ "$a" = 'execute' -o "$a" = "update" -o "$a" = "--" ] ;then
         echo "$line" >> $DEST
      else
         echo "        $line" >> $DEST
      fi
  fi 
done
DO_ALL=do_all_${radical}.ksh
echo "rm nohup.out" > $DO_ALL
echo "rm ${radical}*.log" >> $DO_ALL
if [ -f ${radical}_bef.ksh ];then
   echo ${radical}_bef.ksh >> $DO_ALL
   echo  "EOF" >> ${radical}_bef.ksh
   chmod 755 ${radical}_bef.ksh 
fi
for i in `ls ${radical}?.ksh `
do
   echo "EOF" >> $i
   chmod 755 $i
   echo "nohup $i &" >> $DO_ALL
done
echo "wait" >> $DO_ALL
if [ -f ${radical}_after.ksh ];then
   echo ${radical}_after.ksh >> $DO_ALL
   echo  "EOF" >> ${radical}_after.ksh
   chmod 755  ${radical}_after.ksh
fi
chmod 755 $DO_ALL
ls -l $DO_ALL
ls -l ${radical}*.ksh
}
#............................................................
function uninstall 
{
for f in `echo $FUNC_LIST`
do
  echo "F=$f"
sqlplus -s $CONNECT_STRING <<EOF
  set serveroutput on
  declare
    ftype varchar2(30);
    cmd  varchar2(60) ;
  begin
    select object_type into ftype from user_objects where upper(object_name) = upper('$f');
    cmd:='drop ' ||ftype || ' $f'    ;
    dbms_output.put_line(cmd) ;
    execute immediate cmd ;
  exception
    when others then 
      dbms_output.put_line('Error : ' ||SQLCODE || ' '|| SQLERRM) ;
end ;
/
EOF
done
sqlplus -s $CONNECT_STRING <<EOF
  set serveroutput on
drop table scramble_ini ;
EOF
}
#............................................................
# ------------------------------------------------
# End  : Function section
# ------------------------------------------------


# ------------------------------------------------
#                Main
# ------------------------------------------------
# 
if [ -z "$1" ];then
   help
fi
while [ -n "$1" ]
do
  case "$1" in
    -install ) CHOICE=INSTALL ;;
      -split ) SPLIT_NR=$2 ; shift ;;
        -run ) CHOICE=RUN ;;
     -worker ) WORKER=$2 ;shift ;;
         -cs ) CONNECT_STRING=$2 ;shift ;;
  -uninstall ) CHOICE=UNINSTALL ;;
          -h ) help;;
           * ) echo "So what?" 
               help ;;
  esac
  shift
done
if [ "$CHOICE" = "INSTALL" ];then
   cr_table_scramble
   cr_rule_functions
   load_scramble_table
elif [ "$CHOICE" = "RUN" ];then
#   do_run > scrambling.sql      # I do not trust tee -a anymore. so often I got empty file
#   ls -l  scrambling.sql
   gen_workers
elif [ "$CHOICE" = "UNINSTALL" ];then
   uninstall
fi

