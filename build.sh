# /bin/sh
#
# $Id: build.sh,v 1.12 2005/04/26 16:56:17 pmacvsdg Exp $

help() {
 echo "Usage: $0 [-f] [-v forced-version] [-r release] [-b buildroot]" >&2 
 exit $1
}

frelease=1
force=0
BUILDROOT=../build
while :; do
  case "$1" in
  -v | --version ) fversion=$2 ; shift 2 ;;
  -b | --buildroot ) BUILDROOT=$2 ; shift 2 ;;
  -r | --release ) frelease=$2 ; shift 2 ;;
  -h | --help ) help ;;
  -f | --force ) force=1 ; shift 1 ;;
  -- ) shift ; break ;;
  * ) break ;;
  esac
done

if [ ! -f template.spec ] ; then
	echo "Cannot find specfile template, sorry" >&2
	exit 1
fi

case $# in
0 )	;;
* )	help;;
esac

if [ -d $BUILDROOT ]; then
  echo "Warning: buildroot $BUILDROOT already exists. Remove first..." >&2
  if [ $force -eq 1 ]; then
    echo "Removing it for you (--force specified). OK? (or press ^C" >&2
    read x
    rm -r $BUILDROOT
  else
    exit 1
  fi
fi

mkdir -p $BUILDROOT

# new algorithm: loop over all possible directories here to find
# CA files. An RPM is built for each <hash>.alias file, named after
# this alias, and stored in the directory $BUILDROOT/`<hash>.status`,
# unless the CA name is in accredited.in
#

isaccredited() {
  awk 'BEGIN {s=0} $1 == '$1' { s=1 } END {print s}' accredited.in
}

for cadir in `find . -type d`
do
  [ `expr match "$cadir" ".*CVS.*"` -ne 0 ] && continue

  for caliasfile in `ls -1 $cadir/????????.alias 2>/dev/null`
  do
	release=$frelease
	
	ca=`cat $caliasfile`
	cafile=`basename $caliasfile .alias`
	hash=`openssl x509 -hash -noout -in $cadir/$cafile.0 2>/dev/null`

	# now, hash must be the same as cafile basename
	if [ x"$hash" != x"$cafile" ]; then
		echo "No valid CA cert found for $ca" >&2
		continue
	fi

	s=`expr 365 \* 86400`
	openssl x509 -noout -checkend $s -in $ca/$cafile.0 || \
		echo -e "***\nWARNING $ca will expire within 1 yr\n***" >&2

	if [ x"$fversion" = x"" ]; then
	  if [ -f $cadir/CVS/Tag ]; then
		version=`sed -e 's/^.//' < $ca/CVS/Tag`
	  else
		version=0.unknown
	  fi
	else
	  version=$fversion
	fi

	if [ -f $cadir/$cafile.status ]; then
		prefix=`cat $cadir/$cafile.status`
	elif [ -f $cadir/status  ]; then
		prefix=`cat $cadir/status`
	elif [ `isaccredited $ca` -eq 1 ]; then
		prefix=accredited
	else
		prefix=unknown
	fi

	echo $caliasfile $cadir $cafile $hash $ca $prefix

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

	sed -e '
		s/@VERSION@/'$version'/g;
		s/@HASH@/'$hash'/g;
		s/@RELEASE@/'$release'/g;
		s/@ALIAS@/'$ca'/g;
		s/@DATE@/'"$DATE"'/g' \
			< template.spec > $ca/ca_$ca.spec

	( cd $cadir ;
	tar -zchvf $rpmtop/SOURCES/$ca-$version.tar.gz ${hash}* ;
	mv -f ca_$ca.spec $rpmtop/SPECS/

	rpmbuild -ba $rpmtop/SPECS/ca_$ca.spec
	echo Build RPM and tar for version $version of CA $ca and copied it here.

	)

	[ -d $BUILDROOT/$prefix ] || mkdir $BUILDROOT/$prefix
	[ -d $BUILDROOT/$prefix/RPMS ] || mkdir $BUILDROOT/$prefix/RPMS
	[ -d $BUILDROOT/$prefix/SRPMS ] || mkdir $BUILDROOT/$prefix/SRPMS
	[ -d $BUILDROOT/$prefix/tgz ] || mkdir $BUILDROOT/$prefix/tgz

	cp -p $rpmtop/RPMS/noarch/ca_$ca-$version-$release.noarch.rpm $BUILDROOT/$prefix/RPMS/
	cp -p $rpmtop/SRPMS/ca_$ca-$version-$release.src.rpm $BUILDROOT/$prefix/SRPMS/
	cp -p $rpmtop/SOURCES/$ca-$version.tar.gz $BUILDROOT/$prefix/tgz/

	ls -l $BUILDROOT/$prefix/RPMS/ca_$ca-$version-$release.noarch.rpm
	ls -l $BUILDROOT/$prefix/SRPMS/ca_$ca-$version-$release.src.rpm
	ls -l $BUILDROOT/$prefix/tgz/$ca-$version.tar.gz

  done
done
