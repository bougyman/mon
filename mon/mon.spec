#
# spec file for package mon (Version 1.0.0pre3)
#
# Copyright (c) 2004 SUSE LINUX AG, Nuernberg, Germany.
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself.
#
# Please submit bugfixes or comments via http://www.suse.de/feedback/
#

BuildRequires: bash bzip2 cpio cpp diffutils file filesystem findutils grep groff gzip info m4 make man patch sed tar texinfo autoconf automake binutils gcc libtool perl rpm

Name:         mon
Version:      1.0.0pre4jt1
Release:      2
Summary:      The mon network monitoring system
License:      GPL
Group:        System/Monitoring
URL:          http://www.kernel.org/software/mon/
Source:       http://www.kernel.org/pub/software/admin/mon/%{name}-%{version}.tar.bz2
Source1:      http://www.kernel.org/pub/software/admin/mon/mon-client-%{version}.tar.bz2
Requires:     perl
Requires:     perl(Time::Period)
Requires:     perl-Convert-BER
Requires:     fping
Requires:     perl-libwww-perl
BuildRoot:    %{_tmppath}/%{name}-%{version}-build

%define	filelist %{name}-%{version}-filelist

%description
"mon" is a tool for monitoring the availability of services. Services
may be network-related, environmental conditions, or nearly anything
that can be tested with software.  It is extremely useful for system
administrators, but not limited to use by them. It was designed to be a
general-purpose problem alerting system, separating the tasks of
testing services for availability and sending alerts when things fail.
To achieve this, "mon" is implemented as a scheduler which runs the
programs which do the testing, and triggering alert programs when these
scripts detect failure.  None of the actual service testing or
reporting is actually handled by "mon". These functions are handled by
auxillary programs.



Authors:
--------
    Jim Trocki <trockij@arctic.org>

%prep
###################################################################
%setup -q
%setup -T -D -a 1
###################################################################

%build
cd mon.d
make
cd ../mon-client-%{version}
%{__perl} Makefile.PL `%{__perl} -MExtUtils::MakeMaker -e ' print qq|PREFIX=%{buildroot}%{_prefix}| if \$ExtUtils::MakeMaker::VERSION =~ /5\.9[1-6]|6\.0[0-5]/ '`
%{__make}
###################################################################

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/%{_libdir}/mon/alert.d
mkdir -p %{buildroot}/%{_sbindir}
mkdir -p %{buildroot}/%{_mandir}/man1
mkdir -p %{buildroot}/%{_libdir}/mon/mon.d
mkdir -p %{buildroot}/%{_localstatedir}/lib/mon
mkdir -p %{buildroot}/%{_libdir}/mon/utils
mkdir -p %{buildroot}/%{_sysconfdir}/mon
mkdir -p %{buildroot}/%{_sysconfdir}/init.d
mkdir -p %{buildroot}/%{_sysconfdir}/logrotate.d
mkdir -p ./examples
cp mon %{buildroot}/%{_sbindir}/
cp -a ./alert.d/ %{buildroot}/%{_libdir}/mon/
cp ./clients/moncmd %{buildroot}/%{_sbindir}/moncmd
cp ./clients/monshow %{buildroot}/%{_sbindir}/monshow
cp -a ./doc/*.1 %{buildroot}/%{_mandir}/man1/
mv ./etc/very-simple.cf %{buildroot}/%{_sysconfdir}/mon/mon.cf
mv ./etc/auth.cf %{buildroot}/%{_sysconfdir}/mon
mv ./etc/S99mon %{buildroot}/%{_sysconfdir}/init.d/mon
cp -a ./etc/* ./examples
cp -a ./mon.d/{*.monitor,*.wrap} %{buildroot}/%{_libdir}/mon/mon.d/
cp -a ./utils/ %{buildroot}/%{_libdir}/mon/
mkdir -p %{buildroot}/sbin
ln -sf ../etc/init.d/mon  %{buildroot}/sbin/rcmon
cd mon-client-%{version} && %{makeinstall} `%{__perl} -MExtUtils::MakeMaker -e ' print \$ExtUtils::MakeMaker::VERSION <= 6.05 ? qq|PREFIX=%{buildroot}%{_prefix}| : qq|DESTDIR=%{buildroot}| '`
cd ..
# clean up after perl module install - remove special files
find %{buildroot} -name "perllocal.pod" -o -name ".packlist" -o -name "*.bs" |xargs -i rm -f {}
# build filelist 
echo "%defattr(-,root,root)" > %filelist
find %{buildroot} -type f -printf "/%%P\n" | grep -v "man/man" >> %filelist

[ -z %filelist ] && {
    echo "ERROR: EMPTY FILE LIST"
    exit -1
}

###################################################################

%files -f %filelist
%doc %{_mandir}/man1/moncmd.1*
%doc %{_mandir}/man1/monshow.1*
%doc %{_mandir}/man3/Mon::*


%doc CHANGES COPYING COPYRIGHT CREDITS INSTALL KNOWN-PROBLEMS README
%doc TODO VERSION mon.lsm
%doc ./doc/README.*
%doc ./doc/globals
%doc ./examples
###################################################################

%clean
if
  [ -z "${RPM_BUILD_ROOT}"  -a "${RPM_BUILD_ROOT}" != "/" ]
then
  rm -rf $RPM_BUILD_ROOT
fi
rm -rf $RPM_BUILD_ROOT
###################################################################

%preun
if [ -r %{_localstatedir}/run/mon.pid ]; then
	/etc/init.d/mon stop
fi
###################################################################

%post
if [ -d %{_localstatedir}/log -a ! -f %{_localstatedir}/log/mon_history.log ]; then
    touch %{_localstatedir}/log/mon_history.log
fi
###################################################################

%postun
if [ "$1" = "0" -a -f %{_localstatedir}/log/mon_history.log ]; then
    rm -f %{_localstatedir}/log/mon_history.log
fi

%changelog -n mon
* Thu Jul 07 2004 - eric@transmeta.com
- update to 1.0.0pre2, remove suse-ness
* Mon Mar 01 2004 - hmacht@suse.de
- building as nonroot-user
* Fri Feb 27 2004 - kukuk@suse.de
- Cleanup neededforbuild
- fix compiler warnings
* Mon Feb 10 2003 - lmb@suse.de
- Fixed path to comply with FHS.
* Fri Oct 18 2002 - lmb@suse.de
- Fix for Bugzilla #21086: init script had a broken path and syntax
  error.
* Tue Aug 20 2002 - lmb@suse.de
- Fix for Bugzilla # 17936; PreRequires corrected.
* Mon Aug 12 2002 - lmb@suse.de
- Perl dependencies updated for Perl 5.8.0
* Fri Jul 26 2002 - lmb@suse.de
- Perl dependencies adjusted to comply with SuSE naming scheme
* Fri Jul 26 2002 - lmb@suse.de
- Adapted from Conectiva to UnitedLinux
- init script cleanup
* Wed Jul 24 2002 - Fábio Olivé Leite <olive@conectiva.com.br>
- Version: mon-0.99.2-1ul
- Adapted for United Linux
* Sat Jul 20 2002 - Claudio Matsuoka <claudio@conectiva.com>
- Version: mon-0.99.2-3cl
- updated dependencies on perl modules to lowercase names
* Thu May 16 2002 - Fábio Olivé Leite <olive@conectiva.com.br>
- Version: mon-0.99.2-2cl
- Added %%attr to %%{_libdir}/mon/*, so that the helper scripts are executable
  Closes: #5522 (aparente problema com as permissões)
- Changed initscript to use gprintf
  Closes: #4172 (Internacionalização (?))
* Fri Dec 28 2001 - Ricardo Erbano <erbano@conectiva.com>
- Version: mon-0.99.2-1cl
- New upstream relase 0.99.2
* Sat Nov 17 2001 - Claudio Matsuoka <claudio@conectiva.com>
- Version: mon-0.38.20-6cl
- fixed doc permissions
* Thu Jun 21 2001 - Eliphas Levy Theodoro <eliphas@conectiva.com>
- Version: mon-0.38.20-5cl
- fixed initscript - /usr/lib/mon -> /usr/sbin (Closes: #3792)
- added requires for perl-Convert-BER
- added post{,un} scripts to handle logfile mon_history.log
* Fri Mar 23 2001 - Luis Claudio R. Gonçalves <lclaudio@conectiva.com.br>
- Version: mon-0.38.20-4cl
- fixed the initscript (it was missing a "-f" switch)
* Tue Oct 31 2000 - Arnaldo Carvalho de Melo <acme@conectiva.com.br>
- %%{_sysconfdir}/mon is part of this package
- small cleanups
* Thu Sep 28 2000 - Fábio Olivé Leite <olive@conectiva.com>
- Wrong version in the mon-perl dependency...
* Thu Sep 21 2000 - Fábio Olivé Leite <olive@conectiva.com>
- Updated to 0.38.20.
* Fri Jun 16 2000 - Fábio Olivé Leite <olive@conectiva.com>
- Fixed TIM alert, added history file, added logrotate script
* Mon Jun 12 2000 - Fábio Olivé Leite <olive@conectiva.com>
- Added an alert via TIM Celular cellphones
* Thu Jun 08 2000 - Fábio Olivé Leite <olive@conectiva.com>
- Made the %%preun nicer
* Thu Jun 01 2000 - Fábio Olivé Leite <olive@conectiva.com>
- New spec format
* Mon Apr 17 2000 - Fábio Olivé Leite <olive@conectiva.com>
- Added a new monitor (initscript.monitor)
* Fri Apr 14 2000 - Fábio Olivé Leite <olive@conectiva.com>
- Added proxy support to http.monitor
* Thu Apr 13 2000 - Fábio Olivé Leite <olive@conectiva.com>
- Fixed a small bug in the init script
- Added scripts to alert via Mobi pagers and Global Telecom cellphones
* Mon Apr 10 2000 - Fábio Olivé Leite <olive@conectiva.com>
- Initial RPM packaging
