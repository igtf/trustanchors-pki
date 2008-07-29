#!/bin/sh
verb=0

while :
do
  case "$1" in
  -v ) verb=1 ; shift ;;
  -- ) shift ; break ;;
  -* ) echo "$0: unknown option $1, exiting" >&2 ; exit 127 ;;
  * ) break ;;
  esac
done

nfail=0

FDIR=./
for f in `ls -1 "$@"` ; do
tag=`openssl x509 -noout -modulus -in $f|sha1sum|cut -d ' ' -f 1|cut -c21-41`;
serial=`openssl x509 -noout -serial -in $f|sed -e 's/serial= *//g'` ;
if [ `fgrep -c $tag $FDIR/blacklist.RSA-1024` \
     -ne 0 -o \
     `fgrep -c $tag $FDIR/blacklist.RSA-2048` \
     -ne 0 ] ; then
  dn=`openssl x509 -noout -subject -in $f| sed -e 's/subject= //'` ;
  caid=`awk '/Tag:/ { print $NF}' $f` ;
  echo "Vulnerable: $serial $caid $dn" ;
  nfail=`expr 1 + $nfail`
else
  [ "$verb" -ne 0 ] && echo "OK: $serial $caid $dn"
fi ;
done

exit $nfail
