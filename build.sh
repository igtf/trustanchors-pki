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
	if [ -f $ca/CVS/Tag ]; then
		version=`sed -e 's/^N//' < $ca/CVS/Tag`
	else
		version=unknown
	fi

	if [ -f $ca/hash ]; then
		hash=`cat $ca/hash`
	else
		hash=`ls -1 $ca/*.0 | sed -e 's/.*\///;s/\.0$//'`
	fi

	echo "CA $ca: building version $version release $release for hash $hash"

	rpmtop=`awk '/^%_topdir/ { t=$NF } END {print t}' $HOME/.rpmmacros`
	echo RPMDIR $rpmtop
	DATE=`date '+%a %b %m %Y'`

	sed -e 's/@VERSION@/'$version'/g;s/@RELEASE@/'$release'/g;s/@ALIAS@/'$ca'/g;s/@DATE@/'"$DATE"'/g' < template.spec > $ca/ca_$ca.spec

	( cd $ca ;
	tar -zchvf $rpmtop/SOURCES/$ca-$version.tar.gz ${hash}* ;
	cp -p ca_$ca.spec $rpmtop/SPECS/

	rpmbuild -ba $rpmtop/SPECS/ca_$ca.spec
	cp -p $rpmtop/RPMS/noarch/ca_$ca-$version-$release.noarch.rpm .
	cp -p $rpmtop/SRPMS/ca_$ca-$version-$release.src.rpm .
	cp -p $rpmtop/SOURCES/$ca-$version.tar.gz .
	echo Build RPM and tar for version $version of CA $ca and copied it here.

	)

	ls -l $ca/ca_$ca-$version-$release.noarch.rpm
	ls -l $ca/ca_$ca-$version-$release.src.rpm
	ls -l $ca/$ca-$version.tar.gz

done
