# /bin/sh
frelease=1
while :; do
  case "$1" in
  -v | --version ) fversion=$2 ; shift 2 ;;
  -r | --release ) frelease=$2 ; shift 2 ;;
  -- ) shift ; break ;;
  * ) break ;;
  esac
done

if [ ! -f template.spec ] ; then
	echo "Cannot find specfile template, sorry" >&2
	exit 1
fi

case $# in
0 )	echo "Usage: $0 [-v forced-version] [-r release] directories" >&2 ; exit 1 ;;
esac

for ca in "$@"
do
	release=$frelease
	ca=`echo $ca | sed -e 's/\/*$//'`

	if [ ! -d $ca ]; then
		echo "$ca is not a directory, skipped" >&2
		continue
	fi

	hash=`ls -1 $ca/*.0 2>/dev/null | sed -e 's/.*\///;s/\.0$//'`

	if [ x"$hash" = x"" ]; then
		echo "No valid CA cert found for $ca" >&2
		continue
	fi

	s=`expr 365 \* 86400`
	openssl x509 -noout -checkend $s -in $ca/$hash.0 || echo -e "***\nWARNING $ca will expire within 1 yr\n***" >&2

	if [ x"$fversion" = x"" ]; then
	  if [ -f $ca/CVS/Tag ]; then
		version=`sed -e 's/^.//' < $ca/CVS/Tag`
	  else
		version=unknown
	  fi
	else
	  version=$fversion
	fi

	if [ -f $ca/status ]; then
		prefix=`cat $ca/status`
	else
		prefix=accredited
	fi

	if [ x"$hash" = x"" ] ; then
		echo "$ca is not a CA dir" >&2
		continue
	fi

	case "$version" in
	v*r*	)	fversion=`echo $version | sed -e 's/^v//;s/_/\./g'` 
			version=`echo $fversion | sed -e 's/r.*//'` 
			release=`echo $fversion | sed -e 's/.*r//'` 
			;;
	v*	)	version=`echo $version | sed -e 's/^v//;s/_/\./g'`  ;;
	esac

	echo "CA $prefix $ca: building version $version release $release for hash $hash"

	rpmtop=`awk '/^%_topdir/ { t=$NF } END {print t}' $HOME/.rpmmacros`
	echo RPMDIR $rpmtop
	DATE=`date '+%a %b %m %Y'`

	sed -e 's/@VERSION@/'$version'/g;s/@RELEASE@/'$release'/g;s/@ALIAS@/'$ca'/g;s/@DATE@/'"$DATE"'/g' < template.spec > $ca/ca_$ca.spec

	( cd $ca ;
	tar -zchvf $rpmtop/SOURCES/$ca-$version.tar.gz ${hash}* ;
	mv -f ca_$ca.spec $rpmtop/SPECS/

	rpmbuild -ba $rpmtop/SPECS/ca_$ca.spec
	echo Build RPM and tar for version $version of CA $ca and copied it here.

	)

	[ -d $prefix ] || mkdir $prefix
	[ -d $prefix/RPMS ] || mkdir $prefix/RPMS
	[ -d $prefix/SRPMS ] || mkdir $prefix/SRPMS
	[ -d $prefix/tgz ] || mkdir $prefix/tgz

	cp -p $rpmtop/RPMS/noarch/ca_$ca-$version-$release.noarch.rpm ./$prefix/RPMS/
	cp -p $rpmtop/SRPMS/ca_$ca-$version-$release.src.rpm ./$prefix/SRPMS/
	cp -p $rpmtop/SOURCES/$ca-$version.tar.gz ./$prefix/tgz/

	ls -l $prefix/RPMS/ca_$ca-$version-$release.noarch.rpm
	ls -l $prefix/SRPMS/ca_$ca-$version-$release.src.rpm
	ls -l $prefix/tgz/$ca-$version.tar.gz

done
