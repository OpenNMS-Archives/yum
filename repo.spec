Summary: Yum repository files for %{_tree}/%{_osname} OpenNMS
Name: opennms-repo-%{_tree}
Version: 1.0
Release: 9
License: GPL
Group: Development/Tools
URL: http://yum.opennms.org/

Source0: opennms-%{_tree}-common.repo
Source1: opennms-%{_tree}-%{_osname}.repo

BuildArch: noarch
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
Yum repository files for installing OpenNMS %{_tree} on
%{_osname}.

%build

%install
install -d -m 755            $RPM_BUILD_ROOT%{_sysconfdir}/yum.repos.d
install -c -m 644 %{SOURCE0} $RPM_BUILD_ROOT%{_sysconfdir}/yum.repos.d/
install -c -m 644 %{SOURCE1} $RPM_BUILD_ROOT%{_sysconfdir}/yum.repos.d/

%clean
if [ "$RPM_BUILD_ROOT" != "/" ]; then
	rm -rf "$RPM_BUILD_ROOT"
fi

%files
%{_sysconfdir}/yum.repos.d/*.repo
