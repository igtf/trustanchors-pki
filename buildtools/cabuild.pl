#! /usr/bin/perl -w
#
# @(#)$Id$
#
# The IGTF CA build script
#
use Getopt::Long;
use POSIX qw(strftime);
use File::Temp qw(tempdir);
use File::Copy qw(copy move);
use strict;
use vars qw(@validStatus $opt_f $err $opt_r $opt_tmp 
	$opt_version $opt_o $opt_carep $opt_gver %auth);

$opt_tmp="/tmp";
$opt_carep="../";
$opt_o="../distribution";
$opt_r=1;

my @optdef=qw( f v gver|distversion=s version|ver=s r|release=s 
    carep|repository=s tmp|tmpdir=s o|target=s );

$0 =~ s/.*\///;
&GetOptions(@optdef);
$opt_gver=$opt_version unless $opt_gver;
$opt_gver or die "Need at least a global version (--gver=) option\n";

# ----------------------------------------------------------------------------
# configuration settings
#
@validStatus = qw(accredited:classic accredited:slcgs 
                  discontinued experimental worthless );
$Main::singleSpecFileTemplate="ca_single.spec.cin";
$Main::collectionSpecFileTemplate="ca_bundle.spec.cin";
$Main::bundleMakefileTPL="Makefile.tpl.cin";
$Main::bundleConfigureTPL="configure.cin";
@Main::infoGlob=("*/*.info","*/*/*.info");
# ----------------------------------------------------------------------------


$opt_f and system("rm -fr $opt_o > /dev/null 2>&1");
&generateDistDirectory($opt_o) or die "generateDistDirectory: $err\n";

# fill list of authorities and resolve versions early to make
# inter-RPM dependendies for certificate chains
#
%auth = &getAuthoritiesList($opt_carep,$opt_version);


print "Generating global version $opt_gver\n";

my $tmpdir=tempdir("$opt_tmp/pBundle-XXXXXX", CLEANUP => 0 );
my $bundledir="$tmpdir/igtf-policy-accredited-bundle-$opt_gver";
mkdir $bundledir;

print "  bundle directory $bundledir\n\n";

foreach my $k ( sort keys %auth ) {
  my %info = %{$auth{$k}{"info"}};
  &packSingleCA($auth{$k}{"dir"},$bundledir,$opt_o,$auth{$k}{"hash"},%info) 
    or die "packSingleCA: $err\n";
}

&makeCollectionInfo($opt_carep,$bundledir,$opt_o)
    or die "makeCollectionInfo: $err\n";

&makeBundleScripts($bundledir,$tmpdir,$opt_o)
    or die "makeBundleScripts: $err\n";

1;

# ----------------------------------------------------------------------------
# sub makeBundleScripts($builddir,$tmpdir,$targetdir)
# 
sub makeBundleScripts($$$) {
  my ($builddir,$tmpdir,$targetdir) = @_;

  -d "$builddir" or do {
    $err="Build source directory $builddir does not exist";
    return undef;
  };
  -d "$targetdir/accredited" or do {
    $err="Target directory $targetdir/accredited does not exist";
    return undef;
  };

  copy($Main::bundleMakefileTPL,"$builddir/Makefile.tpl") or do {
    $err="Cannot copy makefile template header: $!";
    return undef;
  };

  open MKTPL,">>$builddir/Makefile.tpl" or do {
    $err="Cannot open makefile template for append: $!";
    return undef;
  };
  
  print MKTPL "# Created: ".gmtime(time)." GMT\n#\n";

  my $prodcas=""; my $ca;
  foreach my $s ( @validStatus ) {
    my $pname;
    if ($s=~/^accredited/) { 
      ($pname=$s)=~s/.*://; 
      $prodcas.=" install-$pname" 
    } else { $pname=$s }
    print MKTPL "install-$pname:";
    foreach $ca ( sort keys %auth ) {
      print MKTPL " $ca" unless $auth{$ca}{"info"}->{"status"} ne $s;
    }
    print MKTPL "\n\t\@echo Installing CAs for profile $s\n";
    $s=~/^accredited/ and 
      print MKTPL "\t\$(install) policy-igtf-$pname.info \$(prefix)/\n";
    print MKTPL "\n";
  }
  print MKTPL "install-production: $prodcas\n".
              "\t\@echo Installing all IGTF production-level CAs\n".
              "\t\$(install) policy-igtf.info \$(prefix)/\n\n";
  print MKTPL "#\n# single CA installations\n#\n\n";

  foreach $ca ( sort keys %auth ) {
    print MKTPL "$ca: prep\n";
    foreach my $ext ( glob("$builddir/".$auth{$ca}{"hash"}.".*") ) {
      (my $f=$ext)=~s/.*\///;
      print MKTPL "\t\$(install) $f \$(prefix)/\n";
    }
    print MKTPL "\n";
  }
  close MKTPL;

  copy($Main::bundleConfigureTPL,"$builddir/configure") or do {
    $err="Cannot copy configure template: $!";
    return undef;
  };
  chmod 0755, "$builddir/configure" or do {
    $err="Cannot set executable mode on configure template: $!";
    return undef;
  };

  system("cd $tmpdir && tar zcf igtf-policy-accredited-bundle-$opt_gver.tar.gz igtf-policy-accredited-bundle-$opt_gver");

  copy("$tmpdir/igtf-policy-accredited-bundle-$opt_gver.tar.gz","$targetdir/accredited/igtf-policy-accredited-bundle-$opt_gver.tar.gz");

  return 1;
}


# ----------------------------------------------------------------------------
# sub makeCollectionInfo($srcdir,$builddir,$targetdir)
#
# generate the tarball with the meta-packages info file, and generate
# the RPM based on the template
# leave the contents of the tarball also in the $builddir
#
sub makeCollectionInfo($$$) {
  my ($srcdir,$builddir,$targetdir) = @_;

  my $tmpdir=tempdir("$opt_tmp/pCIF-XXXXXX", CLEANUP => 0 );
  print "** Collection Information File Generation v$opt_gver\n";
  print "   generating in $tmpdir\n";


  my $pname="ca_policy_igtf-$opt_gver";
  my $pdir="$tmpdir/$pname";
  mkdir $pdir;
  my %fh;
  
  # first the top-level file (with an explicit list of profiles)
  open INFOTL,">$pdir/policy-igtf.info"  or do {
    $err="Cannot open file $pdir/ca-policy_igtf-$pname: $!\n";
    return undef;
  };
  print INFOTL "# @(#)policy-igtf.info - Autogenerated file\n";
  print INFOTL "version = $opt_gver\nrequires = \\\n";
  foreach my $s ( @validStatus ) {
    $s=~/^accredited/ or next; (my $pname=$s)=~s/.*://;
    open INFO,">$pdir/policy-igtf-$pname.info"  or do {
      $err="Cannot open file $pdir/ca_policy_igtf-$pname: $!\n";
      return undef;
    };
    print INFO "# @(#)policy-igtf-$pname.info - Autogenerated file\n";
    print INFO "version = $opt_gver\nrequires = \\\n";
    # loop over all accredited CAs fo rthis profile and add them to
    # this and the top-level file
    foreach my $alias ( keys %auth ) {
      next if $auth{$alias}{"info"}->{"status"} ne $s;
      print INFO   "   $alias = ".$auth{$alias}{"info"}->{"version"}.", \\\n";
      print INFOTL "   $alias = ".$auth{$alias}{"info"}->{"version"}.", \\\n";
    }
    close INFO;
  }
  close INFOTL;

  # collect info files for the tgz bundle
  defined $builddir and do {
    foreach my $f ( glob("$pdir/*") ) { 
      (my $b=$f)=~s/.*\///; 
      copy("$f","$builddir/$b");
    }
  };

  # the info separate tarball 
  system("cd $tmpdir && tar zcf $pname.tar.gz $pname");
  copy("$tmpdir/$pname.tar.gz",
    "$targetdir/accredited/tgz/");

  # build RPM distribution
  my %tokens = ( "VERSION" => $opt_gver,
	  "RELEASE" => $opt_r,
	  "PACKAGENAME" => $pname,
	  "TGZNAME" => "$pname.tar.gz",
	);

  foreach my $s ( @validStatus ) {
    $s=~/^accredited/ or next; my $ucs=uc($s);
    my $l="";
    foreach my $alias ( keys %auth ) {
      next if $auth{$alias}{"info"}->{"status"} ne $s;
      if( $l ne "" ) { $l.=", " }
      $l.="$alias";
    }
    $tokens{$ucs}=&expandRequiresWithVersion($l);
  }
  
  &copyWithExpansion($Main::collectionSpecFileTemplate,"$tmpdir/$pname.spec",
                     %tokens);

  chomp(my $sourcedir=`rpm --eval %_sourcedir`);
  chomp(my $rpmdir=`rpm --eval %_rpmdir`);
  chomp(my $srcrpmdir=`rpm --eval %_srcrpmdir`);
  if ($sourcedir =~ /^%/ || $rpmdir =~ /^%/ || $srcrpmdir =~ /^%/ )  {
    $err="Setup error (no %_source,rpm,srcrpm dir)"; 
    return undef;
  }

  copy("$tmpdir/$pname.tar.gz","$sourcedir/$pname.tar.gz");
  system("rpmbuild --quiet -ba $tmpdir/$pname.spec");

  # now collect all information in the proper place
  foreach my $n ( 
                  "ca_policy_igtf-classic-$opt_gver",
                  "ca_policy_igtf-$opt_gver",
                  "ca_policy_igtf-slcgs-$opt_gver" ) {
    move("$rpmdir/noarch/$n-$opt_r.noarch.rpm",
      "$targetdir/accredited/RPMS/") or do {
      $err="Cannot move $n-$opt_r.noarch.rpm to accredited/RPMS/: $!";
      return undef;
    };
  }
  move("$srcrpmdir/$pname-$opt_r.src.rpm",
    "$targetdir/accredited/SRPMS") or do {
      $err="Cannor move $pname-$opt_r.src.rpm to SRPMS/: $!";
      return undef;
    };


  return 1;
}

# ----------------------------------------------------------------------------
# sub expandRequiresWithVersion($requiresLine)
#
# makes a 'Requires:' line explicit by adding an "=version" to each
# ca alias found in the list. List must be comma-separated. Whitespace
# in the input requires line is ignored.
#
sub expandRequiresWithVersion($) {
  my ($requiresLine) = @_;
  my $vLine=""; 

  return undef unless defined $requiresLine;
  return "" if $requiresLine=~/^\s*$/;

  foreach my $alias ( split(/,/,$requiresLine) ) {
    $alias=~s/\s//g;
    my $r;
    if ($auth{$alias}{"info"}->{"version"}) {
      $r="$alias = ".$auth{$alias}{"info"}->{"version"};
    } else {
      $r="$alias";
    }
    if( $vLine ne "" ) { $vLine.=", " }
    $vLine .= "$r";
  }

  return $vLine;
}

# ----------------------------------------------------------------------------
# sub getAuthoritiesList($dir,$opt_version)
#
# collect all CAs anywhere in the tree (1 level deep)
# and resolve version and version style in the info hash
#
sub getAuthoritiesList($$) {
  my ($carepdir,$eVersion) = @_;
  my %auth;

  foreach my $pat ( @Main::infoGlob ) {
  foreach my $f ( glob("$carepdir/$pat") ) {
    (my $dir=$f)=~s/\/[^\/]+$//;
    (my $hash=$f)=~s/.*\/([a-f0-9]{8})\.info/$1/;
    my %info=&readInfoFile($f);

    my $version=undef;
    $version=($eVersion or ($info{"version"}=~/@/) ? $eVersion : undef );
    $version=$info{"version"} unless ($eVersion or ($info{"version"}=~/@/));
    $version=&getFilesVersion($version,"$dir/$hash.*");
    $info{"version"} = $version;

    $auth{$info{"alias"}} = 
      { "hash" => $hash, "dir" => $dir, "info" => \%info };
    #print "Added CA $hash with version $version\n";
  }
  }
  return %auth;
}


# ----------------------------------------------------------------------------
# sub generateDistDirectory($targetdir)
#
# Generate the directory structure for the final distribution. It should be:
#     TOP
#     +- accredited
#        +- RPMS
#        +- SRPMS
#        +- tgz
#     +- apt
#        +- RPMS.accredited
#        +- RPMS.experimental
#        +- RPMS.worthless
#     +- {experimental,worthless}
#        +- RPMS
#        +- SRPMS
#        +- tgz

sub generateDistDirectory($) {
  my ($dir) = @_;

  -d $dir and $err="$dir already exists, clean first" and return undef;
  mkdir $dir or return undef;

  mkdir "$dir/apt" or return undef;
  for my $s ( qw(accredited experimental worthless) ) {
    mkdir "$dir/$s" or return undef;
    mkdir "$dir/apt/RPMS.$s" or return undef;
    for my $t ( qw (RPMS SRPMS tgz) ) {
      mkdir "$dir/$s/$t" or return undef;
    }
  }
  return 1;
}

# ----------------------------------------------------------------------------
# sub packCA($srcdir,$builddir,$targetdir,$hash,%info)
#
# package a single CA in all formats, and store these in the proper
# structure in the target directory
#
# - prerequisites: <hash>.{0,info,singing_policy} files must exist in
#   $srcdir; $targetdir must exist and be initialised
#   $builddir will be created in /tmp if needed (and then removed later)
# - results: RPM, SRPM, tar.gz packages for this CA
# - return code: 1 if OK, 0 if error and $err will be set
#
sub packSingleCA($$$$) {
  my ($srcdir,$builddir,$targetdir,$hash,%info) = @_;

  -f "$srcdir/$hash.0" or do {
    $err="packSingleCA failed: $srcdir/$hash.0 not available: $!";
    return undef;
  };
  -f "$srcdir/$hash.info" or do {
    $err="packSingleCA failed: $srcdir/$hash.0 not available: $!";
    return undef;
  };

  # essential information MUST be there
  $info{"alias"} or $err="CA $hash has no alias" and return undef;
  $info{"status"} or $err="CA $hash has no status at all" and return undef;
  { my $sts="";
    foreach my $ts ( @validStatus ) { 
      if ($info{"status"} eq $ts) { $sts=$ts; last; } 
    }
    if ( $sts ne $info{"status"} ) {
      $err="CA $info{alias} has impossible status $info{status}, cannot continue";
      return undef;
    }
  }

  # don't include old and dusty CAs
  return 1 if $info{"status"} eq "discontinued";


  my $tmpdir=tempdir("$opt_tmp/pSCA-$hash-XXXXXX", CLEANUP => 1 );
  print "** CA $info{alias} v$info{version} (hash $hash, dir $srcdir)\n";
  print "   generating in $tmpdir\n";


  (my $collection=$info{"status"})=~s/:.*//;
  my $pname="ca_".$info{"alias"}."-".$info{"version"};
  my $pdir="$tmpdir/$pname";
  mkdir $pdir;
  foreach my $ext ( qw(info signing_policy) ) {
    &copyWithExpansion("$srcdir/$hash.$ext","$pdir/$hash.$ext",
	( "VERSION" => $info{"version"} ) );
  }
  if ( $info{"crl_url"} ) {
    open CRLURL,">$pdir/$hash.crl_url" or 
      $err="Cannot open $pdir/$hash.crl_url for write: $!" and return undef;
    print CRLURL $info{"crl_url"}."\n";
    close CRLURL;
  }

  my $i=0;
  while ( -f "$srcdir/$hash.$i" ) { 
    copy("$srcdir/$hash.$i","$pdir/$hash.$i");
    $i++;
  }

  system("cd $tmpdir && tar zcf $pname.tar.gz $pname");
  defined $builddir and do {
    foreach my $f ( glob("$pdir/*") ) { 
      (my $b=$f)=~s/.*\///; 
      copy("$f","$builddir/$b");
    }
  };
  
  &copyWithExpansion($Main::singleSpecFileTemplate,"$tmpdir/$pname.spec",
	( "VERSION" => $info{"version"},
	  "RELEASE" => $opt_r,
	  "ALIAS" => $info{"alias"},
	  "HASH" => $hash,
	  "PACKAGENAME" => $pname,
	  "TGZNAME" => "$pname.tar.gz",
	  "URL" => $info{"url"},
	  "COLLECTION" => $collection,
	  "REQUIRES" => &expandRequiresWithVersion($info{"requires"})
	) 
    );

  chomp(my $sourcedir=`rpm --eval %_sourcedir`);
  chomp(my $rpmdir=`rpm --eval %_rpmdir`);
  chomp(my $srcrpmdir=`rpm --eval %_srcrpmdir`);
  if ($sourcedir =~ /^%/ || $rpmdir =~ /^%/ || $srcrpmdir =~ /^%/ )  {
    $err="Setup error (no %_source,rpm,srcrpm dir)"; 
    return undef;
  }

  copy("$tmpdir/$pname.tar.gz","$sourcedir/$pname.tar.gz");
  system("rpmbuild --quiet -ba $tmpdir/$pname.spec >/dev/null 2>&1");

  # now collect all information in the proper place
  move("$rpmdir/noarch/$pname-$opt_r.noarch.rpm",
    "$targetdir/$collection/RPMS/");
  move("$srcrpmdir/$pname-$opt_r.src.rpm",
    "$targetdir/$collection/SRPMS");
  move("$tmpdir/$pname.tar.gz",
    "$targetdir/$collection/tgz/");

  return 1;
}










# ----------------------------------------------------------------------------
# readInfoFile($filename)
# returns: hash with information
#
sub readInfoFile($) {
  my ($filename) = @_;
  my ($attr,$val,$l,%info);

  -r "$filename" or 
    ($err="Cannot read info file $filename: $!") and return undef;

  open F,"$filename" or die "Still cannot read $filename: $!\n";
  while ($l=<F>) {
    chomp($l);
    while ($l=~/\\$/) {chop($l);chomp($l.=<F>)}
    $l=~s/\s*#.*$//; $l=~s/^\s*//; $l=~/^\s*$/ and next;
    ($attr,$val)=split(/\s*=\s*/,$l,2);
    $info{$attr}=$val unless ($attr eq "");
  }
  close F;
  return %info;
}

# ----------------------------------------------------------------------------
# copyWithExpansion($src,$dst,%table)
#
sub copyWithExpansion($$%) {
  my ($src,$dst,%table) = @_;

  open SRC,"$src" or $err="$src: $!" and return undef;
  open DST,">$dst" or $err="$dst: $!" and return undef;

  while (my $l=<SRC>) {
    foreach my $tok ( keys %table ) {
      defined $table{$tok} or $table{$tok}="";
      $l=~s/\@$tok\@/$table{$tok}/g;
    }
    print DST $l;
  }
  close SRC;
  close DST;
  return 1;
}


# ----------------------------------------------------------------------------
# getFilesVersion($version,$glob)
#
# - returns: preferred version  or undef on error ($err will be set)
sub getFilesVersion($$) {
  my ($requestedVersion,$glob) = @_;
  my ($version);

  return $requestedVersion if defined $requestedVersion;
  my @filelist = glob($glob);
  foreach my $file ( @filelist ) {
    my $mdate= (stat $file)[9];
    $version = $mdate if ! defined $version or ($mdate>$version);
  }
  if (! defined $version ) {
    $err="cannot determine version as no files match $glob";
    return undef;
  };
  $version = strftime "%Y%m%d",gmtime($version);
  return $version;
}