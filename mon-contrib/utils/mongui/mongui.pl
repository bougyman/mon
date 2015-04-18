#!/usr/bin/perl -w -d

# Copyright (C) 2000 Daniel J. Urist
# Contact: Daniel J. Urist <durist@world.std.com>
# Portions of this code are Copyright (C) Jim Trocki
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.


# FIXME 
# - all options supported from latest mon release?
# - hostgroup crashes (still!); right now we preload the debugger as a kluge
# - path validations should test for regular file vs. directory


# RECONSIDER
# - current validation scheme for globals warns but sets them anyway?
#

# TODO:
# - Edit help doco from mon to make it more relevant to the GUI
# - More validation
# - Watches that don't have any periods should be grayed out
# - More use should be made of the Watches HList; it should come up
#   with just a list of hostgroups; double-clicking on a hostgroup should
#   bring up a list of watches. Ideally, we should be able to drag and 
#   drop watches between hostgroups.
# - Add dialog for config file reopen

# Tell the debugger to go nonstop
BEGIN {
  $ENV{PERLDB_OPTS} = "N";
}

my $Version = '1.0';

require 5.00503;

use strict;
use Time::Period; # Needed for read_cf
use Tk;
use Tk::Dialog;
use Tk::Scale;
use Tk::Balloon;
use Tk::HList;
use Tk::BrowseEntry;
use Tk::Pane;

# Global variables for config file 
my $monconfigfile; # Config file
my $savefile;      # Save file
my %CF;
my %groups;
my %watch;
my %globals;       # We have to get this ourselves; read_cf doesn't do it completely


# Globals for windows we only want one of
my $Help;
my $Balloon;       # For any and all balloon help
my $Edit_globals;
my $Edit_global_submenu;
my $Edit_hostgroups;
my $Edit_hostgroups_add;
my $Edit_watches;
my $Edit_watches_edit;
my $Edit_watches_edit_period;
my $Edit_watches_edit_period_add_alert;

#
# Tk Entry function used a lot in the hash below
#
sub GLOBALS_entry {
  my($parent, $value, $g, $msg, $widgets) = @_;
  my $id = $parent->Entry();
  $id->insert(0, $value);
  $Balloon->attach($id, -balloonmsg => $msg);
  return $id;
}

#
# Path validation function used a lot in the hash 
#
sub GLOBALS_path_validate {
  my($parent, $val) = @_;
  $parent->Dialog(-title => 'Warning', 
		  -text => "The path \"$val\" Does Not Exist")->Show
		    unless -e $val;
} 
  
  
#
# All possible global vars in the mon config file and the widget we use to display and set them
#
# The "widget" subroutine gets passed the following args:
#   parent widget ID
#   current value of variable
#   ref to duped globals hash
#   balloon help message
#   ref to hash of widget ids in parent window
#
# This is an odd assortment of stuff, but it's convenient. It would be really nice if Perl provided
# some way to do simple in-line objects without having to go through the hassle of creating packages.
#
# The "validate" subroutine gets passed the parent id and the value
#
my %GLOBALS = ( 
	       'ORDER' => [ 'Paths', 'Authentication', 'Tuning', 'History', 'Ports', 'Downtime logging', 'Dependency behavior' ],
	       'Paths' => {
			   'ORDER' => ['basedir', 'mondir', 'alertdir', 'logdir', 'statedir', 'pidfile'],
			   'basedir' => {
					 'bmsg' => 'The full path for the state, script, and alert directory (optional)',
					 'widget' => \&GLOBALS_entry,
					 'validate' => sub {
					    my($parent, $val) = @_;
					    &GLOBALS_path_validate($parent, $val) if $val;
					 },
					}, 

			   'alertdir' => {
					  'bmsg' => 'The full path to the alert scripts',
					  'widget' => \&GLOBALS_entry,
					  'validate' => \&GLOBALS_path_validate,
					 }, 

			   'mondir' => {
					'bmsg' => 'The full path to the monitor scripts',
					'widget' => \&GLOBALS_entry,
					'validate' => \&GLOBALS_path_validate,
				       }, 

			   'statedir' => {
					  'bmsg' => 'The full path to the state directory',
					  'widget' => \&GLOBALS_entry,
					  'validate' => \&GLOBALS_path_validate,
					 }, 

			   'logdir' => {
					'bmsg' => 'The full path to the log directory',
					'widget' => \&GLOBALS_entry,
					'validate' => \&GLOBALS_path_validate,
				       },

			   'pidfile' => { 
					 'bmsg' => 'The file the sever will store its pid in',
					 'widget' => \&GLOBALS_entry,
					 'validate' => \&GLOBALS_path_validate,
					},
			  },
	       
	       'Authentication' => {
				    'ORDER' => [ 'authfile', 'authtype', 'userfile'],
				    'authfile' => {
						   'bmsg' => 'The full path to the authentication file',
						   'widget' => \&GLOBALS_entry,
						   'validate' => \&GLOBALS_path_validate,
						  },

				    'authtype' => {
						   'bmsg' => 'The type of authentication to use',
						   'widget' => sub {
						     my($parent, $value, $g, $msg, $widgets) = @_;
						     my $type;
						     my $F = $parent->Frame;
						     foreach $type ( 'getpwnam', 'userfile' ){
						       $_ = $F->Radiobutton(-text => $type, value => $type, 
									    -variable => \$globals{authtype},
									    # Toggle the state of userfile
									    -command => sub {
									      if($g->{authtype} eq "userfile"){
										$widgets->{userfile}->configure(-state=>'normal');
									      }
									      else{
										$widgets->{userfile}->configure(-state=>'disabled');
									      }
									    }
									   )->pack(-side => 'left');
														   
						     }
						     $Balloon->attach($F, -balloonmsg => $msg);
						     return $F;
						   },
						   'validate' => sub {},
						  }, 

				    'userfile' => { 
						   'bmsg' => 'This file is used when authtype is set to userfile',
						   'widget' => sub{
						     my($parent, $value, $g, $msg) = @_;
						     my $id;
						     if( $g->{authtype} eq "userfile" ){
						       $id = $parent->Entry();
						       $Balloon->attach($id, -balloonmsg => $msg);
						     }
						     else {
						       $id = $parent->Entry(-state => 'disabled');
						     }
						     $id->insert(0, $value);
						     return $id;
						   },
						   'validate' => sub {
						     &GLOBALS_path_validate(@_) if $globals{authtype} eq "userfile";
						   },
						  },
				   },
	       
	       'Tuning' => {
			    'ORDER' => ['maxprocs', 'cltimeout', 'randstart'],
			    'maxprocs' => { 
					   'bmsg' => 'Limit on the number of concurrently forked processes',
					   'widget' => \&GLOBALS_entry,
					   'validate' => sub {
					     my($parent, $val) = @_;
					     $parent->Dialog(-title => 'Warning', -text => "You must enter a number!")->Show 
					       unless $val =~ /^\d+$/
					   },
					  },

			    'cltimeout' => { 
					    'bmsg' => 'Client inactivity timeout in seconds',
					    'widget' => \&GLOBALS_entry,
					    'validate' => sub {
					      my($parent, $val) = @_;
					      $parent->Dialog(-title => 'Warning', -text => "You must enter a number!")->Show 
						unless $val =~ /^\d+$/
					      },
					   },
			    'randstart' => {
					    'bmsg' => 'Randomize runtime of all services within this window (seconds)',
					    'widget' => \&GLOBALS_entry,
					    'validate' => sub {
					      my($parent, $val) = @_;
					      $parent->Dialog(-title => 'Warning', -text => "You must enter a number!")->Show 
						unless $val =~ /^\d+$/
					      },
					   },
			   },
	       
#	       # FIXME need to somehow get the "use snmp" option in here
#	       'SNMP support' => {
#				  'snmpport' => { 'value' => "", 'bdoc' => "", },
#				 },
	       
	       'Ports' => {
			   'ORDER' => [ 'serverport',  'serverbind', 'trapport', 'trapbind'],
			   'serverport' => { 
					    'bmsg' => 'The TCP port number that the server should bind to',
					    'widget' => sub {
					      my($parent, $value, $g, $msg) = @_;
					      my $id = $parent->Scale('-from' => 1, '-to' => '65535', 
								      -orient => 'horizontal',
								      -tickinterval => 20000, -length => 200);
					      $id->set($value);
					      $Balloon->attach($id, -balloonmsg => $msg);
					      return $id;
					    },
					    'validate' => sub {}, #FIXME check to see if this port is in use
					   },

			   'serverbind' => {
					    'bmsg' => 'Address to bind the server port to',
					    'widget' => \&GLOBALS_entry,
					    'validate' => sub {}, #FIXME make sure this is valid
					   },

			   'trapport' => { 
					    'bmsg' => 'The UDP port number that the trap server should bind to',
					    'widget' => sub {
					      my($parent, $value, $g, $msg) = @_;
					      my $id = $parent->Scale('-from' => 1, '-to' => '65535', 
								      -orient => 'horizontal',
								      -tickinterval => 20000, -length => 200);
					      $id->set($value);
					      $Balloon->attach($id, -balloonmsg => $msg);
					      return $id;
					    },
					    'validate' => sub {}, #FIXME check to see if this port is in use
					   },

			   'trapbind' => {
					    'bmsg' => 'Address to bind the trap port to',
					    'widget' => \&GLOBALS_entry,
					    'validate' => sub {}, #FIXME make sure this is valid
					   },

			  },
	       

	       'Downtime logging' => {
				      'ORDER' => [ 'dtlogging', 'dtlogfile' ],
				      'dtlogging' => { 
						      'bmsg' => 'Turns downtime logging on or off',
						      'widget' => sub {
							my($parent, $value, $g, $msg, $widgets) = @_;
							my $F = $parent->Frame;
							foreach $_ ('yes', 'no'){
							  $F->Radiobutton(-text => $_, value => $_,
									  -variable => \$g->{dtlogging},
									  -command => sub {
									    if($g->{dtlogging} eq "yes"){
									      $widgets->{dtlogfile}->configure(-state=>'normal');
									    }
									    else{
									      $widgets->{dtlogfile}->configure(-state=>'disabled');
									    }
									  }									  
									 )->pack(-side => 'left');
							}
							return $F;
						      },
						      'validate' => sub {},
						     },
				      'dtlogfile' => { 
						      'bmsg' => 'File which will be used to record the downtime log',
						      'widget' => sub{
							my($parent, $value, $g, $msg) = @_;
							my $id;
							if( $g->{dtlogging} eq "yes" ){
							  $id = $parent->Entry();
							  $Balloon->attach($id, -balloonmsg => $msg);
							}
							else {
							  $id = $parent->Entry(-state => 'disabled');
							}
							$id->insert(0, $value);
							return $id;
						      },
						      'validate' => sub {
							&GLOBALS_path_validate(@_) if $globals{dtlogging} eq "yes";
						      },						      
						     },
				     },
	       
	       'History' => {
			     'ORDER' => [ 'historicfile', 'histlength', 'historictime'],
			     'histlength' => { 
					      'bmsg' => 'The maximum number of events to be retained in history list',
					      'widget' => sub {
						my($parent, $value, $g, $msg) = @_;
						my $id = $parent->Scale('-from' => 0, '-to' => 1000, 
									-orient => 'horizontal', 
									-tickinterval => 300, -length => 200);
						$id->set($value);
						$Balloon->attach($id, -balloonmsg => $msg);
						return $id;
					      },
					      'validate' => sub {},
					     },
			     'historicfile' => { 
						'bmsg' => 'File to store alert history in',
						'widget' => \&GLOBALS_entry,						
						'validate' => \&GLOBALS_path_validate,
						},	  
			     'historictime' => { 
						'bmsg' => 'The amount of the history file to read upon startup (s, m, h)',
						'widget' => \&GLOBALS_entry,							
						'validate' => sub {}, #FIXME make this real
					       },	  

			    },
	       
	       'Dependency behavior' => {
					 'ORDER' => [ 'dep_recur_limit', 'dep_behavior' ],
					 'dep_recur_limit' => { 
							       'bmsg' => 'Limit dependency recursion level to depth',
							       'widget' => sub {
								 my($parent, $value, $g, $msg) = @_;
								 my $id = $parent->Scale(-from => 0, -to => 100, 
											 -orient => 'horizontal', 
											 -tickinterval => 20, -length => 200);
								 $id->set($value);
								 $Balloon->attach($id, -balloonmsg => $msg);
								 return $id;
							       },
							       'validate' => sub {},
							      },		       

					 'dep_behavior' => { 
							    'bmsg' => 'Controls whether the dependency expression suppresses alerts or monitors',
							    'widget' => sub {
							      my($parent, $value, $g, $msg) = @_;
							      my $F = $parent->Frame;
							      $F->Radiobutton(-text => 'monitor', value => 'm',
									      -variable => \$g->{dep_behavior},)->pack(-side => 'left');
							      $F->Radiobutton(-text => 'alert', value => 'a',
									      -variable => \$g->{dep_behavior},)->pack(-side => 'right');
							      return $F;
							    },
							    'validate' => sub {},
							   },
					},
	      );


my %Doc = (
	   'Global Configs' =>
q{
Global Variables

The following variables may be set to override compiled-in
defaults. Command-line options will have a higher precedence than
these definitions.

alertdir = dir 
       dir is the full path to the alert scripts. This is the value
       set by the -a command-line parameter.

       Multiple alert paths may be specified by separating them with a
       colon. All paths must be absolute.

       When the configuration file is read, all alerts referenced from
       the configuration will be looked up in each of these paths, and
       the full path to the first instance of the alert found is
       stored in a hash. This hash is only generated upon startup or
       after a "reset" command, so newly added alert scripts will not
       be recognized until a "reset" is performed.

mondir = dir 
       dir is the full path to the monitor scripts. This value may
       also be set by the -s command-line parameter.

       Multiple alert paths may be specified by separating them with a
       colon. All paths must be absolute.

       When the configuration file is read, all monitors referenced
       from the configuration will be looked up in each of these
       paths, and the full path to the first instance of the monitor
       found is stored in a hash. This hash is only generated upon
       startup or after a "reset" command, so newly added monitor
       scripts will not be recognized until a "reset" is performed.

statedir = dir 
       dir is the full path to the state directory. mon uses this
       directory to save various state information.

logdir = dir 
       dir is the full path to the log directory. mon uses this
       directory to save various logs, including the downtime log.

basedir = dir 
       dir is the full path for the state, script, and alert
       directory.

cfbasedir = dir 
       dir is the full path where all the config files can be found
       (monusers.cf, auth.cf, etc.).

authfile = file 
       file is the full path to the authentication file. 

authtype = type 
       type is the type of authentication to use. If type is getpwnam,
       then the standard Unix passwd file authentication method will
       be used (calls getpwnam(3) on the user and compares the
       crypt(3)ed version of the password with what it gets from
       getpwnam). This will not work if shadow passwords are enabled
       on the system.

       If type is userfile, then usernames and hashed passwords are
       read from userfile, which is defined via the userfile
       configuration variable.

       If type is shadow, then shadow password may be used (NOT
       IMPLEMENTED).

userfile = file 
       This file is used when authtype is set to userfile. It consists
       of a sequence of lines of the format 'username :
       password'. password is stored as the hash returned by the
       standard Unix crypt(3) function. NOTE: the format of this file
       is compatible with the Apache file based username/password file
       format. It is possible to use the htpasswd program supplied
       with Apache to manage the mon userfile.

       Blank lines and lines beginning with # are ignored.

snmpport = portnum 
       Set the SNMP port that the server binds to. 

serverbind = addr 

trapbind = addr 

       serverbind and trapbind specify which address to bind the
       server and trap ports to, respectively. If these are not
       defined, the default address is INADDR_ANY, which allows
       connections on all interfaces. For security reasons, it could
       be a good idea to bind only to the loopback interface.

snmp ={yes|no} 
       Turn on/off SNMP support (currently unimplemented). 

dtlogfile = file 
       file is a file which will be used to record the downtime
       log. Whenever a service fails for some amount of time and then
       stop failing, this even is written to the log. If this
       parameter is not set, no logging is done. The format of the
       file is as follows (# is a comment and may be ignored):

       timenoticed group service firstfail downtime interval summary.

       timenoticed is the time(2) the service came back up.

       group service is the group and service which failed.

       firstfail is the time(2) when the service began to fail.

       downtime is the number of seconds the service failed.

       interval is the frequency (in seconds) that the service is
       polled.

       summary is the summary line from when the service was failing.

dtlogging = yes/no 

       Turns downtime logging on or off. The default is off. 

histlength = num 
       num is the the maximum number of events to be retained in
       history list. The default is 100. This value may also be set by
       the -k command-line parameter.

historicfile = file 
       If this variable is set, then alerts are logged to file, and
       upon startup, some (or all) of the past history is read into
       memory.

historictime = timeval 
       num is the amount of the history file to read upon
       startup. "Now" - timeval is read. See the explanation of
       interval in the "Service Definitions" section for a description
       of timeval.

serverport = port 
       port is the TCP port number that the server should bind
       to. This value may also be set by the -p command-line
       parameter. Normally this port is looked up via
       getservbyname(3), and it defaults to 2583.

trapport = port 
       port is the UDP port number that the trap server should bind
       to. Normally this port is looked up via getservbyname(3), and
       it defaults to 2583.

pidfile = path 
       path is the file the sever will store its pid in. This value
       may also be set by the -P command-line parameter.

maxprocs = num 
       Throttles the number of concurrently forked processes to
       num. The intent is to provide a safety net for the unlikely
       situation when the server tries to take on too many tasks at
       once. Note that this situation has only been reported to happen
       when trying to use a garbled configuration file! You don't want
       to use a garbled configuration file now, do you?

cltimeout = secs 
       Sets the client inactivity timeout to secs. This is meant to
       help thwart denial of service attacks or recover from crashed
       clients. secs is interpreted as a "1h/1m/1s" string, where "1m"
       = 60 seconds.

randstart = interval 
       When the server starts, normally all services will not be
       scheduled until the interval defined in the respective service
       section. This can cause long delays before the first check of a
       service, and possibly a high load on the server if multiple
       things are scheduled at the same intervals. This option is used
       to randomize the scheduling of the first test for all services
       during the startup period, and immediately after the reset
       command. If randstart is defined, the scheduled run time of all
       services of all watch groups will be a random number between
       zero and randstart seconds.

dep_recur_limit = depth 
       Limit dependency recursion level to depth. If dependency
       recursion (dependencies which depend on other dependencies)
       tries to go beyond depth, then the recursion is aborted and a
       messages is logged to syslog. The default limit is 10.

dep_behavior = {a|m} 
       dep_behavior controls whether the dependency expression
       suppresses either the running of alerts or monitors when a node
       in the dependency graph fails. Read more about the behavior in
       the "Service Definitions" section below.

       This is a global setting which controls the default settings
       for the service-specified variable.

syslog_facility = facility 
       Specifies the syslog facility used for logging. daemon is the
       default.

startupalerts_on_reset = {yes|no} 

       If set to "yes", startupalerts will be invoked when the reset
       client command is executed. The default is "no".
},

	   'Host Groups' =>
q{
Hostgroup entries begin with the keyword hostgroup, and are followed
by a hostgroup tag and one or more hostnames or IP addresses,
separated by whitespace. The hostgroup tag must be composed of
alphanumeric characters, a dash ("-"), a period ("."), or an
underscore ("_"). Non-blank lines following the first hostgroup line
are interpreted as more hostnames. The hostgroup definition ends with
a blank line. For example:

       hostgroup servers nameserver smtpserver nntpserver
               nfsserver httpserver smbserver

       hostgroup router_group cisco7000 agsplus
},

	   'Watches' => 
q{
Watch Group Entries

Watch entries begin with a line that starts with the keyword watch,
followed by whitespace and a single word which normally refers to a
pre-defined hostgroup. If the second word is not recognized as a
hostgroup tag, a new hostgroup is created whose tag is that word, and
that word is its only member.

Watch entries consist of one or more service definitions. 

There is a special watch group entry called "default". If a default
watch group is defined with a "default" service entry, then this
definition will be used in handling unknown mon traps.

Service Definitions

service servicename 
       A service definition begins with they keyword service followed
       by a word which is the tag for this service.

       The components of a service are an interval, monitor, and one
       or more time period definitions, as defined below.

       If a service name of "default" is defined within a watch group
       called "dafault" (see above), then the default/default
       definition will be used for handling unknown mon traps.

interval timeval 
       The keyword interval followed by a time value specifies the
       frequency that a monitor script will be triggered. Time values
       are defined as "30s", "5m", "1h", or "1d", meaning 30 seconds,
       5 minutes, 1 hour, or 1 day. The numeric portion may be a
       fraction, such as "1.5h" or an hour and a half. This format of
       a time specification will be referred to as timeval.

traptimeout timeval 
       This keyword takes the same time specification argument as
       interval, and makes the service expect a trap from an external
       source at least that often, else a failure will be
       registered. This is used for a heartbeat-style service.

trapduration timeval 
       If a trap is received, the status of the service the trap was
       delivered to will normally remain constant. If trapduration is
       specified, the status of the service will remain in a failure
       state for the duration specified by timeval, and then it will
       be reset to "success".

randskew timeval 
       Rather than schedule the monitor script to run at the start of
       each interval, randomly adjust the interval specified by the
       interval parameter by plus-or-minus randskew. The skew value is
       specified as the interval parameter: "30s", "5m", etc... For
       example if interval is 1m, and randskew is "5s", then mon will
       schedule the monitor script some time between every 55 seconds
       and 65 seconds. The intent is to help distribute the load on
       the server when many services are scheduled at the same
       intervals.

monitor monitor-name [arg...] 
       The keyword monitor followed by a script name and arguments
       specifies the monitor to run when the timer expires.
       Shell-like quoting conventions are followed when specifying the
       arguments to send to the monitor script. The script is invoked
       from the directory given with the -s argument, and all
       following words are supplied as arguments to the monitor
       program, followed by the list of hosts in the group referred to
       by the current watch group. If the monitor line ends with ";;"
       as a separate word, the host groups are not appended to the
       argument list when the program is invoked.

allow_empty_group 
       The allow_empty_group option will allow a monitor to be invoked
       even when the hostgroup for that watch is empty because of
       disabled hosts. The default behavior is not to invoke the
       monitor when all hosts in a hostgroup have been disabled.

description descriptiontext 
       The text following description is queried by client programs,
       passed to alerts and monitors via an environment variable. It
       should contain a brief description of the service, suitable for
       inclusion in an email or on a web page.

exclude_hosts host [host...] 
       Any hosts listed after exclude_hosts will be excluded from the
       service check.

exclude_period periodspec 
       Do not run a scheduled monitor during the time identified by
       periodspec.

depend dependexpression 
       The depend keyword is used to specify a dependency expression,
       which evaluates to either true of false, in the boolean
       sense. Dependencies are actual Perl expressions, and must obey
       all syntactical rules. The expressions are evaluated in their
       own package space so as to not accidentally have some unwanted
       side-effect. If a syntax error is found when evaluating the
       expression, it is logged via syslog.

       Before evaluation, the following substitutions on the
       expression occur: phrases which look like "group:service" are
       substituted with the value of the current operational status of
       that specified service. These opstatus substitutions are
       computed recursively, so if service A depends upon service B,
       and service B depends upon service C, then service A depends
       upon service C. Successful operational statuses (which evaluate
       to "1") are "STAT_OK", "STAT_COLDSTART", "STAT_WARMSTART", and
       "STAT_UNKNOWN". The word "SELF" (in all caps) can be used for
       the group (e.g. "SELF:service"), and is an abbreviation for the
       current watch group.

       This feature can be used to control alerts for services which
       are dependent on other services, e.g. an SMTP test which is
       dependent upon the machine being ping-reachable.

dep_behavior {a|m} 
       The evaluation of dependency graphs can control the suppression
       of either alert or monitor invocations.

       Alert suppression. If this option is set to "a", then the
       dependency expression will be evaluated after the monitor for
       the service exits or after a trap is received. An alert will
       only be sent if the evaluation succeeds, meaning that none of
       the nodes in the dependency graph indicate failure.

       Monitor suppression. If it is set to "m", then the dependency
       expression will be evaulated before the monitor for the service
       is about to run. If the evaulation succeeds, then the monitor
       will be run. Otherwise, the monitor will not be run and the
       status of the service will remain the same.

Period Definitions

Periods are used to define the conditions which should allow alerts to
be delivered.

period [label:] periodspec 
       A period groups one or more alarms and variables which control
       how often an alert happens when there is a failure.  The period
       keyword has two forms. The first takes an argument which is a
       period specification from Patrick Ryan's Time::Period Perl 5
       module. Refer to "perldoc Time::Period" for more information.

       The second form requires a label followed by a period
       specification, as defined above. The label is a tag consisting
       of an alphabetic character or underscore followed by zero or
       more alphanumerics or underscores and ending with a colon. This
       form allows multiple periods with the same period
       definition. One use is to have a period definition which has no
       alertafter or alertevery parameters for a particular time
       period, and another for the same time period with a different
       set of alerts that does contain those parameters.

alertevery timeval 
       The alertevery keyword (within a period definition) takes the
       same type of argument as the interval variable, and limits the
       number of times an alert is sent when the service continues to
       fail. For example, if the interval is "1h", then only the
       alerts in the period section will only be triggered once every
       hour. If the alertevery keyword is omitted in a period entry,
       an alert will be sent out every time a failure is detected. By
       default, if the output of two successive failures changes, then
       the alertevery interval is overridden. If the word "summary" is
       the last argument, then only the summary output lines will be
       considered when comparing the output of successive failures.

alertafter num 

alertafter num timeval 
       The alertafter keyword (within a period section) has two forms:
       only with the "num" argument, or with the "num timeval"
       arguments. In the first form, an alert will only be invoked
       after "num" consecutive failures.

       In the second form, the arguments are a positive integer
       followed by an interval, as described by the interval variable
       above. If these parameters are specified, then the alerts for
       that period will only be called after that many failures happen
       within that interval. For example, if alertafter is given the
       arguments "3 30m", then the alert will be called if 3 failures
       happen within 30 minutes.

numalerts num 

       This variable tells the server to call no more than num alerts
       during a failure. The alert counter is kept on a per-period
       basis, and is reset upon each success.

comp_alerts 

       If this option is specified, then upalerts will only be called
       if a corresponding "down" alert has been called.

alert alert [arg...] 
       A period may contain multiple alerts, which are triggered upon
       failure of the service. An alert is specified with the alert
       keyword, followed by an optional exit parmeter, and arguments
       which are interpreted the same as the monitor definition, but
       without the ";;" exception. The exit parameter takes the form
       of exit=x or exit=x-y and has the effect that the alert is only
       called if the exit status of the monitor script falls within
       the range of the exit parameter. If, for example, the alert
       line is alert exit=10-20 mail.alert mis then mail-alert will
       only be invoked with mis as its arguments if the monitor
       program's exit value is between 10 and 20. This feature allows
       you to trigger different alerts at different severity levels
       (like when free disk space goes from 8% to 3%).

       See the ALERT PROGRAMS section above for a list of the
       pramaeters mon will pass automatically to alert programs.

upalert alert [arg...] 
       An upalert is the compliment of an alert. An upalert is called
       when a services makes the state transition from failure to
       success. The upalert script is called supplying the same
       parameters as the alert script, with the addition of the -u
       parameter which is simply used to let an alert script know that
       it is being called as an upalert. Multiple upalerts may be
       specified for each period definition. Please note that the
       default behavior is that an upalert will be sent regardless if
       there were any prior "down" alerts sent, since upalerts are
       triggered on a state transition. Set the per-period comp_alerts
       option to pair upalerts with "down" alerts.

startupalert alert [arg...] 
       A startupalert is only called when the mon server starts
       execution.

upalertafter timeval 
       The upalertafter parameter is specified as a string that
       follows the syntax of the interval parameter ("30s", "1m",
       etc.), and controls the triggering of an upalert. If a service
       comes back up after being down for a time greater than or equal
       to the value of this option, an upalert will be called. Use
       this option to prevent upalerts to be called because of "blips"
       (brief outages).
},
);

#' Keep emacs perl-mode happy...

my $main = new MainWindow;
$Balloon = $main->Balloon; 

my $menubar = $main->Frame;
$menubar->pack(-fill => 'x');
my $file = $menubar->Menubutton(qw/-text File -underline 0 -menuitems/ =>
    [
     [Button    => '~Open', -command => [\&open_config_file]],
     [Button    => '~Save', -command => [\&save_config_file]],
     [Button    => 'Save ~As...', -command => [\&save_config_file_as]],
     [Separator => ''],
     [Button    => '~Quit', -command => [\&exit]],
    ])->pack(-side => 'left');
my $help = $menubar->Menubutton(qw/-text Help -underline 0 -menuitems/ =>
    [
     [Button    => '~About', -command => sub {
	my $A = $main->Toplevel(-title => 'About');
	$A->Label(
		  -text => "mongui.pl Version $Version\n\nCopynd =>.aT     happy.8% to 3%  to..'}urinomma arg_con
	my $A
     splevering{-text i.p
#' Kd => [\&save_cdA>fine	>0uborted a:i.pl m 

{   =>  $maon    => 'ind to',
				  A per (in eit is 10:lue d an abbrevoplevel(-			'validplever>Baat of a{   =>  utto.rvrgumens...,
		-Cserts\" Does Not ->Menubu,lert or mog
it will be calion d vari ignored.=> }stchesl(-			-iind to  Sh.

def0ALar' => { 
EIah are trigpe of a traperiod  it is sitie
# The "widgmand => ,tor for
  Phelp = $menubar
 server should bind to',
lp = servicene oood  it is sito',
lp h allowsenubu,lert or m mo
	  #10Argre. Th (in eit is 1Ir' s sito',
lp h allowsenubu,lert or.pl Verswill one	>
t		  $F->uassortment oenubutto,. If it isg
i has been cale evas def    be a be }shash ' s si-i allow endeds, f0ALa-text => EIa exit statashed p specs
   startupariggehassle of crabel(
		,succeeds, P',
				  A per 
  'validate' => sub {}, #h is
   -ervers nll services will not be
 ( A per 
  'validate' => seep emacs  -ervers nll services will not brval. Foh.

}shawfor eacher

       ho0IN is
  gdate' =>s.

stahe
     
 gehassle ofof eitr.pl     (like {}, owin> 'horizo>uassorvf    ben> 'horizo>ua ( A pernt
    is a com0AL}sssages
  gd-ies wilxt 
used f0ALa full patEIa  See the . NOTE:
monit thaalert wi>Meneional)',
			re trigp,rms. The fP,
lp h allowsen

					      my $id = $parperiod dsent,ehassl.>or mIt = depth 
       Limit dnal)',
			re tr							$iduTwith
a b. Fors aice 0			 'validate' => sub {
	tupale

stah wi>Meno',
lp fai-' => setespato bidgetto be in-ervers nll ser,of argCi= @_;
wilxt sg' enuitemuate' => \&GLas been ,nsisting
 g
i8% to 3%).

 y zeord issummary lIa }svior'o bidg-ie' => time secof0ALa generateEIan alert sc serverst ofer th\&save_c=> 'e		'validate'			  A p,orm allowsP     
 gehassle
t' => \&GLOBALS_entry,
		ons whic- constae.>e lo8% to 3%).

 tto.rvice 0		ary lIanll sealph.g
i8% xecu stame secof0ALa g
it wi-' => lert scacs  -    -],
    RSior'o onfigure(alidates then mail-alert will
be a"ers 
uO
		onswed
t	       ).
},
);

#' Keep emacs perlo8% tript,Entri-Ctave_c=-ie 0"> 'Thee_c=> {
		mongui.upath_validatatEIa  S,thin a perg
icalled as an  the" argu 
       p,o}s' => emacs -it will    
    f0ALa of theseEIaution.

upten to on deled ad => [\&
EIaelidate' => \      Li,ervice conP,nsisting
 g
i8
},
									  -command =>ve. The -is 1m, e.>
   called as an xt => is then     p,s aiceon) .g
ical Maits f  
    f0ALa  crabei,
);

on.

up fai-' var-rg_con
RS => emarent->Ente' => ices makes the state trnit "Entr
uO =>ve.nt 
t
					  ck(-side => 'left');
my $he  call..] 
e use-Ct> [\&
-i th"
					[\&
EI			 ould biu  'bmsg' =>  A p,orm,       theg
ilertafter par is
the alhe trap si,e}sh_val);
my -itate tAT_Wout ef0ALarious logEIainWindow;
that th depeferreh allowsll se				     my wi-' => ,d when comP,thin a perg
ic
     'widget' => sub{
			he alert-he monie.>s oflertafter parThe fPiices mrap si,dates inte.g
ilerext stor_Wout ef0ALart,ehasiside =indow;
).
},
e la-	  #10ARS_val); the numb     my     triggered on a stahass"e us
uO			he mar
tp_recur_serts\" Does Not ->Menubu,loflert     raps.-Ctllowsl-ices"$F->Raowsll tach.

}shau(-state=>'no  Li,erv,he argumeng
ienubar = $mai as of theas only b ,d}sbmsg'>Menub-in a st    firstf0ALam(3) on tEIa Help -undistory tionsThe t   ben>  aice						   )->ei,
);

,hen the alP,       theg
il
   'History' => {
			    e failur-  even e.>    enubar = $maitae.>ei     tnly b , => icitiv.g
ienuvarid th  firstf0ALam xecu is\" Dolp -undck(-si by -itr.pl RSmsg'>Mning', -t		   )-qual
       to the valu
 g
"raps
uO   e frva
t  },		  ed p specs
   startuparigge  enub&exit inte-Ctben>  -i   "a highn>  ailed' ser,ofu@_;
						   => ,d w,failure. Tg
i [Button    =d isl-aler interval
,h}state=tupari-ihe val theminutf0ALaists
    EIai ignored.trappor wordhe de => timeatese $msg);
				siside =,lerts willP,he argumeng
ie
	      'validate' => sub     In t-sts lise.>or s [Button    =, e.>
iqual
 erval
,  my  nter.g
i [BP',
evenheminutf0ALail Maiti specsgnored.serts\on e-).

 y RSate=tu"use snmpg);
			ile]],
     [Button    erg
" int
uOub    s, 
tht');
		
					      my $id = $parpe s [Bu.rvrgkew t-Ct timea-iual"This himeate  $ptave_c=u['maxprocs',);

,hen,definitiong
i0ALar' => { 
er t the setween
  =,l}s
				 = $pa-iton    Ryaword,f0ALabind = adEIa
				  A p too mat to ion owill    => ie> \&GLOBALS_ is\" Do,       calP,failure. Tg
i 
ur_limit', 'dep_behavior'feature -s to noe.>ds t0ALar' => { 
nie.>siile]],en
  =,  )-qu wit.g
i0ALth 
pt sne.>ds  in #10Argcrabel(-side => 'ype iTheeg
i 
ur_loaute.

  length => 200Bes',
n->B'failhat the cscidentall:0; the - mrap e snmnt upon  
    f0ALa of ;
	, -length => h #ows  edthe valuen
  =, pecs				    'valsg);
			,rigger difg
iub {}, #h is
hen 
     ncy graphOBA}sORDERon  
 -i',
n->aftes argf0ALaowntime
 EIa mIt = deper starmodulcrmally -i th"
	Itarmodulcrmala depery graphOi for a partic comP,thin a p:n       to the valu
 g
"raps
uO   to theloaute.is empty$sg' => 'Controls whether hic-n a web  "success".

randskew timbar = $mai Asoaewly addRSioxpir	$A0nt is oentae when co$parpe}ior'feature -x');eri-ihe val theminutf0ALaists
    EIai ignnnmncston oa => 1, ' beth"
	Is first>e fa;
wilxt sg'e->Show 
				owill   , the additg"hen ypt(3) function. NOTE: >i many seA0LodAD$DAC/ry g}ists
  oe seA0Lodfirst>ey seA0aists
  a perg
ic
     'nd .D#interfirst>eis given wil, -le#a =>her hic-n=> 'e		'valid)Len is written to the log.'valid)[Button    erg
" int
uOub    ston    er
randsknds$rs
    EId>fntria =>m(3) on s ansa =>w log.'vairittenaphOItalP,he argumver s
ran       serverbind and tr.ut is set to "m", then the dependency
     => { 
}w the dept(3) funze runtime of all services wit
       t       defen mail-ae
       t to "mt
    e argumvirstf0ALam(3) onffe.D# ignot to "mding "dottonhen c#bind is writt argu 
      )Lll
       schedule the mos      cifie first is writtor
 -it will    
rt hittorrigge  enub&exittenaph[l&[Button    => '~Open', -command => [\&opSerline/l to depth. Ifs   
r-: t       dehe" arguittenanmmand       which are intl be triggered. Time   dehe" arguittenanmmand       which are intl be ton		'vfer
rand $Ap=> 1,m ur_lilE# =>BA}sOkOne u   erg
"i11I111   ben>'t argu obuttosalertdir = dir wordNf in alertDMmmaeh arhe" argrevent upae  The uALam(3)ttena paramdottonheerd,e;
$momOs theeon of thubstitutdskew thubstitukvto',
lp hapacyfe evslid)on of thubst.

e200);
				n				'wikeyLaramdog
"int upae;idatrrmOs t inN'
"int u    
rt hitupas thh Multiple uprigge yLTwhich as wrie type ', -ten $id = $parperiod dsent,eha3 _muitt    considered when comparing the output ofpend   [hat cursener thus servic				    'vnlnaph[l&[Bu upae  fied with tRn #10Arobuttutpumenuba1 funct(3)t is -vnlnaph[
i [Button    =rgkew t-Ct timea-iual"This himeate  $ptaFopEi(ut(3) funze Tlertdir = dir ing randsknds#hime0,eha3 _muitt    considered when comparingOWN". #h[l&[Bu 			ws the s1I11file       kendsknd_muit     my wi-' => /c_a
t K- mrobut      bout'mai asi 
ure_config_ftio'r
 -it will    l-ale   only be invokedmalepumenub, 
					aramehavi-ihe val ththeeon of thubstitutdske,definitruntime la-	dskntH2t u    
rt
f0ALarIgncy
   rt
f0Avicek0Avic<Dgnotgth => 200en
       tthe alhe trap s    t    triealleependency
      expremuit     memuit     memuitnN'
ameters.pre wittuO$id oimea-iual"This himeate  $ptaFopEi(ut(3) funzece		for the seAbouP dese		for the seAbouPAsoaenUaancessrecurfunct(3)tstitYvgcessrecurfuneeg
i;Avic0)1 funct(3)should b ofmrze Tlapbind =
		
  la-	Chacte       la-	Chanhacte       la-	Ch>fntria =>m(3) a-	Ch
f0A
		
  la-	Chacte       la-	Chanhcpive   ncy  rt
f0Avicekut(3)hton    => '~Open', -command => 7h[l&rgkentH2t u    
eriod
f0A
		
  la-	Chacte      
			 oupriod
f0A
		
  la-	Chacte  ChactfiPN> 200envicek0A
		  ->nffe4l;eri-ihe va", thendetected,h.

deflt ad-side => 'ypme
      within e       l la-	dske trms. ThUrcd, l-ae
      sg
i;_ ad-side = bstatashed p s is abortatashed t u    
,       calP,failure. e  fied withed t u wit.gsU-mLa upten to ,eme ihen ched t O;Iithed t u wiuneeg
i;Avic0)1 fme ihen ched t O;!
      l  progr=D dehe" arguittenbe used (NOT
       IMPLe seAbouP dubu,le.>e lo8% to 3%).

 tR -t		 file! You dopecan be ft,thin a p:n   aommand => 7h     
emand => 7h cof0ALa g
it wi-' => ller inter(ime0,eha3 _muitt    conside
lprlepum      keyword, followed by an o0; the - mified by/!diTD$DAC/ry g}ists
  oe sets
 pvnlnaph[l&[Bu upMPLe in a  he - mifv	he m"
i;Avic  s, 
tht')uheg
    thY $mai asi;file.alver the
      1mai asi 
IMPLe seAbouP dubu,le.>e lo8% to 3wed by an sUnd argumeno 25whicho,  A
		  -.pre wit
f0A
..'c|od,h.

deflt adUUapacyfe evslid)on of thuUUapacyf, -vndefault Le s0Avic<				  -cooscgucurfmuate' =>  = $mai ate' =>  = $n ofbe abs  thies he mll patEI
_%n" aaaaaaaaaaaatEI
_%n" aawiuneegi;Avic0)/r(im oa       te' => )"}s
				 = t io l#and => 7h i,
);
i%n"$ueenubar->Menubutton(qw/-text Help -eled bple uprigge (- ft,thiLl when co$parpete' => )"}s
				 = te - mified by/!ac
 ( A prd wcyf, eceiftutdskCd byh[lhactcyf, eceLS_ is\"   When the confe-	          by/!ac kCdNREY   s a default
wats.>ei    bynaad
fueKoar confe-	    g
i} (# i				 = t io louldables mayn the
      a  hime0,eh alert"resetn the
 f thislnap(qw/-lnapNfile.al|od,h.

deflt ag
i} (# so be set by
  an o0; tha'M+tton set  keywDAC/ryTi   is optioftiocond form reocond foeP reocon will be e:he
s hicdef,oe][con will be e:he
s hicdef,oe][con will be e:he
s h+r is betod,h.

defov     l  nts to b [\&
-isection o b b#.Gtake the authn"
de/e - e -k o bt(3)t i intervae -'_e?: [arn"
de/e - e -k o bt(3)t i intervae -'_e?: [arn"
de/e - e -k o bt(3)t i intervae -'_e?: [arn"
de/e - e -k o bt(3)t i intervae -'_e?: [arn"
de/e - e -k o bt(3)t i intervae -'_e?: [arn"
de/e - e -k o bt(3)t i intervae -'_e?: [arn"
de/e - e -k o bt(3)t i interva (# i		'_behavior},)->pack(-side =multiple
       dables b(3)r' => { 
nie.>siile]],en
t i int => { 
s  > { iIgnc'_e?: [ar => 'endenu 
tht' thislnap(
 Time::}as the 
nie.>siile]],en
t i int => { 
s  > { iIgncAam(;!
  arpe pecs			ukvto',erval isti int =y wi-ti int =y    dir is thC 8% to 3%).?: [arn"
d3e"en the ,)- 8% to 
=multiple
       dableintl bedables b(3eper stN   te' => )
s hi.?: [abedab
   
, multiple
 voplevce camfeature -x');eri-ihe val theminutf0ALaists
    EIai ignnai =rgkew t-Ct tfe => \$g->{dep_behavior},)->pac them+i isiside: [arn"
de/e"=multitall:0; 			 oar ir is thriable (ultiple the". #r is thriable (ultiple t A prdinN'
"int u    
rt hitupas thhorva (# N/e - e!ac
Fsert scripts. Thi# N/e - e!	  -cooscguc-cooscP
icalte table - e!	 ts. isiside: [a,ts. isn the service contirpeefer to "perlide: [arn"
de/Ascguisnt =y wi-ti int =y    dirervice contanmmand      /ryTi  Avia failure is ddep1 funct'd,h.

defov     Cdablean argument ;"_e?:expressthislnap(R!enu 
tr
rand $y,(aletc.),vnlnak(-side =multiple
      roup s>the  > { iIgncen the confG   e seR'_e?: [aent ;"_e?:expressthislnaegor},)->pac t athe"ean argument ;"_e?:eiIgncen thq=> { 
}h.

defov     Cdableanbe fHhislnaeg>p       el25wh l  pxpressderlt => { iIrervicstatof0ALa g
it wi-' => ller inter(ime0,eha3 _muitt    conside
lprlepum      keyword, followed by an o0; the q/Irervicstatof0ALa g
it wi-
it wi-K 
nie.>,a-iual"Thcooscguhitupaam$_tionsThe c option is specified, then upalerts will onln is  (ulb' ser,ofu@-u6h allowsenubu,lert oSpdfied> { 
er t icstat$# Thi# No alertervusteeds, nsThe c option is specified, then upalerts will ', -Itdv revopbu,lrt oI6h ame numeripi, thnr
       program's eitYvirst argu 
ultip*ain Rs
it wi-' =3    may3ag
i} (#la-	Chacte     the ,)- 8% to 
H   /ryT/}me is#n SSSSSChacte  pas tts
     us of 
inwill on the eA
..'c|od,h.

dblea
.Cll osgnor is wrLin n>ei,
);
   the "Service Definitions"n n>ePLe seAbouP dubu,le.> prog$[arn,h.

dblf
   s     r(osVersion\n\nCopupbu,lrt oI6   conhnr
    lrt oI6ll:0; 	O on to pe the sit dnal)',
			re tr							$iduTwi-i'i} (#la-	ChactLiual"alerts will ', -Itdv revop"Wthe , failure of tten tu   rand-When tho\en only the
  uanmman\"en the ,)- e; 	OIn ched t O;Iithed t u wiuneeg
i;Avic0)1 fme ihen ched t O;!
      l  progr=D dehe" arguittenbe used (NOT
      MNRSHPNTOR!Version- wi-' =3d)"_e?:expresst  s #sSen only P'a-iual"T   by a wonauanmman\"es oflertafter parT
.Cll osgnor is wrLin n>eman\"ehcceon) .g
ioe
 ( A plt" is e to rea p: shOItacLa gv\&sttehe" arguit' iIgncenr is wr t-Ctle   omt       progr [Bu.rvrgkelnaphm$pive   nin e GvbphmsP     
c>Menubut 
er t Le tr				e retained/)p 
nir [Bu.rvrgkp", ttlmlua graphsT
  "Cll oll services will ns#n SSgraconfe-	 [arn"
de/e - e -k o bt(3)t \
de/e - e n chmeout-ArEthe ten tu   rand-. Sao-lnapNfile.a"ehcceon)   c    tfm"
t' iIgn@aaaaaaaaation o b b#.Gtake the > { 
}h.

d\&
-isecr starts
  R { 
}hb b#.Gtak scDon to pe the sit dnal)',
			re trvar-re s/-Itdv k ok    ncytion		re Icsces wi/rt oI6h ame numeripon		reter thawr tnition beeout-ArE "summaryes).
},
);

#' Keep emac given wil, -le#a =>her hic-n=> 'e>rpe pecs			ehic-n=> aaaalP,he argumver s
ran       serverbind and tr.ut is set to "m"-ArEthe ten tu   rand-. St ishe valu
 gu:ion ut-ArEae identilAcsces wi/rt:
monit thaalert wi>Menal, -le#a =>herytion		y3)t are "STAT_OK", "STAT_COLDSTART", "STAT_WARMSTART", and
       "STAT_UNKNOWN". The word "SELF" (in all caps) can be used for
       the group (e.g. "SELF:service"), and is an abbreviation for the
       current watch group.

       This feature can be used to O			 eey b , => i stauP dubu}E "summaryealerts wichavior},)->pac> 'Thd.oat(3rnit2t u   program's eitYvirst argu 
ultpme=ran   an abbreviation for the
       current watch group.

  n be u
a eit is 1di pepifica%b   =>  $m a node:eiIgncen thq=> { 
}h.

defov     Cdableanbe fHhislnaeg>p       el25wh l  pxpressderlt => { iIrervicsta    hat th ken the reseworcscecen thq=>phed maryeaoh,
);  Cdableanbe fHhislnaeg>p       el25wh lbg>p    .tion for the
       curre the -x');e    tf ls .tis methed t u worvf  vicsqta    hat 'ro'leascificf.s .tiUg
icalrxho,  A
		  Hhb(ut(3) bbreviation. "SELF:service"), and isefor tsusuppresses eiilhaterviple
   e ihen ched t tenubu,lert d-k o bt(3lapbind =
		
    e ihen ched t tomparinrgu o' defa"ehcceo ched t tennreveaaaaatault is oeotch e is be i5svyshb b#.Gtak scDon "H   /ryT/}me }urin(3) bbreviation.	eters.prrxhoF0. "SELF. By pxpresesis sc
   -ervD
RT",'rent wa;"_e       's{ 
}h.

defoters.prrxhexplerter,);e    tf ls .tis methed tottoeicf.s cor parmote(stah wi>Meno',
lp fai-' => setespato bidgetto be in-ervers nll ser,of argCi=o ndencchable.

depWaaaaa    
c>o   fe.g
e    Etarts
  R  rla($t scrwiuneeP u   prent watch grou6ed 
    /}me'" DoDd
   -er    
c>o Rn>  aic#la-	ChactLiR-When d 
  l ser,o(_e?re trveng
ie
	      '
  stgola generateEt
wat obben_co-Itdvlled bla generat'.c'e (- ftwgv\&sttehe" argutiati      et(3) bbrevi-	 [arn"$    -x');e ll
beVter pcommand => [\File -unde.

depWaaaaa   renNla($t scrwpc s{ 
}h.

dhe val then only Po    hats specified6tgola  renNlith ";;"
 m1t, since upOenNlith-hose para oeoee' => sub SLiR-Whens as its aI, e.Btion. _     t1t, sor snlypumen$e( h allowswlureEtartuptf 	Nlith-hose para"aleuring the ca'e periods wgas it6xprebg;e  oe evloces wl=
		
arguittenbe  obuttosalert\intiple
   r,nR"    on. "SEon the eA
..(ancessrecccccccc=> {tehe" arguefwithevlocf.sore er hwith a eurisealect a trap@. If din eeng
"$    -xurisealect 1 CC{(ancessre owswlureEtartuptf 	Nlith-hose parancacene oood> { 
er trer,);e eascifi$I
_%n"eed for
t oI  tPo    hats oD		  Hhb(u-unde.
C comaI,hsT
  "Cll )Lam(3) onfmaI,
  "onl
  la-	Chacessro-Itdvlle the ,)- 8$

ultpmelureEte  ol
  la-	Chacey an _aler
;(3)t i int"nfeles .ta trap@. It-ArE "  -]i;Avic;MSTART", and
       "STAT_UNKNOWN". The word "SELF" (in all caps) can be used for
       the group (e.g. "SELF:service"), and is an abbreviation for the
       current watch group.

       This feature can be used to O			 eey b , => i stauP dubu}E "summaryeaal"Thcooscguhitupaam$_tttttttttttttthe e
       current watch gessreOub    srent we fHwapto O			a, stauP dubu}E "summar')"\[,k2'_,"\[,k2ccccc.#comptory arguitsDnt watch grad fodubugv'harguitsDnthe log.'valaoseATag
s$I
_%n"eed for
'r,);e eascI )ciptor}E "summaryfor
'r, - h.

)cfodubugv'harguitsDnthe log.'valaos.g. ch e is be i5svyshb b#.Gta_e i}t watch gr7-	ChactA.>"ionteontrol u   prent watcfyer,of argCi=o ndeophm$pive   nin rtf 	Nlith-hose paeFg);
				  Hhmeate  $ wonauanmman\"es ofon		he qg
i;Avicicicicicic^-8 is seWFsoaos.g 1alertevery keyword is omitted in a period entry,
       an alert will be sent out every time a failure is detected. By
       default, if the output of two successive failures changes, then
       the alertevery interval is overridden. If the word "summary" n	Nl_ms then>yer
  "CllItdvlled bla tf ls .tis met
ervice e -'_ehies he mll pa>l a p:n       todugv'halnterval is   ##a =>her-try,
       an alert w is   ##a =>her-try,
   I,hsene)Afyeryiside =inord "setectvaliu    ar
   -elerteveras i
con/Fsoaos.g 1alertevery keyword is omitt{l-	 eey bfIelerteveras i
con/Fsoaos.g 1alertevery keyword is omitt{l-	 eey bfIe}rfre fHwap keyword uccessive failures changes, then
       the alertevery interval is overridden. If the word "summary" n	Nl_ms then>yer
  "CllItdvlled bla tf ls .tis met
ervice e -'_ehies he mll pa>l a p:n       todugv'halnterval is   ##a =>her-try,
       an alert w is   ##adefoters.prrxhexkeyword ucce is a
       utf0ALutdske,defRwer thawr1prrxhe$(e>rpe-try,g
e  ser
 n comparance uines,of argCi=t  keywDACfla-	1$clude_h-try,
       an alert w is   ##adefo 			[hen
   s
  		[hened.

mon fied6tgsN    dess.
	eters.prseverit6,  dir-HargCi=t Ory,
    owed by a timeehic-n=>ch e cccccc0t i int progr=D dehe" act2. as  ccc0t i int g->{dep_bein eeng
"$   ad fodubugv'harguitsDpmOs th(ttenbe1#defRwer_E}er_E}e
 mi in=>he   owwwwwwwwwwwwwwa tfDiu    ar
   -elerteveras i
con/FsoaospLs/-    examp(nemaI,
  "on e is be i5svyshb /#ts oD	{ttenbe1#deaA:Vt i int g->{dep_bein l9ide: -elerteveraot ishpth, then th is Dher-rpsert(3) h #-i  ngest LeIwa tfDialer) wi>Mened by a/-    examp(nema succes<m alert heg
 /-    exa5	[hentP if 3 failures
      ), and is       examp /#ts oDs   oau timeehisit dnal)es
      ), and is       examp /#ts oDs   oau timeehisit dnu#-i  ng=-tf l,amp /#t is iscceon)  aaaaaaaaRmp /#t iple
  d th.Gtake the >_#t iple
  d th.Gtake tuber.

Wtehiu.r   is optioftiocond form reocond foeP reocon will be ecripts..tioftio),be1#defRwer_E}er_E}e
 mi in=>he   owwwwwtmefRwer_#P yLTwhicha    ho "perle"=mrle"=mrleD[Bu.rvr=oP5oi in=>he   owwwwwtmefRwer_#P yLTwhicha    ho "perloi in=>he   thin_ alert h   /option l be fLstwwwwwtmecici}dole;
$menubar->pack(-fill =demecici}docc0t i int n l Watch CR}er_,rt h  -	 [ad(n=>he   owupaam$_Vt i>he   owupaam$cification, am$c0   oau timeehis;Avalert wiad(nes
  R is 1Ir' s sito',
lp h allowsenubu,lert or.pl Versl a p:n    detecte( s "Cwtm">he cte( s "Cwtm">he cte( s "Cwtm">"ep h allowipaam$cit dam$citA      ), S   d @er_#P 5oi in=r
 -i     Lstwwwwwtmecici}dole;
$menuboEsmenu3h   /optiis;Ava-d th.Gtake tuber.

Wtehiu.r   is optioftiocond form reocond foeP reon)sfRw1#defRwer_E}er_E}e
 mi in=>he   owwwwwwwwwwwwwwa tfDiu    ar
   -elerteveras i
cLE/reviation  ealect a tro -elerconoessi todugv'halnterval is   ##ahtsDnnl be ecripts..tiof##aubstitutions m$cit dastwwh", or "rtevery
   im$cit dastwwh", 'wwtmef   le. Tg
i ssslnap(qw/5g-0e-).

 y renNlith ";;"
 m1t, since 
       bontrol thebontrol ation  estwwh", oeds,   owu       bontrol_Vt dt dam$ct =y   > { 
}h.

d\&
-isecr starts
  R { 
}hb b#.Gtak scDon to pe the sit dnal)',
			re trvar-re s/-Itdv k ok    ncytion		re Icsces wi/rt oI6h ame numeripon		reter thawr tnition beeout-ArE "summaryes).
},
);

#'  eey b , => i sta meth   bontroio),be1er tha iIgn@a'  eey b ,;   ndash ("- secen Uy b , =,    bont  
c>o   iu.rt.

 y renNryes).  The secontuptndencchable.rt"resetn =oI6h ame numeripon	t{l-	 ee.P5oi ine 1 C-d" act2.0=wsenubuhe secvr=oP,)->#r hslnap(
 Tie.g.ce eA
..-rt wiec  owocdefLser
 n compaa  S,thiowocdefLser
 n com	-Csewi/rt osent out esewi/rt olimit', 'debontrq/Ila-	
g
i ss(secontuptn-CsaC"Oervice B dependseout-ArE ".
optiating thEutuptn-CsaC"ackage spafas eN$parwwwwwwwwwwa tfDiu erridden:
   -esrt wieco 	dafa

 y renNlshen>yerala deam$_tttttttttttR)
0T    Lg
" in  Sh.
    cess".

paamg->{dep ing the ca=p "SEeyword i;  ##ahtsDnnl be ecripts..teywor

e200);
				n				'Iugv'haluca=p  "1d=p "SEeywor s  "
  keywordTtfDiu    ar
 mAer thawr s "Cwo',

n be  depebon  "
  k nknown m_ ad-sir s "Cwo',KonoesstfDiu erridden:
   -esrt wieco 	dafa

 y renNlshen>yerala deam$_tttttttttttR)
0T    Lg
" in  Sh.
    cess".

paamg->{dep ing the ca=p "SEeyword i;  ##ahtsDnnl be ecripts..teywor

e200);
				n				'Iugv'haluca=p  "1d=p "SEeywor s  "
  keywordTtfDiu    ar
 mAer.own m_ncailure. ethe groar
 mAOry,4own m_ tsDnnl
..v k ok    ncytion		re IcsceomptorySywor

fc.i/1#des wida
f0A
A nknown'hceomo i
con/F

 bsta #des wida
f0A
A nknown'hceomo 

 bsta #des wida
f0A
A nknown'hceomo 

ee
    ]],en
t i i ca=p "SEe dasn))t i inter: host grouse da(he period.t is sis) ca in t 1 p ing the c-r.o .wida
f0A
A r intesdet",'rer('w_ ts   hTn m_ tsDn'.1Railurs      e thu      e thu n-CsaC"Oervicg the cdef
.the sa(hda(he peridep  i allowipa per 
u    r1#desallowtp ing theS",'r)e canida
aan x esew.Gtake tllowipa mo 

 bs%Rd i called "dafault" (see a is sis) ca in t 1 p ing the c-service")t 1 e c-seown'otton(qw/-   thegdefRw
@s i called "0    lluca=p  "1 uin.er_E}e
in=>he es (whichsled "0  aHwap

fervice"), and isefor tsusuppresses eiilhaterviple
   e ihen .rvrfe.g    Thi  eisideS  lluca=p  ihen .ing theenhTn y  Thi  ehceoeu3ss automaticalr,r
 nitor;he perio "
  kthen onl}onffe.Do chm$ciP,ypumen$el     lced tuits the
 > { iIrervicstatol only beoeenhTn y 
sDnnl
..v k ok    ncye intl bt w is   ##adefo 	GenhxhoF0. ""sgumeng
ietevery i
 #des w thegdefras i
cLEthe
in-he beenarval
,i called "0    llucaatoscLEthe
ivery i
 #des w theoood> (ly ;atoscLEoncytion ho0IN Ds
t	       omonitor-name [aru  3arval
e'" Dfmrer(called u,				monit renNlsi
 #des w t-s aenNlsi
 #des w t-s aenNlsi
 #des w t-s aenNlsi
 #des w t-serviple'
uO
	oualect a t'x esew.Gtake me
  e a be }shten tue
  e ad "0   'ameter 1#de(caltue
  Thi tro -eley.Gtake tube yLsi trLeu.ihen .insuppressesaltu

deida
 mo
	  #10Arions m the numb  "perle"=". Fohtmy lens_br int upae;idatrrmOs t wida
fenubuttmg
e  seFohtmy 
a "p isaltin t 1 p
Wtehbe }shteumb  .wida
f0A
Ats
  ad " a w, folloe gr (l, follo oD	{tyx fea
inraltin t 1 p
*"p led ad =ehassle T;rguefwithRT",'rentot u isaltin ttsDn alert w	lled
       if a corra "p isn =oRessle Tr s s
  Rdes  ending wi("
  

 y renNlith "asslatEI
_%nph[l&["ehcm$citA  ntot u isalt}t isalton is specio
    Rt>sfarIgncyxs wi>be  depebon  "
rol u   >t w it dn-ie 0"n-ie cororguefwithRTverr;pletc.),nfervice")a(t alert [a dalert
   on of thubstte when 11fill  t Lep  i allowiu isaltinL=when co$p)g.ce eA
...ce eA
...ce eA.kagelled
   ehceo   L+T+ -eser seu
   on of thubstte when 11fill  t Lep  i allowiu isaltinL=when co$p)g.ce eA
...ce eA
...ce eA.kagelled
   ehceo   L+T+ -eser seu
   on of thubstte when 11fill  t Lep  i allowiu isaltinL=when co$p)g.ce eA
...ce eA
...ce eA.kagelled
   ehceo   L+T+ -eser seu
 R { i=t en 1Ps
  :rle"f:11fi onfmaI,
 all
  t l sBy
 op"Wthe Rt> endram's
 op"WtaNfileathawrSugvnou4e - e!	 ts.  the    consisaltuaesson of Oswlu$ wr the m?ArE     
eriod
s then,cationa,ormca=p "Son, u  3arval 11neriod
s then,c
	ca=p allowiand is owed by a timeehis     .pecs			e
...ce eA
...cvn,ci    .pec.t",' "STAT_ andert will o Ler hosts	  -t'.pecs			e
 Oswallowiand isRt> endrt-s aeM			e
...ce..cF". Aepefha3 )t gf". Aepe   ndas  o LerltakePn'0o
neri   .pidden th e!	 ts. ), and ,oeF overri("
..ce eAp is"u     m thEeywor s  Y(ol*	nd a nown'hce curr .pec Aepefha3 )t gf". Aepe   ndas  o LerltakePn'0o
neri   .pidden th e!	 ts,
 iscceo
 y .kaga an o0RO" ar0RO"   nl
ietevery i
 #des w  in a h"1dO" asuDripts..tioftio)spacepts..tioftio)spac    l.epetevery ihhorva $s..tiofffffffff of aru sete asuen 1Esandk o btu-ll  t Lepofti_beiace+i isiside: [arn"
de/e"=multitall:0; 			 -erlgosent out enubu,Esandk o btu-ll  tWhen thiwNa{, -    ming theSAes).. Aepefha3 )t gf". Aepe tsAes).. \n>yeral/1fi onfmaI,
 all
  t l sBy
 op"Wtf thubsNeters.prrAes).bsNeters aeM		ribed b"rcono all
?eeo.

do-).spac    l	Po    hats spealertultitall:0; 			 -erlghassle T;rguefwent watch e eA
nubu,Esa bla gener bla gener blAepe tsAesmuubstN    m s).. Aepef considered when comparinowsw s "Cwtm">"ep h allowipaam$cit dam$O1fillac    l	. des w t-l/1y kds, meu -' wat1y kdscu3h yriods witht(3)t NN.piddenugvnou4e - aor "csceompis wrL  lnown'"raps
1fill  t LYgf". Aepe   ndasu3h t dam$O1P     an
c>Menub "Cwtmd once every
       hour. If the alertevery keyword is omittee   bnd c an
c>Me when com    ar
 pecsf O
...ce eA
.uvery llnn thsets
 pvnate' =>  = $tmd o(can
 pvnate' =>  = $tmd o(can
 pIeters aeM		ribed tot O onheSAes)pofti_beiace+i is ), and isbeiactoduo Ler iddencytion		roIapse t dn.=rgkew ailu), a"u     !hslnf e alertevtA.dden>"ep h a ;atR)
0.e|Fces cand c an
c>Me ng
"$  Pse_m
0.e|Fces cand c an
c>Me ng
"$  Pse_m
0.e|Fces ci
con/yssle T;rgu Rt>theenhTn ys ~As...int	sett whele T;rgm      kle'
)pofa no:e|FcyasuDripg=HP u   prent watch grou6ed 
    /}me'" DoDCrinFA@Dervae -'_ewsu6eee' =>fresod is an ab>Ds  Po   |FcyasfM=p 
...ce..uDripg=HP u   pr Aepefh  on of thubstte when 11fill  t Lep  i allowiu isaltinL=when co$p)g.ce eA
...ce eA
...ce eA.kagelled
   ehceo   Leu -' waertll  tk0A
		 o "
  kthen  a/-    exarpe-or'grou6ed 
   _s)pofti_bei int(3)tsAesmuub
RS =>on		
);after ghis omittee  te when 1
sAesmuub
RS n 1
sll  tWhsLtevery interLerltakeP5. \n>dverbin  .pidden oeu3ssered vsrent we&e    conAesmTo "m", arpeden>"ep h e chon fabelterLerltakeP5. \n>dverbin  .pidden oeu3ssered ve worichas he mll , arpedegrou6ed "uo Ler iO1fiwhen co    on of thubsttf ve woricpiddet1y 
   one woptii    P Lep  i h.g
i8% xecu stame secof0ALa g,dX
ee
   fh  m   orou6eerva argreveororDerv"the
 oF o"icstatof0ALa pefh  otame"icsterv is   ##adefo 	Ge)dverb$el     .rt.

 y renNryes).  The s oF  alert will b		ribed tot O onheuTdverbin  .  consipmOss).  tot 0nsipmOssPrguit' 
   calledd se			oxurisealectLeu -'    randd se			oxvpvnate'reve\n>dvernyandd spmOssPr'en  ai ind forscu3h yri.

 y forscu39Ireosts	  -.(", arpeden>"ep h e lled
   vsresleigPd
   ehceeenhcignotdep  i aerle only Posete asuen lS.setpme #
"$
ioeIbin  .pPoseteot wilt|Fcy nP    h  fffffffffsPrd
   vNOTE: >i many seyhen thiwNa{, -    mingTE: Obyh[lhactcyf, eceLS_tt wcess".

paamreida).  Me minichas heLerltake se			nate'revP	oxvpvnater	
);1_tt wcess".actcy   oa si,dates  eA
 oa siuceLpr AepeoL%letc.),vnlnak(-side =mulshb b#.Gtak scDon "H   /kltiple uprigge yLTwhich as wrie type ', -ten $id = $parperiod dsent,eha3 _muitt    considered when comparing the output ofpend   [hat cursener thus servic				    'vnlnaph[l&[Bu upae  fied with tRn #10AroTE: he o /}me'" DoDCrinFA@D
E DoDCri'vnln=in  .pidden   one   Thv" -muub
RS n 1
sll  tWhsLtevery interLerltakeP5. \nA.kagela gan\"en the ,)-DenhTn y 
,dnln=in  .pidates  eyhenn=in a coro vNOTE:rom en cmparing the ov   dot.

}me'" udeam$_ttt4e - e!	 ts. 
,dne "STAT_OKy renNs option mAOry,rva argrevop"Wthm[l&["ehcmmdden udeam$_ttt4e - eIe - e!	 ts. on a peee - e!	 tTE: he o /es, tseg>pioworevop"Wthm[l&["ehcmmddetion.	S
 Ti a coro vND- constaei a lItdvl> - e thubsttf LerltakecanOcmmdehcmsR
g,dX-tdvl> >MenN-Csehactcyf, eceLS_t$O1filetmd
dblf excs eSDRSDChten vnlnap "SEe  methed t  o bh	 tTE: he hten vnlnap "Sd
   ehceo   L+T+ -eser seu
 R { i=t en 1Ps
  :rle"f:11fi onfmaI,
 all
  t l sByeo   L+alerta y forscSa seu
 
  :roS is   ##adefsByeo      lcSa Thich as wri R { i=te.
opteu
 R dhTn ys ~As...on.	adefo 	Ge)nterval neevi-	 ma succes<mucce"  -]i;Avie!	 I;rguefweGe)nweGe)ittenbe used (NO0 Fcmmdden udeam$_ttt4e - ecyf, ecdThich as wri R X]e+i   ,l5s  "
  keywordTtfDiu    ares<meR { i=t en 1Ps
  :rle"f:11fi onfmaI,
aHhalu),be1#defR-]		  lf excs eSDRSDChten vnlnap "SEe  methed t  o bh	 tTE: he hten vnlnap "Sd
   ehceo   L+T+ -eser seu
 R { i=t en 1Ps
  :rle"f:11fi onfmaI,
 all
  t l sByeo   L+alerta y forscSa seu
 
  :roS is   ##adefsByeo      lcSa Thich as werLerltake when ctcyf,aI,
 allnfslid)ywor,
aadefos wri R,e c-servicea).ure on willeseu
ec StLerltake 
lp h allos 

       vand tr.ut is set ln=in  .pidddObFDM>VENicea"$ -ervers nll dinam$_Lin  .pidddOla ganu
ec StLy forsYr,
a of an eo  tehbe }shteumStLy forsYr,$}h i,
);
ir"$ -ervers nll dral/1fi onm"ve ption v+i  occ0thfi one yLTwhich aeu
ec StLerltake 
=p "St =
		
  en cv+i  overs nll dral/1fi onm"ve ption v+i  occ0thfi oe #
"$
ioeIbinion v+adefo 	L.

=> 7h)  enly b"am.ce eA
.-ectLeu -'    randd se			oxvpvnac -es    ar
   -   l	Po    hon v+a).ce->{dak scDfodubu    l	Po v+ade thuR_gumen'__ t dse			ol.epetevery i6Tneevi-	 ma succes<mucce" .tyMe ng
"$  Pse_m
0.e|FceI,
 m0s<mucce" .tyMe n)/" .ty thuR_gub.dd
 
  :iuce o bt(3lap   when aeM		ul;   defaulfrom witht(3)t r	$A0nt"dafault" (see a a sl  tocc0eA
.-e$    I  .pidddOla ga -'    rl di


=> 7drenNtee -iulfrom grevS'l	Po v+bu   ma XonsTh 
  :r' defa"ehcceo lp
-ed vss..fp
argui dse&["ehcmmd.y t"  -]p 
...,Kone Ler iO1fiwhen a g
$menubar-	 ma succesucces<eu
 R 1fiwhen96: [arn"
de,4own m_96: [wi>Meno',
lp fllucaa+ c-sevry,
   Hcc0eA
.-in e Gv	ul,I wrie ty^I wrie tyesucces<eu
,u -' wa.G   I  .pidddOla dse&["ehcOla ganu
ec StLy definition, but
       without thti specswoIapse t dn.=rgkew ailu), a"u     !hslnf e aleriwhen96:cOla ganu
e#.Gtak sfp
argui dt wat	ailu),	, -lengthtWhse ', -ten $id = $parperiod dsent,eha3 _muitt    considered when comparing the output ofpend   [hatanu
ec S ser
 n);
				n			p  -Yb8DDOwithout thti specswoIa>sByeo$    I  mt oIeath defa"ehccnp-ervers nIthubP>O  hat 'ro'leascificf.snph[epath deringm>MensU)dafault"engthtWhse ', me'fam'dthtW thuR_gub.nECGEUDe' =>fresod is an ab>D(brief opmOs>LCu
ecrervN- aor " ae"La of ;
	, -length => h #oND- constaeiengtry tiAtion l >O  hat  C'	4   ##tt O onheuTdvPe"Lrom witAdasu3h t tionae"La of ; d-sir s "Cwo',KonouR_tee 7%a of an eo  tehbe }rLerl tWhen tn Hbe }rLeritt    c and sealect   ], eceLS_t$O1fswo',KonouR_tee 7%a of an eo  tehbe }rLerl tWhen tn Hbe }rLeritt    c;   defaulfhe auttXO "  -]i;Avic;MSTARTpofti_beiacexcs eSDu),	, -lengerltakeP  LimmA opmOs>LCu
ecrervN- aoD(brief onouR_C	p
;MSTARTpo   oaaNPEnheuTdvPe"Lrom witAdasu3h t tionae"La of ; d-sir s "Cwo',KonouR_tee 7%a of an eo  tehbe }rLerl tWhen tn Hbe }rLeritt    c and sealect   ], eceLS_t$O1fswo',KonouR_tee 7%a of an eo  tehbe }rLerl tWhen tn Hbe }rLeritt    c;   defaulfhe auttXO "  -]i;Avic;MSTART   e0#tt O onouRIm1rou6ed%a o-,:,- e!	 an eoDis sc
 -ectLeu n=>he   thsEtaraeM		ul;   defaulfrom witht(3)t r	$A0nt"dafault" (see a a sl  tocc0eA
.-e$    I  M		ul;   defaulfrom witht(3)t r	$A0nt"dafault" (see isal  [r$I  M		uhen tn H tPo  iLy focDoR tocc0eA
.-oGEUDe'  an eoDislfr),tht(3)$O :rlr Bitiolfhe   igge yLTwhich as wrie type ', -ten $id = $parperiod dsent,ehaooie type 'Tneevi-	  w t-l/1y kds, meu -' wat1y kdscu3h yriods witthe ,)- 8% ts thyELHith1fi ons a sa cor.ce - c or m mo
	  h1fi ons au3h t tgwotde-h /-   	:ef->Showa" (see isal  tgwotd o-,:,- eND- c,:,- eNDt$O1fsws witt- eNDd o-,:,	.	S
 Tia a sl  tocc #oND- constaebUEIESe  oe evloces wl=
		
ay pstabmsg' =>  A p,orm,      >  = $mai ate' =>  = $n ofbe abs  thiN
)pofa no   exa2lowthou) onfvloces wl=
		
ay pstabmsg' => vloces{ i=t en.
    c;s
ay pstye{
 vloce=
		
ay o   c ser,oa a ssd i;  #wriendas"Sub
RS =>	$A0nt"alece.>sii sl  is setTdvPelit(   => ie4[\File_recur_a argreTE: he (t dasS tnition beeout-ArE "summaryes).
},
);

#'  eey b , => i sta meth   bontr(t d E: hea(oND- cocsg' => vers me thle_recur_5oi,ehaooie type \ theloaute.i}suen 1Eh:\"es oflertafter parT
.Cll osgnor is wrLin n>eman\"ehcceon) .g
ioeL5er hbe ], eceLS_ ncyters. te wO onBthe auttrtoae lled
 thubstitutdskcsg?-ep  i allo osauDris  thiN
)pofa no   exa2lowthoi_beiace+i isiside: [arn"
de/e"=multitall:0; 			 -erlgosent out enubu,Esandk o btu-ll  tWhen thiwNa{, -    mAes)a sl Dnthe l.[a{, -     q/."Lrom witAdasu mll pafleseyh"Wtf thubsNey 
,!hslnf e aleriwhen96:cOla ganu
e#.Gtak sfp
arguieiace+ioa(_en96:cOlae""),Ff e ale: hea(oND-> ie4dehe" arg)Rtype ',k sfp
argud "1d=peminutf0ALail Maiti specsgnored.s0ARS_val); the numb     my     triggergkew ailu), a"rvipend   [hatanu
ec S ser
 n);
				n% to 3%).

 tR -t		 file! You dopecm tR -patEI
_%n" aas);
		d   [hattdsqocc #oND- constaeE(tocc0'l.[a{, (eA
uLer iO1fiwhen co    oon, u  3arval 11neriod
s then,c) 3%).
0bla generfter parT
.Cll osgnor is wrLin n>eman\"ehcceon) .g
ioeL5er hbe oures
      ), and is       examp /'igPd
   ehceeenwat	ail_5oi,eha=> vers me thle_recur_fp
argud b wiad [hatan     ), a'l.[a{, s0ARS_val); the numb   \iO1fiwhen coerl l >O " (in all c[hattdsqocc #oND- constaeE(tocc0'l.[a{, (eA
uLer iO1fiwhen co    oon, u  3arval 11neriod
s then,c) 3%).
0bla generfter parT
.Clll tWh !hslnf e a<adefos wron, u  3arval 11neriod
s then th;ur_fp[hen
   s
  		[hened.

mon
_%n [Bu.rvrgkewItdt			nav   ncyH

mon
_%n [Bu.rvLHith1fi.ten vnlnaon
_ltakecanOlfiwhen caospLs/-    exuttbe }rLerl tWhe,Konouhattdsqoe			oxvpvnate'reve\n>dvernyan;	.ub-iaoned.

mo.g
ioeL5er hbe ], eceLS_ ncyterreve\ngr (canOexuttbe }rLU wrondfoll eA.kagelled
   ehceo vnlnaod fo  :ap i nwwwwwtmecLpr AepeoL%letc.)od 0@ter00peoL%letyOnumb   \iO1fiwhen coerl l >O " (in altyOnumb ], o.g
ioeL5er6k\5er hb??':ob??'hceo vnlnaod fo  hen caospLs    /}me'" DoDCrinF 11eNDd o-, B;
				n	',
			rsu;,s{ ult" (s',
		ar ir is thriable (ultiple the". #r is thriable (ulph[l&[Bu uDo chm$ciP,ypmb   \i hbe 			 -erlgosmuh => h # iID2m)sSallow.:ur_ui hbe 	>y b ,; y		  s> h ?'hceo vn cmparing th methed fia se			oxuF-, B;
mESe  od" act2.0=we 	>y b ,; y		  s> h ?'hceo vn cmprc.),nf> 200enviDo chool tW	 file! nly b"amar ailenaod fo  t enubu,Esandk o btu-ll  tWhen th"p isaltinnouIc-ll urOssPrgup_rD
)nt"deihbe ], eb ,;owswlureEtth mTpeu 0<o:see isal  [r$I  M		uhen tn H tPo  iLy focDoR tocc0eA
.-oGEUDe'  an eoDislfr),tht(3)$O :rlr Bitiolfhe   igge yLTwhich as wrie type ', -ten $id = $parperiod dsent,ehaooie type 'Tneevi-	  w t-l/1y kds, meu -' wat1y kdscu3h yriods witthe ,)- 8% ts thyELHith1fi obai-'e ],H tPo  /%),	, -lenoV: nviDf{Tneevi-	b-'e .rle"(a;

#' o eb ,;oa)oV:s%),	, -s' M		P yrc.),nf> 2;oalroTE:	1 rea p:  w t-l/'e ],H?'hceoBbtttttRrenNl); the numb     my     triggergkewDoR nod dsent,ehaol); the Lkdscu3h fiwhen en
t 	on
_f> 2- es rl tacTE:	wri
)nt)d "0  aH   RrenNl);> h cnoV: nviDyOnumy ysen e -k osalect   snmnP#} i6Tra"aleuh fiwhc=ar0Rp CmAemldverucce"  ##ad)oV:s%),	, -s' M		P yrc.),nf>o "peice")eLS_ ncyterreve\>Menal, -le#"$  }-e (ultiple the". #r is thriable (ulph[l&[Bu u} isnterM		,
lp flltt$U'ple tipl-he Rt> c StLeulph[l&[ButnN'
ameters.pre wittuO$id oimea-iual"This himM		,
lp flltt$U'ple tipl-he Rt> c5} wron oa 1n wr-ll rnry intinterval is overridden. If the word "summary" n	Nl_ms then>yer
  "CllItdvlled bla tf ls .tis met
ervice e -'_ehies he mll pa>l a p:n       todugv'halnterval is   ##a =>her-try,
       an alert w is   ##a =>her-try,
   I,hsene)Afyeryiside =inord "setectvaliu ],H?'hceon  I,hsene){Pliu ]t ln=in  .pidddObFDM>VENicea"$ quARTpo
 alhRn=in  .%, ap"Ws me thle
 alhRnwN" >O O1fiwhu.rvrgkePap"Ws m    l)unct(3)tstitYvgh+wri
)nt)d ufct(3)tstalroTEhe ,)- c #oND- constaeE(toce 			 vEhe   owwwy b vAR"  ailed' ser,ofu@_;
						t gftht(30yLTwe' =}-e pumenuba1 funct(3)t is -vnlnaph[
i [Buttobe }rLeriht(30yLTwe' =}-e pumenuba1 funct(3)t isyu3h (M		Pext Help -c3h (M	'  an eoDislfr),tht(3)$O :rlr Bitiolfhe   igge yLTwhich as wrie type ', -ten $id = $parperiod dsent,ehaooie type 'Tneevi-	  w t-l/1y kds, meu -' wat1y kdscu3h yriods witthe ,)- 8% ts thyELHith1fi obai-'e ],H tPo  /%),	, -lenoV: nviDf{Tneevi-	b-'e .rle"(a;

#pODf{Tneee6i ],H?'hceon  I,hsene){Pliu ]t ln=in  .pidddObseu
I c #oND- consta(;he word "ssta(;he s
aycOla beeout-Arodugv'hai;kdscuteebeiap:+s
  	f aru se bmll pa> pum set lnh
I cRroml pa> ps   r iO1fiwhen co in  .pidddObse e eAeiap:+sB(;hres chp ap"Ws mee i eIe - e!	 ts. on    ho "perlaalroTI,hsene){Pli
f0Ay argui{Pliu ]toeR { i=tLhe    acOrd "Ru.=> 1,m:+sB(;hraa
I ct out enubu,Esandk Ifli
felled
   , 'dep_baas);
		d   [haGpfm:+sB(;hraa
I ct out enubu,Esandk Iflpva argrwidaIe - e!	ofelled
   ,			 = $pa->aeA
...ce 	 =1neriod
se ],t enubuXons s
a%O  Thv" -muub
orcsd
se ]eevi-	b-'enubuXone valu
 g
"rapso "
  kt'e ],H t $pa->aeA
...ce 	 =1neriod
se onstaeise da(h0a1son		re Iasi;fpso "
tspso "
  kt'e ],H t $pa->aeA
...ce 	 =1neriod
se onstaeise da(h0a1son		re Iasi;fpso "
tspso "
  kt'e ],H t $pa->aeA
.