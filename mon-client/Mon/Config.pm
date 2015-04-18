#
# Perl module for interacting with a mon server
#
# $Id: Config.pm,v 1.1.1.1 2004/06/18 14:25:16 trockij Exp $
#
# Copyright (C) 1998-2000 Jim Trocki
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
#
package Mon::Config;
require Exporter;
require 5.004;
use strict;

@ISA = qw(Exporter);
@EXPORT_OK = qw($VERSION);

$VERSION = "1.0000";

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = {
	"error" => "",
    	"alias" => undef,
	"group" => {},
	"watch" => {},
	"cf"	=> {},
    };

    bless ($self, $class);
    return $self;
}


sub error
{
    my $self = shift;

    return $self->{"error"};
}

#
# parse configuration file
#
# build the following data structures:
#
# %group
#       each element of %group is an array of hostnames
#       group records are terminated by a blank line in the
#       configuration file
# %watch{"group"}->{"service"}->{"variable"} = value
# %alias
#
sub read
{
    my $self = shift;
    my (%args) = @_;

    $self->{"error"} = "";

    my ($var, $watchgroup, $ingroup, $curgroup, $inwatch,
	$args, $hosts, %disabled, $h, $i,
	$inalias, $curalias);
    my ($sref, $pref);
    my ($service, $period);
    my ($authtype, @authtypes);
    my $line_num = 0;

    #
    # parse configuration file
    #
    if ($args{"m4"} || $args{"file"} =~ /\.m4$/)
    {
	if (!open (CFG, "m4 $args{file} |"))
	{
	    $self->{"error"} = "could not open m4 pipe of $args{file}: $!";
	    return $self->{"error"};
	}
    }
    
    else
    {
	if (!open (CFG, $CF))
	{
	    $self->{"error"} = "could not open $args{file}: $!"
	    return $self->{"error"};
	}
    }

    #
    # buffers to hold the new un-committed config
    #
    my %new_alias = ();
    my %new_CF = %CF;
    my %new_groups;
    my %new_watch;

    my %is_watch;

    my $servnum = 0;

    my $DEP_BEHAVIOR = "a";

    my $incomplete_line = 0;
    my $linepart = "";
    my $l = "";
    my $acc_line = "";

    for (;;)
    {
	#
	# read in a logical "line", which may span actual lines
	#
	do
	{
	    $line_num++;
	    last if (!defined ($linepart = <CFG>));
	    next if $linepart =~ /^\s*#/;

	    #
	    # accumulate multi-line lines (ones which are \-escaped)
	    #
	    if ($incomplete_line) { $linepart =~ s/^\s*//; }

	    if ($linepart =~ /^(.*)\\\s*$/)
	    {
		$incomplete_line = 1;
		$acc_line .= $1;
		chomp $acc_line;
		next;
	    }

	    else
	    {
		$acc_line .= $linepart;
	    }

	    $l = $acc_line;
	    $acc_line = "";

	    chomp $l;
	    $l =~ s/^\s*//;
	    $l =~ s/\s*$//;

	    $incomplete_line = 0;
	    $linepart = "";
	};

	#
	# global variables which can be overriden by the command line
	#
	if (!$inwatch && $l =~ /^(\w+) \s* = \s* (.*) \s*$/ix)
	{
	    if ($1 eq "alertdir") {
		$new_CF{"ALERTDIR"} = $2;

	    } elsif ($1 eq "basedir") {
		$new_CF{"BASEDIR"} = $2;
		$new_CF{"BASEDIR"} = "$PWD/$new_CF{BASEDIR}" if ($new_CF{"BASEDIR"} !~ m{^/});
		$new_CF{"BASEDIR"} =~ s{/$}{};

	    } elsif ($1 eq "cfbasedir") {
		$new_CF{"CFBASEDIR"} = $2;
		$new_CF{"CFBASEDIR"} = "$PWD/$new_CF{CFBASEDIR}" if ($new_CF{"CFBASEDIR"} !~ m{^/});
		$new_CF{"CFBASEDIR"} =~ s{/$}{};

	    } elsif ($1 eq "mondir") {
		$new_CF{"SCRIPTDIR"} = $2;

	    } elsif ($1 eq "logdir") {
		$new_CF{"LOGDIR"} = $2;

	    } elsif ($1 eq "histlength") {
		$new_CF{"MAX_KEEP"} = $2;

	    } elsif ($1 eq "serverport") {
		$new_CF{"SERVPORT"} = $2;

	    } elsif ($1 eq "trapport") {
		$new_CF{"TRAPPORT"} = $2;

	    } elsif ($1 eq "serverbind") {
	    	$new_CF{"SERVERBIND"} = $2;

	    } elsif ($1 eq "trapbind") {
	    	$new_CF{"TRAPBIND"} = $2;

	    } elsif ($1 eq "pidfile") {
		$new_CF{"PIDFILE"} = $2;

	    } elsif ($1 eq "randstart") {
		$new_CF{"RANDSTART"} = dhmstos($2);
		if (!defined ($new_CF{"RANDSTART"})) {
		    close (CFG);
		    return "cf error: bad value '$2' for randstart option (syntax: historictime = timeval), line $line_num";
		}

	    } elsif ($1 eq "maxprocs") {
		$new_CF{"MAXPROCS"} = $2;

	    } elsif ($1 eq "statedir") {
		$new_CF{"STATEDIR"} = $2;

	    } elsif ($1 eq "authfile") {
		$new_CF{"AUTHFILE"} = $2;
                if (! -r $new_CF{"AUTHFILE"}) {
                    close (CFG);
                    return "cf error: authfile '$2' does not exist or is not readable, line $line_num";
                }

	    } elsif ($1 eq "authtype") {
		$new_CF{"AUTHTYPE"} = $2;
		@authtypes = split(' ' , $new_CF{"AUTHTYPE"}) ;
		foreach $authtype (@authtypes) {
		    if ($authtype eq "pam") {
			eval 'use Authen::PAM qw(:constants);' ;
			if ($@ ne "") {
			    close (CFG);
			    return "cf error: could not use PAM authentication: $@";
			}
		    }
		}

	    } elsif ($1 eq "pamservice") {
		$new_CF{"PAMSERVICE"} = $2;

	    } elsif ($1 eq "userfile") {
		$new_CF{"USERFILE"} = $2;
                if (! -r $new_CF{"USERFILE"}) {
                    close (CFG);
                    return "cf error: userfile '$2' does not exist or is not readable, line $line_num";
                }

	    } elsif ($1 eq "ocfile") {
		$new_CF{"OCFILE"} = $2;

	    } elsif ($1 eq "historicfile") {
	    	$new_CF{"HISTORICFILE"} = $2;

	    } elsif ($1 eq "historictime") {
	    	$new_CF{"HISTORICTIME"} = dhmstos($2);
		if (!defined $new_CF{"HISTORICTIME"}) {
		    close (CFG);
		    return "cf error: bad value '$2' for historictime command (syntax: historictime = timeval), line $line_num";
		}

	    } elsif ($1 eq "cltimeout") {
		$new_CF{"CLIENT_TIMEOUT"} = dhmstos($2);
		if (!defined ($new_CF{"CLIENT_TIMEOUT"})) {
		    close (CFG);
		    return "cf error: bad value '$2' for cltimeout command (syntax: cltimeout = secs), line $line_num";
		}

	    } elsif ($1 eq "snmp") {
		if ($2 =~ /^1|yes|on|true$/i) {
		    $new_CF{"SNMP"} = 1;
		    eval "use SNMP";
		    if ($@ ne "") {
			close (CFG);
			return "cf error: could not use SNMP: $@";
		    }
		} else {
		    $new_CF{"SNMP"} = 0;
		}

	    } elsif ($1 eq "monerrfile") {
	    	$new_CF{"MONERRFILE"} = $2;

	    } elsif ($1 eq "dtlogfile") {
		$new_CF{"DTLOGFILE"} = $2;

	    } elsif ($1 eq "dtlogging") {
		$new_CF{"DTLOGGING"} = 0;
		if ($2 == 1 || $2 eq "yes" || $2 eq "true") {
		    $new_CF{"DTLOGGING"} = 1;
		}

	    } elsif ($1 eq "snmpport") {
		$new_CF{"SNMPPORT"} = $2;

	    } elsif ($1 eq "dep_recur_limit") {
	    	$new_CF{"DEP_RECUR_LIMIT"} = $2;

	    } elsif ($1 eq "dep_behavior") {
		if ($2 ne "m" && $2 ne "a") {
		    close (CFG);
		    return "cf error: unknown dependency behavior '$2', line $line_num";
		}
		$DEP_BEHAVIOR = $2;

	    } elsif ($1 eq "syslog_facility") {
	    	$new_CF{"SYSLOG_FACILITY"} = $2;

	    } elsif ($1 eq "startupalerts_on_reset") {
		if ($2 =~ /^1|yes|true|on$/i) {
		    $new_CF{"STARTUPALERTS_ON_RESET"} = 1;
		} else {
		    $new_CF{"STARTUPALERTS_ON_RESET"} = 0;
		}

	    } else {
		close (CFG);
		return "cf error: unknown variable '$1', line $line_num";
	    }

	    next;
	}

	#
	# end of record
	#
	if ($l eq "")
	{
	    $ingroup    = 0;
	    $inalias	= 0;
	    $inwatch    = 0;
	    $period	= 0;

	    $curgroup   = "";
	    $curalias	= "";
	    $watchgroup = "";

	    $servnum	= 0;
	    next;
	}

	#
	# hostgroup record
	#
	if ($l =~ /^hostgroup\s+([a-zA-Z0-9_.-]+)\s*(.*)/)
	{
	    $curgroup = $1;

	    $ingroup = 1;
	    $inalias = 0;
	    $inwatch = 0;
	    $period  = 0;


	    $hosts = $2;
	    %disabled = ();

	    foreach $h (grep (/^\*/, @{$groups{$curgroup}}))
	    {
		# We have to make $i = $h because $h is actually
		# a pointer to %groups and will modify it.
		$i = $h;
		$i =~ s/^\*//;
		$disabled{$i} = 1;
	    }

	    @{$new_groups{$curgroup}} = split(/\s+/, $hosts);

	    #
	    # keep hosts which were previously disabled
	    #
	    for ($i=0;$i<@{$new_groups{$curgroup}};$i++)
	    {
		$new_groups{$curgroup}[$i] = "*$new_groups{$curgroup}[$i]"
		    if ($disabled{$new_groups{$curgroup}[$i]});
	    }

	    next;
	}

	if ($ingroup)
	{
	    push (@{$new_groups{$curgroup}}, split(/\s+/, $l));

	    for ($i=0;$i<@{$new_groups{$curgroup}};$i++)
	    {
		$new_groups{$curgroup}[$i] = "*$new_groups{$curgroup}[$i]"
		    if ($disabled{$new_groups{$curgroup}[$i]});
	    }

	    next;
	}

	#
	# alias record
	#
	if ($l =~ /^alias\s+([a-zA-Z0-9_.-]+)\s*$/)
	{
	    $inalias = 1;
	    $ingroup = 0;
	    $inwatch = 0;
	    $period  = 0;

	    $curalias = $1;
	    next;
	}
	
	if ($inalias)
	{
	    if ($l =~ /\A(.*)\Z/)
	    {
		push (@{$new_alias{$curalias}}, $1);
		next;
	    }
	}

	#
	# watch record
	#
	if ($l =~ /^watch\s+([a-zA-Z0-9_.-]+)\s*/)
	{
	    $watchgroup = $1;
	    $inwatch = 1;
	    $inalias = 0;
	    $ingroup = 0;
	    $period  = 0;

	    if (!defined ($new_groups{$watchgroup}))
	    {
		#
		# This hostgroup doesn't exist yet, we'll create it and warn
		#
	    	@{$new_groups{$watchgroup}} = ($watchgroup);
		print STDERR "Warning: watch group $watchgroup defined with no corresponding hostgroup.\n";
	    }
	    if ($new_watch{$watchgroup})
	    {
		close (CFG);
		return "cf error: watch '$watchgroup' already defined, line $line_num";
	    }

	    $curgroup   = "";
	    $service = "";

	    next;
	}
	
	if ($inwatch)
	{
	    #
	    # env variables
	    #
	    if ($l =~ /^([A-Z_][A-Z0-9_]*)=(.*)/)
	    {
		if ($service eq "") {
		    close (CFG);
		    return "cf error: environment variable defined without a service, line $line_num";
		}
		$new_watch{$watchgroup}->{$service}->{"ENV"}->{$1} = $2;

		next;
	    }

	    #
	    # non-env variables
	    #
	    else
	    {
		$l =~ /^(\w+)\s*(.*)$/;
		$var = $1;
		$args = $2;
	    }

	    #
	    # service entry
	    #
	    if ($var eq "service")
	    {
		$service = $args;

		if ($service !~ /^[a-zA-Z0-9_.-]+$/) {
		    close (CFG);
		    return "cf error: invalid service tag '$args', line $line_num";
		}

		$period = 0;
		$sref = \%{$new_watch{$watchgroup}->{$service}};
		$sref->{"service"} = $args;
		$sref->{"interval"} = undef;
		$sref->{"randskew"} = 0;
		$sref->{"dep_behavior"} = $DEP_BEHAVIOR;
		$sref->{"exclude_period"} = "";
		$sref->{"exclude_hosts"} = {};
		$sref->{"_op_status"} = $STAT_UNTESTED;
		$sref->{"_last_op_status"} = $STAT_UNTESTED;
		$sref->{"_ack"} = 0;
		$sref->{"_ack_comment"} = '';
		$sref->{"_consec_failures"} = 0;
		$sref->{"_failure_count"} = 0 if (!defined($sref->{"_failure_count"}));
		$sref->{"_start_of_monitor"} = time if (!defined($sref->{"_start_of_monitor"}));
		$sref->{"_alert_count"} = 0 if (!defined($sref->{"_alert_count"}));
		$sref->{"_last_failure"} = 0 if (!defined($sref->{"_last_failure"}));
		$sref->{"_last_success"} = 0 if (!defined($sref->{"_last_success"}));
		$sref->{"_last_trap"} = 0 if (!defined($sref->{"_last_trap"}));
		$sref->{"_exitval"} = "undef" if (!defined($sref->{"_exitval"}));
		$sref->{"_last_check"} = undef;
		$sref->{"_depend_status"} = undef;
		$sref->{"failure_interval"} = undef;
		$sref->{"_old_interval"} = undef;
		next;
	    }

	    if ($service eq "")
	    {
		close (CFG);
		return "cf error: need to specify service in watch record, line $line_num";
	    }


	    #
	    # period definition
	    #
	    # for each service there can be one or more alert periods
	    # this is stored as an array of hashes named
	    #     %{$watch{$watchgroup}->{$service}->{"periods"}}
	    # each index for this hash is a unique tag for the period as
	    # defined by the user or named after the period (such as
	    # "wd {Mon-Fri} hr {7am-11pm}")
	    #
	    # the value of the hash is an array containing the list of alert commands
	    # and arguments, so
	    #
	    # @alerts = @{$watch{$watchgroup}->{$service}->{"periods"}->{"TAG"}}
	    #
	    if ($var eq "period")
	    {
		$period = 1;

		my $periodstr;

		if ($args =~ /^([a-z_]\w*) \s* : \s* (.*)$/ix)
		{
		    $periodstr = $1;
		    $args = $2;
		}
		
		else
		{
		    $periodstr = $args;
		}

		$pref = \%{$sref->{"periods"}->{$periodstr}};

		if (inPeriod (time, $args) == -1)
		{
		    close (CFG);
		    return "cf error: malformed period '$args' (the specified time period is not valid as per Time::Period::inPeriod), line $line_num";
		}

		$pref->{"period"} = $args;
		$pref->{"alertevery"} = 0;
		$pref->{"numalerts"} = 0;
		$pref->{"_alert_sent"} = 0;
		$pref->{"no_comp_alerts"} = 0;
		@{$pref->{"alerts"}} = ();
		@{$pref->{"upalerts"}} = ();
		@{$pref->{"startupalerts"}} = ();
		next;
	    }

	    #
	    # period variables
	    #
	    if ($period)
	    {
		if ($var eq "alert")
		{
		    push @{$pref->{"alerts"}}, $args;
		}
		
		elsif ($var eq "upalert")
		{
		    $sref->{"_upalert"} = 1;
		    push @{$pref->{"upalerts"}}, $args;
		}
		
		elsif ($var eq "startupalert")
		{
		    push @{$pref->{"startupalerts"}}, $args;
		}
		
		elsif ($var eq "alertevery")
		{
		    my $observe_detail = 0;

		    if ($args =~ /(\S+) \s+ observe_detail \s*$/ix)
		    {
			$observe_detail = 1;
			$args = $1;
		    }

		    #
		    # for backawards-compatibility with <= 0.38.21
		    #
		    elsif ($args =~ /(\S+) \s+ summary/ix)
		    {
			$args = $1;
		    }

		    if (!($args = dhmstos ($args))) {
			close (CFG);
			return "cf error: invalid time interval '$args' (syntax: alertevery {positive number}{smhd}), line $line_num";
		    }

		    $pref->{"alertevery"} = $args;
		    $pref->{"_observe_detail"} = $observe_detail;
		    next;
		}

		elsif ($var eq "alertafter")
		{
		    my ($p1, $p2);

		    #
		    # alertafter NUM
		    #
		    if ($args =~ /^(\d+)$/)
		    {
			$p1 = $1;
			$pref->{"alertafter_consec"} = $p1;
		    }

		    #
		    # alertafter timeval
		    #
		    elsif ($args =~ /^(\d+[hms])$/)
		    {
			$p1 = $1;
			if (!($p1 = dhmstos ($p1)))
			{
			    close (CFG);
			    return "cf error: invalid time interval '$args' (syntax: alertafter = [{positive integer}] [{positive number}{smhd}]), line $line_num";
			}

			$pref->{"alertafterival"} = $p1;
			$pref->{"_1stfailtime"} = 0;
		    }

		    #
		    # alertafter NUM timeval
		    #
		    elsif ($args =~ /(\d+)\s+(\d+[hms])$/)
		    {
			($p1, $p2) = ($1, $2);
			if (($p1 - 1) * $sref->{"interval"} >= dhmstos($p2))
			{
			    close (CFG);
			    return "cf error:  interval & alertafter not sensible. No alerts can be generated with those parameters, line $line_num";
			}
			$pref->{"alertafter"} = $p1;
			$pref->{"alertafterival"} = dhmstos ($p2);

			$pref->{"_1stfailtime"} = 0;
			$pref->{"_failcount"} = 0;
		    }

		    else
		    {
			close (CFG);
			return "cf error: invalid interval specification '$args', line $line_num";
		    }
		}
	    
		elsif ($var eq "upalertafter")
		{
		    if (!($args = dhmstos ($args))) {
			close (CFG);
			return "cf error: invalid upalertafter specification '$args' (syntax: upalertafter = {positive number}{smhd}), line $line_num";
		    }
		}
		
		elsif ($var eq "numalerts")
		{
		    if ($args !~ /^\d+$/) {
			close (CFG);
			return "cf error: -numeric arg '$args' (syntax: numalerts = {positive integer}, line $line_num";
		    }
		    $pref->{"numalerts"} = $args;
		    next;
		}

		elsif ($var eq "no_comp_alerts")
		{
		    $pref->{"no_comp_alerts"} = 1;
		    next;
		}
	    }

	    #
	    # non-period variables
	    #
	    elsif (!$period)
	    {
		if ($var eq "interval")
		{
		    if (!($args = dhmstos ($args))) {
			close (CFG);
			return "cf error: invalid time interval '$args' (syntax: interval = {positive number}{smhd}), line $line_num";
		    }
		}

		elsif ($var eq "failure_interval")
		{
		    if (!($args = dhmstos ($args))) {
			close (CFG);
			return "cf error: invalid interval '$args' (syntax: failure_interval = {positive number}{smhd}), line $line_num";
		    }
		}

		elsif ($var eq "monitor")
		{
		    # valid
		}

		elsif ($var eq "allow_empty_group")
		{
		    # valid
		}

		elsif ($var eq "description")
		{
		    # valid
		}

		elsif ($var eq "traptimeout")
		{
		    if (!($args = dhmstos ($args))) {
			close (CFG);
			return "cf error: invalid traptimeout interval '$args' (syntax: traptimeout = {positive number}{smhd}), line $line_num";
		    }
		    $sref->{"_trap_timer"} = $args;
		}

		elsif ($var eq "trapduration")
		{
		    if (!($args = dhmstos ($args))) {
			close (CFG);
			return "cf error: invalid trapduration interval '$args' (syntax: trapduration = {positive number}{smhd}), line $line_num";
		    }
		}
		
		elsif ($var eq "randskew")
		{
		    if (!($args = dhmstos ($args))) {
			close (CFG);
			return "cf error: invalid randskew time interval '$args' (syntax: randskew = {positive number}{smhd}), line $line_num";
		    }
		}


		
		elsif ($var eq "dep_behavior")
		{
		    if ($args ne "m" && $args ne "a")
		    {
			close (CFG);
			return "cf error: unknown dependency behavior '$args' (syntax: dep_behavior = {m|a}), line $line_num";
		    }
		}

		elsif ($var eq "depend")
		{
		    $args =~ s/SELF:/$watchgroup:/g;
		}

		elsif ($var eq "exclude_hosts")
		{
		    my $ex = {};
		    foreach my $h (split (/\s+/, $args))
		    {
			$ex->{$h} = 1;
		    }
		    $args = $ex;
		}

		elsif ($var eq "exclude_period" && inPeriod (time, $args) == -1)
		{
		    close (CFG);
		    return "cf error: malformed exclude_period '$args' (the specified time period is not valid as per Time::Period::inPeriod), line $line_num";
		}

		else
		{
		    close (CFG);
		    return "cf error: unknown syntax [$l], line $line_num";
		}

		$sref->{$var} = $args;
	    }

	    else
	    {
		close (CFG);
		return "cf error: unknown syntax outside of period section [$l], line $line_num";
	    }
	}

	next;
    }

    close (CFG) || return "Could not open pipe to m4 (check that m4 is properly installed and in your PATH): $!";

    #
    # Go through each defined hostgroup and check that there is a 
    #  watch associated with that hostgroup record.
    #
    # hostgroups without associated watches are not a violation of 
    #  mon config syntax, but it's usually not what you want.
    #
    for (keys(%new_watch)) { $is_watch{$_} = 1 };
    foreach $watchgroup ( keys (%new_groups) ) {
	print STDERR "Warning: hostgroup $watchgroup has no watch assigned to it!\n" unless $is_watch{$watchgroup};
    }

    "";
}



=head1 NAME

Mon::Client - Methods for interaction with Mon client

=head1 SYNOPSIS

    use Mon::Client;

=head1 DESCRIPTION

    Mon::Client is used to interact with "mon" clients. It supports
    a protocol-independent API for retrieving the status of the mon
    server, and performing certain operations, such as disableing hosts
    and service checks.

=head1 METHODS

=over 4

=item new

Creates a new object. A hash can be supplied which sets the
default values. An example which contains all of the variables
that you can initialize:

    $c = new Mon::Client (
    	host => "monhost",
	port => 2583,
	username => "foo",
	password => "bar",
    );

=item password (pw)

If I<pw> is provided, sets the password. Otherwise, returns the
currently set password.

=item host (host)

If I<host> is provided, sets the mon host. Otherwise, returns the
currently set mon host.


=item port (portnum)

If I<portnum> is provided, sets the mon port number. Otherwise, returns the
currently set port number.


=item username (user)

If I<user> is provided, sets the user login. Otherwise, returns the
currently set user login.

=item prot

If I<protocol> is provided, sets the protocol, specified by a string
which is of the form "1.2.3", where "1" is the major revision, "2" is
the minor revision, and "3" is the sub-minor revision.
If I<protocol> is not provided, the currently set protocol is returned.


=item protid ([protocol])

Returns true if client and server protocol match, false otherwise.
Implicitly called by B<connect>. If protocol is specified as an integer,
supplies that protocol version to the server for verification.


=item version

Returns the protocol version of the remote server.

=item error

Returns the error string from set by the last method, or undef if
there was no error.

=item connected

Returns 0 (not connected) or 1 (connected).

=item connect (%args)

Connects to the server. If B<host> and B<port> have not been set,
uses the defaults. Returns I<undef> on error.  If $args{"skip_protid"}
is true, skip protocol identification upon connect.

=item disconnect

Disconnects from the server. Return I<undef> on error.

=item login ( %hash )

B<%hash> is optional, but if specified, should contain two keys,
B<username> and B<password>.

Performs the "login" command to authenticate the user to the server.
Uses B<username> and B<password> if specified, otherwise uses
the username and password previously set by those methods, respectively.


=item checkauth ( command )

Checks to see if the specified command, as executed by the current user,
is authorized by the server, without actually executing the command.
Returns 1 (command is authorized) or 0 (command is not authorized).


=item disable_watch ( watch )

Disables B<watch>.

=item disable_service ( watch, service )

Disables a service, as specified by B<watch> and B<service>.


=item disable_host ( host )

Disables B<host>.

=item enable_watch ( watch )

Enables B<watch>.

=item enable_service ( watch, service )

Enables a service as specified by B<watch> and B<service>.

=item enable_host ( host )

Enables B<host>.

=item set ( group, service, var, val )

Sets B<var> in B<group,service> to B<val>. Returns
undef on error.

=item get ( group, service, var )

Gets variable B<var> in B<group,service> and returns it,
or undef on error.

=item quit

Logs out of the server. This method should be followed
by a call to the B<disconnect> method.

=item list_descriptions

Returns a hash of service descriptions, indexed by watch
and service. For example:

    %desc = $mon->list_descriptions;
    print "$desc{'watchname'}->{'servicename'}\n";

=item list_deps

Lists dependency expressions and their components for all
services. If there is no dependency for a particular service,
then the value will be "NONE".

    %deps = $mon->list_deps;
    foreach $watch (keys %deps) {
    	foreach $service (keys %{$deps{$watch}}) {
	    my $sref = \%{$deps{$watch}->{$service}};
	    print "expr ($watch,$service) = $sref->{expression}\n";
	    print "components ($watch,$service) = @{$sref->{components}}\n";
	}
    }

=item list_group ( hostgroup )

Lists members of B<hostgroup>. Returns an array of each
member.

=item list_watch

Returns an array of all the defined watch groups and services.

    foreach $w ($mon->list_watch) {
    	print "group=$w->[0] service=$w->[1]\n";
    }

=item list_opstatus ( [group1, service1], ... )

Returns a hash of per-service operational statuses, as indexed by watch
and service. The list of anonymous arrays is optional, and if is not
provided then the status of all groups and services will be queried.

    %s = $mon->list_opstatus;
    foreach $watch (keys %s) {
    	foreach $service (keys %{$s{$watch}}) {
	    foreach $var (keys %{$s{$watch}{$service}}) {
	    	print "$watch $service $var=$s{$watch}{$service}{$var}\n";
	    }
	}
    }

=item list_failures

Returns a hash in the same manner as B<list_opstatus>, but only
the services which are in a failure state.

=item list_successes

Returns a hash in the same manner as B<list_opstatus>, but only
the services which are in a success state.

=item list_disabled

Returns a hash of disabled watches, services, and hosts.

    %d = $mon->list_disabled;

    foreach $group (keys %{$d{"hosts"}}) {
    	foreach $host (keys %{$d{"hosts"}{$group}}) {
	    print "host $group/$host disabled\n";
	}
    }

    foreach $watch (keys %{$d{"services"}}) {
    	foreach $service (keys %{$d{"services"}{$watch}}) {
	    print "service $watch/$service disabled\n";
	}
    }

    for (keys %{$d{"watches"}}) {
    	print "watch $_ disabled\n";
    }

=item list_alerthist

Returns an array of hash references containing the alert history.

    @a = $mon->list_alerthist;

    for (@a) {
    	print join (" ",
	    $_->{"type"},
	    $_->{"watch"},
	    $_->{"service"},
	    $_->{"time"},
	    $_->{"alert"},
	    $_->{"args"},
	    $_->{"summary"},
	    "\n",
	);
    }

=item list_dtlog

Returns an array of hash references containing the downtime log.

@a = $mon->list_dtlog

     for (@a) {
       print join (" ",
           $_->{"timeup"},
           $_->{"group"},
           $_->{"service"},
           $_->{"failtime"},
           $_->{"downtime"},
           $_->{"interval"},
           $_->{"summary"},
           "\n",
       );
     }

=item list_failurehist

Returns an array of hash references containing the failure history.

    @f = $mon->list_failurehist;

    for (@f) {
    	print join (" ",
	    $_->{"watch"},
	    $_->{"service"},
	    $_->{"time"},
	    $_->{"summary"},
	    "\n",
	);
    }

=item list_pids

Returns an array of hash references containing the list of process IDs
of currently active monitors run by the server.

    @p = $mon->list_pids;

    $server = shift @p;

    for (@p) {
    	print join (" ",
	    $_->{"watch"},
	    $_->{"service"},
	    $_->{"pid"},
	    "\n",
	);
    }

=item list_state

Lists the state of the scheduler. Returns a two-element array. The 
first element of the array is 0 if the scheduler is stopped, and 1
if the scheduler is currently running. The second element of the array
returned is the string "scheduler running" if the scheduler is 
currently running, and if the scheduler is stopped, the second
element is the time(2) that the scheduler was stopped.

    @s = $mon->list_state;

    if ($s[0] == 0) {
    	print "scheduler stopped since " . localtime ($s[1]) . "\n";
    }

=item start

Starts the scheduler.

=item stop

Stops the scheduler.

=item reset

Resets the server.

=item reload ( what )

Causes the server to reload its configuration. B<what> is an optional
argument, and currently the only supported option is B<auth>, which
reloads the authorization file.

=item term

Terminates the server.

=item set_maxkeep

Sets the maximum number of history entries to store in memory.

=item get_maxkeep

Returns the maximum number of history entries to store in memory.

=item test ( test, group, service [, exitval, period])

Schedules a service test to run immediately, or tests an alert for a
given period. B<test> must be B<monitor>, B<alert>, B<startupalert>, or
B<upalert>. To test alerts, the B<exitval> and B<period> must be supplied.
Periods are identified by their label in the mon config file. If there
are no period tags, then the actual period string must be used, exactly
as it is listed in the config file.

=item test_config

Tests the syntax of the configuration file. Returns a two-element 
array. The first element of the array is 0 if the syntax of the
config file is invalid, and 1 if the syntax of the config file
is OK. The second element of the array returned is the failure 
message, if the config file has invalid syntax, and the result code
if the config file syntax is OK. This function returns undef if it
cannot get a connection or a response from the mon server.

Config file checking stops as soon as an error is found, so
you will need to run this command more than once if you have multiple
errors in your config file in order to find them all.

    @s = $mon->test_config;

    if ($s[0] == 0) {
        print "error in config file:\n" . $s[1] . "\n";
    }


=item ack ( group, service, text )

When B<group/service> is in a failure state,
acknowledges this with B<text>, and disables all further
alerts during this failure period.

=item loadstate ( state )

Loads B<state>.

=item savestate ( state )

Saves B<state>.

=item servertime

Returns the time on the server using the same output as the
time(2) system call.

=item send_trap ( %vars )

Sends a trap to a remote mon server. Here is an example:

    $mon->send_trap (
    	group		=> "remote-group",
	service		=> "remote-service",
	retval		=> 1,
	opstatus	=> "fail",
	summary		=> "hosta hostb hostc",
	detail		=> "hosta hostb and hostc are unresponsive",
    );

I<retval> must be a nonnegative integer.

I<opstatus> must be one of I<fail>, I<ok>, I<coldstart>, I<warmstart>,
I<linkdown>, I<unknown>, I<timeout>,  I<untested>.

Returns I<undef> on error.

=back

=cut
