Summary:   EUGridPMA combined policy package for accredited CAs
Name:      ca_policy_eugridpma
Version:   %(awk -F/ '$2=="%{name}.spec" && $6~/^Tv/ {s=substr($6,3);gsub("_",".",s)} END { if(s) {print s} else {print "unknown"} }' CVS/Entries )
Release:   1
URL:       http://www.eugridpma.org/
BuildRoot: %{_tmppath}/%{name}-buildroot
License:   Freely distributable
Group:	   system/certificates
Provides:  ca_policy_eugridpma-%{version}
BuildArch: noarch
Requires:  %(awk '$2~/^(classic|sips|acs)$/ { printf "ca_%s = %s, ",$1,"%{version}" } ' profiles.cnf )
Prefix:    /

%description
This is the comprehensive policy package of the EUGridPMA, which 
includes dependencies on the CAs accredited according to any
of the CLASSIC, SIPS and ACS profiles.

%build
exit 0

%install

%files

%package classic
Summary: EUGridPMA accredited classic CAs
Group: system/certificates
Requires: %(awk '$2=="classic" { printf "ca_%s = %s, ",$1,"%{version}" } ' profiles.cnf )
Prefix: /
%description classic
This is the CLASSIC policy package of the EUGridPMA including dependencies 
on the CAs accredited according to CLASSIC authenitication profile.
%files classic

%package sips
Summary: EUGridPMA accredited SIPS CAs
Group: system/certificates
Requires: %(awk '$2=="sips" { printf "ca_%s = %s, ",$1,"%{version}" } ' profiles.cnf )
Prefix: /
%description sips
This is the SIPS policy package of the EUGridPMA including dependencies 
on the CAs accredited according to SIPS authenitication profile.
%files sips

