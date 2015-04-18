#!/usr/local/bin/perl
#
# NAME
#  dtquery.cgi
#
#
# DESCRIPTION
#  Downtime log query and grpahing tool for mon. Please see
#  http://www.nam-shub.com/files/ for more information. There 
#  are quite a few pieces involved in getting dtquery to work
#  and this page documents them all.
#
#
# NOTES
#  Don't run this script under mod_perl, you will pay for it with 
#  potentially sever performance penalties.
#
#
# SEE ALSO
#  mon
#   http://www.kernel.org/software/mon/
#
#  gnuplot
#   http://www.gnuplot.org
#
#
# AUTHOR
#  andrew ryan <andrewr@nam-shub.com> and many others
#  $Id: dtquery.cgi,v 1.1.1.1 2005/02/18 17:52:22 trockij Exp $
#
#
# BUGS
#  Report bugs to the author.
#
#
# COPYRIGHT
#    Copyright (C) 2000 Andrew Ryan
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


BEGIN {
    # Auto-detect if we are running under mod_perl or CGI.
    $USE_MOD_PERL = exists $ENV{'MOD_PERL'}
    ? 1 : 0;
    if ($USE_MOD_PERL) {
        # Use the cgi module and compile all methods at
        # the beginning but only once
        use CGI qw (-compile :standard) ;
	print STDERR "dtquery.cgi warning: running this script under mod_perl is NOT A GOOD IDEA!\n";
    } else {
        # Use the cgi module and compile all methods only
        # when they are invoked via the autoloader.
        use CGI qw (:standard) ;
    }
    $CGI::POST_MAX=1024 * 100;  # max 100K posts
    $CGI::DISABLE_UPLOADS = 1;  # no uploads
    # gnuplot needs this to include /usr/local/lib, or wherever else
    # you have zlib and libpng installed.
    $ENV{'LD_LIBRARY_PATH'} = '/lib:/usr/lib:/usr/local/lib';
}

use vars qw ($RCSID $RCSVERSION $VERSION);

$RCSID = '$Id: dtquery.cgi,v 1.1.1.1 2005/02/18 17:52:22 trockij Exp $';
$RCSVERSION = '$Revision: 1.1.1.1 $';
$VERSION = $RCSVERSION;
$VERSION =~ s/\$Revision: 1.1.1.1 $$//i;
$VERSION = $1;

use Time::Local;
use CGI;
use Carp;
use strict;
use Mon::Client;
use Statistics::Descriptive;
use GD::Graph::bars;


# Set debug to 1 to get a lot of stuff
$main::debug = 0;

# We print a maximum of 100 records at a time
$main::dtlog_max_failures_per_page = "100";


################################################################
# HTML display defaults
################################################################
use vars qw /$doctitle $organization $logo $textcolor 
    $bgcolor $linkcolor $vlinkcolor $fixed_font_face/;
# Base title of the HTML document
$doctitle = "Downtime Information";
# Your organization name
$organization = "Your Organization";
# Logo to use on each page (optional)
$logo = "/url/path/to/your/logo.gif";      # Company or mon logo.
# mon.cgi color scheme
#$bgcolor = "black";				# Background color
#$textcolor = "#D8D8BF";			        # Text color (default is gray)
#$linkcolor = "yellow";			        # Link color
#$vlinkcolor = "#00FFFF";			# Visited link color (default is teal)
# The new, softer look!
$bgcolor = "#FFFFFF";				# Background color
$textcolor = "#333366";			        # Text color
$linkcolor = "#333366";			        # Link color
$vlinkcolor = "#333366";			# Visited link color
$fixed_font_face = "courier";                   #fixed font face to use

################################################################
# dtquery.cgi parameters
################################################################
use vars qw /$logdir $dtlogfile_name $moncgi_url /;
# Set this to either "mon" or "files", "mon" will query the live mon
# server you specify for dtlogs, "files" will look in the local location
# that you specify.
#$main::dtlog_source = "files";
$main::dtlog_source = "mon";
# You will need to set this to your own log location, if you are using the
# "files" datasource for downtime logs. If you're not using the "files"
# datasource, this variable has no effect.
$logdir = '/d2/andrewr';
# What your downtime log files begin with (this pattern is globbed, so
# we'll catch files named dt.log.1, etc.)
$dtlogfile_name = "dt.log";
# URL for mon.cgi
$moncgi_url = "/mon/mon.cgi";
$main::failure_image = "/images/failed.gif";


################################################################
# Mon parameters
################################################################
use vars qw /$monhost $monport $contact/;
# The name of the server which the mon instance we want to connect to 
# is running on.
$monhost = "localhost";
# The port which mon is running on the above server (default is 2583) 
$monport = 2583;
# The name of the contact person to send email to
$contact = "bofh\@your.domain";


################################################################
# tmpdir settings
################################################################
use vars qw /$tmpdir $graphdir/;
# Location of temporary dir where we will store gnuplot datafiles
$tmpdir = "/tmp";
# Location where we will store graphs
$graphdir = "/tmp/dtquery-graphs";


################################################################
# Graphing defaults
################################################################
use vars qw /$gnuplot $graph_xsize $graph_ysize/;
# Location of gnuplot on your system
$gnuplot = "/usr/local/bin/gnuplot";
# If you want to change the size of the graphs produced, do that here.
$graph_xsize = 512;    # length of graphs produced, in pixels
$graph_ysize = 384;    # height of graphs produced, in pixels



################################################################
# You shouldn't need to edit anything below this line
################################################################
# Variables for dealing with the HTML form and query
use vars qw ($not $not1 $not2 $not3 $not4 $logdir
	     $name %namedvalue $key $value $exact
	     $f1 $f2 $f3 $f4 $f5 $f6 $f7 $found @entries
	     $field0 $field1 $field2 $oldkey
	     $datefield0 $sortby $fieldRef
	     $file);
undef $not; undef $not1; undef $not2; undef $not3; undef $not4; 
undef $f1; undef $f2; undef $f3; undef $f4; undef $f5; undef $f6;  undef $f7;
undef $found ; undef @entries;

use vars qw /@names %months @year_months @days_of_week %fields 
    $time_now @localtime_now $rand $up_value $down_value $url
    @query_string/;
$main::query = new CGI;
undef @names;
undef %namedvalue;
@names = $main::query->param;


%months = (   January => 0,
	      February => 1,
	      March => 2,
	      April => 3,
	      May => 4,
	      June => 5,
	      July => 6,
	      August => 7,
	      September => 8,
	      October => 9,
	      November => 10,
	      December => 11);

@year_months = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
@days_of_week = ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday');

%fields = ("Time Back Up", "0",
	      "Group", "1",
	      "Service", "2",
	      "First Failure", "3",
	      "Downtime", "4",
	      "Interval", "5",
	      "Host", "6");

# $time_now should probably really be Mon::Client::servertime()
$time_now = time;
@localtime_now = localtime(time);

use vars qw (@gt  @lt $tzsec);
@gt = gmtime($time_now);
@lt = localtime($time_now);
$tzsec = ($gt[1] - $lt[1]) * 60 + ($gt[2] - $lt[2]) * 3600;
my($lday,$gday) = ($lt[7],$gt[7]);
if($lt[5] > $gt[5]) {
    $tzsec -= 86400;
}
elsif($gt[5] > $lt[5]) {
    $tzsec += 86400;
}
else {
    $tzsec += ($gt[7] - $lt[7]) * 86400;
}
$tzsec += 3600 if($lt[8]);


# Generate a random # to make a tmpdir out of
$rand = int(rand(99999));
$tmpdir = "$tmpdir/$time_now-$rand";

# The value of data to put in gnuplot when a service is up/down
# You could reverse this, if you wanted to change the look of the 
# graphs.
$up_value = 0;
$down_value = 1;


$url = CGI::script_name();			# URL of this script.



#
# This subroutine opens up a connection to a mon server and executes
# the list_dtlog method, and returns the results as an array of hash
# references. Returns undef upon failure.
#
sub read_dtlog_mon {
    my ($monhost , $monport) = @_;
    my ($c, $retval, @entries);

    $c = new Mon::Client (
			  host => $monhost,
			  port => $monport,
			  );    
    if ($c->connected() == 0) {
	$c->connect();
	if ($c->error) {
	    $retval = $c->error;
	    print "<font face=\"$fixed_font_face\">mon_connect: Could not contact mon server &quot;$monhost&quot;: $retval </font>\n" ;
	    return undef;
	}

	if (@entries = $c->list_dtlog()) {
	    return @entries;
	} else {
	    return undef;
	}
    }
}


#
# open the log file, split all entries
# into an array of arrays
#
# args   : $logdir, the directory where the dtlogs are stored
#          $dtlogfile_name, the pattern to glob search on for logfiles
# returns: an array of hash references containing the downtime log
#
sub read_dtlog_file {
    my ($logdir, $dtlogfile_name) = @_ ;
    my (@files, $file, @entries);
    my ($timeup, $group, $service, $failtime, $downtime, 
	$interval, $summary);
				
    if (opendir LOGDIR, "$logdir") {
	@files = readdir LOGDIR;
	closedir LOGDIR;
    } else {
	print STDERR "Could not open log directory $logdir, $!\n";
	return undef;
    }
    foreach $file (@files) {
	if ($file =~ /^$dtlogfile_name*/) {
	    if ( open( LOGFILE, "$logdir/$file") ) {
		$main::debug && print "Reading in log file $logdir/$file<br>\n";
		while (<LOGFILE>) {
		    next if /^\#/ ;   # skip comment lines

		    ($timeup, $group, $service, $failtime, $downtime, 
		    $interval, $summary) = (/^(\d+) \s+ (\S+) \s+ (\S+) \s+
					    (\d+) \s+ (\d+) \s+ (\d+) \s+ (.*)$/x);

		    push @entries, { timeup => $timeup,
				     group => $group,
				     service => $service,
				     failtime => $failtime,
				     downtime => $downtime,
				     interval => $interval,
				     summary => $summary 
				     };
		}
	    } else {
		print STDERR "Could not open log file $logdir/$file for read, $!\n";
	    } 
	}
    }
    return @entries;
}

#############################################################
#
# If we have any CGI params passed to us, we have 3 possibilities:
# 1) We output a graph only, if the png param is set and displayGraph != 1
# 2) We output a graph prezo page, if the png param is set 
#    and displayGraph == 1 (which calls this script again using case #1
#    to display graphs).
# 3) We search with the parameters passed to us.
#
# Else we just print the form, if there are no parameters sent our way.
#
#############################################################
if (@names) {    #we have parameters, either perform query or display graph

    foreach $name (@names) {
	$namedvalue{$name} = $main::query->param($name);
    }

    # Check to see if we are printing a graph prezo page
    # Trying to get the titles of the graphs to display properly
    # on the graphs was too painful and hokey. This is also painful
    # and somewhat hokey but at least it gives us the results we
    # want.
    if ( ($namedvalue{displayGraph}) && ($namedvalue{displayGraph} == 1) ) {
	# print out the page here
	# Information that we need:
	# (name of png, keytitle text)
	#
	# Here's another option: a META file that contains $keytitle_text
	# and lives in $graphdir. One meta file for each graph. meta 
	# files created at the same time as the graphs.
	#
	#
	# That way we only need 2 parameters: png=name_of_png,displayGraph=1
	#
	# now exit
	undef @query_string;
	my $face="Helvetica, Arial";
	print $main::query->header;
	# Now slurp in title text from the relevant file
    
	if ( open(META , "$graphdir/$namedvalue{png}.meta") ) {
	    while (<META>) {
		chomp;
		push (@query_string, $_);
	    }
	} else {
	    print STDERR "Unable to open file $graphdir/$namedvalue{png}.meta for reading: $!\n";
	    print "<font size=+1><b>No graph information found</b></font>\n";
	    exit 0;
	}
	print $main::query->start_html(-"title"=>"$doctitle: $query_string[0]",
				       -"author"=>"$contact",
				       -"bgcolor"=>"$bgcolor",
				       -"link"=>"$linkcolor",
				       -"text"=>"$textcolor",
				       -"vlink"=>"$vlinkcolor"); 
	#
	# Now print out the HTML graph title
	print "<img alt=\"[$organization logo]\" src=\"$logo\"><h3>$query_string[0]</h3><hr>";
	shift @query_string;
	print "<table border=0><tr><td valign=top><b>Query Criteria:</b><br></td>";
	print "<td><font face='$face' size=-1>";
	print join("\n" , @query_string);
	print "</font></td></tr></table>";
	print "<br>\n";
	print "<center>";
	# Now print out the graph
	print "<img src=\"$url?png=$namedvalue{png}\">\n";
	print "</center>";
	# Close the page
	print $main::query->end_html;
	# bye
	exit 0;
    }

    # Check to see if we are printing a graph
    if ($namedvalue{png}) {
	sprayPng("$graphdir/$namedvalue{png}");
	exit 0;
    }

    # Print the results
    # Happy CGI header first
    print $main::query->header;
    print $main::query->start_html(-"title"=>"$doctitle",
				   -"author"=>"$contact",
				   -"bgcolor"=>"$bgcolor",
				   -"link"=>"$linkcolor",
				   -"text"=>"$textcolor",
				   -"vlink"=>"$vlinkcolor"); 

    # Read in the dtlog, either from a file or from a running mon server
    if ($main::dtlog_source eq "files") {
	$main::debug && print "Reading downtime information from log source &quot;$main::dtlog_source&quot;<br>\n";
	@entries = &read_dtlog_file($logdir, $dtlogfile_name);
    } elsif ($main::dtlog_source eq "mon") {
	$main::debug && print "Reading downtime information from log source &quot;$main::dtlog_source&quot;<br>\n";
	@entries = &read_dtlog_mon($monhost , $monport);
    } else {
	print "I don't know how to read downtime information from log source &quot;$main::dtlog_source&quot;\n";
    }
    
    if ($namedvalue{boolean0} =~ /not/) {$not = 1;} 
    if ($namedvalue{boolean1} =~ /not/) {$not1 = 1;}
    if ($namedvalue{boolean2} =~ /not/) {$not2 = 1;}
    if ($namedvalue{boolean3} =~ /not/) {$not3 = 1;}
    if ($namedvalue{boolean4} =~ /not/) {$not4 = 1;}
    
    if ($main::debug) {
	while (($key, $value) = each %namedvalue) {
	    print "$key = $value <br>\n";
	}
    }
    
    ######################################3
    # 
    # Remove the group string that's put
    # in for clarification
    #
    ######################################3
    
    $namedvalue{string0} =~ s/\ \(.*\)//;
    $namedvalue{string1} =~ s/\ \(.*\)//;
    # 'Any' is a NOOP :)
    $namedvalue{string0} =~ s/Any//;
    $namedvalue{string1} =~ s/Any//;
    ######################################3
    # 
    # Start the searches
    #
    ######################################3


    $exact = ($namedvalue{choice0} eq "host") ? "yes" : "";
    $f1 = SearchFor($namedvalue{string0}, $namedvalue{choice0}, \@entries, $not, $exact);
    
#    $main::debug &&  print "f1 is @$f1 <br>\n";
    
    if (($namedvalue{operation0} eq "And") && 
	($namedvalue{string1} =~ /.*\S.*/ )) {
	$exact = ($namedvalue{choice1} eq "host") ? "yes" : "";
	$f2 = SearchFor($namedvalue{string1}, $namedvalue{choice1}, $f1, $not1);
    } elsif (($namedvalue{operation0} eq "Or") && 
	     ($namedvalue{string1} =~ /.*\S.*/ )) {
	$f2 = SearchFor($namedvalue{string1}, $namedvalue{choice1}, \@entries, $not1);
	push @$f1, @$f2;
	$f2 = $f1;
    } else { $f2 = $f1; }
    
#    $main::debug && print "f2 is @$f2 <br>\n";
    
    if (($namedvalue{operation1} eq "And") && 
	($namedvalue{string2} =~ /.*\S.*/)) {
	$exact = ($namedvalue{choice1} eq "host") ? "yes" : "";
	$f3 = SearchFor($namedvalue{string2}, $namedvalue{choice2}, $f2, $not2);
    } elsif (($namedvalue{operation1} eq "Or") && 
	     ($namedvalue{string2} =~ /.*\S.*/)) {
	$f3 = SearchFor($namedvalue{string2}, $namedvalue{choice2}, \@entries, $not2);
	push @$f2, @$f3;
	$f3 = $f2;
    } else { $f3 = $f2; }
    
#    $main::debug && print "f3 is @$f3 <br>\n";
    
    $f4 = [];

    # Uniq the hash
    foreach $key (sort {$a <=> $b} @$f3) {
	if ($oldkey != $key) {
	    push @$f4, $key;
	    $oldkey = $key;
	}
    }
    
#    $main::debug && print "f4 is @$f4 <br>\n";

    # At this point, if the user selected "Or" for the operation3 
    # CGI param, we have to start over with a fresh copy of the 
    # original downtime log and then perform an intersection of the
    # two result sets.

    # initialize the start and end time variables
    $namedvalue{start_time} = 0;
    $namedvalue{end_time} = 0;
    if ($namedvalue{choice3}) {
	$namedvalue{start_hours} = defined($namedvalue{start_hour}) ? $namedvalue{start_hour} : 0 ;
	$namedvalue{start_min} = defined($namedvalue{start_minute}) ? $namedvalue{start_minute} : 0 ;
	if ($namedvalue{start_month} eq "Epoch") {
	    $namedvalue{start_time} = 0;
	    $namedvalue{start_sec} = 0;
#	    $namedvalue{start_hours} = defined($namedvalue{start_hour}) ? $namedvalue{start_hour} : 0 ;
#	    $namedvalue{start_min} = defined($namedvalue{start_minute}) ? $namedvalue{start_minute} : 0 ;
	} elsif ($namedvalue{start_day} && $namedvalue{start_year}) {
	    $namedvalue{start_sec} = 0;
#	    $namedvalue{start_hours} = 0;
#	    $namedvalue{start_min} = 0;
#	    $namedvalue{start_hours} = $namedvalue{start_hour} if (defined($namedvalue{start_hour}));
#	    $namedvalue{start_min} = $namedvalue{start_minute} if (defined($namedvalue{start_minute}));
	    $namedvalue{start_mon} = $months{$namedvalue{start_month}};
	    $namedvalue{start_mday} = $namedvalue{start_day};
	    $namedvalue{start_year} -= 1900 if ($namedvalue{start_year} > 1900);
	    $namedvalue{start_time} = timelocal($namedvalue{start_sec}, 
						$namedvalue{start_min}, 
						$namedvalue{start_hours}, 
						$namedvalue{start_mday}, 
						$namedvalue{start_mon}, 
						$namedvalue{start_year});
	} else {
	    $namedvalue{start_sec} = 0;
	    $namedvalue{start_hours} = defined($namedvalue{start_hour}) ? $namedvalue{start_hour} : 0 ;
	    $namedvalue{start_min} = defined($namedvalue{start_minute}) ? $namedvalue{start_minute} : 0 ;
#	    $namedvalue{start_hours} = 0;
#	    $namedvalue{start_min} = 0;
	    # Default begin month is this month
	    if ( defined($months{$namedvalue{start_month}}) ) {
		$namedvalue{start_mon} = $months{$namedvalue{start_month}};
	    } else {
		$namedvalue{start_mon} = $localtime_now[4];
	    }
	    # Default begin day is 1
	    if ($namedvalue{start_day}) {
		$namedvalue{start_mday} = $namedvalue{start_day};
	    } else {
		$namedvalue{start_mday} = 1;
	    }
	    # Default begin year is this year
	    if ($namedvalue{start_year}) {
		$namedvalue{start_year} -= 1900 if ($namedvalue{start_year} > 1900);
	    } else {
		$namedvalue{start_year} = $localtime_now[5] ;
	    }
	    $namedvalue{start_time} = timelocal($namedvalue{start_sec}, 
						$namedvalue{start_min}, 
						$namedvalue{start_hours}, 
						$namedvalue{start_mday}, 
						$namedvalue{start_mon}, 
						$namedvalue{start_year});
	}
	
	# Now determine the end month
	if ($namedvalue{end_month} eq "Present") {
	    $namedvalue{end_time} = $time_now;
	    $namedvalue{end_hours} =  defined($namedvalue{end_hour}) ? $namedvalue{end_hour} : 23;
	    $namedvalue{end_min} = defined($namedvalue{end_minute}) ? $namedvalue{end_minute} : 59 ;
	    $namedvalue{end_sec} = 59;
	} else {
	    $namedvalue{end_hours} = defined($namedvalue{end_hour}) ? $namedvalue{end_hour} : 23 ;
	    $namedvalue{end_min} =  defined($namedvalue{end_minute}) ? $namedvalue{end_minute} : 59 ;
	    $namedvalue{end_sec} = 59;
	    # Default end month is this month
	    if( $months{$namedvalue{end_month}} ) {
		$namedvalue{end_mon} = $months{$namedvalue{end_month}};
	    } else {
		$namedvalue{end_mon} = $localtime_now[4];
	    }
	    # Default end day is the 31st
	    if ($namedvalue{end_day}) {
		$namedvalue{end_mday} = $namedvalue{end_day};
	    } else {
		$namedvalue{end_mday} = 31;
	    }
	    # This might be a bug if there aren't 31 days in the month
	    # we're interested (i'm not sure how localtime/timelocal 
	    # handles this case)

	    # Default end year is this year
	    if ($namedvalue{end_year}) {
		$namedvalue{end_year} -= 1900 if ($namedvalue{end_year} > 1900);
	    } else {
		$namedvalue{end_year} = $localtime_now[5] ;
	    }
	    $namedvalue{end_time} = timelocal($namedvalue{end_sec}, 
					      $namedvalue{end_min}, 
					      $namedvalue{end_hours}, 
					      $namedvalue{end_mday}, 
					      $namedvalue{end_mon}, 
					      $namedvalue{end_year});
	}
	$main::debug && print "start time is $namedvalue{start_time} <br>\n";
	$main::debug && print "end time is $namedvalue{end_time} <br>\n";
	my $hoho1=$namedvalue{start_hours} * 3600 + $namedvalue{start_min} * 60 + $namedvalue{start_sec};
	my $hoho2=$namedvalue{end_hours} * 3600 + $namedvalue{end_min} * 60 + $namedvalue{end_sec};
	$main::debug && print "start time range is $namedvalue{start_hours}:$namedvalue{start_min} ($hoho1)<br>\n";
	$main::debug && print "end time range is $namedvalue{end_hours}:$namedvalue{end_min} ($hoho2)<br>\n";
    
	# Perform search based on date
	if ($namedvalue{operation2} eq "And") {
	    $f5 = SearchForDate($namedvalue{start_time}, 
				$namedvalue{end_time}, 
				$namedvalue{choice3}, 
				$f4, 
				$not3) ;
	} elsif ($namedvalue{operation2} eq "Or") {
	    $f5 = SearchForDate($namedvalue{start_time}, 
				$namedvalue{end_time}, 
				$namedvalue{choice3}, 
				\@entries, 
				$not3) ;	    
	    push @$f4, @$f5;
	    $f5 = $f4;
	} else {
	    $f5 = $f4;
	}


	# Perform search based on time of day
	if ($namedvalue{operation3} eq "And") {
	    $f6 = SearchForTime(
				$namedvalue{start_hours} * 3600 +  
				$namedvalue{start_min} * 60 + 
				$namedvalue{start_sec}, 
				$namedvalue{end_hours} * 3600 +  
				$namedvalue{end_min} * 60 + 
				$namedvalue{end_sec}, 
				$namedvalue{choice3}, 
				$f5, 
				$not4) ;
	    print STDERR "Did OR search\n";
	} elsif ($namedvalue{operation3} eq "Or") {
	    $f6 = SearchForTime(
				$namedvalue{start_hours} * 3600 +  
				$namedvalue{start_min} * 60 + 
				$namedvalue{start_sec}, 
				$namedvalue{end_hours} * 3600 +  
				$namedvalue{end_min} * 60 + 
				$namedvalue{end_sec}, 
				$namedvalue{choice3}, 
				\@entries, 
				$not4) ;
	    push @$f5, @$f6;
	    $f6 = $f5;
	} else {
	    $f6 = $f5;
	}
	# NEW CODE DONT WORK
	$f7 = [];
	$oldkey = "";
	foreach $key (sort {$a <=> $b} @$f6) {
	if ($oldkey != $key) {
	    push @$f7, $key;
	    $oldkey = $key;
	}
    }

     }    


    
    my $entry;
    if (($namedvalue{choice4}) && ($namedvalue{string3})) {
	foreach $entry (@$f7) {
	    if ($namedvalue{gtlt} eq "<=") {
		if ($namedvalue{string3} >= $$entry{$namedvalue{choice4}}) {
		    push @$found, $entry;
		}
	    } else {
		if ($namedvalue{string3} < $$entry{$namedvalue{choice4}}) {
		    push @$found, $entry;
		}
	    }
	}
    } else {
	$found = $f7;
    }

    if (scalar(@$f7) > $main::dtlog_max_failures_per_page) {
	print "\n<center><table><tr>\n";
	if ($namedvalue{startwith}) {
	    print "<td>\n";
	    print "\n<form name=\"Previous\" action=\"$url\" method=\"post\">\n";
	    while (($key, $value) = each %namedvalue) {
		print "<input type=hidden name=\"$key\" value=\"$value\">\n" unless ($key eq "startwith");
	    }
	    my $newstartwith = $namedvalue{startwith} - $main::dtlog_max_failures_per_page;
	    print "<input type=hidden name=\"startwith\" value=\"$newstartwith\">\n";
	    print "<input type=submit value=\"Previous $main::dtlog_max_failures_per_page Entries\">\n";
	    print "</form></td>\n";
	}


	if (scalar(@$f7) > ($namedvalue{startwith} + $main::dtlog_max_failures_per_page)) {
	    print "\n<td><form name=\"Next\" action=\"$url\" method=\"post\">\n";
	    while (($key, $value) = each %namedvalue) {
		print "<input type=hidden name=\"$key\" value=\"$value\">\n" unless ($key eq "startwith");
	    }
	    my $newstartwith = $namedvalue{startwith} + $main::dtlog_max_failures_per_page;
	    print "<input type=hidden name=\"startwith\" value=\"$newstartwith\">\n";
	    print "<input type=submit value=\"Next $main::dtlog_max_failures_per_page Entries\">\n";
	    print "</form></td>\n";
	}
	    print "</tr></table></center>\n";
    }

    $main::debug && print "f1 has " . scalar @$f1 . " entries<br>\n"; ##DEBUG##
    $main::debug && print "f2 has " . scalar @$f2 . " entries<br>\n"; ##DEBUG##
    $main::debug && print "f3 has " . scalar @$f3 . " entries<br>\n"; ##DEBUG##
    $main::debug && print "f4 has " . scalar @$f4 . " entries<br>\n"; ##DEBUG##
    $main::debug && print "f5 has " . scalar @$f5 . " entries<br>\n"; ##DEBUG##
    $main::debug && print "f6 has " . scalar @$f6 . " entries<br>\n"; ##DEBUG##
    $main::debug && print "f7 has " . scalar @$f7 . " entries<br>\n"; ##DEBUG##
    $main::debug && print "found " . scalar @$found . " entries<br>\n"; ##DEBUG##
    &list_dtlog($found, $sortby, $namedvalue{startwith});
    print $main::query->end_html;
    exit;
}
#####################################################
#
# Just print the form
#
#####################################################
else {
    my ($c, $w, $entry, $retval, $connect_failed, $i,
	@groups, @services, @hosts);

    $c = new Mon::Client (
			  host => $monhost,
			  port => $monport,
			  );    
    if ($c->connected() == 0) {
	$c->connect();
	if ($c->error) {
	    $retval = $c->error;
	    print "<font face=\"$fixed_font_face\">mon_connect: Could not contact mon server &quot;$monhost&quot;: $retval </font>\n" if $connect_failed == 0 ;
	    $connect_failed = 1;    #set the global $connect_failed var
	    return 0;
	}
    }

    print $main::query->header;
    print "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML//EN\">
<HTML><HEAD><TITLE>Query Downtime Log</TITLE>
<LINK REV=MADE HREF=\"mailto:$contact\">\n";

    foreach $w ($c->list_watch) {
	push @groups, $w->[0];
	push @services, $w->[1];
    }

    @groups = &Uniq(\@groups);
    @services = &Uniq(\@services);

    my $g;
    foreach $g (@groups) {
	my $t;
	my @tmp = $c->list_group($g);
	foreach $t (@tmp) {
	    push @hosts, "$t ($g)";
	}
    }

    @hosts = &Uniq(\@hosts);

#    print "groups are @groups <br>\nservices are @services <br>\n";
#    print "hosts are @hosts <br>\n";

    print "
<SCRIPT Language=\"JavaScript\">
var maxLength = 10;
siteopt = new Array;
siteopt[0] = \"----            ----\";
//-----------------------
var trueLength = siteopt.length;
var lst = siteopt.length;
//-----------------------

function changeMenu(i, j) {
      siteopt.length = 0;
      menuNum = document.SelectMenu.elements[i].selectedIndex;
      if (menuNum == null) return;
      if (menuNum == 1){
         siteopt = new Array;
   	 siteopt[0] = new Option(\"          \");
   	 siteopt[1] = new Option(\"Any\");\n";

    for ($i = 0; $i <= $#groups; $i++) {
	my $j = $i +2;
	print "siteopt[$j] = new Option(\"$groups[$i]\");\n";
    }
    
    print "
     }
     if (menuNum == 2){
         siteopt = new Array;
   	 siteopt[0] = new Option(\"          \");
   	 siteopt[1] = new Option(\"Any\");\n";
    
    for ($i = 0; $i <= $#hosts; $i++) {	
	my $j = $i +2;
	print "siteopt[$j] = new Option(\"$hosts[$i]\");\n";
    }
        
    print "
     }
     if (menuNum == 3){
         siteopt = new Array;
   	 siteopt[0] = new Option(\"          \");
   	 siteopt[1] = new Option(\"Any\");\n";

    for ($i = 0; $i <= $#services; $i++) {	
	my $j = $i +2;
	print "siteopt[$j] = new Option(\"$services[$i]\");\n";
    }
    print "
     }

     tot = siteopt.length;
     for (i = lst; i > 0; i--){
         document.SelectMenu.elements[j].options[i] = null; 
     }

     for (i = 0; i < tot; i++){
         document.SelectMenu.elements[j].options[i] = siteopt[i]; 
     }
     document.SelectMenu.elements[j].options[0].selected = true;
     lst = siteopt.length;
}
</SCRIPT>
<BODY BGCOLOR=\"$bgcolor\" VLINK=\"$vlinkcolor\" TEXT=\"$textcolor\" LINK=\"$linkcolor\">
<img alt=\"[$organization logo]\" src=\"$logo\"><font size=+3><b>&nbsp;&nbsp;Query
Downtime Log</b></font>
<hr>
<center>

<table width=100% height=100%>
<TR height=85><TD valign=top align=center>

<form name=\"SelectMenu\" action=\"$url\" method=\"post\">
<h3>Show downtime where</h3>
(
<table border=0 cellpadding=3>
<tr>
	<td><select name=choice0 onChange=\"changeMenu(0, 2)\">
		<option>
                <option value=group>Group
                <option value=summary>Host
		<option value=service>Service
		</select>
	</td>
	<td><select name=boolean0>
		<option>contains
		<option>does not contain
		</select>
	</td>
	<td><select name=string0>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <option>---------------------</option>
            </select>
	</td>
</tr>
</table>

<select name=operation0>
	<option> And
	<option> Or
</select>

<table border=0 cellpadding=3>
<tr>
	<td><select name=choice1 onChange=\"changeMenu(4, 6)\">
		<option>
                <option value=group>Group
                <option value=summary>Host
		<option value=service>Service
		</select>
	</td>
	<td><select name=boolean1>
		<option>contains
		<option>does not contain
		</select>
	</td>
	<td><select name=string1>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <OPTION> </OPTION>
               <option>---------------------</option>
            </select>
	</td>
</tr>
</table>

)<p>

<select name=operation1>
	<option> And
	<option> Or
</select>

<table border=0 cellpadding=3>
<tr>
	<td><select name=choice2>
		<option>
                <option value=group>Group
                <option value=summary>Host
		<option value=service>Service
		</select>
	</td>
	<td><select name=boolean2>
		<option>contains
		<option>does not contain
		</select>
	</td>
	<td><input name=string2 size=20>
	</td>
</tr>
</table>

<select name=operation2>
	<option> And
	<option> Or
</select>

<table border=0 cellpadding=3>
<tr>
	<td colspan=3>
        <table width=100%><tr>
        <td align=center><select name=choice3>
		<option>
                <option value=failtime selected>Start of Failure
                <option value=timeup>Time Back Up
		</select>
	</td>
	<td align=center><select name=boolean3>
		<option>is within
		<option>is not within
		</select>
	</td>
        <tr></table>
        </td>  
</tr>
<tr>
<td align=left><select name=\"start_month\">
                <option>Epoch</option>
		<option>January</option>
		<option>February</option>
		<option>March</option>
		<option>April</option>
		<option>May</option>
		<option>June</option>
		<option>July</option>
		<option>August</option>
		<option>September</option>
		<option>October</option>
		<option>November</option>
		<option>December</option>
		</select>
	      <select name=\"start_day\">
                <option></option>
		<option>1</option>
		<option>2</option>
		<option>3</option>
		<option>4</option>
		<option>5</option>
		<option>6</option>
		<option>7</option>
		<option>8</option>
		<option>9</option>
		<option>10</option>
		<option>11</option>
		<option>12</option>
		<option>13</option>
		<option>14</option>
		<option>15</option>
		<option>16</option>
		<option>17</option>
		<option>18</option>
		<option>19</option>
		<option>20</option>
		<option>21</option>
		<option>22</option>
		<option>23</option>
		<option>24</option>
		<option>25</option>
		<option>26</option>
		<option>27</option>
		<option>28</option>
		<option>29</option>
		<option>30</option>
		<option>31</option>
	      </select>,
	      <select name=\"start_year\">
                <option></option>
		<option>2000</option>
		<option>2001</option>
		<option>2002</option>
		<option>2003</option>
		<option>2004</option>
		<option>2005</option>
	      </select>
</td>
<td align=center>to</td>
<td align=left><select name=\"end_month\">
                <option>Present</option>
		<option>January</option>
		<option>February</option>
		<option>March</option>
		<option>April</option>
		<option>May</option>
		<option>June</option>
		<option>July</option>
		<option>August</option>
		<option>September</option>
		<option>October</option>
		<option>November</option>
		<option>December</option>
		</select>
	      <select name=\"end_day\">
                <option></option>
		<option>1</option>
		<option>2</option>
		<option>3</option>
		<option>4</option>
		<option>5</option>
		<option>6</option>
		<option>7</option>
		<option>8</option>
		<option>9</option>
		<option>10</option>
		<option>11</option>
		<option>12</option>
		<option>13</option>
		<option>14</option>
		<option>15</option>
		<option>16</option>
		<option>17</option>
		<option>18</option>
		<option>19</option>
		<option>20</option>
		<option>21</option>
		<option>22</option>
		<option>23</option>
		<option>24</option>
		<option>25</option>
		<option>26</option>
		<option>27</option>
		<option>28</option>
		<option>29</option>
		<option>30</option>
		<option>31</option>
	      </select>,
	      <select name=\"end_year\">
                <option></option>
		<option>2000</option>
		<option>2001</option>
		<option>2002</option>
		<option>2003</option>
		<option>2004</option>
		<option>2005</option>
	      </select>
</td>
</tr>
</table>

<select name=operation3>
	<option> And
	<option> Or
</select>
<select name=boolean4>		
        <option>is within
        <option>is not within
</select>
    
<table>
<tr>
<td>
    the hours of:
</td>

<td>
    <select name=\"start_hour\">
    <option selected>00</option>
    <option>01</option>
    <option>02</option>
    <option>03</option>
    <option>04</option>
    <option>05</option>
    <option>06</option>
    <option>07</option>
    <option>08</option>
    <option>09</option>
    <option>10</option>
    <option>11</option>
    <option>12</option>
    <option>13</option>
    <option>14</option>
    <option>15</option>
    <option>16</option>
    <option>17</option>
    <option>18</option>
    <option>19</option>
    <option>20</option>
    <option>21</option>
    <option>22</option>
    <option>23</option>

    </select>:

</td>
<td>
    <select name=\"start_minute\">
    <option selected>00</option>
    <option>01</option>
    <option>02</option>
    <option>03</option>
    <option>04</option>
    <option>05</option>
    <option>06</option>
    <option>07</option>
    <option>08</option>
    <option>09</option>
    <option>10</option>
    <option>11</option>
    <option>12</option>
    <option>13</option>
    <option>14</option>
    <option>15</option>
    <option>16</option>
    <option>17</option>
    <option>18</option>
    <option>19</option>
    <option>20</option>
    <option>21</option>
    <option>22</option>
    <option>23</option>
    <option>24</option>
    <option>25</option>
    <option>26</option>
    <option>27</option>
    <option>28</option>
    <option>29</option>
    <option>30</option>
    <option>31</option>
    <option>32</option>
    <option>33</option>
    <option>34</option>
    <option>35</option>
    <option>36</option>
    <option>37</option>
    <option>38</option>
    <option>39</option>
    <option>40</option>
    <option>41</option>
    <option>42</option>
    <option>43</option>
    <option>44</option>
    <option>45</option>
    <option>46</option>
    <option>47</option>
    <option>48</option>
    <option>49</option>
    <option>50</option>
    <option>51</option>
    <option>52</option>
    <option>53</option>
    <option>54</option>
    <option>55</option>
    <option>56</option>
    <option>57</option>
    <option>58</option>
    <option>59</option>
    </select>
</td>
<td>
    to
</td>

<td>
    <select name=\"end_hour\">
    <option>00</option>
    <option>01</option>
    <option>02</option>
    <option>03</option>
    <option>04</option>
    <option>05</option>
    <option>06</option>
    <option>07</option>
    <option>08</option>
    <option>09</option>
    <option>10</option>
    <option>11</option>
    <option>12</option>
    <option>13</option>
    <option>14</option>
    <option>15</option>
    <option>16</option>
    <option>17</option>
    <option>18</option>
    <option>19</option>
    <option>20</option>
    <option>21</option>
    <option>22</option>
    <option selected>23</option>

    </select>:

<td>
    <select name=\"end_minute\">
    <option>00</option>
    <option>01</option>
    <option>02</option>
    <option>03</option>
    <option>04</option>
    <option>05</option>
    <option>06</option>
    <option>07</option>
    <option>08</option>
    <option>09</option>
    <option>10</option>
    <option>11</option>
    <option>12</option>
    <option>13</option>
    <option>14</option>
    <option>15</option>
    <option>16</option>
    <option>17</option>
    <option>18</option>
    <option>19</option>
    <option>20</option>
    <option>21</option>
    <option>22</option>
    <option>23</option>
    <option>24</option>
    <option>25</option>
    <option>26</option>
    <option>27</option>
    <option>28</option>
    <option>29</option>
    <option>30</option>
    <option>31</option>
    <option>32</option>
    <option>33</option>
    <option>34</option>
    <option>35</option>
    <option>36</option>
    <option>37</option>
    <option>38</option>
    <option>39</option>
    <option>40</option>
    <option>41</option>
    <option>42</option>
    <option>43</option>
    <option>44</option>
    <option>45</option>
    <option>46</option>
    <option>47</option>
    <option>48</option>
    <option>49</option>
    <option>50</option>
    <option>51</option>
    <option>52</option>
    <option>53</option>
    <option>54</option>
    <option>55</option>
    <option>56</option>
    <option>57</option>
    <option>58</option>
    <option selected>59</option>
    </select>
</td>

</tr>


</table>

<!--select name=operation3-->
<select name=operation4>
	<option> And
	<option> Or
</select>


<table>
<tr><td>
   <!--select name=choice4-->
   <select name=choice4>
      <option> </option>
      <option value=downtime>Downtime</option>
   </select>
</td>
<td>
   <select name=gtlt>
      <option>&lt;=</option>
      <option>&gt;</option>
   </select>
</td>
<td>
   <!--input name=string3 size=6--> seconds
   <input name=string3 size=6> seconds
</td>
</tr>
</table>
<input type=hidden name=startwith value=0>
<input type=hidden name=extend value=0>
<br>

<input type=submit name=\"action\" value=\"Submit Query\"><br>
</form>

</td></tr><tr><td valign=bottom align=center>
</td></tr></table>

</center>
</body>
</html>\n";
}


#
# END MAIN
#


#######################################################
# Begin subroutine definitions
#######################################################


#######################################################
# Accepts a reference to a hash and a field to sort by
########################################################

sub list_dtlog {
    my ($hashRef, $sortby, $startwith) = (@_);
    my $face="Helvetica, Arial";
    my $summary_table_width = "90%";
    my $dt_table_width = "100%";
    my ($line, $localtimeup, $localfailtime, $ppdowntime, $ppinterval, $ppfft,
	$first_failure_time, $total_failures, $mtbf, 
	$mean_recovery_time, $median_recovery_time, $std_dev_recovery_time, 
	$min_recovery_time, $max_recovery_time, $ppmtbf, $ppmean_recovery_time, 
	$ppmedian_recovery_time, $ppmin_recovery_time, $ppmax_recovery_time, 
	$ppstd_dev_recovery_time, @recovery_times, $stat, $group, $service );
 
    my $time_now = time;
    my $max_recovery_time_default = -1;
    my $min_recovery_time_default = 9999999999999;
    $max_recovery_time = $max_recovery_time_default;                     # initialize this to something really small
    $min_recovery_time = $min_recovery_time_default;          # initialize this to something really big
    $first_failure_time = $time_now;
    print $main::query->hr;
    if ( ($hashRef) && (scalar(@$hashRef) > 0) )  {
	foreach $line (reverse sort {$a->{"failtime"} <=> $b->{"failtime"}}(@$hashRef)){
	    if ($line->{"failtime"} < $first_failure_time) {
		# since this list is already sorted, this will only be true
		# the very first time we go thru this loop
		$first_failure_time = $line->{"failtime"} if $line->{"failtime"} < $first_failure_time ;
	    }
	    push(@recovery_times, $line->{"downtime"});
	    # set min and max
	    $min_recovery_time = $line->{"downtime"} if $line->{"downtime"} < $min_recovery_time;
	    $max_recovery_time = $line->{"downtime"} if $line->{"downtime"} > $max_recovery_time;
	}
	# Calculate mean recovery time
	$stat = Statistics::Descriptive::Full->new();
	$stat->add_data(@recovery_times);
	$mean_recovery_time = $stat->mean();
	# also calculate median recovery time
	$median_recovery_time = $stat->median();
	# calculate the mean time between failures as:
	# (total elapsed time since first failure + E(time until first failure))/(total # of failures)
	$mtbf = (scalar(@recovery_times) == 0) 
	    ? 0 
		: ($time_now - $first_failure_time + 
		   (($time_now - $first_failure_time) / scalar(@recovery_times))) / scalar(@recovery_times);
	$std_dev_recovery_time = $stat->standard_deviation();
	# In case max_recovery_time is unset (i.e. there were no failures), set
	# it to a sensible default.
	$max_recovery_time = ($max_recovery_time == $max_recovery_time_default) ? 0 : $max_recovery_time;
	$min_recovery_time = ($min_recovery_time == $min_recovery_time_default) ? 0 : $min_recovery_time;
	$total_failures = scalar(@recovery_times);
	my $approx_uptime_pct = ( ( ($time_now - $first_failure_time + $mtbf ) > 0) && 
				 ( ($time_now - $first_failure_time + $mtbf - scalar(@$hashRef) 
				    * $mean_recovery_time > 0 ) ) ) 
	    ? sprintf("%.2f%", ( ( ($time_now - $first_failure_time + $mtbf) - (scalar(@$hashRef) 
										* $mean_recovery_time) ) 
				/ ($time_now - $first_failure_time + $mtbf) ) * 100 ) 
		: "-not applicable-";

	###############################	
	# Generate an english version of the search criteria.
	#
	# This code looks ugly because it is.
	# The main criteria string is put into @query_string, and the
	# vars $stringtmp and $stringtmp{2,3} are used as temp variables
	# along the way.
	#
	# If you add new fields to the form, you'll have to update this
	# code.
	###############################
	my (@query_string, $stringtmp, $stringtmp2, $stringtmp3);
	# choice0 is either "host,group,service"
	# boolean0 is either "contains,does not contain"
	# string0 is the name of the {host,group,service}
	# operationN is the AND,OR between entries
	if ($namedvalue{choice0}) {
	    $stringtmp2 = ($namedvalue{boolean0} =~ /not/) ? "does not contain" : "contains";
	    $stringtmp3 = ($namedvalue{string0} eq "") ? "Any" : $namedvalue{string0} ;
	    push (@query_string, "field &quot;$namedvalue{choice0}&quot; $stringtmp2 value &quot;$stringtmp3&quot;") ;
	}

	# Now we do the same for the second set of choice boxes
	if ($namedvalue{choice1}) {
	    $stringtmp = ($namedvalue{choice0}) ? uc($namedvalue{operation0}) . " " : "" ;
	    $stringtmp2 = ($namedvalue{boolean1} =~ /not/) ? "does not contain" : "contains";
	    $stringtmp3 = ($namedvalue{string1} eq "") ? "Any" : $namedvalue{string1} ;
	    push (@query_string, $stringtmp . "field &quot;$namedvalue{choice1}&quot; $stringtmp2 value &quot;$stringtmp3&quot;") ;
	}

	# Now we do the same for the third set of choice boxes
	if ($namedvalue{choice2}) {
	    $stringtmp = ( ($namedvalue{choice0}) || ($namedvalue{choice1}) ) ? uc($namedvalue{operation1}) . " " : "" ;
	    $stringtmp2 = ($namedvalue{boolean2} =~ /not/) ? "does not contain" : "contains";
	    $stringtmp3 = ($namedvalue{string2} eq "") ? "Any" : $namedvalue{string2} ;
	    push (@query_string, $stringtmp . "field &quot;$namedvalue{choice2}&quot; $stringtmp2 value &quot;$stringtmp3&quot;") unless ($namedvalue{string2} eq "");
	}

	# At this point, we've finished with the "field x contains y"
	# Put in a sensible default if there aren't any criteria selected
	# (i.e. user wants all downtime log entries returned)
	push (@query_string, "no host, group or service criteria selected " ) unless (@query_string);

	# Now do 'start of failure' or 'time back up' part of form
	$stringtmp = ($namedvalue{choice3} eq "failtime") ? "&quot;start of failure&quot;" : "&quot;time back up&quot;" ;
	$stringtmp2 = uc($namedvalue{operation2});
	push (@query_string, "$stringtmp2 where $stringtmp is" ) ;
	# This next line is a long one, so it gets its own entry
	my @start_ltime = localtime($namedvalue{start_time});
	my @end_ltime = localtime($namedvalue{end_time});
	push (@query_string, sprintf ("from %.2d:%.2d,%.2d-%s-%d to %.2d:%.2d,%.2d-%s-%d", @start_ltime[2,1], $start_ltime[3], @year_months[$start_ltime[4]], $start_ltime[5] + 1900, @end_ltime[2,1], $end_ltime[3], @year_months[$end_ltime[4]], $end_ltime[5] + 1900) );
#	$stringtmp = ($namedvalue{choice3} eq "failtime") ? "&quot;start of failure&quot;" : "&quot;time back up&quot;" ;
	$stringtmp2 = ($namedvalue{boolean4} =~ /not/) ? "is not within" : "is within";
	$stringtmp3 = uc($namedvalue{operation3});
	push (@query_string , "$stringtmp3 where $stringtmp $stringtmp2 the hours of $namedvalue{'start_hour'}:$namedvalue{'start_minute'} and $namedvalue{'end_hour'}:$namedvalue{'end_minute'}");


	# optional, where 'failtime' {>,<=} n seconds
	if ($namedvalue{choice4} && $namedvalue{string3}) {
	    $stringtmp = uc($namedvalue{operation4});
	    push (@query_string, "$stringtmp where $namedvalue{choice4} $namedvalue{gtlt} $namedvalue{string3} seconds");
	}


	###############################
	# Now print the summary statistics table
	###############################
	# Print company logo/title
	$main::query->print("<img alt=\"[$organization logo]\" src=\"$logo\"><font size=+3>&nbsp;&nbsp;Downtime Query Results</font><br>");

	$main::query->print("<table border=1 align=center width=\"$summary_table_width\">\n");
	$main::query->print("<tr>\n");
	$main::query->print("<td colspan=2 align=center><font size=+1 face=\"$face\">\n<b>");
	$main::query->print("Downtime Summary");
	$main::query->print("</b></font></td>\n");
	$main::query->print("</tr>\n");
	$main::query->print("<tr>\n");
	$main::query->print("<td>Search criteria:</td>\n<td><font size=-1>" . join(' ' , @query_string) . "</font></td>\n");
	$main::query->print("</tr>\n");
	$main::query->print("<tr>\n");
	$main::query->print("<td>Total observed service failures:</td>\n<td>$total_failures</td>\n");
	$main::query->print("</tr>\n");
	$main::query->print("<tr>\n");
	$ppfft = localtime($first_failure_time);
	$main::query->print("<td>Log begins at:</td>\n<td>$ppfft</td>\n");
	$main::query->print("</tr>\n");

	$main::query->print("<td>Mean time between service failures:</td>\n");
	$ppmtbf = &pp_sec($mtbf);
	$main::query->print("<td>$ppmtbf</td>\n"); 
	$main::query->print("<tr>\n");
	$main::query->print("<td>Mean observed service failure time:</td>\n");
	$ppmean_recovery_time = &pp_sec($mean_recovery_time);
	$main::query->print("<td>$ppmean_recovery_time</td>\n");
	$main::query->print("</tr>\n");
	$main::query->print("<tr>\n");
	$main::query->print("<td>Median observed service failure time:</td>\n");
	$ppmedian_recovery_time = &pp_sec($median_recovery_time);
	$main::query->print("<td>$ppmedian_recovery_time</td>\n");
	$main::query->print("</tr>\n");
	$main::query->print("<tr>\n");
	$main::query->print("<td>Standard deviation of observed service failure times:</td>\n");
	$ppstd_dev_recovery_time = &pp_sec($std_dev_recovery_time);
	$main::query->print("<td>$ppstd_dev_recovery_time</td>\n");
	$main::query->print("</tr>\n");
	$main::query->print("<tr>\n");
	$main::query->print("<td>Minimum observed service failure time:</td>\n");
	$ppmin_recovery_time = &pp_sec($min_recovery_time);
	$main::query->print("<td>$ppmin_recovery_time</td>\n");
	$main::query->print("</tr>\n");
	$main::query->print("<tr>\n");
	$main::query->print("<td>Maximum observed service failure time:</td>\n");
	$ppmax_recovery_time = &pp_sec($max_recovery_time);
	$main::query->print("<td>$ppmax_recovery_time</td>\n");
	$main::query->print("</tr>\n");
	$main::query->print("<tr>\n");
	$main::query->print("<td><i>Approximate</i> percentage of time in failure-free operation:</td>\n");
	$main::query->print("<td>$approx_uptime_pct</td>\n");
	$main::query->print("</tr>\n");
	$main::query->print("</table>\n");


	###############################
	# Now print out a graphing menu
	###############################
	# First, populate the data files
	my $retval = &write_data_to_file($first_failure_time, $hashRef, "dtgraph.txt");
        # This is the code which generates the uptime graph
	my $dtgraph_HR = &make_dt_HR_graph("$retval.HR", "dtgraphHR-$time_now-$rand.png", \@query_string) if $retval;
        # Now generate the "Cumulative Downtime by Time of Day" graph
	my $dtgraph_TOD = &make_dt_TOD_graph("$retval.TOD", "dtgraphTOD-$time_now-$rand.png", \@query_string) if $retval;
        # Now generate the "Cumulative Downtime by Day of Week" graph
	my $dtgraph_DOW = &make_dt_DOW_graph("$retval.DOW", "dtgraphDOW-$time_now-$rand.png", \@query_string) if $retval;
        # Now generate the "Failure Time Distribution" graph
	my $dtgraph_DT = &make_dt_DT_graph("$retval.DT", "dtgraphDT-$time_now-$rand.png", \@query_string) if $retval;
        # Now generate the "Cumulative Failure Time by Service" graph
	my $dtgraph_SVC = &make_dt_GD_graph("$retval.SVC", "dtgraphSVC-$time_now-$rand.png", \@query_string, "Cumulative Downtime by Service") if $retval;
        # Now generate the "Cumulative Failure Time by Group" graph
	my $dtgraph_GRP = &make_dt_GD_graph("$retval.GRP", "dtgraphGRP-$time_now-$rand.png", \@query_string, "Cumulative Downtime by Group") if $retval;
	$main::debug && print "retval from file = ($retval)<br>"; #DEBUG
	$main::debug && print "retval from graph = ($dtgraph_HR)<br>"; #DEBUG
	$main::debug && print "retval from graphTOD = ($dtgraph_TOD)<br>"; #DEBUG
	$main::debug && print "retval from graphDOW = ($dtgraph_DOW)<br>"; #DEBUG
	$main::debug && print "retval from graphDT = ($dtgraph_DT)<br>"; #DEBUG
	$main::debug && print "retval from graphSVC = ($dtgraph_SVC)<br>"; #DEBUG
	$main::debug && print "retval from graphGRP = ($dtgraph_GRP)<br>"; #DEBUG
	# Clean out the temporary directory, unless we're in debug mode
	&_clean_tmpdir unless $main::debug ;
	$main::query->print("\n<a name=1></a>");

	# Make the window slightly bigger than the image itself, so 
	# nothing gets cut off.
	my $window_xsize = $graph_xsize + 30;
	my $window_ysize = $graph_ysize + 200;
	my $graph_cell_width = "16%%"; # should be (100% / number of graphs)
	$main::query->print("<br><center>");
	$main::query->print("<table border=1 width=\"$summary_table_width\"><tr valign=top>\n");
	$main::query->print("<tr><td colspan=6 align=center>");
	$main::query->print("<font size=+1 face='$face'><b>Graphs</b></font>");
	$main::query->print("</td></tr><tr valign=top>");
	$main::query->print("<font size=+0>");
	$main::query->print("<td width=\"$graph_cell_width\">");
	$main::query->print("<a href=\"#1\" onClick=window.open('$url?png=$dtgraph_HR&displayGraph=1','dtgraphWin','width=$window_xsize,height=$window_ysize,toolbar=yes,location=yes,directories=no,status=no,menubar=no,resizable=yes,scrollbars=yes','replace=false')>Downtime by Hour of Day</a>") if $dtgraph_HR;
	$main::query->print("</td>");
	$main::query->print("<td width=\"$graph_cell_width\">");
	$main::query->print("<a href=\"#1\" onClick=window.open('$url?png=$dtgraph_TOD&displayGraph=1','dtgraphTODwin','width=$window_xsize,height=$window_ysize,toolbar=yes,location=yes,directories=no,status=no,menubar=no,resizable=yes,scrollbars=yes','replace=false')>Cumulative Downtime by Time of Day</a>") if $dtgraph_TOD;
	$main::query->print("</td>");
	$main::query->print("<td width=\"$graph_cell_width\">");
	$main::query->print("<a href=\"#1\" onClick=window.open('$url?png=$dtgraph_DOW&displayGraph=1','dtgraphDOWwin','width=$window_xsize,height=$window_ysize,toolbar=yes,location=yes,directories=no,status=no,menubar=no,resizable=yes,scrollbars=yes','replace=false')>Cumulative Downtime by Day of Week</a>") if $dtgraph_DOW;
	$main::query->print("</td>");
	$main::query->print("<td width=\"$graph_cell_width\">");
	$main::query->print("<a href=\"#1\" onClick=window.open('$url?png=$dtgraph_DT&displayGraph=1','dtgraphDTwin','width=$window_xsize,height=$window_ysize,toolbar=yes,location=yes,directories=no,status=no,menubar=no,resizable=yes,scrollbars=yes','replace=false')>Failure Time Distribution</a>") if $dtgraph_DT;
	$main::query->print("</td>");
	$main::query->print("<td width=\"$graph_cell_width\">");
	$main::query->print("<a href=\"#1\" onClick=window.open('$url?png=$dtgraph_SVC&displayGraph=1','dtgraphSVCwin','width=$window_xsize,height=$window_ysize,toolbar=yes,location=yes,directories=no,status=no,menubar=no,resizable=yes,scrollbars=yes','replace=false')>Cumulative Downtime by Service</a>") if $dtgraph_SVC;
	$main::query->print("</td>");
	$main::query->print("<td width=\"$graph_cell_width\">");
	$main::query->print("<a href=\"#1\" onClick=window.open('$url?png=$dtgraph_GRP&displayGraph=1','dtgraphGRPwin','width=$window_xsize,height=$window_ysize,toolbar=yes,location=yes,directories=no,status=no,menubar=no,resizable=yes,scrollbars=yes','replace=false')>Cumulative Downtime by Group</a>") if $dtgraph_GRP;
	$main::query->print("</td>");
	$main::query->print("</tr></table>");
	$main::query->print("</center></font>");


	
	$main::query->print("<br>\n");
	$main::query->print("<table border=1 width=\"$dt_table_width\" align=center>\n");
	$main::query->print("<tr>");
	$main::query->print("<td align=center>");
	$main::query->print("<font size=+1 face='$face'><b>Failure Details</b></font>");
	$main::query->print("</td>");
	$main::query->print("</tr></table>\n");


	###############################
	# Now print the actual downtime table
	###############################
	#
	# Now that we've printed the stats
	# we splice out a chunk to print on
	# this page
	#

	if (@$hashRef > $main::dtlog_max_failures_per_page) {
	    if ($startwith) {
		splice(@$hashRef, 0, $startwith);
	    }
	    splice(@$hashRef, $main::dtlog_max_failures_per_page);
	}
	
	# Print the header as a table with a thicker border
	$main::query->print("<table border=1 width=\"$dt_table_width\" align=center>\n");
	$main::query->print("<tr>");
	$main::query->print("<th><font size=+1>Group</font></th>\n");
	$main::query->print("<th><font size=+1>Service</font></th>\n");
	$main::query->print("<th><font size=+1>Service Failure Begin Time</font></th>\n");
	$main::query->print("<th><font size=+1>Service Failure End Time</font></th>\n");
	$main::query->print("<th><font size=+1>Total Observed Service Failure Time</font></th>\n");
	$main::query->print("<th><font size=+1>Testing Interval</font></th>\n");
	$main::query->print("<th><font size=+1>Summary</font></th>\n");
	$main::query->print("</tr>");

	$sortby = "failtime" if ($sortby eq "");
	# Otherwise sort by key, if any
	$main::debug && print "sortby is $sortby<br>\n";
	if ($sortby ne "") {
	    # do a forward-alphanumeric or reverse-numeric sort, 
	    # depending on the sortby parameter
	    if ( ($sortby eq "group") || ($sortby eq "service") || ($sortby eq "summary") ) {
		@$hashRef = (sort {$a->{"$sortby"} cmp $b->{"$sortby"}}(@$hashRef));
	    } else {
		@$hashRef = (reverse sort {$a->{"$sortby"} <=> $b->{"$sortby"}}(@$hashRef));
	    }
	}


	
	foreach $line (@$hashRef) {
	    $main::query->print("<tr><td><a href=\"$moncgi_url?command=list_dtlog&args=$line->{\"group\"}\">");
	    $main::query->print("<font face=\"$face\">$line->{\"group\"}</font></a></td>");
	    $main::query->print("<td><a href=\"$moncgi_url?command=list_dtlog&args=$line->{\"group\"},$line->{\"service\"}\">");
	    $main::query->print("<font face=\"$face\">$line->{\"service\"}</font></a></td>\n");
	    
	    $localfailtime = localtime ($line->{"failtime"});
	    $main::query->print("<td>$localfailtime</td>\n");
	    
	    $localtimeup = localtime ($line->{"timeup"});
	    $main::query->print("<td>$localtimeup</td>\n");
	    
	    $ppdowntime = &pp_sec ($line->{"downtime"});
	    $main::query->print("<td>$ppdowntime</td>\n");
	    $ppinterval = &pp_sec ($line->{"interval"});
	    $main::query->print("<td>$ppinterval</td>\n");
	    $main::query->print("<td>$line->{\"summary\"}</td>");
	    
	    $main::query->print("</tr>\n");
	}
	
	$main::query->print("</table>\n");
    } else {
	$main::query->print("<b>No entries match the specified parameters</b><br>\n");
	# maybe print something here to list what the searched-for parameters
	# were.
    }
    print $main::query->hr;
}







    
######################################
# Search for what you want, by string
#
# Inputs: ($string, $fn, $pref, $not, $exact)
# $string = string, to search for
# $fn = integer, field number in log to search for
# $pref = reference, to an array to search through
# $not = boolean, specifies whether to reverse search criteria $string
# $exact = boolean, specifies whether to search exactly for the word 
#          or inclusively (set to true only when searching the "summary" 
#          field for hosts).
#
# Outputs:
# A reference to an array (of hashes?) containing the results.
######################################

sub SearchFor
{
  my $string = shift @_;
  my $fn = shift @_;
  my $pref = shift @_;
  my $not = shift @_;
  my $exact = shift @_;
  my @newentries;
  my $entry;

  unless ($string =~ /.*\S.*/) {
      $string = ".*";
  }

  # set the search string to be exact if we specified it
  $string = "^$string\$" if ($exact) ;

  $main::debug && print "searching field $fn for $string<br>\n";

  foreach $entry (@$pref) {
      if ($not) {
	  if ($$entry{$fn} !~ /$string/i) {
	      push @newentries, $entry;
	  }
      } else {
	  if ( ($string) && ($$entry{$fn} =~ /$string/i)) {
	      push @newentries, $entry;
	  }
      }
  }

  return \@newentries;
}



######################################
# Search for what you want, by date
######################################
#
sub SearchForDate
{
  my $startdate = shift @_;
  my $enddate = shift @_;
  my $fn = shift @_;
  my $pref = shift @_;
  my $not = shift @_;
  my @newentries;
  my $entry;

  $not = 0 if !defined($not);

  foreach $entry (@$pref) {
      unless (defined $$entry{$fn}) { $$entry{$fn} = -1; }
      if (($not == 1) && (($$entry{$fn} < $startdate) || 
                          ($$entry{$fn} > $enddate))) {
	  push @newentries, $entry;
      } elsif (($not != 1) && (($$entry{$fn} >= $startdate ) && 
                               ($$entry{$fn} <= $enddate))) {
	  push @newentries, $entry;
      }
  }
  return \@newentries;
}



######################################
# Search for what you want, by date
######################################
#
sub SearchForTime
{
  my $starttime = shift @_;
  my $endtime = shift @_;
  my $fn = shift @_;
  my $pref = shift @_;
  my $not = shift @_;
  my @newentries;
  my $entry;
  my @fail_ltime;

  my $dbg; #DEBUG

  $not = 0 if !defined($not);

  foreach $entry (@$pref) {
      unless (defined $$entry{$fn}) { $$entry{$fn} = -1; }
      @fail_ltime = localtime($$entry{$fn});

      if ( ($not == 1) &&  #now check the start time to make sure it's in range
	   ( ( $fail_ltime[0] + $fail_ltime[1] * 60 + $fail_ltime[2] * 3600 < $starttime ) ||
	   ( $fail_ltime[0] + $fail_ltime[1] * 60 + $fail_ltime[2] * 3600 > $endtime ) )
	   ) {
	  
	  $dbg = localtime($$entry{$fn}); #DEBUG
	  #print STDERR "NOT TIME: time=$$entry{$fn}, localtime=$dbg (tzsec = $tzsec)\n"; #DEBUG
	  push @newentries, $entry;
      } elsif (($not != 1) && 
	       ( ( $fail_ltime[0] + $fail_ltime[1] * 60 + $fail_ltime[2] * 3600 >= $starttime ) &&
	       ( $fail_ltime[0] + $fail_ltime[1] * 60 + $fail_ltime[2] * 3600 <= $endtime ) )
	       ) {
	  $dbg = localtime($$entry{$fn}); #DEBUG
	  #print STDERR "TIME: time=$$entry{$fn}, localtime=$dbg (tzsec = $tzsec)\n"; #DEBUG
	  push @newentries, $entry;
      }
  }
  print STDERR "Returning " . scalar(@newentries) . " entries from Time\n"; #DEBUG
  return \@newentries;
}


sub Uniq {
    my $aRef = shift @_;
    my ($key, @new, $oldkey);
    foreach $key (sort @$aRef) {
	$key =~ s/\*//g;
	if ($oldkey ne $key) {
            push @new, $key;
            $oldkey = $key;
        }
    }
    @new = sort @new;
    return @new;
}


sub write_data_to_file {
    # This sub is used to dump downtime data into a file
    #
    # This subroutine accepts a first failure time (in epoch seconds),
    # a reference 
    # to a hash of downtime data, and a filename to write to, 
    # and dumps the data to the output file suitable for reading 
    # by gnuplot.
    #
    # Returns $filename : Name of file successfully written, 
    #                     operation was a success
    #         undef     : Operation was a failure
    my ($first_failure_time, $hashRef, $filename) = @_;
    $filename = "$tmpdir/$filename" ;
    my ($line, $i, @ltime, $hhmm, $dow);
    my (%dt_by_TOD, %dt_by_DOW, %dt_by_DT, %dt_by_SVC, %dt_by_GRP, $key);
    my $filename_orig = $filename;
    unless (opendir TMPDIR, "$tmpdir") {
	# create tmpdir if it doesn't exist
	mkdir ("$tmpdir",0777) or die "Unable to create tmpdir $tmpdir:$!";
    }
    $filename = "$filename_orig.HR";
    if (open(DATAFILE, "> $filename")) { # dump the data to a file
	# Here's where the log starts
	if ( $namedvalue{start_time} == 0 ) {
	    # We're always assuming that we're up the instant that the 
	    # graph starts. Those more pedantic than I are free to 
	    # correct this assumption.
	    print DATAFILE &format_date($first_failure_time) . "\t$up_value\n"   ;
	}
	# Because  %dt_by_DOW is using GD::Graph instead of gnuplot,
	# it need to be initialized (GD::Graph doesn't handle holes 
	# in data gracefully).
	for ($i = 0 ; $i < 7 ; $i++) {
	    $dt_by_DOW{$i} = 0 ;
	}
	foreach $line (@$hashRef) {
	    # Assume 1 second before failure, service was up
	    print DATAFILE &format_date($line->{'failtime'} - 1) . "\t$up_value\n" ;
	    # At time of service failure, service is down, and
	    # service continues to be down for failtime seconds
	    print DATAFILE &format_date($line->{'failtime'}) . "\t$down_value\n" ;
	    # Put all failures into 1-minute buckets (you don't really
	    # want 86400 potential data points, do you?) (hint: I tried
	    # it, you don't - andrewr)
	    for ( $i = 0 ; $i <= $line->{'downtime'} ; $i+=60) {
		@ltime = localtime($line->{'failtime'} + $i);
		$hhmm = sprintf("%02d:%02d" , $ltime[2],$ltime[1]);    #time in hh:mm
		$dt_by_TOD{$hhmm} = 0 unless $dt_by_TOD{$hhmm};
		$dt_by_TOD{$hhmm}++;
	    }

	    # Now add the data on this failure to the dt_by_DT hash
	    $dt_by_DT{int($line->{'downtime'}/60)} = 0 unless $dt_by_DT{int($line->{'downtime'}/60)};
	    $dt_by_DT{int($line->{'downtime'}/60)}++;

	    # This works, but what if dt crosses one or more day boundaries?
	    $dow = $ltime[6];   #time in day of week
	    my $sec_remaining_in_day = 86400 - ($line->{'failtime'} % 86400) ;

	    my $failtime_addl_days = ($line->{'downtime'} / 86400) - ($sec_remaining_in_day / 86400) ;
	    # The simple case, where the failure ends on the same day
	    # as it started.
	    if ( $line->{'downtime'} <= $sec_remaining_in_day ) {
		$dt_by_DOW{$dow} += $line->{'downtime'};  #absolute downtime, note that DOW has already been initialized
	    } else {
		# The failure ends one or more days from when it began
		$dt_by_DOW{$dow} += $sec_remaining_in_day ;  # first add the rest of the seconds in the current day
		# downtime for subsequent whole days
		for ($i = 0 ; $i < int($failtime_addl_days) ; $i++ ) {
		    # Move the day to be the next day of the week
		    $dow = ($dow == 6) ? 0 : $dow++ ;
		    $dt_by_DOW{$dow} += 86400 ; #whole day is a failure
		}
		# the last day, a partial
		$dow = ($dow == 6) ? 0 : $dow++ ;
		$dt_by_DOW{$dow} += ($failtime_addl_days - $i) * 86400 ;
	    }
	    # Assume 1 second after failure finished, service was up
	    print DATAFILE &format_date($line->{'failtime'} + $line->{'downtime'} + 1) . "\t$up_value\n" ;

	    # Now put the downtime event into the $dt_by_SVC
	    #$dt_by_SVC{$line->{'service'}} = 0 unless $dt_by_SVC{$line->{'service'}};
	    $dt_by_SVC{$line->{'service'}} += int($line->{'downtime'}/60) ;
	    # Now put the downtime event into $dt_by_GRP
	    $dt_by_GRP{$line->{'group'}} += int($line->{'downtime'}/60) ;

	}
	# Assume that at end_time, service is up (where end_time is now
	# if the user didn't explicitly give one)
	if ( $namedvalue{end_time} == 0 ) {
	    print DATAFILE &format_date($time_now) . "\t$up_value\n" ;
	} else {
	    print DATAFILE &format_date($namedvalue{end_time}) . "\t$up_value\n" ;
	}
	close DATAFILE;

	# Now write out the Downtime by TOD data
	$filename = "$filename_orig.TOD";
	if (open(DATAFILE, "> $filename")) { # dump the data to a file
	    foreach $key (sort keys(%dt_by_TOD)) {
		print DATAFILE "$key\t$dt_by_TOD{$key}\n";
	    }
	    close DATAFILE;
	} else {
	    return undef;
	}

	# Now write out the Downtime by DOW data
	$filename = "$filename_orig.DOW";
	if (open(DATAFILE, "> $filename")) { # dump the data to a file
	    foreach $key (sort keys(%dt_by_DOW)) {
		printf DATAFILE ("%s\t%.1f\n", $key, $dt_by_DOW{$key} / 60);
	    }
	    close DATAFILE;
	} else {
	    return undef;
	}

	# Now write out the Downtime distribution data
	$filename = "$filename_orig.DT";
	if (open(DATAFILE, "> $filename")) { # dump the data to a file
	    foreach $key (sort keys(%dt_by_DT)) {
		print DATAFILE "$key\t$dt_by_DT{$key}\n";
	    }
	    close DATAFILE;
	} else {
	    return undef;
	}

	# Now write out the Downtime by SERVICE  data
	$filename = "$filename_orig.SVC";
	if (open(DATAFILE, "> $filename")) { # dump the data to a file
	    foreach $key (sort keys(%dt_by_SVC)) {
		print DATAFILE "$key\t$dt_by_SVC{$key}\n";
	    }
	    close DATAFILE;
	} else {
	    return undef;
	}

	# Now write out the Downtime by GROUP data
	$filename = "$filename_orig.GRP";
	if (open(DATAFILE, "> $filename")) { # dump the data to a file
	    foreach $key (sort keys(%dt_by_GRP)) {
		print DATAFILE "$key\t$dt_by_GRP{$key}\n";
	    }
	    close DATAFILE;
	} else {
	    return undef;
	}

	# All is well!
	return $filename_orig;
    } else {
	print "unable to open data file $filename for writing: $!";
	return undef;
    }
}


sub format_date {
    # takes a time() and returns a formatted date string as "%d-%m-%Y %H:%M:%S"
    # no error checking or input validation!
    my @localtime = localtime($_[0]) ;
    return  sprintf  ("%.2d-%s-%d %.2d:%.2d:%.2d", $localtime[3], $localtime[4]+ 1, $localtime[5] + 1900, @localtime[2,1,0]);
}


sub make_dt_TOD_graph {
    # Makes the "Downtime by TOD" graph
    #
    # Requires as arguments a filename containing data, and an output filename
    # "$data_filename" is assumed to be in $tmpdir, this behavior cannot
    # "$output_filename" is assumed to be in $graphdir, this behavior cannot
    # be overridden.
    # $graph_desc is an array reference to an array containing
    #                text which describes the graph in detail
    my ($data_filename, $output_filename, $graph_desc) = @_;
    my $output_filename_orig = $output_filename ;
    $output_filename = "$graphdir/$output_filename";
    my $cmd_filename = "$tmpdir/gplotTOD.cmd";   #the gnuplot command file
    my $gnuplot_size = sprintf("%.2f,%.2f" , $graph_xsize/640, $graph_ysize/480);
    my $keytitle_text = "Cumulative Downtime by Time of Day";

    unless (opendir GRAPHDIR, "$graphdir") { # create graphdir if it doesn't exist
	unless (mkdir ("$graphdir",0777)) {
	    print STDERR "Unable to create graphdir $graphdir:$!";
	    return undef;
	}
    }

    # We don't check to see if $tmpdir already exists, because if it 
    # doesn't exist, we won't have any data to plot anyway!
    if (open(GPLOTCMD, ">$cmd_filename" ) ) { #open gnuplot command file for writing
	print GPLOTCMD <<EOF ;
set term png small color
set output '$output_filename'
set xdata time
set timefmt "%H:%M"
set size $gnuplot_size
#set key below
#set keytitle "$keytitle_text"
set xrange ["00:00":"23:59"]
set ylabel "Minutes In Failure"
set xlabel "Time of Day"
set data style points
set format x "%H:%M"
plot '$data_filename' \\
        using 1:2 \\
        notitle
EOF
    close GPLOTCMD;
	# Now write out the meta file (contains description of the graph)
	if ( open(META , ">$output_filename.meta") ) {
	    print META join("\n" ,  $keytitle_text, @$graph_desc);
	    close META;
	} else {
	    print STDERR "Unable to create graph metafile $output_filename.meta:$!";
	    return undef;
	}
} else {
    print STDERR "Unable to create gnuplot command file $cmd_filename: $!";
    return undef;
}

    # Now run gnuplot with the command file
    if (not &_exec_gnuplot($cmd_filename)) {
	return undef;
    } else {
	return $output_filename_orig;
    }
}


sub make_dt_DT_graph {
    # Makes the "Failure Time Distribution" graph
    #
    # Requires as arguments a filename containing data, and an output filename
    # "$data_filename" is assumed to be in $tmpdir, this behavior cannot
    # "$output_filename" is assumed to be in $graphdir, this behavior cannot
    # be overridden.
    # $graph_desc is an array reference to an array containing
    #                text which describes the graph in detail
    my ($data_filename, $output_filename, $graph_desc) = @_;
    my $output_filename_orig = $output_filename ;
    $output_filename = "$graphdir/$output_filename";
    my $cmd_filename = "$tmpdir/gplotTOD.cmd";   #the gnuplot command file
    my $gnuplot_size = sprintf("%.2f,%.2f" , $graph_xsize/640, $graph_ysize/480);
    my $keytitle_text = "Failure Time Distribution" ;

    unless (opendir GRAPHDIR, "$graphdir") { # create graphdir if it doesn't exist
	unless (mkdir ("$graphdir",0777)) {
	    print STDERR "Unable to create graphdir $graphdir:$!";
	    return undef;
	}
    }

    # We don't check to see if $tmpdir already exists, because if it 
    # doesn't exist, we won't have any data to plot anyway!
    if (open(GPLOTCMD, ">$cmd_filename" ) ) { #open gnuplot command file for writing
	print GPLOTCMD <<EOF ;
set term png small color
set output '$output_filename'
set size $gnuplot_size
# 'key' doesn't get printed if we use the 'notitle' option
#set key below
#set keytitle "$keytitle_text"
set ylabel "Number of Failures"
set xlabel "Downtime, in Minutes"
set logscale x
set data style impulse
set tics out
plot '$data_filename' \\
        using 1:2 \\
        notitle
#        title "Failures"
EOF
    close GPLOTCMD;
	# Now write out the meta file (contains description of the graph)
	if ( open(META , ">$output_filename.meta") ) {
	    print META join("\n" ,  $keytitle_text, @$graph_desc);
	    close META;
	} else {
	    print STDERR "Unable to create graph metafile $output_filename.meta:$!";
	    return undef;
	}
} else {
    print STDERR "Unable to create gnuplot command file $cmd_filename: $!";
    return undef;
}

    # Now run gnuplot with the command file
    if (not &_exec_gnuplot($cmd_filename)) {
	return undef;
    } else {
	return $output_filename_orig;
    }
}


#
# This subroutine makes the "Downtime by Day of Week" graph.
# It's quite a bit different from the other two since it uses
# GD::Graph to make the graph instead of gnuplot. The choice of
# GD::Graph was made because it produces a much nicer graph for
# this application (just like it does a lousy job for the other 
# gnuplot graph types).
#
sub make_dt_DOW_graph {
    # $graph_desc is an array reference to an array containing
    #                text which describes the graph in detail
    my ($data_filename, $output_filename, $graph_desc) = @_;
    my $output_filename_orig = $output_filename ;
    $output_filename = "$graphdir/$output_filename";
    my ( $graph, $gd, @line, @DOWdata, $keytitle_text );
    $graph = GD::Graph::bars->new($graph_xsize, $graph_ysize);
    $keytitle_text = "Cumulative Downtime by Day of Week";

    # Feel free to muck with the defaults, and/or add your own
    # Default bar color is red, and shadow color is dark red
    # Let me know if you come up with anything cool! - andrewr
    $graph->set(
		y_label           => 'Minutes in Failure',
		title             => "$keytitle_text",
		x_all_ticks       => 1,
		show_values       => 1,
		bar_spacing       => 8,
		shadow_depth      => 4,
		shadowclr         => 'dred',
		);

    unless (opendir GRAPHDIR, "$graphdir") { # create graphdir if it doesn't exist
	unless (mkdir ("$graphdir",0777)) {
	    print STDERR "Unable to create graphdir $graphdir:$!";
	    return undef;
	}
    }

    if (open(DATAFILE, $data_filename) ) {
	# Read in the data file and convert day-of-week numbers into english
	while (<DATAFILE>) {
	    chomp;
	    @line = (split(' ' , $_));
	    # push the x and y datapoints into the array for GD::Graph
	    push (@{$DOWdata[0]}, $days_of_week[$line[0]]);
	    push (@{$DOWdata[1]}, $line[1]);
	    #print STDERR "pushing $days_of_week[$line[0]]:$line[1]\n"; #DEBUG
	}
	close DATAFILE;
    } else {
	print STDERR "Unable to open data file $data_filename: $!\n";
	return undef;
    }
	
    # Now graph the data
    $gd = $graph->plot(\@DOWdata) ;
    if (open(IMG, ">$output_filename")) {
	binmode IMG;
	print IMG $gd->png;
	close IMG;
    } else {
	print STDERR "Unable to open output file $output_filename: $!\n";
	return undef;
    }
    
    # Now write out the meta file (contains description of the graph)
    if ( open(META , ">$output_filename.meta") ) {
	print META join("\n" , $keytitle_text, @$graph_desc);
	close META;
    } else {
	print STDERR "Unable to create graph metafile $output_filename.meta:$!";
	return undef;
    }

    return $output_filename_orig;
 
}


#
# This subroutine makes the "Downtime by Service/Group" graph.
# It's quite a bit different from the other two since it uses
# GD::Graph to make the graph instead of gnuplot. The choice of
# GD::Graph was made because it produces a much nicer graph for
# this application (just like it does a lousy job for the other 
# gnuplot graph types).
#
sub make_dt_GD_graph {
    # $graph_desc is an array reference to an array containing
    #                text which describes the graph in detail
    my ($data_filename, $output_filename, $graph_desc, $keytitle_text) = @_;
    my $output_filename_orig = $output_filename ;
    $output_filename = "$graphdir/$output_filename";
    my ( $graph, $gd, @line, @data );
    $graph = GD::Graph::bars->new($graph_xsize, $graph_ysize);
#    $keytitle_text = "Cumulative Downtime by Service";

    # Feel free to muck with the defaults, and/or add your own
    # Default bar color is red, and shadow color is dark red
    # Let me know if you come up with anything cool! - andrewr
    $graph->set(
		y_label           => 'Minutes in Failure',
		title             => "$keytitle_text",
		x_all_ticks       => 1,
		show_values       => 1,
		x_labels_vertical => 1,
		bar_spacing       => 8,
		shadow_depth      => 4,
		shadowclr         => 'dred',
		);

    unless (opendir GRAPHDIR, "$graphdir") { # create graphdir if it doesn't exist
	unless (mkdir ("$graphdir",0777)) {
	    print STDERR "Unable to create graphdir $graphdir:$!";
	    return undef;
	}
    }

    if (open(DATAFILE, $data_filename) ) {
	# Read in the data file and convert day-of-week numbers into english
	while (<DATAFILE>) {
	    chomp;
	    @line = (split(' ' , $_));
	    # push the x and y datapoints into the array for GD::Graph
	    push (@{$data[0]}, $line[0]);
	    push (@{$data[1]}, $line[1]);
	}
	close DATAFILE;
    } else {
	print STDERR "Unable to open data file $data_filename: $!\n";
	return undef;
    }
	
    # Now graph the data
    $gd = $graph->plot(\@data) ;
    if (open(IMG, ">$output_filename")) {
	binmode IMG;
	print IMG $gd->png;
	close IMG;
    } else {
	print STDERR "Unable to open output file $output_filename: $!\n";
	return undef;
    }
    
    # Now write out the meta file (contains description of the graph)
    if ( open(META , ">$output_filename.meta") ) {
	print META join("\n" , $keytitle_text, @$graph_desc);
	close META;
    } else {
	print STDERR "Unable to create graph metafile $output_filename.meta:$!";
	return undef;
    }

    return $output_filename_orig;
 
}



sub make_dt_HR_graph {
    # Makes the "Downtime by Hour of Day" graph
    #
    # Requires as arguments a filename containing data, and an output filename
    # "$data_filename" is assumed to be in $tmpdir, this behavior cannot
    # "$output_filename" is assumed to be in $graphdir, this behavior cannot
    # be overridden.
    # $graph_desc is an array reference to an array containing
    #                text which describes the graph in detail
    my ($data_filename, $output_filename, $graph_desc) = @_;
    my $output_filename_orig = $output_filename ;
    $output_filename = "$graphdir/$output_filename";
    my $cmd_filename = "$tmpdir/gplot.cmd";   #the gnuplot command file
    #default graph size is 640x480, this scales it
    my $gnuplot_size = sprintf("%.2f,%.2f" , $graph_xsize/640, $graph_ysize/480);
    my $keytitle_text = "Downtime by Hour of Day";


    unless (opendir GRAPHDIR, "$graphdir") { # create graphdir if it doesn't exist
	unless (mkdir ("$graphdir",0777)) {
	    print STDERR "Unable to create graphdir $graphdir:$!";
	    return undef;
	}
    }

    # We don't check to see if $tmpdir already exists, because if it 
    # doesn't exist, we won't have any data to plot anyway!
    if (open(GPLOTCMD, ">$cmd_filename" ) ) { #open gnuplot command file for writing
	print GPLOTCMD <<EOF ;
set term png small color
set output '$output_filename'
#set key below
#set keytitle "$keytitle_text"
set xdata time
set timefmt "%d-%m-%Y %H:%M"
set format x "%m/%d\\n%H:%M"
set ylabel "Downtime"
set tics out
set size $gnuplot_size
set noytics
plot '$data_filename' \\
        using 1:3 \\
        notitle \\
        with step
EOF
    close GPLOTCMD;
} else {
    print STDERR "Unable to create gnuplot command file $cmd_filename: $!";
    return undef;
}

    # Now write out the meta file (contains description of the graph)
    if ( open(META , ">$output_filename.meta") ) {
	print META join("\n" , $keytitle_text, @$graph_desc);
	close META;
    } else {
	print STDERR "Unable to create graph metafile $output_filename.meta:$!";
	return undef;
    }

    # Now run gnuplot with the command file
    if (not &_exec_gnuplot($cmd_filename)) {
	return undef;
    } else {
	return $output_filename_orig;
    }
}


#
# Subroutine: exec_gnuplot()
#
# Description: this executes gnuplot on the command file
#              and data sets that we have generated.
#
sub _exec_gnuplot {
    my ($command_file) = @_;
    my $status = system("$gnuplot", "$command_file");

    if (not _chk_status($status)) {
        return 0;
    }

    return 1;
}


#
# Subroutine: chk_status
#
# Description: checks the exit status of system() calls for errors
# From Chart-Graph
#
#
sub _chk_status {
    my ($status) = @_;
    if ($status) {
        my $exit_value = $? >> 8;
        my $signal_num = $? & 127;
        my $dumped_core = $? & 128;
        Carp::carp "gnuplot exit value = $exit_value\n
              gnuplot signal number = $signal_num\n
              gnuplot dumped core = $dumped_core\n" if $exit_value > 0 ;
        return 0;
    }
    return 1;
}


sub _clean_tmpdir {
    # Cleans out the tmpdir of all files and removes tmpdir
    my (@files, $file);
    if (opendir( TMPDIR, "$tmpdir")) {
	@files = readdir TMPDIR;
	closedir TMPDIR;
    } else {
	print STDERR "Could not open temp directory $tmpdir, $!\n";
	return undef;
    }
    foreach $file (@files) {
	next if ($file eq "." || $file eq "..");
	unlink "$tmpdir/$file" or print STDERR "Unable to remove temp file $tmpdir/$file: $!\n";
    }
    if (rmdir $tmpdir) {
	return 0;
    } else {
	print STDERR "Unable to remove tmpdir $tmpdir: $!\n";
	return undef;
    }
}



sub pp_sec {
    # This routine converts a number of seconds into a text string
    # suitable for (pretty) printing. The dtlog from Mon reports downtime
    # in seconds, and we want to present the user with more meaningful
    # data than "the service has been down for 13638 seconds"
    #
    # From mon.cgi
    # By Martha Greenberg <marthag@mit.edu> w/ pedantic plural 
    # modifications by Andrew.
    use integer;
    my $n = $_[0];
    my ($days, $hrs, $min, $sec) = ($n / 86400, $n % 86400 / 3600,
				    $n % 3600 / 60, $n % 60);
    my $s = $sec . " second";
    $s .= "s" if $sec != 1;   #because 0 is plural too :)
    if ($min > 0) {
	if ($min == 1) {
	    $s = $min . " minute, " . $s;
	} else {
	    $s = $min . " minutes, " . $s;
	}
    }
    if ($hrs > 0) {
	if ($hrs == 1) {
	    $s = $hrs . " hour, " . $s;
	} else {
	    $s = $hrs . " hours, " . $s;
	}
    }
    if ($days > 0) {
	if ($days == 1) {
	    $s = $days . " day, " . $s;
	} else {
	    $s = $days . " days, " . $s;
	}
    }
    return $s;
}



#
# This subroutine puts the gif to stdout if it is available
# Lifted from Cricket, http://cricket.sourceforge.net
#
sub tryPng {
    my($png) = @_;

        # we need to make certain there are no buffering problems here.
    local($|) = 1;

    if (! open(PNG, "<$png")) {
	return;
    } else {
	my($stuff, $len);
	binmode(PNG);
	while ($len = read(PNG, $stuff, 8192)) {
	    print $stuff;
	}
	close(PNG);
    }
    return 1;
}


#
# This subroutine outputs the image to the screen. It will either
# spray the real image or display a failure image if the cached image
# is not available.
# Lifted from Jeff Allen's Cricket, http://cricket.sourceforge.net
#
sub sprayPng {
    my($png) = @_;

    # image/gif is fine for png
    print $main::query->header(-type=>'image/gif');

    if (! tryPng($png)) {
      Carp::carp("Could not open $png: $!");
	if (! &tryPng("$main::failure_image")) {
	    Carp::carp("Could not send failure image: $!");
	    return undef;
	}
    }

    return 1;
}
