Summary:   EUGridPMA meta-rpm
Name:      eugridpma
Version:   0.23
Release:   1
URL:       http://eugridpma.org/
BuildRoot: %{_tmppath}/%{name}-buildroot
License: unknown
Group:	system/certificates
Provides: eugridpma-%{version}
BuildArch: noarch
Requires: ca_ASGCCA  = %{version}, ca_ArmeSFo = %{version}, ca_CERN = %{version}, ca_CESNET = %{version}, ca_CNRS = %{version}, ca_CNRS-DataGrid = %{version}, ca_CNRS-Projets = %{version}, ca_CyGrid = %{version}, ca_DOEGrids = %{version}, ca_DOESG-Root = %{version}, ca_ESnet = %{version}, ca_FNAL = %{version}, ca_GermanGrid = %{version}, ca_Grid-Ireland = %{version}, ca_GridCanada = %{version}, ca_HellasGrid = %{version}, ca_INFN = %{version}, ca_LIP = %{version}, ca_NIKHEF = %{version}, ca_NorduGrid = %{version}, ca_PolishGrid = %{version}, ca_Russia = %{version}, ca_SlovakGrid = %{version}, ca_Spain = %{version}, ca_UKeScience = %{version}

%description
Meta-package for all EUGridPMA accredited CAs 

%build
exit 0

%install
mkdir -p $RPM_BUILD_ROOT/etc/grid-security/certificates

%files
%defattr(-,root,root)
%dir /etc/grid-security/certificates
