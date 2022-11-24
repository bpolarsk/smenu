#!/bin/sh
# 25 December 2006
# this script is from Chris foot
# http://www.dbazine.com/blogs/blog-cf/chrisfoot/blogentry.2005-09-17.7657940139

{
echo "*************************************************"
echo "`date '+Execution Start Time:%H:%M:%S Date:%m-%d-%y'`"
echo " "
echo "Remove several files in agent directory to"
echo "enable agent to re-register with the EM console"
echo " "

if [[ `grep EM_AGENT_VERSION /etc/oratab` == "" ]]
then
   echo "Varable EM_AGENT_VERSION is not set in /etc/oratab"
   echo "the current ORACLE_HOME will be used"
else 
   echo "Using EM_AGENT_VERSION for ORACLE_HOME from /etc/oratab"
   #export ORACLE_HOME=`grep EM_AGENT_VERSION /etc/oratab | awk '{ print $3; exit }' `
fi

echo " "
echo "EM Agent HOME is:" ${ORACLE_HOME}
echo " "
  
if [[ $1 == "Y" ]]
then
   echo " "
   echo "  Stop the agent on the target node"
   $ORACLE_HOME/bin/emctl stop agent

   echo ""
   echo "Removing EM files"
   echo "rm -r $ORACLE_HOME/sysman/emd/state/*"
   rm -r $ORACLE_HOME/sysman/emd/state/*

   echo ""
   echo "rm -r $ORACLE_HOME/sysman/emd/collection/*"
   rm -r $ORACLE_HOME/sysman/emd/collection/*

   echo ""
   echo "rm -r $ORACLE_HOME/sysman/emd/upload/*"
   rm -r $ORACLE_HOME/sysman/emd/upload/*

   echo ""
   echo "rm $ORACLE_HOME/sysman/emd/lastupld.xml"
   rm $ORACLE_HOME/sysman/emd/lastupld.xml

   echo ""
   echo "rm $ORACLE_HOME/sysman/emd/agntstmp.txt"
   rm $ORACLE_HOME/sysman/emd/agntstmp.txt

   echo ""
   echo "rm $ORACLE_HOME/sysman/emd/blackouts.xml"
   rm $ORACLE_HOME/sysman/emd/blackouts.xml

   echo ""
   echo "rm $ORACLE_HOME/sysman/emd/protocol.ini"
   rm $ORACLE_HOME/sysman/emd/protocol.ini

   echo ""
   echo "Issues an agent cleanstate from teh agent home"
   ${ORACLE_HOME}/bin/emctl clearstate

   echo ""
   echo "Start the agent"
   ${ORACLE_HOME}/bin/emctl start agent

   echo ""
   echo "Force an upload to the OMS"
   ${ORACLE_HOME}/bin/emctl upload

   echo ""
   echo "Display Agent Status"
   ${ORACLE_HOME}/bin/emctl status agent 
else
   echo ""
   echo "-------------------------------------------------"
   echo "If the ORACLE_HOME is set correctly "
   echo "  type:   clean_up_oms.sh Y "
   echo "-------------------------------------------------"
fi

echo " Log file: /opt/oracle/admin/general/log/clean_up_oms.log"
echo " "
echo "`date '+Execution End Time:%H:%M:%S Date:%m-%d-%y'`"
echo " "
echo "*************************************************"
} | tee -a /opt/oracle/admin/general/log/clean_up_oms.log 
exit 0  
