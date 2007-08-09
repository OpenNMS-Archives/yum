%define tree stable
%define os   rhel5

Summary: Yum repository files for %{tree}/%{os} OpenNMS
Name: opennms-repo
Version: 1.0
Release: 1
License: GPL
Group: Development/Tools
URL: http://yum.opennms.org/

Source0: opennms-%{tree}-common.repo
Source1: opennms-%{tree}-%{os}.repo

BuildArch: noarch
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
Yum repository files for installing OpenNMS %{tree} on
%{os}.

%build

%install
install -d -m 755            $RPM_BUILD_ROOT%{_sysconfdir}/yum.repos.d
install -c -m 644 %{SOURCE0} $RPM_BUILD_ROOT%{_sysconfdir}/yum.repos.d/
install -c -m 644 %{SOURCE1} $RPM_BUILD_ROOT%{_sysconfdir}/yum.repos.d/

%files
%{_sysconfdir}/yum.repos.d/*.repo
