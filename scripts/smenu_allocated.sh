#!/usr/bin/ksh
# Program  : smenu_allocated.sh
# Author   : J. Vermue
#            Adapted  to smenu by B. Polarski

function A1 {
awk '
BEGIN{
printf "%13s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n","Filesystem","DB\ Used\ Space","DB\ Maxsize","DB\ Max\ Growth","FS\ Capacity","FS\ Free\ Space","%\ Used","FS\ After\ Growth"
printf "%13s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n","----------","-------------","----------","-------------","-----------","-------------","-----","---------------"
}
{
"df -k "$1" | sed -n '2p'"|getline data
n=split(data,vector)
printf "%15s %8.2f Gb\t%8.2f Gb\t%8.2f Gb\t%8.2f Gb\t%8.2f Gb\t%s\t%8.2f Gb\t\n",$1,$2/1024/1024,$3/1024/1024,$4/1024/1024,vector[2]/1024/1024,vector[3]/1024/1024,vector[4],(vector[3]-$4)/1024/1024
}
'

}

function A2 {

awk '
BEGIN{
printf "%13s\t%s\t%s\t%s\t%s\t%s\t%s\t%s %c\n","Filesystem","DB\ Used\ Space","DB\ Maxsize","DB\ Max\ Growth","FS\ Capacity","FS\ Free\ Space","%\ Used","FS\ After\ Growth","T"
printf "%13s\t%s\t%s\t%s\t%s\t%s\t%s\t%s %c\n","----------","-------------","----------","-------------","-----------","-------------","-----","---------------","-"
}
{
if ($NF!=prev && NR>1 ) {
if (n>1) {
printf "%104s %11s\n"," ","----------"
printf "%103s %8.2f Gb\n\n","Sub Total: ",sum/1024/1024
}
else print ""
sum=0
n=0
}

n++
prev=$NF
"df -k "$1" | sed -n '2p'"|getline data
num=split(data,vector)
sum+=(vector[3]-$4)

printf "%15s %8.2f Gb\t%8.2f Gb\t%8.2f Gb\t%8.2f Gb\t%8.2f Gb\t%s\t%8.2f Gb\t%c\n",$1,$2/1024/1024,$3/1024/1024,$4/1024/1024,vector[2]/1024/1024,vector[3]/1024/1024,vector[4],(vector[3]-$4)/1024/1024,$5
A[$1]++; if(A[$1] > 1) { print $1 " has Indexes and Data mixed up!"; exit }
}

END{
if (A[$1]<=1 && n>1) printf "%103s %8.2f Gb\n\n","Sub Total: ",sum/1024/1024
}'
}

T=''
G=''
postprocessing=A1

if [ "$1" ]
then
T=",decode(substr(file_name, instr(file_name,'/',-1,1)+4,1),'I','I','D','D','X') Type"
G=",decode(substr(file_name, instr(file_name,'/',-1,1)+4,1),'I','I','D','D','X') order by Type"
postprocessing=A2
fi

{


. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

sqlplus -s "$CONNECT_STRING" <<EOF
set pages 0 feedback off
col Disk format a35
Select substr(file_name, 1,instr(file_name,'/',-1)-1) Disk
     , sum(bytes)/1024 "Used"
     , sum(Greatest(bytes, maxbytes))/1024 "Virtual Maxsize"
     , sum(Greatest(bytes, maxbytes) - bytes)/1024 Grow $T
  From
     (select file_name,bytes,maxbytes from DBA_Data_Files
          union all
          select file_name,bytes,maxbytes from DBA_Temp_Files)
 Group By substr(file_name, 1,instr(file_name,'/',-1)-1) $G;
EOF
} | sed '/^ *$/d' | $postprocessing


