dnl
dnl ########################################################################
dnl #          This file is meant to be processed with m4                  #
dnl ########################################################################
dnl
dnl #
dnl # m4 macro definitions
dnl #
dnl
define(_DIR_,           `/usr/lib/mon')dnl
define(_FILE_LOG_DIR_,  `_DIR_/file-log.d')dnl
dnl
dnl #
dnl # useful time periods
dnl #
dnl
define(_FILE_,          `_TST_/log.d')dnl
define(_WEEKDAY_,       `wd {Mon-Fri}')dnl
define(_WEEKEND_,       `wd {Sat-Sun}')dnl
define(_ANYTIME_,       `wd {Sun-Sat}')dnl
define(_OFF_HOURS_,     `wd {Mon-Fri} hr {10pm-7am}, wd {Sat Sun}')dnl
define(_WORK_HOURS_,    `wd {Mon-Fri} hr {7am-10pm}')dnl
define(_PAGING_HOURS_,  `_WORK_HOURS_')dnl
dnl
dnl #
dnl # useful pager aliases
dnl #
dnl
define(_MIS_PAGER_,    `joe bob zoomzip')dnl
dnl
dnl #
dnl # useful mail aliases
dnl #
dnl
define(_MIS_EMAIL_,       `joe bob zoomzip')dnl
define(_PRINTER_EMAIL_,   `zoomzip')dnl       # facilities are responsible for
dnl                                           # printer maintenance
define(_RAS_EMAIL_,       `bob')dnl           # bob is the remote access admin
dnl
dnl #
dnl # -------------------------actual config begins here-------------------------
dnl #
#
# Example "mon.cf" configuration for "mon".
#
# $Id: example.m4,v 1.1.1.1 2004/06/09 05:18:06 trockij Exp $
#
#
# This works with 0.38pre13
#

#
# global options
#
cfbasedir   = _DIR_/etc
alertdir    = _DIR_/alert.d
mondir      = _DIR_/mon.d
maxprocs    = 20
histlength  = 100
randstart   = 60s

#
# authentication types:
#   getpwnam      standard Unix passwd, NOT for shadow passwords
#   shadow        Unix shadow passwords (not implemented)
#   userfile      "mon" user file
#
authtype = getpwnam

#
# NB:  hostgroup and watch entries are terminated with a blank line (or
# end of file).  Don't forget the blank lines between them or you lose.
#

#
# group definitions (hostnames or IP addresses)
#
hostgroup serversbd1 dns-yp1 foo1 bar1

hostgroup serversbd2 dns-yp2 foo2 bar2 ola3

hostgroup routers cisco7000 linuxrouter agsplus

hostgroup hubs cisco316t hp800t ssii10

hostgroup workstations blue yellow red green cornflower violet

hostgroup netapps f330 f540

hostgroup wwwservers www

hostgroup printers hp5si hp5c hp750c

hostgroup new nntp

hostgroup ftp ftp

#
# For the servers in building 1, monitor ping and telnet
# BOFH is on weekend call :)
#
watch serversbd1
    service ping
	description ping servers in bd1
	interval 5m
	monitor fping.monitor
	period _WORK_HOURS_
	    alert mail.alert _MIS_EMAIL_
	    alertevery 1h
	period PAGE: _PAGING_HOURS_
	    alert qpage.alert _MIS_PAGER_
	    alertevery 2h
	period _WEEKEND_
	    alert mail.alert bofh@domain.com
	    alert qpage.alert bofh@domain.com
	    alertevery 1h
    service telnet
	description telnet to servers in bd1
	interval 10m
	monitor telnet.monitor
	depend serversbd1:ping
	period _WORK_HOURS_
	    alertevery 1h
	    alertafter 2 30m
	    alert mail.alert _MIS_EMAIL_
	period PAGE: _PAGING_HOURS_
	    alert qpage.alert _MIS_PAGER_
	    alertevery 2h

watch serversbd2
    service ping
	description ping servers in bd2
	interval 5m
	monitor fping.monitor
	depend routers:ping
	period _WORK_HOURS_
	    alert mail.alert _MIS_EMAIL_
	    alertevery 1h
	period _WEEKEND_
	    alert mail.alert bofh@domain.com
	    alert qpage.alert bofh@domain.com
    service telnet
	description telnet to servers in bd2
	interval 10m
	monitor telnet.monitor
	depend routers:ping serversbd2:ping
	period _WORK_HOURS_
	    alertevery 1h
	    alertafter 2 30m
	    alert mail.alert _MIS_EMAIL_
	period PAGE: _PAGING_HOURS_
	    alert qpage.alert _MIS_PAGER_
	    alertevery 2h

watch mailhost
    service fping
	period _WORK_HOURS_
	    alert mail.alert _MIS_EMAIL_
	    alert qpage.alert _MIS_PAGER_
	    alertevery 1h
    service telnet
	interval 10m
	monitor telnet.monitor
	period _WORK_HOURS_
	    alertevery 1h
	    alertafter 2 30m
	    alert mail.alert _MIS_EMAIL_
	    alert qpage.alert _MIS_PAGER_
    service smtp
	interval 10m
	monitor smtp.monitor
	period _WORK_HOURS_
	    alertevery 1h
	    alertafter 2 30m
	    alert qpage.alert _MIS_PAGER_
    service imap
	interval 10m
	monitor imap.monitor
	period _WORK_HOURS_
	    alertevery 1h
	    alertafter 2 30m
	    alert qpage.alert _MIS_PAGER_
    service pop
	interval 10m
	monitor pop3.monitor
	period _WORK_HOURS_
	    alertevery 1h
	    alertafter 2 30m
	    alert qpage.alert _MIS_PAGER_

watch wwwservers
    service ping
	interval 2m
	monitor fping.monitor
	allow_empty_group
	period _ANYTIME_
	    alert qpage.alert _MIS_PAGER_
	    alertevery 45m
    service http
	interval 4m
	monitor http.monitor
	allow_empty_group
	period _ANYTIME_
	    alert qpage.alert _MIS_PAGER_
	    upalert mail.alert -S "web server is back up" _MIS_EMAIL_
	    alertevery 45m
    service telnet
	monitor telnet.monitor
	allow_empty_group
	period _WORK_HOURS_
	    alertevery 1h
	    alertafter 2 30m
	    alert mail.alert _MIS_EMAIL_
	    alert qpage.alert _MIS_PAGER_

#
# If the routers aren't pingable, send a page using
# a phone line and the IXO protocol, which doesn't
# rely on the network. Failure of a router is pretty serious,
# so check every two minutes.
#
# Send out one page every 45 minutes, but log the failure
# to a file every time.
#
watch routers
    service ping
	description routers which connect bd1 and bd2
	interval 1m
	monitor fping.monitor
	period _ANYTIME_
	    alert qpage.alert _MIS_PAGER_
	    alertevery 45m
	period LOGFILE: _ANYTIME_
	    alert file.alert -d _FILE_LOG_DIR_ routers.log ;;

#
# If mon cannot ping one of the hubs, users will be calling soon
#
watch hubs
    service ping
	interval 1m
	monitor fping.monitor
	period _ANYTIME_
	    alert qpage.alert _MIS_PAGER_
	    alertevery 45m

#
# Monitor free disk space on the NFS servers
#
# When space gets below 5 megs, send mail, and delete
# the oldest nightly snapshots.
#
# monitors that terminate with ";;" are not executed with the
# host group appended to the command line
#
watch netapps
    service freespace
    	interval 15m
	monitor freespace.monitor /f330:5000 /f540:5000 ;;
	period _ANYTIME_
	    alert mail.alert _MIS_EMAIL_
#	    alert delete.snapshot
	    alertevery 1h

#
# workstations
#
watch workstations
    service ping
	interval 5m
	monitor fping.monitor
	period _ANYTIME_
	    alert mail.alert _MIS_EMAIL_
	    alertevery 1h

#
# news server
#
watch news
    service ping
	interval 5m
	monitor fping.monitor
	period _ANYTIME_
	    alert mail.alert _MIS_EMAIL_
	    alertevery 1h
    service nntp
	interval 5m
	monitor nntp.monitor
	period _ANYTIME_
	    alert mail.alert _MIS_EMAIL_
	    alertevery 1h

#
# HP printers
#
watch printers
    service ping
	interval 5m
	monitor fping.monitor
	period _ANYTIME_
	    alert mail.alert _PRINTER_EMAIL_
	    alertevery 1h
    service hpnp
	interval 5m
	monitor hpnp.monitor
	period wd {Sun-Sat}
	    alert mail.alert _PRINTER_EMAIL_
	    alertevery 1h

#
# FTP server
#
watch ftp
    service ftp
	interval 5m
	monitor ftp.monitor
	period _ANYTIME_
	    alert mail.alert _MIS_EMAIL_
	    alertevery 1h

#
# dial-in terminal server
#
watch dialin
    service 555-1212
        interval 60m
        monitor dialin.monitor.wrap -n 555-1212 -t 80 ;;
        period _ANYTIME_
            alert mail.alert _RAS_EMAIL_
            upalert mail.alert _RAS_EMAIL_
            alertevery 8h
    service 555-1213
        interval 33m
        monitor dialin.monitor.wrap -n 555-1213 -t 80 ;;
        period wd {Sun-Sat}
            alert mail.alert _RAS_EMAIL_
            upalert mail.alert _RAS_EMAIL_
            alertevery 8h
