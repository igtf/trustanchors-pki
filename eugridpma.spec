Summary:   EUGridPMA meta-rpm
Name:      ca_policy_eugridpma
Version:   0.25
Release:   1
URL:       http://eugridpma.org/
BuildRoot: %{_tmppath}/%{name}-buildroot
License: unknown
Group:	system/certificates
Provides: ca_policy_eugridpma-%{version}
BuildArch: noarch
Requires: %(awk '{ printf "ca_%s = %s, ",$1,%{version} } ' accredited.in )

%description
This is the policy meta-package that depends on all EUGridPMA accredited CAs.

%build
exit 0

%install
mkdir -p $RPM_BUILD_ROOT/etc/grid-security/certificates

%files
%defattr(-,root,root)
%dir /etc/grid-security/certificates
