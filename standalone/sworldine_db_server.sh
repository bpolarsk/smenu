#!/bin/sh
# set -xv
# smenu_change_SID.sh

NAWK=${NAWK:-/bin/awk}
# -----------------------------------------------------------------
function help
{
    cat <<EOF

   List instances per host

     lsrv
     lsrv -f    : long hostname

     lsrv -h    : this help

EOF
}
# -----------------------------------------------------------------
NAME=short
while [ -n "$1" ]
do
  case "$1" in
         -f ) NAME=full ;;
         -h ) help
              exit;;
         -v ) set -xv ;;
  esac
  shift
done
if [ "$LOCAL_ORAENV" = "TRUE" ];then
   PS3=' Select SID ==> '
   if [ -n "$TNS_ADMIN" ];then  
       FILE=$TNS_ADMIN/tnsnames.ora
   else
       FILE=$SBIN/data/tnsnames.$TNS_TARGET
   fi
   if [ "$TNS_TARGET" = "prd" -o "$TNS_TARGET" = "ist" -o "$TNS_TARGET" = "rac" ];then
        FILE="$FILE $SBIN/data/tnsnames.add"
   fi
   cat $FILE |  sed -r ':r;$!{N;br};s:\n([[:blank:]])(\1*):<EOL>\1\2:g' | sort -k 7 -t = | sed -r '/^$/d;:l;G;s:(.*)<EOL>(.*)(\n):\1\3\2:;tl;$s:\n$::'| sed 's/-vip//' |$NAWK -v tgt="HOST" -v virg="," -v name="$NAME" 'BEGIN{cpt=0}
{
         if (/,/) {
              b=index($0,virg);
              bt[cpt]=substr($0,0, b-1);
              cpt=cpt+1 ;
         }
         if (/HOST = /) {
              a=index($0,tgt);
              if ( name == "short" ) {
                  b=index(substr($0, a+7),".");
                  host=substr($0, a+7,b-1);
              } 
              else {
                  b=index(substr($0, a+7),")");
                  host=substr($0, a+7,b-1);
              }
              if ( old_host != host ) {
                  if ( name == "short" ) {
                      printf("%-12.12s : ", host);
                  } else {
                      printf("%-30.30s : ", host);
                  }
                  old_host=host ;
                  for (i=0;i<cpt; i++){
                      printf("%-11.11s ", bt[i])
                  }
                  cpt=0;
                  printf("\n");
                  
            }
        }
         
}
END{
     if ( name == "short" ) {
        printf("%-12.12s : ", host);
     } else {
        printf("%-30.30s : ", host);
     }
     old_host=host ;
     for (i=0;i<cpt; i++){
            printf("%-11.11s ", bt[i])
     }
     printf("\n");
                  
}'
fi
