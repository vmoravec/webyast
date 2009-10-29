#
# spec file for package yast2-webservice-services (Version 0.1)
#
# Copyright (c) 2008 SUSE LINUX Products GmbH, Nuernberg, Germany.
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself.
#
# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-webservice-services
PreReq:         yast2-webservice
Provides:       yast2-webservice:/srv/www/yastws/app/controllers/services_controller.rb
License:	GPLv2
Group:          Productivity/Networking/Web/Utilities
Autoreqprov:    on
Version:        0.0.9
Release:        0
Summary:        YaST2 - Webservice - Services
Source:         www.tar.bz2
Source1:        org.opensuse.yast.modules.yapi.services.policy
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildArch:      noarch
BuildRequires:  rubygem-yast2-webservice-tasks rubygem-restility

# YaPI/SERVICES.pm
%if 0%{?suse_version} == 0 || %suse_version > 1110
# 11.2 or newer
Requires:       yast2 >= 2.18.24
%else
# 11.1 or SLES11
Requires:       yast2 >= 2.17.72
%endif


#
%define pkg_user yastws
%define plugin_name services
#


%description
YaST2 - Webservice - REST based interface of YaST in order to handle services.
Authors:
--------
    Stefan Schubert <schubi@opensuse.org>
    Jiri Suchomel <jsuchome@suse.cz>
    Ladislav Slezak <lslezak@suse.cz>

%prep
%setup -q -n www

%build

# build restdoc documentation
mkdir -p $RPM_BUILD_ROOT/srv/www/%{pkg_user}/vendor/plugins/%{plugin_name}/public/services/restdoc
export RAILS_PARENT=/srv/www/yastws
env LANG=en rake restdoc

%install

#
# Install all web and frontend parts.
#
cp -a * $RPM_BUILD_ROOT/srv/www/%{pkg_user}/vendor/plugins/%{plugin_name}
rm -f $RPM_BUILD_ROOT/srv/www/%{pkg_user}/vendor/plugins/%{plugin_name}/COPYING

# Policies
mkdir -p $RPM_BUILD_ROOT/usr/share/PolicyKit/policy
install -m 0644 %SOURCE1 $RPM_BUILD_ROOT/usr/share/PolicyKit/policy/

# do not package restdoc sources
rm -rf $RPM_BUILD_ROOT/srv/www/%{pkg_user}/vendor/plugins/%{plugin_name}/restdoc

%clean
rm -rf $RPM_BUILD_ROOT

%post
#
# granting all permissions for root 
#
/etc/yastws/tools/policyKit-rights.rb --user root --action grant >& /dev/null || :
/etc/yastws/tools/policyKit-rights.rb --user yastws --action grant >& /dev/null || :

%files 
%defattr(-,root,root)
%dir /srv/www/%{pkg_user}
%dir /srv/www/%{pkg_user}/vendor
%dir /srv/www/%{pkg_user}/vendor/plugins
%dir /srv/www/%{pkg_user}/vendor/plugins/%{plugin_name}
%dir /srv/www/%{pkg_user}/vendor/plugins/%{plugin_name}/doc
%dir /usr/share/PolicyKit
%dir /usr/share/PolicyKit/policy
/srv/www/%{pkg_user}/vendor/plugins/%{plugin_name}/README
/srv/www/%{pkg_user}/vendor/plugins/%{plugin_name}/Rakefile
/srv/www/%{pkg_user}/vendor/plugins/%{plugin_name}/init.rb
/srv/www/%{pkg_user}/vendor/plugins/%{plugin_name}/install.rb
/srv/www/%{pkg_user}/vendor/plugins/%{plugin_name}/uninstall.rb
/srv/www/%{pkg_user}/vendor/plugins/%{plugin_name}/app
/srv/www/%{pkg_user}/vendor/plugins/%{plugin_name}/config
/srv/www/%{pkg_user}/vendor/plugins/%{plugin_name}/tasks
/srv/www/%{pkg_user}/vendor/plugins/%{plugin_name}/doc
/srv/www/%{pkg_user}/vendor/plugins/%{plugin_name}/public

%attr(644,root,root) %config /usr/share/PolicyKit/policy/org.opensuse.yast.modules.yapi.%{plugin_name}.policy
%doc COPYING

