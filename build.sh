# /bin/sh

release=1

if [ ! -f template.spec ] ; then
	echo "Cannot find specfile template, sorry" >&2
	exit 1
fi

case $# in
0 )	echo "Usage: $0 <version>" >&2 ; exit 1 ;;
esac

for ca in "$@"
do
	if [ ! -d $ca ]; then
		echo "$ca is not a directory, skipped" >&2
		continue
	fi

	if [ -f $ca/CVS/Tag ]; then
		version=`sed -e 's/^.//' < $ca/CVS/Tag`
	else
		version=unknown
	fi

	if [ -f $ca/hash ]; then
		hash=`cat $ca/hash`
	else
		hash=`ls -1 $ca/*.0 2>/dev/null | sed -e 's/.*\///;s/\.0$//'`
	fi

	if [ x"$hash" = x"" ] ; then
		echo "$ca is not a CA dir" >&2
		continue
	fi

	prefix=unknown_ca

	case "$version" in
	unknown	) prefix=unknown ;;
	t*	) prefix=test ;;
	v*	) version=`echo $version | sed -e 's/^v//;s/_/\./g'` ; prefix=accredited ;;
	u*	) version=`echo $version | sed -e 's/^u//;s/_/\./g'` ; prefix=worthless ;;
	o*	) version=`echo $version | sed -e 's/^o//;s/_/\./g'` ; prefix=others ;;
	esac

	echo "CA $prefix $ca: building version $version release $release for hash $hash"

	rpmtop=`awk '/^%_topdir/ { t=$NF } END {print t}' $HOME/.rpmmacros`
	echo RPMDIR $rpmtop
	DATE=`date '+%a %b %m %Y'`

	sed -e 's/@VERSION@/'$version'/g;s/@RELEASE@/'$release'/g;s/@ALIAS@/'$ca'/g;s/@DATE@/'"$DATE"'/g' < template.spec > $ca/ca_$ca.spec

	( cd $ca ;
	tar -zchvf $rpmtop/SOURCES/$ca-$version.tar.gz ${hash}* ;
	cp -p ca_$ca.spec $rpmtop/SPECS/

	rpmbuild -ba $rpmtop/SPECS/ca_$ca.spec
	echo Build RPM and tar for version $version of CA $ca and copied it here.

	)

	[ -d RPMS.$prefix ] || mkdir RPMS.$prefix
	[ -d SRPMS.$prefix ] || mkdir SRPMS.$prefix
	[ -d tgz.$prefix ] || mkdir tgz.$prefix

	cp -p $rpmtop/RPMS/noarch/ca_$ca-$version-$release.noarch.rpm ./RPMS.$prefix
	cp -p $rpmtop/SRPMS/ca_$ca-$version-$release.src.rpm ./SRPMS.$prefix
	cp -p $rpmtop/SOURCES/$ca-$version.tar.gz ./tgz.$prefix

	ls -l RPMS.$prefix/ca_$ca-$version-$release.noarch.rpm
	ls -l SRPMS.$prefix/ca_$ca-$version-$release.src.rpm
	ls -l tgz.$prefix/$ca-$version.tar.gz

done
