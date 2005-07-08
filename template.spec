%define globus_location /opt/globus

%define CA_ALIAS @ALIAS@

Name: ca_%{CA_ALIAS}
Version: @VERSION@
Release: @RELEASE@
Source: %{CA_ALIAS}-%{version}.tar.gz
License: GPL
Prefix: %{globus_location} /etc
Group: Security/Certificates
#BuildRequires: openssl
BuildRoot: %{_tmppath}/%{name}-root
BuildArch: noarch

#%define CA_HASH      %(tar xOfz %{SOURCE0} '*.0' | openssl x509 -noout -hash)
%define CA_HASH      @HASH@
%define GSI_CA_NAME  %(tar xOfz %{SOURCE0} %{CA_HASH}.0 | openssl x509 -noout -subject |sed 's#^.*/CN=##')
%define CA_LDAP      %(tar  tfz %{SOURCE0} %{CA_HASH}.ldap          > /dev/null 2>&1 && echo 1 || echo 0)
%define CA_LOCAL     %(tar  tfz %{SOURCE0} %{CA_HASH}.grid-security > /dev/null 2>&1 && echo 1 || echo 0)
%define CA_CRL      %(tar  tfz %{SOURCE0} %{CA_HASH}.crl_url          > /dev/null 2>&1 && echo 1 || echo 0)
%define HAS_CA_EMAIL      %(tar  tfz %{SOURCE0} %{CA_HASH}.email >/dev/null 2>&1 && echo 1 || echo 0)
%define CA_EMAIL  %(tar xOfz %{SOURCE0} %{CA_HASH}.email )

Summary: Trust anchors for Certification Authority %{CA_ALIAS}

%if %(tar tfz %{SOURCE0} %{CA_HASH}.url > /dev/null 2>&1 && echo 1 || echo 0)
URL: %(tar xOfz %{SOURCE0} %{CA_HASH}.url)
%endif

%if %(tar tfz %{SOURCE0} %{CA_HASH}.requires > /dev/null 2>&1 && echo 1 || echo 0)
Requires: %(tar xOfz %{SOURCE0} %{CA_HASH}.requires | sed -e 's/^/ca_/' -e 's/$/ = %{version}/' ) 
%endif

%prep
%setup -c -n %{name}

%description
This package contains information about the %{CA_ALIAS} 
Certification Authority with the hash value %{CA_HASH} and the common 
name: %{GSI_CA_NAME}. 
Several instances of this package, corresponding to different CA's, can 
be installed simultaneously on the same system. 
%if %{HAS_CA_EMAIL}
In case of concerns, the authority can be contacted by electronic
mail at the address <%{CA_EMAIL}>.
%endif

%if %{CA_LOCAL}
%package local
Summary: Configuration files for grid-cert-request with %{CA_ALIAS} certification authority with hash %{CA_HASH}
Group: Security/Certificates

%description local
Configuration files for trusted certification authority %{CA_ALIAS} with hash %{CA_HASH}.
The common name for this Certification Authority is:

%{GSI_CA_NAME}

These files are needed by grid-cert-request and defines which CA certificates requests should
be directed to. Only one package of this type should be installed.
%endif

%build
exit 0

%install
rm -rf $RPM_BUILD_ROOT

mkdir -p $RPM_BUILD_ROOT/etc/grid-security/certificates

%if %{CA_LOCAL}
  cp -p %{CA_HASH}.grid-security $RPM_BUILD_ROOT/etc/grid-security/grid-security.conf
  touch $RPM_BUILD_ROOT/etc/grid-security/globus-{host,user}-ssl.conf
%endif

%if %{CA_LDAP}
  cp -pv %{CA_HASH}.ldap %{CA_HASH}.signing_policy $RPM_BUILD_ROOT/etc/grid-security/certificates/
%endif

cp -pv %{CA_HASH}.0 %{CA_HASH}.signing_policy $RPM_BUILD_ROOT/etc/grid-security/certificates/

%if %{CA_CRL}
cp -pv %{CA_HASH}.crl_url                     $RPM_BUILD_ROOT/etc/grid-security/certificates/
%endif

%if %{CA_LOCAL}
%post local

if [ -r /etc/sysconfig/globus ]; then
  . /etc/sysconfig/globus
fi

GLOBUS_LOCATION=${GLOBUS_LOCATION:-/opt/globus}

if [ -x $GLOBUS_LOCATION/setup/globus/grid-cert-request-config ]; then
  cd /etc/grid-security/
  $GLOBUS_LOCATION/setup/globus/grid-cert-request-config
fi
%endif

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(644,root,root)
/etc/grid-security/certificates/%{CA_HASH}.0
/etc/grid-security/certificates/%{CA_HASH}.signing_policy
%if %{CA_CRL}
/etc/grid-security/certificates/%{CA_HASH}.crl_url
%endif
%if %{CA_LDAP}
/etc/grid-security/certificates/%{CA_HASH}.ldap
%endif

%if %{CA_LOCAL}
%files local
%defattr(644,root,root)
/etc/grid-security/grid-security.conf
%verify(not size md5 mtime) %config /etc/grid-security/globus-user-ssl.conf
%verify(not size md5 mtime) %config /etc/grid-security/globus-host-ssl.conf
%endif

%changelog
* @DATE@ David Groep <davidg@nikhef.nl>
- RPM spec template generated automatically

