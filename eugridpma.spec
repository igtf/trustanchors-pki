Summary:   EUGridPMA policy RPM requiring all accredited CAs
Name:      ca_policy_eugridpma
Version:   @VERSION@
Release:   @RELEASE@
URL:       http://www.eugridpma.org/
BuildRoot: %{_tmppath}/%{name}-buildroot
License:   Freely distributable under license by the individual CAs
Group:	system/certificates
Provides: ca_policy_eugridpma-%{version}
BuildArch: noarch
Requires: %(awk '{ printf "ca_%s = %s, ",$1,"%{version}" } ' accredited.in )

%description
This is the policy meta-package that implies trust on all 
EUGridPMA accredited CAs, under any of the authentication profiles.
Install this package if you are willing to trust all CAs that
are somehow accredited by the EUGridPMA.
Please refer to the EUGridPMA web site for authentication profiles
and minimum requirements

%build

%install


%package classic
Summary: EUGridPMA policy RPM requiring only classic profile accredited CAs
Group: System/Certificates
Provides: ca_policy_eugridpma-classic-%{version}
Requires: %(awk '$2 == "classic" { printf "ca_%s = %s, ",$1,"%{version}" } ' accredited.in )

%description classic
This is the policy meta-package that implies trust on EUGridPMA accredited 
CAs according to the classic, secured X.509 certification authorities only.
Install this package if you are willing to trust CAs that are 
accredited by the EUGridPMA under the "classic" profile.
Please refer to the EUGridPMA web site for authentication profiles
and minimum requirements

%package sips
Summary: EUGridPMA policy RPM requiring only sips profile accredited CAs
Group: System/Certificates
Provides: ca_policy_eugridpma-classic-%{version}
Requires: %(awk '$2 == "sips" { printf "ca_%s = %s, ",$1,"%{version}" } ' accredited.in )

%description sips
This is the policy meta-package that implies trust on EUGridPMA accredited 
CAs according to the site-integrated proxy servers only.
Install this package if you are willing to trust CAs that are 
accredited by the EUGridPMA under the "sips" profile.
Please refer to the EUGridPMA web site for authentication profiles
and minimum requirements

%files
%defattr(-,root,root)

%files classic
%defattr(-,root,root)

%files sips
%defattr(-,root,root)
