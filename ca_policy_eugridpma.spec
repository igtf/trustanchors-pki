Summary:   EUGridPMA meta-rpm
Name:      ca_policy_eugridpma
Version:   %(awk -F/ '$2=="%{name}" && $6~/^Tv/ {s=substr($6,3);gsub("_",".",s)} END { if(s) {print s} else {print "unknown"} }' CVS/Entries )
Release:   1
URL:       http://www.eugridpma.org/
BuildRoot: %{_tmppath}/%{name}-buildroot
License: unknown
Group:	system/certificates
Provides: ca_policy_eugridpma-%{version}
BuildArch: noarch
Requires: %(awk '{ printf "ca_%s = %s, ",$1,%{version} } ' accredited.in )
Prefix: /etc/grid-security/certificates

%description
This is the policy meta-package that depends on all EUGridPMA accredited CAs.

%build
exit 0

%install
mkdir -p $RPM_BUILD_ROOT/etc/grid-security/certificates

%files
%defattr(-,root,root)
%dir /etc/grid-security/certificates
