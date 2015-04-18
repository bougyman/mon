#!/usr/bin/perl -w
#
# monremote.pl - Propagates client (user) requests from one mon process to another, 
#   via mon.cgi
#
# David Nolan, vitroth@cmu.edu
#
# $Id: monremote.pl,v 1.2 2004/11/15 14:45:17 vitroth Exp $
#
# Copyright (C) 2002 Carnegie Mellon University
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#


# monremote.pl will issue HTTPS requests to a remote Mon server.  You must provide it with an
# SSL certificate & key, and tell it where mon.cgi is running on the remote server.

# Configuration block
# SSL Key.  You can use your apache server's key for simplicity
$crt = '/usr/local/apache/conf/ssl.crt/server.crt';
$key = '/usr/local/apache/conf/ssl.key/server.key';
# List of servers to propagate changes to
@hosts = ('monserver1.example.com', 'monserver2.example.com');
# Name of your master Mon server, to prevent propagations from any other hosts
$mon_master = "mon-master.example.com";
# URI of mon.cgi on the remote servers.  If its different on individual servers
# you'll need to do extra work.  (Make the hosts list a hash, with the URLS.)
$path = '/cbin/mon.cgi';
# Set this to non-zero to enable debugging
$debug = 0;

# Comment this out once you've edited the config block above.
die "monremote.pl must be customized for your environment!  Please edit the configuration block.";



# You shouldn't need to change anything below here.


use LWP::UserAgent;
use Sys::Hostname;

if (!defined $ARGV[0]) {
    print "Usage: monremote.pl (enable|disable|test) (watch <groupname>|host <hostname>|service <group> <service>)\n";
    exit;
}


# Make sure we're running on the master.
$hostname = hostname;
$hostname =~ tr/a-z/A-Z/;
$mon_master =~ tr/a-z/A-Z/;
if ($hostname ne $mon_master) {
    print STDERR "No propagation from servers other then the master!\n";
    exit -1;
}


# Figure out what the argument portions of the URL need to be.
if ($ARGV[0] eq 'disable') {
    $args = "?command=mon_disable";
    if ($ARGV[1] eq 'watch') {
	$args .= "&args=watch,$ARGV[2]&rt=none";
    } elsif ($ARGV[1] eq 'service') {
	$args .= "&args=service,$ARGV[2],$ARGV[3]&rt=none";
    } elsif ($ARGV[1] eq 'host') {
	$args .= "&args=host,$ARGV[2]&rt=none";
    }
} elsif ($ARGV[0] eq 'enable') {
    $args = "?command=mon_enable";
    if ($ARGV[1] eq 'watch') {
	$args .= "&args=watch,$ARGV[2]&rt=none";
    } elsif ($ARGV[1] eq 'service') {
	$args .= "&args=service,$ARGV[2],$ARGV[3]&rt=none";
    } elsif ($ARGV[1] eq 'host') {
	$args .= "&args=host,$ARGV[2]&rt=none";
    }
} elsif ($ARGV[0] eq 'test') {
    $args = "?command=mon_test_service&args=$ARGV[1],$ARGV[2]";
} else {
    print STDERR "Unknown command $ARGV[0]\n";
    exit -1;
}


$ENV{HTTPS_CERT_FILE} = $crt;
$ENV{HTTPS_KEY_FILE} = $key;

# Now fork and do the work.
# We fork so that we don't wait for each individual request to finish.
# We fork twice so that the kernel will take care of process cleanup for us.
$pid = fork;
if ($pid) {
    waitpid ($pid, 0);
    print STDERR "Parent exiting\n" if ($debug);
    exit 0;
} else {
    foreach $host (@hosts) {
	if (fork) {
	    next;
	}
	my $ua = LWP::UserAgent->new;
	
	$ua->agent("MonRemote/0.1");
	print STDERR "@ARGV\n" if ($debug);
	print STDERR "$args\n" if ($debug);
	my $req = HTTP::Request->new(GET => "https://$host/$path$args");
	
	$req ->content_type('application/x-www-form-urlencoded');
	
	my $res = $ua->request($req);
	
	if ($res->is_success) {
	    print STDERR "Worker exiting\n" if ($debug);
	    exit 0;
	} else {
	    print STDERR "\n$host\n@ARGV\nRequest to remote server failed\n";
	    exit 0;
	}
    }
    print STDERR "Child exiting\n" if ($debug);
    exit 0;
}
