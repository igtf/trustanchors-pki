#! /usr/bin/perl
#
for $f ( @ARGV ) {
  $f=~/\.0$/ or next;
  %info=();

  ($hash=$f)=~s/\.0$//; $hash=~s/.*\///;
  ($dir=$f)=~s/[^\/]*$//;
  $dir or $dir="./";

  -f "$dir/$hash.info" and next;

  $age=(stat("$dir/$hash.0"))[9];

  -r "$dir/status" and do {
      chomp($info{"status"}=`cat $dir/status`);
  };

  $info{"version"}='@VERSION@';
  foreach $n ( "status", "requires", "crl_url", 
               "email", "alias", "url", "ca_url" ) {
    -r "$dir/$hash.$n" and do {
      chomp($info{"$n"}=`cat $dir/$hash.$n`);
      $cage=(stat("$dir/$hash.$n"))[9];
      if ($cage>$age) { $age=$cage}
    };
  }
  $info{"status"} = "accredited:classic" unless $info{"status"};

  open INFO,">$dir/$hash.info";
  print INFO "#\n# @(#)\$Id\$\n";
  print INFO "# Information for CA ".$info{"alias"}."\n";
  print INFO "#   obtained from $hash in $dir\n";


  foreach $key ( sort keys %info ) {
    print INFO "$key = ".$info{$key}."\n";
  }
  close INFO;
  utime $age,$age,"$dir/$hash.info";
}
