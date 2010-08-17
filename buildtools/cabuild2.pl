#! /usr/bin/perl -w
#
# @(#)$Id: cabuild2.pl,v 1.1 2010/01/05 21:38:02 pmacvsdg Exp $
#
# The IGTF CA build script
#
use Getopt::Long;
use POSIX qw(strftime);
use File::Temp qw(tempdir);
use File::Copy qw(copy move);
use strict;
use vars qw(@validStatus $opt_f $err $opt_r $opt_tmp $opt_nojks
	$opt_debian $opt_v $opt_url $opt_s $opt_version $opt_o $opt_carep $opt_obsoletedbase $opt_gver %auth
        $opt_opensslzero $opt_opensslone
    );

$opt_tmp="/tmp";
$opt_carep="../";
$opt_o="../distribution";
$opt_r=1;
$opt_debian="./check-debian.sh";
$opt_obsoletedbase="./obsoleted";
$opt_opensslzero="/usr/bin/openssl";
$opt_opensslone="/opt/openssl1/bin/openssl";

my @optdef=qw( url|finalURL=s nojks:i
    s|sign f v:i gver|distversion=s version|ver=s r|release=s 
    carep|repository=s tmp|tmpdir=s o|target=s debian=s 
    opensslzero=s opensslone=s );

$0 =~ s/.*\///;
&GetOptions(@optdef);

-x $opt_opensslzero or die "Cannot execute openssl v0.x command at $opt_opensslzero, exiting.\n";
-x $opt_opensslone  or die "Cannot execute openssl v1.x command at $opt_opensslone, exiting.\n";

$opt_version=~/AUTO/i and do {
  chomp($opt_version=`cat VERSION`);
  $opt_version=~/-/ and do {
    ($opt_r=$opt_version)=~s/.*-//;
    $opt_version=~s/-.*//;
  };
};

$opt_gver=$opt_version unless $opt_gver;
$opt_gver or die "Need at least a global version (--gver=) option\nThis version may be set to AUTO, in which case the version is read\nfrom the VERSION file in the current directory.";

$opt_debian ne "" and do {
  -x "$opt_debian" or die "Debian SSL checking tool not available, please install $opt_debian";
};

defined $opt_url or
  $opt_url="http://dist.eugridpma.info/distribution/igtf/$opt_gver/apt";

# ----------------------------------------------------------------------------
# configuration settings
#
@validStatus = qw(accredited:classic accredited:slcs accredited:mics
                  suspended discontinued experimental worthless );
$Main::singleSpecFileTemplate="ca_single.spec.cin";
$Main::collectionSpecFileTemplate="ca_bundle.spec.cin";
$Main::legacyEUGridPMASpecFileTemplate="eugridpma.spec.cin";
$Main::bundleMakefileTPL="Makefile.tpl.cin";
$Main::bundleConfigureTPL="configure.cin";
$Main::jksPass="eugridpma";
@Main::infoGlob=("*/*.info","*/*/*.info","*/*/*/*.info");
# ----------------------------------------------------------------------------
#
# IGTF distribution generation logic
#


$opt_f and system("rm -fr $opt_o > /dev/null 2>&1");
&generateDistDirectory($opt_o) or die "generateDistDirectory: $err\n";

# fill list of authorities and resolve versions early to make
# inter-RPM dependendies for certificate chains
#
%auth = &getAuthoritiesList($opt_carep,$opt_version);


print "Generating global version $opt_gver release $opt_r\n";

my $tmpdir=tempdir("$opt_tmp/pBundle-XXXXXX", CLEANUP => 0 );
#my $tmpdir="$opt_o/expanded"; mkdir $tmpdir;
my $bundledir="$tmpdir/igtf-policy-installation-bundle-$opt_gver";
mkdir $bundledir;

foreach my $k ( sort keys %auth ) {
  my %info = %{$auth{$k}{"info"}};
  &packSingleCA($auth{$k}{"dir"},$bundledir,$opt_o,$auth{$k}{"basename"},%info) 
    or die "packSingleCA: $err\n";
}

&makeCollectionInfo($opt_carep,$bundledir,$opt_o)
    or die "makeCollectionInfo: $err\n";

&makeBundleScripts($bundledir,$tmpdir,$opt_o)
    or die "makeBundleScripts: $err\n";

(defined $opt_s) and (&signRPMs($opt_o) or die "signRPMs: $err\n");

&yumifyDirectory($opt_o) or die "yumifyDirectory: $err\n";
&aptifyDirectory($opt_o) or die "aptifyDirectory: $err\n";

&makeInfoFiles($opt_carep,$opt_o) or die "makeInfoFiles: $err\n";

# done
1;

# ----------------------------------------------------------------------------
# sub makeInfoFiles($repo,$targetdir)
# copy generic files to distribution directory
sub makeInfoFiles($$) {
  my ($carep,$targetdir) = @_;

  &copyWithExpansion("toplevel-README.cin","$targetdir/README.txt",
    ( "VERSION" => $opt_gver, "RELEASE" => $opt_r, 
      "DATE" => (strftime "%A, %d %b, %Y",gmtime(time)) ) ) or return undef;
  &copyWithExpansion("experimental-README.cin",
                     "$targetdir/experimental/README.txt",
    ( "VERSION" => $opt_gver, "RELEASE" => $opt_r, 
      "DATE" => (strftime "%A, %d %b, %Y",gmtime(time)) ) ) or return undef;
  &copyWithExpansion("worthless-README.cin","$targetdir/worthless/README.txt",
    ( "VERSION" => $opt_gver, "RELEASE" => $opt_r, 
      "DATE" => (strftime "%A, %d %b, %Y",gmtime(time)) ) ) or return undef;
  &copyWithExpansion("toplevel-version.txt.cin","$targetdir/version.txt",
    ( "VERSION" => $opt_gver) ) or return undef;
  copy("$opt_carep/GPG-KEY-EUGridPMA-RPM-3",
       "$targetdir/GPG-KEY-EUGridPMA-RPM-3")
    or do { $err="GPG key copy: $!\n"; return undef };
  copy("$carep/CHANGES","$targetdir/CHANGES")
    or do { $err="CHANGES copy: $!\n"; return undef};
  open ACCIN,">$targetdir/accredited/accredited.in" 
    or do { $err="accredited.in generation: $!\n"; return undef};
  foreach my $alias ( sort keys %auth ) {
    $auth{$alias}{"info"}->{"status"} =~ /^accredited/ or next; 
    (my $pname=$auth{$alias}{"info"}->{"status"})=~s/.*://;
    print ACCIN "$alias\t$pname\n";
  }
  close ACCIN;

  return 1;
}

# ----------------------------------------------------------------------------
# sub signRPMs($targetdir)
sub signRPMs($) {
  my ($targetdir) = @_;

  $|=1; 
  print "Please insert any removable disks that contain your signing key\n";
  print "and make sure that your rpmmacros file is correct\n\n";
  print "press enter to continue ...\n";
  my $nonsense=<>;
  system("cd $targetdir ; ".
         "find -name \*.rpm -print | xargs rpm --resign")
    and do {
      $err="system command error: $!"; return undef;
    };
  return 1;
}

# ----------------------------------------------------------------------------
# sub yumifyDirectory($targetdir)
# create the headers/ directories and build the yum metadata
sub yumifyDirectory($) {
  my ($targetdir) = @_;

  system("sync ; sleep 1 ; cd $targetdir ; yum-arch .")
    and do {
      $err="old-style YUM system command error: $!"; return undef;
    };
  system("sync ; sleep 1 ; cd $targetdir ; createrepo -x apt/\* .")
    and do {
      $err="new-style YUM system command error: $!"; return undef;
    };
  return 1;
}
  
# ----------------------------------------------------------------------------
# sub aptifyDirectory($targetdir)
# create the symlinks in the rpt/RPMS.<status> directories and build
# the APT metadata
sub aptifyDirectory($) {
  my ($targetdir) = @_;
  my ($s);
  chomp(my $cwd = `/bin/pwd`);
  $targetdir =~ /^\// or do {
    $targetdir="$cwd/$targetdir";
  };

  mkdir "$targetdir/apt" or return undef;
  mkdir "$targetdir/apt/base" or return undef;

  open RELEASE,">$targetdir/apt/base/release" or do {
      $err="Cannot create $targetdir/apt/base/release.$s: $!"; return undef;
    };
  print RELEASE <<EOF;
Origin: $opt_url
Label: IGTF Distribution $opt_gver
Suite: IGTF Distribution $opt_gver
Architectures: noarch
Components: accredited experimental worthless
Description: APT repository of IGTF distribution $opt_gver
EOF
  close RELEASE;

  for my $s ( qw(accredited experimental worthless) ) {
    mkdir "$targetdir/apt/RPMS.$s" or return undef;
    open RELEASE,">$targetdir/apt/base/release.$s" or do {
        $err="Cannot create $targetdir/apt/base/release.$s: $!"; return undef;
      };
    print RELEASE <<EOF;
Archive: stable
Component: $s
Version: $opt_gver
Origin: $opt_url
Label: IGTF $s CA distribution version $opt_gver
Architectures: noarch
EOF
    close RELEASE;
    foreach my $f ( glob "$targetdir/$s/RPMS/*.rpm" ) {
      (my $filename=$f)=~s/.*\///;
      symlink "../../$s/RPMS/$filename","$targetdir/apt/RPMS.$s/$filename";
    }

    system("genbasedir --bloat $targetdir/apt $s")
      and do {
        $err="system command error: $!"; return undef;
      };
  }

  system("genbasedir --hashonly $targetdir/apt ".
                     "accredited experimental worthless")
    and do {
      $err="system command error: $!"; return undef;
    };

  &copyWithExpansion("apt-README.cin","$targetdir/apt/README.txt",
	( "VERSION" => $opt_gver ) );

  return 1;
}


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

  &copyWithExpansion("bundle-README.cin","$builddir/README.txt",
    ( "VERSION" => $opt_gver, "RELEASE" => $opt_r,
      "DATE" => (strftime "%A, %d %b, %Y",gmtime(time)) ) ) or return undef;


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
    #$s=~/^accredited/ and 
      print MKTPL "\t\$(install) policy-igtf-$pname.info \$(prefix)/\n";
    print MKTPL "\n";
  }
  print MKTPL "install-all-accredited: $prodcas\n".
              "\t\@echo Installing all IGTF accredited CAs under ANY profile\n".
              "\t\$(install) policy-igtf.info \$(prefix)/\n\n";
  print MKTPL "#\n# single CA installations\n#\n\n";

  foreach $ca ( sort keys %auth ) {
    (my $collection=$auth{$ca}{"info"}->{"status"})=~s/:.*//;
    print MKTPL "$ca: prep\n";
    foreach my $ext (
            glob("$builddir/src/$collection/".$auth{$ca}{"info"}->{"alias"}.".*") ) {
      (my $f=$ext)=~s/.*\///;
      print MKTPL "\t\$(install) src/$collection/$f \$(prefix)/\n";
    }
    # also create the symlinks for both OpenSSL versions
    # from the info data and offsets
    print MKTPL "\t\$(ln) -s ".$auth{$ca}{"info"}->{"alias"}.".pem \$(prefix)/".
                $auth{$ca}{"info"}->{"hash0"}.".".$auth{$ca}{"info"}->{"offset0"}."\n";
    print MKTPL "\t\$(ln) -s ".$auth{$ca}{"info"}->{"alias"}.".pem \$(prefix)/".
                $auth{$ca}{"info"}->{"hash1"}.".".$auth{$ca}{"info"}->{"offset1"}."\n";

    -f "$builddir/src/$collection/".$auth{$ca}{"info"}->{"alias"}.".signing_policy" and do {
      print MKTPL "\t\$(ln) -s ".$auth{$ca}{"info"}->{"alias"}.".signing_policy ".
                  "\$(prefix)/".$auth{$ca}{"info"}->{"hash0"}.".signing_policy\n";
      print MKTPL "\t\$(ln) -s ".$auth{$ca}{"info"}->{"alias"}.".signing_policy ".
                  "\$(prefix)/".$auth{$ca}{"info"}->{"hash1"}.".signing_policy\n";
    };
    -f "$builddir/src/$collection/".$auth{$ca}{"info"}->{"alias"}.".namespaces" and do {
      print MKTPL "\t\$(ln) -s ".$auth{$ca}{"info"}->{"alias"}.".namespaces ".
                  "\$(prefix)/".$auth{$ca}{"info"}->{"hash0"}.".namespaces\n";
      print MKTPL "\t\$(ln) -s ".$auth{$ca}{"info"}->{"alias"}.".namespaces ".
                  "\$(prefix)/".$auth{$ca}{"info"}->{"hash1"}.".namespaces\n";
    };
    # do NOT link the info (or crl_url) files, or the fetch-crl tool
    # will do double or triple downloads

    # close of stanza needs empty line
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

  system("cd $tmpdir && tar zcf igtf-policy-installation-bundle-$opt_gver.tar.gz igtf-policy-installation-bundle-$opt_gver");

  copy("$tmpdir/igtf-policy-installation-bundle-$opt_gver.tar.gz","$targetdir/igtf-policy-installation-bundle-$opt_gver.tar.gz");

  (defined $opt_s) and do {
    chomp(my $gpghome=`awk '/%_gpg_path/ { print \$2 }' \$HOME/.rpmmacros`);
    chomp(my $gpgkey=`awk '/%_gpg_name/ { print \$2 }' \$HOME/.rpmmacros`);
    my $cmd="gpg --homedir=$gpghome --default-key=$gpgkey -o $tmpdir/igtf-policy-installation-bundle-$opt_gver.tar.gz.asc -ba $tmpdir/igtf-policy-installation-bundle-$opt_gver.tar.gz";
    print "Executing GPG signing command:\n  $cmd\n";
    system($cmd);
    copy("$tmpdir/igtf-policy-installation-bundle-$opt_gver.tar.gz.asc","$targetdir/igtf-policy-installation-bundle-$opt_gver.tar.gz.asc");
  };

  # make the pre-installed tarballs
  foreach my $s ( @validStatus ) {
    my $pname;
    if ($s=~/^accredited/) { 
      ($pname=$s)=~s/.*://; 
    } else { next; }
    my $preinst_tmp=tempdir("$opt_tmp/pPreinstBundle-$pname-XXXXXX", CLEANUP => 0 );
    chmod 0755,$preinst_tmp;
    system("cd $tmpdir/igtf-policy-installation-bundle-$opt_gver ; ".
           "./configure --with-profile=$pname --prefix=$preinst_tmp && make install");
    system("cd $preinst_tmp ; tar zcf $tmpdir/igtf-preinstalled-bundle-$pname-$opt_gver.tar.gz .");
    system("rm $preinst_tmp/*");
    copy("$tmpdir/igtf-preinstalled-bundle-$pname-$opt_gver.tar.gz",
         "$targetdir/accredited/igtf-preinstalled-bundle-$pname-$opt_gver.tar.gz");
    system("cd $targetdir/accredited/ && ln -s igtf-preinstalled-bundle-$pname-$opt_gver.tar.gz igtf-preinstalled-bundle-$pname.tar.gz");
  }

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
  my @allobscas=();
  
  # RPM distribution tokens for spec file
  my %tokens = ( "VERSION" => $opt_gver,
	  "RELEASE" => $opt_r,
	  "PACKAGENAME" => $pname,
	  "TGZNAME" => "$pname.tar.gz",
	);

  # first the top-level file (with an explicit list of profiles)
  open INFOTL,">$pdir/policy-igtf.info"  or do {
    $err="Cannot open file $pdir/ca-policy_igtf-$pname: $!\n";
    return undef;
  };
  print INFOTL "# @(#)policy-igtf.info - all IGTF accredited authorities\n";
  print INFOTL "# Generated ".(strftime "%A, %d %b, %Y",gmtime(time))."\n";
  print INFOTL "version = $opt_gver\nrequires = ";
  foreach my $s ( @validStatus ) {
    (my $pname=$s)=~s/.*://;
    my $nauthorities=0;
    my @obscas=();

    my $obsfilename = "${opt_obsoletedbase}.${s}.in";
    $obsfilename =~ s/:/./g;
    $tokens{"OBSOLETED.$pname"} = "";
    -f "$obsfilename" and do {
      open OBSFILE,"$obsfilename" or die "Cannot open $obsfilename: $!\n";
      while (<OBSFILE>) {
        chomp($_);
        push @obscas,$_;
        push @allobscas,$_;
      }
      close OBSFILE;
      if ($#obscas>=0) {
        $tokens{"OBSOLETED.$pname"} = "Obsoletes:";
      }
    };

    open INFO,">$pdir/policy-igtf-$pname.info"  or do {
      $err="Cannot open file $pdir/ca_policy_igtf-$pname: $!\n";
      return undef;
    };
    print INFO "# @(#)policy-igtf-$pname.info - IGTF $pname authorities\n";
    print INFO "# Generated ".(strftime "%A, %d %b, %Y",gmtime(time))."\n";
    print INFO "version = $opt_gver\nrequires = ";
    # loop over all accredited CAs for this profile and add them to
    # this and the top-level file
    foreach my $alias ( keys %auth ) {
      next if $auth{$alias}{"info"}->{"status"} ne $s;

      $nauthorities and print INFO ", \\\n    ";
      print INFO   "$alias = ".$auth{$alias}{"info"}->{"version"};

      # only add accredited CAs to the production igtf policy file
      $s=~/^accredited/ and do {
        $nauthorities and print INFOTL ", \\\n    ";
        print INFOTL "$alias = ".$auth{$alias}{"info"}->{"version"};
      };
      $nauthorities++;
    }
    print INFO "\n";

    if ($#obscas>=0) {
      $nauthorities=0;
      print INFO "obsoletes = ";
      foreach my $ca ( @obscas ) { 
        $tokens{"OBSOLETED.$pname"} .= " ca_${ca}";
        $nauthorities and print INFO ", \\\n    ";
        print INFO "$ca";
        $nauthorities++;
      }
    }

    close INFO;
  }
  print INFOTL "\n";

  if ($#allobscas>=0) {
    my $nauthorities=0;
    print INFOTL "obsoletes = ";
    foreach my $ca ( @allobscas ) { 
      $nauthorities and print INFOTL ", \\\n    ";
      print INFOTL "$ca";
      $nauthorities++;
    }
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
  &copyWithExpansion($Main::legacyEUGridPMASpecFileTemplate,
                     "$tmpdir/ca_policy_eugridpma-$opt_gver.spec",
                     %tokens);

  chomp(my $sourcedir=`rpm --eval %_sourcedir`);
  chomp(my $rpmdir=`rpm --eval %_rpmdir`);
  chomp(my $srcrpmdir=`rpm --eval %_srcrpmdir`);
  if ($sourcedir =~ /^%/ || $rpmdir =~ /^%/ || $srcrpmdir =~ /^%/ )  {
    $err="Setup error (no %_source,rpm,srcrpm dir)"; 
    return undef;
  }

  copy("$tmpdir/$pname.tar.gz","$sourcedir/$pname.tar.gz");
  system("rpmbuild --quiet -ba $tmpdir/$pname.spec ".($opt_v?"> /dev/null 2>&1":""));

  system("rpmbuild --quiet -ba $tmpdir/ca_policy_eugridpma-$opt_gver.spec ".($opt_v?"> /dev/null 2>&1":"") );

  # now collect all information in the proper place
  foreach my $n ( 
                  "ca_policy_igtf-classic-$opt_gver",
                  "ca_policy_igtf-slcs-$opt_gver",
                  "ca_policy_igtf-mics-$opt_gver",
                  "ca_policy_eugridpma-classic-$opt_gver",
                  "ca_policy_eugridpma-$opt_gver"
    ) {
    move("$rpmdir/noarch/$n-$opt_r.noarch.rpm",
      "$targetdir/accredited/RPMS/") or do {
      $err="Cannot move $n-$opt_r.noarch.rpm \n  from $rpmdir/noarch/$n-$opt_r.noarch.rpm\n  to $targetdir/accredited/RPMS/:\n  $!\nRPM build error?";
      return undef;
    };
  }
  move("$srcrpmdir/ca_policy_eugridpma-$opt_gver-$opt_r.src.rpm",
    "$targetdir/accredited/SRPMS") or do {
      $err="Cannor move ca_policy_eugridpma-$opt_gver-$opt_r.src.rpm to $targetdir/accredited/SRPMS/:\n  $!\nRPM build error?";
      return undef;
    };
  move("$srcrpmdir/ca_policy_igtf-$opt_gver-$opt_r.src.rpm",
    "$targetdir/accredited/SRPMS") or do {
      $err="Cannor move ca_policy_igtf-$opt_gver-$opt_r.src.rpm to SRPMS/: $!\nRPM builde error?";
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
      $r="ca_$alias = ".$auth{$alias}{"info"}->{"version"};
    } else {
      $r="ca_$alias";
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
# and resolve version and version style in the info basename
#
sub getAuthoritiesList($$) {
  my ($carepdir,$eVersion) = @_;
  my %auth;
  my %hashzerocount;
  my %hashonecount;

  foreach my $pat ( @Main::infoGlob ) {
  foreach my $f ( glob("$carepdir/$pat") ) {
    (my $dir=$f)=~s/\/[^\/]+$//;
    (my $basename=$f)=~s/.*\/(\w+)\.info$/$1/;
    my %info=&readInfoFile($f);

    my $version=undef;
    $version=($eVersion or ($info{"version"}=~/@/) ? $eVersion : undef );
    $version=$info{"version"} unless ($eVersion or ($info{"version"}=~/@/));
    $version=&getFilesVersion("$dir/$basename.*") unless defined $version;
    $info{"version"} = $version;

    # figure out if there is a certificate to go with this CA, and
    # bail out otherwise. A certificate has a ".0" extension or is
    # named in the info file
    my $certfilename;
    if ( defined $info{"certfile"} ) {
      $certfilename = $info{"certfile"};
    } else {
      $certfilename = $info{"certfile"} = "$basename.0";
    }
    if ( ! -f "$dir/$certfilename" ) {
      warn "CA $info{alias} in $dir has no actual certificate file ($certfilename), skipping.\n";
      next;
    }

    defined $info{"hash0"} or do {
      chomp(my $hashzero = `$opt_opensslzero x509 -noout -hash -in '$dir/$certfilename'`);
      $info{"hash0"} = $hashzero;
      # calculate the 'offset' for the OpenSSL v0 symlinking (.0, .1, .2, etc files)
      defined $hashzerocount{$hashzero} or $hashzerocount{$hashzero}=0;
      $info{"offset0"} = $hashzerocount{$hashzero}++;
    };
    defined $info{"hash1"} or do {
      chomp(my $hashone  = `$opt_opensslone  x509 -noout -hash -in '$dir/$certfilename'`);
      $info{"hash1"} = $hashone;
      # calculate the 'offset' for the OpenSSL v1 symlinking (.0, .1, .2, etc files)
      defined $hashonecount{$hashone} or $hashonecount{$hashone}=0;
      $info{"offset1"} = $hashonecount{$hashone}++;
    };

    $auth{$info{"alias"}} = 
      { "basename" => $basename, "dir" => $dir, 
        "hash0" => $info{"hash0"},
        "hash1" => $info{"hash1"},
        "info" => \%info 
      };
    print "Added CA $basename (alias $info{alias}) with version $version\n";
  }
  }
  return %auth;
}


# ----------------------------------------------------------------------------
# sub generateDistDirectory($targetdir)
#
# Generate the directory structure for the final distribution. It should be:
#     TOP
#     +- {accredited,experimental,worthless}
#        +- RPMS
#        +- SRPMS
#        +- tgz

sub generateDistDirectory($) {
  my ($dir) = @_;

  -d $dir and $err="$dir already exists, clean first" and return undef;
  mkdir $dir or return undef;

  for my $s ( qw(accredited experimental worthless) ) {
    mkdir "$dir/$s" or return undef;
    for my $t ( qw (RPMS SRPMS tgz jks) ) {
      mkdir "$dir/$s/$t" or return undef;
    }
  }
  return 1;
}

# ----------------------------------------------------------------------------
# sub packCA($srcdir,$builddir,$targetdir,$basename,%info)
#
# package a single CA in all formats, and store these in the proper
# structure in the target directory
#
# - prerequisites: <basename>.{0,info,signing_policy} files must exist in
#   $srcdir; $targetdir must exist and be initialised
#   $builddir will be created in /tmp if needed (and then removed later)
# - results: RPM, SRPM, tar.gz packages for this CA
# - return code: 1 if OK, 0 if error and $err will be set
#
sub packSingleCA($$$$) {
  my ($srcdir,$builddir,$targetdir,$basename,%info) = @_;
  my $alias;

  # essential information MUST be there
  $info{"alias"} or $err="CA $basename has no alias" and return undef;
  $info{"status"} or $err="CA $basename has no status at all" and return undef;
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

  $alias = $info{"alias"};

  # do debian checking
  -x "$opt_debian" or die "$opt_debian: not found or not executable";
  my $debianflawed = system "$opt_debian $srcdir/$basename.0";
  if ( $debianflawed ) {
    $err = "CA $basename (alias $alias) is affected by the Debian SSL vulnerblity" and return undef;
  }

  my $tmpdir=tempdir("$opt_tmp/pSCA-$basename-XXXXXX", CLEANUP => 1 );
  print "** CA $alias v$info{version} (basename $basename, dir $srcdir)\n";

  -f "$srcdir/$basename.0" and do {
    if ( (!defined $info{"sha1fp.0"}) or ($info{"sha1fp.0"}=~/@/) ) {
      chomp($info{"sha1fp.0"} = 
        `$opt_opensslzero x509 -fingerprint -sha1 -noout -in $srcdir/$basename.0`);
      $info{"sha1fp.0"}=~s/^[^=]+=//;
    }
  };

  (my $collection=$info{"status"})=~s/:.*//;
  my ($profile);
  if ( $collection eq "accredited" ) {
    ($profile=$info{"status"})=~s/.*://;
  } else {
    $profile="";
  }
  my $pname="ca_".$info{"alias"}."-".$info{"version"};
  my $pdir="$tmpdir/$pname";
  mkdir $pdir;
  foreach my $ext ( qw(info signing_policy namespaces) ) {
    if ( -f "$srcdir/$basename.$ext" ) {
      &copyWithExpansion("$srcdir/$basename.$ext","$pdir/$alias.$ext",
	( "VERSION" => $info{"version"}, 
          "SHA1FP.0" => $info{"sha1fp.0"},
          "SRCDIR" => $srcdir
        ) );
      symlink "$alias.$ext","$pdir/$info{hash0}.$ext";
      symlink "$alias.$ext","$pdir/$info{hash1}.$ext";
    }
  }
  if ( $info{"crl_url"} ) {
    open CRLURL,">$pdir/$alias.crl_url" or 
      $err="Cannot open $pdir/$alias.crl_url for write: $!" and return undef;
    #print CRLURL $info{"crl_url"}."\n";
    foreach my $url ( split(/[; ]+/,$info{"crl_url"}) ) {
      print CRLURL "$url\n";
    }
    close CRLURL;
  }

  # package up the certificate, max one per alias
  # in the symlink generation phase for OpenSSL, increment the ".i" index according to
  # the global inventory generated in the getAuthoritiesList phase
  #
  my $certfile = $info{"certfile"};
  -f "$srcdir/$certfile" or die "Certificate file for $alias ($srcdir/$certfile) disappeared!\n";

  #
  # check for validity and generate visual warning for packager
  #
  my $rc;
  $rc=system("$opt_opensslzero x509 -checkend 15552000 -noout -in $srcdir/$certfile");
  if ( $rc ) {
    chomp($rc=`$opt_opensslzero x509 -noout -in $srcdir/$certfile -enddate`);
    $rc=~/=(.*)/;
    print "WARNING: $srcdir/$certfile: \n";
    print "         certificate for $alias will expire within 180 days\n";
    print "         on: $1\n";
    print "\n";
  }

  #
  # package into Java keystore
  #
  $opt_nojks or do {
   system("$opt_opensslzero x509 -outform der -in $srcdir/$certfile -out $tmpdir/$certfile-der");
   system("keytool -import -alias ".$info{"alias"}." ".
          "-keystore $targetdir/$collection/jks/ca-".$info{"alias"}."-".$info{"version"}.".jks ".
          "-storepass $Main::jksPass -noprompt -trustcacerts ".
          "-file $tmpdir/$certfile-der");
   my $jksname="igtf-policy-$collection";
   $profile ne "" and $jksname.="-$profile";
   system("keytool -import -alias ".$info{"alias"}." ".
          "-keystore $targetdir/$collection/jks/$jksname-$opt_gver.jks ".
          "-storepass $Main::jksPass -noprompt -trustcacerts ".
          "-file $tmpdir/$certfile-der");
   unlink "$tmpdir/$basename-der";
  };

  #
  # put the certificate in place with a generic name
  # and generate the offsetted symlinks with the proper hashes for both OpenSSL
  # versions
  #
  system("$opt_opensslzero x509 -outform pem -in $srcdir/$certfile -out $pdir/$alias.pem");
  symlink "$alias.pem","$pdir/".$info{"hash0"}.".".$info{"offset0"};
  symlink "$alias.pem","$pdir/".$info{"hash1"}.".".$info{"offset1"};



  system("cd $tmpdir && tar zcf $pname.tar.gz $pname");
  -d "$builddir/src" or mkdir "$builddir/src" or 
    die "Cannot mkdir $builddir/src: $!\n";
  -d "$builddir/src/$collection" or mkdir "$builddir/src/$collection" or 
    die "Cannot mkdir $builddir/$collection: $!\n";
  defined $builddir and do {
    foreach my $f ( "$pdir/$alias.pem","$pdir/$alias.crl_url",
                    "$pdir/$alias.signing_policy","$pdir/$alias.namespaces",
                    "$pdir/$alias.info" ) { 
      (my $b=$f)=~s/.*\///; 
      -f "$f" and copy("$f","$builddir/src/$collection/$b");
    }
  };
  
  &copyWithExpansion($Main::singleSpecFileTemplate,"$tmpdir/$pname.spec",
	( "VERSION" => $info{"version"},
	  "RELEASE" => $opt_r,
	  "ALIAS" => $info{"alias"},
	  "CERTFILE" => $info{"certfile"},
	  "HASH" => $basename,
	  "PACKAGENAME" => $pname,
	  "TGZNAME" => "$pname.tar.gz",
	  "URL" => $info{"url"},
	  "COLLECTION" => $collection,
	  "PROFILE" => $profile,
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
# returns: basename with information
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
sub getFilesVersion($) {
  my ($glob) = @_;
  my ($version);

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
