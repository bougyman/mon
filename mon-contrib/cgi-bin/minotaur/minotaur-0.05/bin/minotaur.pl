#!/usr/bin/perl -wT
#
# all-in-one, no frills, just the information you need, web page for mon
#    Copyright (C) 1998, Gilles Lamiral and Jim Trocki.
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

use Socket;
use CGI::Carp qw(fatalsToBrowser);
use CGI qw(:standard :html3);
use English;
use Getopt::Long;
use Time::Local;

# the local libraries are in ../lib

use Translation('load', 'translate', 'language');
use Mon::Client;

# analyse the command options
#
# You see there is a debug flag. Can be useful.
# ./minotaur.cgi --debug

GetOptions("configfile=s" => \$configurationFile,
	   "debug"        => \$debug,
	   "Dconf"        => \$debugConf,
	   "Ddisa"        => \$debugDisable,
	   );

# sets some default values

&setDefaultValues();

# Read the configuration file, if any
# So, some default value are erased.
# If the file can not be open then go on.

readTheConfigurationFile($configurationFile, \%conf);

&cookieAndParamStuff();

# Get everything we need with the client API.
&getConfAndStatus();
$formatedDate = &formateDate($serverTime, $preferences{'language'});

# 
&beginTheOutput();
&tryToMakeThingsClear();
print startform;
 
# Construct the top header
@topHeader = &make_top_header();

# Construct the status table
@statusTable = &make_status_table() if ($preferences{'Status'} eq 'yes');

# Construct the preferences table
@preferenceTable = &make_preference_table();

# Print the top header
print @topHeader;

# Print the infos section
print	&make_infos_section if (param(-Name=>'infos') eq 'yes');

# Print the status table
print	@statusTable if (param(-Name=>'Status') eq 'yes');

# Print the aliases table
&printAliases() if (param(-Name=>'aliases') eq 'yes');

# Print the historic table
&historic() if (param(-Name=>'historic') eq 'yes');

# Print the preferences table
print	@preferenceTable;

# Near the end
print	endform, "\n";		
#print dump(),
end_html();

# The end
exit(0);





sub make_infos_section {
	my(@infosection);
	
	$debug and push @debug, "entering <b>make_infos_section</b>...<BR>\n";
	# the anchor, the navbar, centered
	push(@infosection,
		"<CENTER>\n",
		a({-name=>'infos'}),
		&filletOfFish('#infos'), 
		"</CENTER>\n",
	);
	
	# include the infosfile if possible
  	unless (open(CONF,$corpus->translate($conf{'infosfile'}))) {
		 warn   "Can not open ", $corpus->translate($conf{'infosfile'}), " : $!";
		 print  "Can not open ", $corpus->translate($conf{'infosfile'}), " : $!";
	}else{
		my(@infosfile);
		@infosfile = <CONF>;
		close(CONF);
		push (@infosection, @infosfile, hr);
	}
	# That's all
	$debug and  push @debug, "leaving <b>make_infos_section</b><BR>\n";
	return @infosection;
}

sub filletOfFish {
	my ($emphasis, @filletOfFish);
	($emphasis) = @_;
	push(@filletOfFish, 
		&adressFish($emphasis, '#top', $conf{'topTitle'}), " ",
		&adressFish($emphasis, '#infos', $conf{'infosTitle'}), " ",
		&adressFish($emphasis, '#status', $conf{'statusTitle'}), " ",
		&adressFish($emphasis, '#aliases', $conf{'aliasTitle'}), " ",
		&adressFish($emphasis, '#historic', $conf{'historicTitle'}), " ",
		&adressFish($emphasis, '#preferences', $conf{'preferencesTitle'}), " ",
		a(
		        {-href=>$corpus->translate($conf{'whereIsTheDoc'})},
		        $corpus->translate($conf{'documentationTitle'})
		),
	);
	return(@filletOfFish);
}

sub adressFish {
	my($emphasis, $anchor, $label) = @_;
	my($adressFish);
	
	if ($emphasis eq $anchor) {
		$adressFish = 
			"<font size=+3>".
			a({-href=>$anchor}, $corpus->translate($label)).
			"</font>"
			;
	}else{
		$adressFish = a({-href=>$anchor}, $corpus->translate($label));
	}
	return($adressFish);
}

sub make_top_header {
	"<CENTER>\n",
	a({-name=>'top'}),
	"<font size=+3>",
	"<B>", $conf{'monserver'}, "</B>", ' : ',  $formatedDate,
	"</font>",
	hr,
	"</CENTER>\n",
	;
}

sub make_preference_table {
	"<CENTER>\n",
	a(
		{-name=>'preferences'}	
	),
	&filletOfFish('#preferences'), "<BR><BR>\n",
	"<TABLE border=", $conf{'tableborder'}, " bgcolor=", $conf{'tablebgcolor'},">",
	"<TR>",
	"<TH>", $corpus->translate('Refresh'), 
	"<TH>", $corpus->translate('Language'),
	"<TH>", $corpus->translate('Tables'),
	"<TR>",
	"<TD>", 
	popup_menu(-name=>'refresh',
		-Values=>['none',
			'60',
			'120',
			'240',
			'480',
			'960',
			'1920',
			'3840',
		],
		-Labels=>{'none'=>$corpus->translate('none'),
			'60' =>'1 min',
			'120'=>'2 min',
			'240'=>'4 min',
			'480'=>'8 min',
			'960'=>'16 min',
			'1920'=>'24 min',
			'3840'=>'48 min',
		},
		-default=>$preferences{'refresh'}
	),
	"<TD>", 
	popup_menu(-name=>'language',
		-Values=>['Francais',
			'English',
		],
		-default=>$preferences{'language'}
	),
	"<TD>",
	checkbox(-Name=>'infos',
		-Value=>'yes',
		-Label=>$corpus->translate($conf{'infosTitle'})
	),
	"<BR>",
	checkbox(-Name=>'Status',
		-Value=>'yes',
		-Label=>$corpus->translate($conf{'statusTitle'})
	),
	"<BR>",
	checkbox(-Name=>'aliases',
		-Value=>'yes',
		-Label=>$corpus->translate($conf{'aliasTitle'})
	),
	"<BR>",
	checkbox(-Name=>'historic',
		-Value=>'yes',
		-Label=>$corpus->translate($conf{'historicTitle'})
	),
	"<TR>",
	"<TH colspan=3>", $corpus->translate('Login'), 
	"<TR>",
	"<TD colspan=3 align=center>", 
	"\n ",
	$corpus->translate('User'), 
	"\n",
	textfield(
		-name=>'user',
		-default=>$preferences{'user'},
		-size=>9,
		-maxlength=>25
	),
	"\n",
	$corpus->translate('Password'), 
	"\n",
	password_field(
		-name=>'password',
		-default=>$preferences{'password'},
		-size=>9,
		-maxlength=>25
	),
	" <BR>\n",
	checkbox(-Name=>'memorizeUserPassword',
		-Value=>'yes',
		-Label=>$corpus->translate(" Memorize User and Password")
	),
	
	"</TABLE>\n",
	"<P>",
	@submitCancel, 
	"</CENTER>\n",
	"<HR>";
}

sub make_status_table {
# Now the status table
my (@statusTable);

push @statusTable,
	"<CENTER>\n",
		a({-name=>'status'}),
		&filletOfFish('#status'), "<BR>\n",
		@submitCancel,
	#"<table border=3 align=center>\n",
	"<TABLE border=", $conf{'tableborder'}, " bgcolor=", $conf{'tablebgcolor'}," align=center>",
 
	# The first line
	"<th>", $corpus->translate('Host') ,
	"<th>", $corpus->translate('Group') ,
	"<th>", $corpus->translate('Members') ,
	"<th>", $corpus->translate('Service') ,
	"<th>", $corpus->translate('Last at') ,
	"<th>", $corpus->translate('Next in') ,
	"<th>", $corpus->translate('Status');

push @statusTable,
	"<TR>",
	"<TD rowspan=$totalNumberOfServices>",
	CGI::scrolling_list(-name=>"Enable_Host_CompleteListe",
		 -Values=>[sort { 
			$hostList{$a} cmp $hostList{$b} 
			or
			$a cmp $b
		 }(keys(%hostList))],
		 -Default=>[@hostListDisable],
		 -Multiple=>'true',
		 -Size=>min(max($preferences{'scrollHostLength'}, $totalNumberOfServices),
			    scalar(keys(%hostList))),
	),	
  ;

#print dump();
foreach $group (sort { 
		# first a failure
		$Watch{$b}{'order'}{'failed'} <=> $Watch{$a}{'order'}{'failed'}
		or
		# a disabled watch
		$Watch{$b}{'function'} cmp $Watch{$a}{'function'}
		or
		# disabled services
		$Watch{$b}{'order'}{'disabled'} <=> $Watch{$a}{'order'}{'disabled'}
		or 
		# Alphabetic
		$a cmp $b
	} 
	keys(%Watch)  ) {
		$numberOfServices = scalar(keys(%{$Watch{$group}{'service'}}));
		if ($Watch{$group}{'function'}){
			$groupColor = "bgcolor=".$conf{'blue'};
		}elsif($Watch{$group}{'order'}{'failed'}){
			$groupColor = "bgcolor=".$conf{'red'};
		}else{
			$groupColor = "";
		};

		# "-w" flag obliges.  An other way (cleaner).
		@groupValues = (
			defined(@{$Watch{$group}{'disable'}})
				? sort {$a cmp $b} (@ { $Watch{$group}{'disable'} })
				: (),
			defined(@ { $Watch{$group}{'enable'} }) 
				? sort {$a cmp $b}(@ { $Watch{$group}{'enable'} })
				: () 
		);
		
		@groupValuesDisable = (
				@{$Watch{$group}{'disable'}}
				? sort {$a cmp $b} (@ { $Watch{$group}{'disable'} })
				: ()
		);
		
		#print "groupValues:[@groupValues]", scalar(@groupValues),"<BR>\n";
		#print "groupValuesDisable:[@groupValuesDisable]", scalar(@groupValuesDisable) ,"<BR>\n";
	
	push @statusTable,
	"<TD rowspan=$numberOfServices align=center $groupColor>", $group,
	"<TD rowspan=$numberOfServices  $groupColor>",
	CGI::scrolling_list(-Name=>"Enable_Host_In_Group_$group",
		-Values=>[@groupValues],
		-default=>[@groupValuesDisable],
		-Multiple=>'true',
		-Size=>min($preferences{'scrollGroupLength'}, scalar(@groupValues))
		);
	
	foreach $service ( sort {
		$Watch{$group}{'service'}{$b}{'order'}{'failed'}
		<=>
		  $Watch{$group}{'service'}{$a}{'order'}{'failed'}
		or
		  $Watch{$group}{'service'}{$b}{'order'}{'disabled'}
		<=>
		  $Watch{$group}{'service'}{$a}{'order'}{'disabled'}
		or
		  $a cmp $b
		}keys(%{$Watch{$group}{'service'}})) {
    
    my(	$statusService,
    	$timeStringLast,
    	$timeStringNext,
	$ServiceColor
	);
    
    $statusService = $Watch{$group}{'service'}{$service}{'status'};
    
    if($Watch{$group}{'function'} eq 'disabled'){
      $ServiceColor = "bgcolor=".$conf{'blue'};
    }elsif($Watch{$group}{'service'}{$service}{'function'} eq 'disabled'){
      $ServiceColor = "bgcolor=".$conf{'blue'};
    }elsif($Watch{$group}{'service'}{$service}{'order'}{'failed'}){
      $ServiceColor =   "bgcolor=".$conf{'red'};
    }elsif($Watch{$group}{'service'}{$service}{'opstatus'} == 7){
	#$ServiceColor = ($groupColor) ? "bgcolor=".$conf{'yellow'} :  "";
	$ServiceColor = "bgcolor=".$conf{'yellow'};
    }else{
      $ServiceColor = ($groupColor) ? "bgcolor=".$conf{'green'} :  "";
    };
	
	$timeLast = $Watch{$group}{'service'}{$service}{'last'};
	($ls,$lm,$lh) = (localtime ($timeLast))[0,1,2];
	($ns,$nm,$nh,$nyear) = (gmtime ($Watch{$group}{'service'}{$service}{'next'}))[0,1,2,7];
	$nyear = ($nyear == 0) ? "" : $nyear . "d";
	
	unless ($timeLast) {
		$timeStringLast = $corpus->translate("none");
	}else{
		$timeStringLast = sprintf("%02d:%02d:%02d", $lh, $lm, $ls);
	}
	$timeStringNext = sprintf("%s %02d:%02d:%02d", $nyear, $nh, $nm, $ns);
	$checkboxTest = join("::", "Test", $group, $service);
	
	my $checkboxEnable = join("::", "Enable_Service", $group, $service);
	
	push @statusTable,
		"<TD $ServiceColor align=center>", 
		$service,
		br,
		checkbox(-Name=>$checkboxEnable,
			-Value=>'yes',
			-Label=>" ".$corpus->translate('HS')
		),
		"<TD $ServiceColor align=center>$timeStringLast",
		"<TD $ServiceColor align=center>$timeStringNext",
		br,
		checkbox(-Name=>$checkboxTest,
			-Value=>'yes',
			-Label=>" ".$corpus->translate('Now')
		),
		"<TD $ServiceColor>", $statusService,
		"<TR>";
	}
};

push @statusTable,
  "<th>", 
  $corpus->translate("Length "),
  textfield(-name=>'scrollHostLength',
            -default=>$preferences{'scrollHostLength'},
            -override=>1,
            -size=>length($preferences{'scrollHostLength'})+1,
),

  "<th>", $corpus->translate('Group'),
  "<th>",
  $corpus->translate("Length "),
  textfield(-name=>'scrollGroupLength',
            -default=>$preferences{'scrollGroupLength'},
            -override=>1,
            -size=>length($preferences{'scrollGroupLength'})+1,
	),
  
  "<th>", $corpus->translate('Service'),
  "<th>", $corpus->translate('(H:M:S)'),
  "<th>", $corpus->translate('(H:M:S)'),
  "<th>", $corpus->translate('Status'),
	"\n</table>",
	"</CENTER>\n",
	hr;
	
	return (@statusTable);
}
#
# die with some HTML output
#
sub html_die {
	my (@str) = @_;
	print 
		h1('A problem occured'),
		"The cgi script works.", "<BR>\n",
		"But it failed with the following diagnostics:", "<BR>\n",
		@str,
		end_html();
    	exit(1);
}
  
sub max {
	my $max = shift(@_);
	if (defined($max)){
		foreach $foo (@_) {
			$max = $foo if $max < $foo;
		}
	return $max;
	}else{
		return undef;
	}
}

###############################################################################
sub min {
	my $min = shift(@_);
	if (defined($min)){
		foreach $foo (@_) {
		$min = $foo if $min > $foo;
 		}
	return $min;
	}else{
		return undef;
	}
}
###############################################################################
sub readTheConfigurationFile {
	local($configurationFile, *paramConf) = @_;

	$debugConf and push @debug, "entering <b>readTheConfigurationFile</b>...<BR>\n<PRE>\n";

  	unless (open(CONF,$configurationFile)) {
		 warn  "Can not open $configurationFile : $!";
  		return "Can not open $configurationFile : $!";
	}
	while (<CONF>) {
		next if /^#/;
		next if /^\s*$/;
		if (/^[ \t]*(\w+)[ \t]+:(.*)$/){
			$paramConf{$1}=$2;
			$debugConf and push @debug, sprintf("--> %-22s: [%s]\n", $1, $2);
		} else {
			warn "Syntax error in the configuration File : $configurationFile",
			" line $INPUT_LINE_NUMBER\n",
			"You have to use only alphanumeric terms\n",
			"A correct syntax example :\n",
			" ResultLengthMax   :500  \n";
		}
	}
	close(CONF);
	$debugConf and  push @debug, "</PRE>\nleaving <b>readTheConfigurationFile</b><BR>\n";
	return("");
}

###############################################################################
sub diff {
	local (*listA, *listB) = @_ ;
	
	return(1) unless (scalar(@{[ %listA ]}) == scalar(@{[ %listB ]}));		
	foreach $key (%listA) {
		return(1) unless (
			not(defined($listB{$key}))
				or ($listA{$key} eq $listB{$key})
		);
	};
	return(0);
};

# List alert history --------------------------------------------------
sub historic {
	my($count) = (0);
	
	if (defined(param('historicFrom')) and (param('historicFrom') =~ /(\d\d)(?:\s+|\/)(\d\d)(?:\s+|\/)(\d\d\d\d)/)) {;
		($fromHistoricDay, $fromHistoricMonth, $fromHistoricYear) = ($1,$2,$3);
	
	}else{
		# 
		($fromHistoricDay, $fromHistoricMonth, $fromHistoricYear) = (localtime(time - $conf{'historicFromDate'}))[3,4,5];
		$fromHistoricDay   = sprintf("%02d", $fromHistoricDay);
		$fromHistoricMonth = sprintf("%02d", $fromHistoricMonth + 1);
		$fromHistoricYear  += 1900;
	}
	$fromHistoricEpoch = timelocal(0,0,0,$fromHistoricDay, $fromHistoricMonth - 1, $fromHistoricYear -1900);
	
	if (defined(param('historicTo')) and (param('historicTo') =~ /(\d\d)(?:\s+|\/)(\d\d)(?:\s+|\/)(\d\d\d\d)/)) {;
		($toHistoricDay, $toHistoricMonth, $toHistoricYear) = ($1,$2,$3);
	
	}else{
		($toHistoricDay, $toHistoricMonth, $toHistoricYear) = (localtime)[3,4,5];
		$toHistoricDay =  sprintf("%02d", $toHistoricDay);
		$toHistoricMonth = sprintf("%02d", $toHistoricMonth + 1);
		$toHistoricYear  += 1900;
	}
	$toHistoricEpoch = timelocal(59,59,23,$toHistoricDay, $toHistoricMonth -1, $toHistoricYear -1900);
	
	foreach (@alertHistoric){
		my($service, $group, @line);
				
		$_ = join(" ", ++$count, $_ );
		
	};
	foreach $alert (@alertHistoricRef){
	       $everyServices{$alert->{"service"}} = 1;
	       $everyGroup{$alert->{"watch"}} = 1;
	       #print "[",$alert->{"watch"},"]","[",$alert->{"service"},"]","<BR>\n";
	      
	};
	unless (param(-name=>"historicServices")) {
		param(-name=>"historicServices", -Value=>[sort (keys(%everyServices))]);
	}
	
	foreach $service (param(-name=>"historicServices")) {
		$historicServicesWanted{$service}=1;
	}
	
	unless (param(-name=>"historicGroups")) {
		param(-name=>"historicGroups", -Value=>[sort (keys(%everyGroup))]);
	}
	
	foreach $group (param(-name=>"historicGroups")) {
		$historicGroupsWanted{$group}=1;
	}
	
	
	foreach $alert (@alertHistoricRef){
		
		if (	($historicServicesWanted{$alert->{"service"}}) 
			and 
			($historicGroupsWanted{$alert->{"watch"}})
			and
			($alert->{"time"} >= $fromHistoricEpoch)
			and
			($alert->{"time"} <= $toHistoricEpoch)
				
		){
			push @alertHistoricFiltered, 
				join(" ",
					$alert->{"number"},
					$alert->{"type"},
					$alert->{"watch"},
					$alert->{"service"},
					$alert->{"time"},
					$alert->{"alert"},
					"(",$alert->{"args"},")",
					$alert->{"summary"},
				)
			;
		}	
	};
	
	print a({-name=>'historic'}),
		"<CENTER>\n",
		&filletOfFish('#historic'), "<BR>\n",
		@submitCancel, 
		"<TABLE border=", $conf{'tableborder'}, " bgcolor=", $conf{'tablebgcolor'}," align=center>",
		"<tr>",
                "<th>", $corpus->translate('Service'),
                "<th>", $corpus->translate('Group'),
                "<th>", $corpus->translate('No'),
                "<th>", $corpus->translate('Date'),
		"<small>", '&#160;' x 5,
		$corpus->translate("jj/mm/aaaa"),
		"</small>",
               "<th>", $corpus->translate('Status'),
		
		"<tr>",
                "<TD>",
		CGI::scrolling_list(-name=>"historicServices",
			-Values=>[sort (keys(%everyServices))],
			-Multiple=>'true',
			-Size=>min(5,
		    		scalar(keys(%everyServices))),
			),
                "<TD>",
		CGI::scrolling_list(-name=>"historicGroups",
			-Values=>[sort (keys(%everyGroup))],
			-Multiple=>'true',
			-Size=>min(5,
		    		scalar(keys(%everyGroup))),
			),
                "<TD>",
		textfield(-name=>'historicLength',
			-default=>$preferences{'historicLength'},
			-override=>1,
			-size=>length($preferences{'historicLength'})+1,
		),

                "<TD>",
		"<TABLE border=0>",		
		"<TR>",
		"<TD>",
		$corpus->translate('From'),
		"</TD>",
		"<TD>",
		textfield(-name=>'historicFrom',
			-default=>join ("/",$fromHistoricDay, $fromHistoricMonth, $fromHistoricYear),
			-override=>1,
			-size=>'10'
		),
		"</TD>",
		"<TR>",
		"<TD>",
		$corpus->translate('To'),
		"</TD>",
		"<TD>",
		textfield(-name=>'historicTo',
			-default=>join ("/",$toHistoricDay, $toHistoricMonth, $toHistoricYear),
			-override=>1,
			-size=>'10'
		),
		"<TR>",
		"<TD bgcolor=", $conf{'brokenWhite'}, " >",
		$corpus->translate('Filter'),
		"</TD>",
		"<TD bgcolor=", $conf{'brokenWhite'}, " align=center>",
		popup_menu(-name=>'historicFilter',
			-Values=>['0',
				'3600',
				'10800',
				'21600',
				'43200',
				'86400',
				'172800',
				'345600',
				'604800'
			],
			-Labels=>{'0'=>$corpus->translate('none'),
				'3600' =>' 1 h',
				'10800'=>' 3 h',
				'21600'=>' 6 h',
				'43200'=>'12 h',
				'86400'=>' 1 j',
				'172800'=>' 2 j',
				'345600'=>' 4 j',
				'604800'=>' 7 j',
			},
			-default=>$preferences{'historicFilter'}
		),
		"</TABLE>\n",
                "<TD>",
                "&nbsp;",
		"</TD>",
                "\n";
	
	
	@alertHistoric = reverse(@alertHistoricFiltered);
	unless ($preferences{'historicLength'}){
		@alertHistoricTroncated = splice(@alertHistoric, 0);
	}else{
		@alertHistoricTroncated = splice(@alertHistoric, 0, $preferences{'historicLength'});
	}
	# I do not understand why splice(reverse(@alertHistoric)) does not work.
	foreach $ligne  (@alertHistoricTroncated) {
		my($groupName,
		$serviceName, 
		$timeNumeric, 
		$alertFile, 
		$argList, 
		$hostList,
		$timeString,
		$sec,
		$min,
		$hour,
		$day,
		$month,
		$year);
	
		chomp($ligne);
		$ligne =~ /\A(\d+)\s+(alert|upalert|startupalert)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\S+)\s+\((.*?)\)\s+(.*)\Z/;
		($number, $alertType, $groupName, $serviceName, $timeNumeric, $alertFile, $argList, $hostList) = 
			($1, $2, $3, $4, $5, $6, $7, $8);
		@hostList = split(/\s+/,$hostList);
      
		$nowItIs = $serverTime;
		$diffTime = $nowItIs - $timeNumeric;
		if (defined($preferences{'historicFilter'})) {
	      		unless ($diffTime > $preferences{'historicFilter'}){
				$colorBack = " bgcolor=".$conf{'brokenWhite'};
			}else{
				$colorBack = " ";
			}
		}else{
				$colorBack = " ";
		}
		($min,$hour,$day,$month,$year) = (localtime ($timeNumeric))[1,2,3,4,5];
		
		$timeString = sprintf ("%02d/%02d/%04d <b>%02d:%02d</b>", 
			$day,$month +1,$year +1900,$hour,$min);

		print("\n<tr>");
		if ($alertType eq 'upalert') {
			print("<td $colorBack><font color=", $conf{'darkgreen'}, ">$serviceName</font></td>\n");
		}elsif ($alertType eq 'startupalert') {
			print("<td $colorBack><font color=", $conf{'darkgreen'}, ">$serviceName</font></td>\n");
		}elsif ($alertType eq 'alert') {
			print("<td $colorBack><font color=", $conf{'red'}, ">$serviceName</font></td>\n");
		}else {
			print("<td $colorBack><font color=black>$serviceName</font></td>\n");
		}
      
		print 
			"<td $colorBack>$groupName</a>",
			"<td $colorBack align=right>$number</a>",
			"<td nowrap $colorBack align=center>$timeString";
		
		if ($alertType eq 'upalert') {
			print("<td align=center $colorBack>OK");
		}elsif ($alertType eq 'startupalert') {
			print("<td align=center $colorBack>reloading config");
		}elsif ($alertType eq 'alert') {
			print("<td align=center $colorBack>");
			foreach $hostElement (@hostList){
				print("$hostElement <BR>");
			}
		}else{
			print("<td align=center $colorBack>");
			foreach $hostElement (@hostList){
				print("$hostElement <BR>");
			}
		}
	}
	print 
		"</table>\n",
		"<p>",
		"</CENTER>",
		hr;    
}


sub printAliases {
	my(@allAlias, $numberOfAliasServices);
	@aliasWanted = ();
	$numberOfAliasServices = 0;
	
	#print dump();
	if (defined(param('aliasSelection'))) {
		if (param('aliasSelection') eq 'all'){
			@aliasWanted = ();
			CGI::delete('aliasWanted');
			# but but but...
			$allAliasWanted = 1;
		}elsif(param('aliasSelection') eq 'none'){
			@aliasWanted = ();
			CGI::delete('aliasWanted');
		}elsif(param('aliasSelection') eq 'selection'){
			@aliasWanted = param(-Name => 'aliasWanted');
		}
	}else{
		#@aliasWanted = param(-Name => 'aliasWanted');
		@aliasWanted = split(" ", $preferences{'aliasWanted'});
	}
	
	# reset the selection for the next choice because
	# the alias will be selected as wanted.
	CGI::delete('aliasSelection');
	
	foreach (@aliasWanted){
		$aliasWanted{$_} = 1;
	}
	foreach $alias (keys(%aliasesHash)) {
		if($allAliasWanted){
			$aliasWanted{$alias} = 1;
			push @aliasWanted, $alias;
		}
		
		$aliasesHash{$alias}{'failure'} = 0;
		
		push @debugAliases,  "<H2>Alias [$alias]</H2>";
		
		foreach $service (keys(%{$aliasesHash{$alias}{'service'}})){
		
			++$numberOfAliasServices if ($aliasWanted{$alias});
			push @debugAliases, "--service $service <BR>";
			
			foreach $groupWatched (keys(%{$aliasesHash{$alias}{'service'}{$service}{'watch'}})) {
				push @debugAliases, "groupWatched $groupWatched <BR>";
				if (&groupWatchedExists()){
					foreach $serviceWatched (keys(%{$aliasesHash{$alias}{'service'}{$service}{'watch'}{$groupWatched}{'service'}})) {
						push @debugAliases, "serviceWatched:[$serviceWatched]{",
							@{ $aliasesHash{$alias}{'service'}{$service}{'watch'}{$groupWatched}{'service'}{$serviceWatched}{'items'} },
							"}<BR>\n";
						if (&serviceWatchedExists()){
							&checkTheStatus	;
						}
					}
				}
			}
			if(defined($aliasesHash{$alias}{'service'}{$service}{'url'})){
				push @debugAliases,  "url:", $aliasesHash{$alias}{'service'}{$service}{'url'},"<BR>\n";
			}
			
		}
		push @debugAliases,  "<BR>\n";
	}
	
	#print @debugAliases;
	
	
	param(-Name => 'aliasWanted', -Values => [@aliasWanted]);
	push @aliasOutput,
		"<CENTER>\n",
		a({-name=>'aliases'}),
		&filletOfFish('#aliases'), "<BR>\n",
		@submitCancel, 
		"<TABLE border=", $conf{'tableborder'}, " bgcolor=", $conf{'tablebgcolor'}," align=center>",
		"<tr>",
                "<th>",
		radio_group(
			-name=>'aliasSelection',
			-Values=>['all','none','selection'],
			-Default=>'selection',
			-Labels=>{
				'none'=>" ".$corpus->translate('none'),
				'all'=>" ".$corpus->translate('all'),
				'selection'=>" ".$corpus->translate('selection')
			}
		),
                 "<th>", $corpus->translate($conf{'aliasTitle'}),
                "<th>", $corpus->translate('Description'),
                "<th>", $corpus->translate('Service'),
                "<th>", $corpus->translate('Status'),
                "\n",
		"<tr>",
 		"<td rowspan=$numberOfAliasServices valign=top >",
		CGI::scrolling_list(-name=>"aliasWanted",
			-Values=>[sort (keys(%aliasesHash))],
			-Multiple=>'true',
			-Size=>min(max($preferences{'scrollAliasLength'}, $numberOfAliasServices), 
		    	scalar(keys(%aliasesHash))),
			);
		unless (@aliasWanted) {
			push @aliasOutput,  "<TR>\n";
		}else{
			foreach $alias (sort {
						$aliasesHash{$b}{'failure'} <=> $aliasesHash{$a}{'failure'}
						or
						$a cmp $b
					} @aliasWanted) {
				$numberOfServices = scalar(keys(%{$aliasesHash{$alias}{'service'}}));
				if($aliasesHash{$alias}{'failure'}){
					$aliasColor = "bgcolor=".$conf{'red'};
				}else{
					$aliasColor = "";
				}
				push @aliasOutput, 
    				"<TD $aliasColor rowspan=$numberOfServices align=center>", $alias,
				"<TD $aliasColor rowspan=$numberOfServices>", $aliasesHash{$alias}{'declaration'};
				foreach $service (sort {
							$a cmp $b
						} keys(%{$aliasesHash{$alias}{'service'}})){
					my(@status, $serviceColor);
					
					if (defined(@{ $aliasesHash{$alias}{'service'}{$service}{'failed'} })) {
						@status = @{ $aliasesHash{$alias}{'service'}{$service}{'failed'} };
						$serviceColor = "bgcolor=".$conf{'red'};
					}else{
						@status = ("OK");
						$serviceColor = "";
					}
					
					if(defined($aliasesHash{$alias}{'service'}{$service}{'url'})){
						$url = $aliasesHash{$alias}{'service'}{$service}{'url'};
						push @aliasOutput,
						"<TD $serviceColor>", "<A href=\"$url\">$service</A>";
					}else{
						push @aliasOutput,
						"<TD $serviceColor>", $service;
					}
					push @aliasOutput,
					"<TD $serviceColor>", @status,
					"<TR>\n";
				}
			}
		}
	
	push @aliasOutput, 
		"<th>", $corpus->translate('List'),
		"<th>", $corpus->translate($conf{'aliasTitle'}),
                "<th>", $corpus->translate('Description'),
                "<th>", $corpus->translate('Service'),
                "<th>", $corpus->translate('Status'),
		"</table>\n",
		"</CENTER>",
		hr;
		
	print "@aliasOutput";
}


sub checkTheStatus {
	my(@items);
	@items = @{ $aliasesHash{$alias}{'service'}{$service}{'watch'}{$groupWatched}{'service'}{$serviceWatched}{'items'} };

	unless(@items){
		my($item, $status, $opstatus);
		$status = $Watch{$groupWatched}{'service'}{$serviceWatched}{'status'};
		$opstatus = $Watch{$groupWatched}{'service'}{$serviceWatched}{'opstatus'};
		
		unless ($opstatus){
			push @debugAliases, "STATUS:no item{$status}<BR>";
			if ($status =~ /\A(.+)\Z/) {
				$item = $1;
				push @debugAliases,  "[$service]:Failed [$item] on [$groupWatched] service [$serviceWatched]<BR>\n";
				push @{ $aliasesHash{$alias}{'service'}{$service}{'failed'} }, $item;
				$aliasesHash{$alias}{'failure'}++;
			}else{
				push @debugAliases,  "[$service]:Failed [$item] on [$groupWatched] service [$serviceWatched]<BR>\n";
				push @{ $aliasesHash{$alias}{'service'}{$service}{'failed'} }, "??";
				$aliasesHash{$alias}{'failure'}++;
			}
		}else{
			push @debugAliases,  "No problem for [$serviceWatched] in group [$groupWatched]<BR>\n";
		}
	}else{
		
		foreach $item (@items) {
			my($status, $allHostsInGroup);
			
			$allHostsInGroup = join " ", @ { $Watch{$groupWatched}{'hosts'} };
			push @debugAliases, "QQQ:[", @ { $Watch{$groupWatched}{'hosts'}} , "]<BR>\n";
			unless ($allHostsInGroup =~ /\A$item|\s+$item|$item\Z/){
				push @debugAliases,  "Item [$item] does not belong to group [$groupWatched]<BR>\n";
				push @{ $aliasesHash{$alias}{'service'}{$service}{'failed'} }, "Item $item does not belong to group $groupWatched<BR>\n";
				$aliasesHash{$alias}{'failure'}++;
				next;
			}
			$status = $Watch{$groupWatched}{'service'}{$serviceWatched}{'status'};
			if ($status){
				push @debugAliases, "STATUS:{$status}<BR>";
				if ($status =~ /\Afailed.*\s+(?:\[\d+:$item\])|(?:$item(\s|\Z)|(?:$item:.+(\s|\Z)))/) {
					push @debugAliases,  "[$service]:Failed [$item] on [$groupWatched] service [$serviceWatched]<BR>\n";
					push @{ $aliasesHash{$alias}{'service'}{$service}{'failed'} }, $item;
					$aliasesHash{$alias}{'failure'}++;
				}
			}else{
				push @debugAliases,  "No status for [$serviceWatched] in group [$groupWatched]<BR>\n";
				push @{ $aliasesHash{$alias}{'service'}{$service}{'failed'} }, "?!";
				$aliasesHash{$alias}{'failure'}++;
			}
		}
	}	
}

sub groupWatchedExists {
	unless($allGroups =~ /\A$groupWatched|\s+$groupWatched|$groupWatched\Z/){
		push @debugAliases,  "The group $groupWatched does not exist<BR>\n";
		push @{ $aliasesHash{$alias}{'service'}{$service}{'failed'} }, "The group $groupWatched does not exist<BR>\n";
		$aliasesHash{$alias}{'failure'}++;
		return(0);
	}
	return(1);
}

sub serviceWatchedExists {
	unless($servicesInOneString{$groupWatched} =~ /\A$serviceWatched|\s+$serviceWatched|$serviceWatched\Z/){
		push @debugAliases,  "The service $serviceWatched does not exist in group $groupWatched<BR>\n";
		push @{ $aliasesHash{$alias}{'service'}{$service}{'failed'} }, "The service $serviceWatched does not exist in group $groupWatched<BR>\n";
		$aliasesHash{$alias}{'failure'}++;
		return(0);
	}
	return(1);
}

sub formateDate {

	my($time, $format) = @_;

	$stringday = {
		'0'  => 'sunday',
		'1'  => 'monday',
		'2'  => 'tuesday',
		'3'  => 'wednesday',
		'4'  => 'thursday',
		'5'  => 'friday',
		'6'  => 'saturday'
	};

	$stringmonth = {
		'0'  => 'january',
		'1'  => 'february',
		'2'  => 'march',
		'3'  => 'april',
		'4'  => 'may',
		'5'  => 'june',
		'6'  => 'july',
		'7'  => 'august',
		'8'  => 'september',
		'9'  => 'october',
		'10'  => 'november',
		'11'  => 'december'
	};

	($sec,$min,$hour,$mday,$month,$year,$wday) = (localtime($time))[0,1,2,3,4,5,6,7];

	$dateFormated =  join( "",
		$corpus->translate($stringday->{$wday}),
		", ",
		$mday,
		" ",
		$corpus->translate($stringmonth->{$month}),
		" ",
		$year + 1900,
		",",
		" ",
		sprintf("%02d:%02d:%02d",$hour,$min,$sec)
	);
	return $dateFormated;
}

sub getConfAndStatus {
	&connectMonServer();
	&loginMonServer() if ($user);
	&getServerTime();
	&testServicesNow();	
	&getAndsetDisabled();
	&getOperationStatus();
	&getGroupsMembers();
	&getAlertHistoric();
	%aliasesHash = &getAliases() if ($preferences{'aliases'} eq 'yes');
	&disconnectMonServer();
}

sub loginMonServer {
	$cl->login();
	if (defined($cl->error)) {
		print b($corpus->translate("ERROR")), " : ", $cl->error, "\n";
	};
	
}

sub connectMonServer {
	$cl = Mon::Client->new;
	$cl->host ($conf{'monserver'});
	$cl->port ($conf{'monport'});
	$cl->prot ($conf{'monserverVersion'});
	$cl->username($user);
	$cl->password($password);
	
	if (!defined ($cl->connect)) {
		html_die ("could not connect to mon server ",
		    "<B>",$conf{monserver},"</B>",
		    " on port ",
		    "<B>",$conf{monport},"</B>",
		    " ", $cl->error, "<BR>\n",
		    "Suggestion: Is mon running ?",
		    "<BR>\n");
	};
}

sub getServerTime {
	$serverTime = $cl->servertime();
}

sub disconnectMonServer {
	$cl->disconnect;
}

sub getAndsetDisabled {
	my(%d, %hostToDisable, %hostAlreadyDisabled);
	
	%d = $cl->list_disabled;
	
	# Two cases : post with status table or not
	if ($definedParam 
		and (param(-Name=>'Status') eq 'yes') 
		and ($cookie{'Status'} eq 'yes')
	) {
		print "<PRE>";
		# What the user want to disable ?
		# Just looking.
		# Make a hash to simplify the search.
		foreach $host (param('Enable_Host_CompleteListe')) {
			$hostToDisable{$host} = 1;
			$debugDisable and print "want disabling $host\n";
		}
		# Which are disabled ?
		# Enable the hosts that the user wants to be
		foreach $group (keys %{$d{"hosts"}}) {
			foreach $host (keys %{$d{"hosts"}{$group}}) {
				$debugDisable and print "host $group/$host disabled\n";
				if (not defined($hostToDisable{$host})) {
					# User want to enable this host
					$debugDisable and print "host $group/$host have to be enabled\n";
					$cl->enable_host($host);
				}else{
					# User want to leave this host disabled
					$hostAlreadyDisabled{$host} = 1;
					$debugDisable and print "host $group/$host already disabled\n";
				}
			}
		}
		# Now we can disable if necessary
		foreach $host (param('Enable_Host_CompleteListe')) {
			if (defined($hostAlreadyDisabled{$host})) {
				$debugDisable and print "disabling $host already done\n";
			}else{
				$debugDisable and print "disabling $host\n";
				$cl->disable_host($host);
			}
		}
	}else{
		# Nothing to disable or enable
		foreach $group (keys %{$d{"hosts"}}) {
			foreach $host (keys %{$d{"hosts"}{$group}}) {
				$debugDisable and print "host $group/$host disabled\n";
			}
		}
	}
	
	if ($definedParam 
		and (param(-Name=>'Status') eq 'yes') 
		and ($cookie{'Status'} eq 'yes')
	) {
		foreach my $param (@allParamreters) {
			my($group, $service);
		
			if ($param =~ /\AEnable_Service::(.+)::(.+)\Z/) {
				($group,$service) = ($1,$2);
				CGI::delete($param);
				$debugDisable and print "Wanna change <b>$service</b> service on group <b>$group</b>\n";
				if ($d{"services"}{$group}{$service}) {
					$cl->enable_service($group, $service);
				}else{
					$cl->disable_service($group, $service);
				}
				if (defined($cl->error)) {
					$debugDisable and print b($corpus->translate("ERROR")), " : ", $cl->error, "\n";
				}
			}
		}
	%d = $cl->list_disabled;
	}
	
	foreach $watch (keys %{$d{"services"}}) {
		foreach $service (keys %{$d{"services"}{$watch}}) {
			$debugDisable and print "service $watch/$service disabled\n";
			$service{$watch}{$service} = 1;
			$Watch{$watch}{'service'}{$service}{'function'}="disabled";
		}
	}

	foreach $watch (keys %{$d{"watches"}}) {
		$debugDisable and print "watch $_ disabled\n";
		$watch{$watch} = 1;
		$Watch{$watch}{'function'} = "disabled";
	}
	print "</PRE>";

}

sub testServicesNow {
	foreach $param (@allParamreters) {
		my($group, $service);
		
		if ($param =~ /\ATest::(.+)::(.+)\Z/) {
			($group,$service)=($1,$2);
			CGI::delete($param);
			print "Asking server to test service <b>$service</b> on group <b>$group</b><BR>\n";
			#print "$param $group $service<BR>\n";
			$cl->test('monitor', $group, $service);
			if (defined($cl->error)) {
				print b($corpus->translate("ERROR")), " : ", $cl->error, "<BR>\n";
			}
		}
	}
}


sub getOperationStatus {
	my(%s);
	$debug and print "Entering function <b>getOperationStatus</b><BR>\n";
	%s = $cl->list_opstatus;
	foreach $group (keys %s) {
		$debug and print "Group [<b>$group</b>]<BR>\n";
		# You can't imagine the time it got to understand CGI.pm
		# and finally write the next line.
		CGI::delete("Enable_Host_In_Group_$group");
		
		foreach $service (keys %{$s{$group}}) {
			my($last_failure, $last_success, $last_test, $opstatus, $status);
			# $debug and print "--> Service [<b>$service</b>]<BR>\n";
			foreach $var (keys %{$s{$group}{$service}}) {
	    			# $debug and print "----> $var=$s{$group}{$service}{$var}<BR>\n";
				
			}
			
			$last_failure = $s{$group}{$service}{'last_failure'};
			$last_success = $s{$group}{$service}{'last_success'};
			$last_test    = max($last_failure,$last_success);
			$opstatus     = $s{$group}{$service}{'opstatus'};
			$timer        = $s{$group}{$service}{'timer'};
			$last_summary = $s{$group}{$service}{'last_summary'};
			
			CASE: {
				($opstatus == 0) and do {$status =  $last_summary, last CASE};
				($opstatus == 1) and do {$status =  $corpus->translate("succeeded"), last CASE};
				($opstatus == 7) and do {$status =  $corpus->translate("untested"), last CASE};
				$status =  $corpus->translate("unknown");
			}
	
			$Watch{$group}{'function'} = (defined($Watch{$group}{'function'})) ? $Watch{$group}{'function'} : "";
	
			$Watch{$group}{'service'}{$service}{'function'} = 
				defined($Watch{$group}{'service'}{$service}{'function'}) 
				? $Watch{$group}{'service'}{$service}{'function'} 
				: "";
	
			$Watch{$group}{'order'}{'failed'} = 
				(defined($Watch{$group}{'order'}{'failed'})) 
				? $Watch{$group}{'order'}{'failed'} 
				: 0;
	
			$Watch{$group}{'order'}{'disabled'} = 
				(defined($Watch{$group}{'order'}{'disabled'})) 
				? $Watch{$group}{'order'}{'disabled'} 
				: 0;

			$Watch{$group}{'service'}{$service}{'order'}{'failed'}   = 0;
			$Watch{$group}{'service'}{$service}{'order'}{'disabled'} = 0;
    
			$Watch{$group}{'service'}{$service}{'last'}=$last_test;
			$Watch{$group}{'service'}{$service}{'next'}=$timer;
			$Watch{$group}{'service'}{$service}{'status'}=$status;
			$Watch{$group}{'service'}{$service}{'opstatus'}=$opstatus;
			$Watch{$group}{'service'}{$service}{'summary'}=$last_summary;
    
    
			if (defined($watch{$group}) and $watch{$group} == 1) {
				push (@dis_watch, join(" ", ($group, $service, $last_test, $timer, $opstatus)));
				next;
			} elsif (defined ($service{$group}{$service}) and $service{$group}{$service} == 1) {
				push (@dis_service,join(" ", ($group, $service, $last_test, $timer, $opstatus)));
				next;
			} elsif ($opstatus == 0) {
				push (@failures, join(" ", ($group, $service, $last_test, $timer, $opstatus)));
				next;
			} elsif ($opstatus == 7) {
				push (@untested, join(" ", ($group, $service, $last_test, $timer, $opstatus)));
				next;
			} else {
				push (@op, join(" ", ($group, $service, $last_test, $timer, $opstatus)));
				next;
			}
		}
	}
	$debug and print "Leaving function <b>getOperationStatus</b><BR>\n";

}



sub getGroupsMembers {
	$debug and print "Entering function <b>getGroupsMembers</b><BR>\n";
	foreach $i (@failures, @dis_watch, @dis_service, @untested, @op) {
		my(@hostsOfGroup, @hosts);
		#$debug and print "--> [$i]<BR>\n";
		($group, $service) = (split (/\s+/, $i))[0,1];
		next if (defined($groups{$group}));
		@hostsOfGroup = $cl->list_group($group);

		#$debug and print "--> list_group(<b>$group</b>)=<b>@hostsOfGroup</b><BR>\n";
		
		$Watch{$group}{'hosts'}=[@hostsOfGroup];
  
  		# Remove the star of disabled hosts
		foreach $host (@hostsOfGroup) {
			if ($host =~ /\A\*(.*)/) {
				push ( @{$Watch{$group}{'disable'}}, $1);   
			}else{
				push ( @{$Watch{$group}{'enable'}}, $host);
			}
		};
		$hosts = join(" ", @hostsOfGroup);
		$groups{$group} = $hosts;
		
	}
	$debug and print "Leaving function <b>getGroupsMembers</b><BR>\n";
}

sub setDefaultValues {

$configurationFile = defined($configurationFile) 
	? $configurationFile : "./minotaur-cgi.conf";

# %conf is general configuration parameters
# %preferences is user parameters saved in the cookie
# See the file ./minotaur-cgi.conf to see what they mean.

%conf = (
	messagesFile	   => './messages.conf',
	monserver	   => 'Localhost',
	monserverVersion   => '0.38',
	monport 	   => '2583',
	refresh 	   => 'none',
	tablebgcolor 	   => '#FFFFFF',
	tableborder 	   => '1',
	scrollGroupLength  => '4',
	scrollHostLength   => '10',
	'language'         => 'English',
	blue		   => '#8888ff',
	green		   => '#88e088',
	blue		   => '#8888ff',
	red		   => '#ff8888',
	yellow  	   => '#ffff44',
	darkgreen  	   => '#00c000',
	pagebgColor	   => 'lightblue',
	brokenWhite        => '#ffffee',
	historicLength     => '20',
	historicFilter	   => '3600',
	historicFromDate   => '7948800',
	infos	 	   => 'yes',
	'historic' 	   => 'no',
	aliases 	   => 'no',
	cookieExpiration   => '+1y',
	scrollAliasLength  => '10',
	user               => '',
	password           => '',
	memorizeUserPassword  => 'no',
	topTitle           => 'Top',
	infosTitle	   => 'Infos',
	aliasTitle         => 'CrossView',
	statusTitle	   => 'Status',
	historicTitle      => 'Historic',
	preferencesTitle   => 'Preferences',
	documentationTitle => 'Documentation',
	whereIsTheDoc	   => '../doc',
	infosfile	   => '../infos.html',
	aliasSelection	   => 'all',
	);
}

sub getAlertHistoric {
	my($count);
	if (defined($preferences{'historic'}) and $preferences{'historic'} eq 'yes') {
		@alertHistoricRef = $cl->list_alerthist();
		$count = 0;
		foreach $alert (@alertHistoricRef) {
			$alert->{"number"} = ++$count;
             }
	}
}

sub getAliases {
	my(%alias);
	%alias = $cl->list_aliases();
	
	#This is just debug code
	
	#foreach $alias (keys(%alias)){
		#print "[$alias]:",$alias{$alias}{'declaration'}, "<BR>\n";
		#foreach $service (keys(%{$alias{$alias}{'service'}})){
			#print "service:[$service]<BR>\n";
			#foreach $groupWatched (keys(%{$alias{$alias}{'service'}{$service}{'watch'}})) {
				#print "groupWatched:[$groupWatched]<BR>\n";
				#foreach $serviceWatched (keys(%{$alias{$alias}{'service'}{$service}{'watch'}{$groupWatched}{'service'}})) {
					#print "serviceWatched:[$serviceWatched]{",
						#@{ $alias{$alias}{'service'}{$service}{'watch'}{$groupWatched}{'service'}{$serviceWatched}{'items'} },
						#"}<BR>\n";
				#}
			#}
			#if(defined($alias{$alias}{'service'}{$service}{'url'})){
				#print "url:", $alias{$alias}{'service'}{$service}{'url'},"<BR>\n";
			#}
		#}
	
	
	return(%alias);
}

sub cookieAndParamStuff {
# recover the "preferences" cookie.
# See, you have one cookie per mon/port server.

$cookieName = "mon-" . $conf{'monserver'} . $conf{'monport'} ;

%cookie = cookie($cookieName);
%preferences = %cookie;

# Simple checkboxes need special traitment
@checkboxes = ('historic', 'aliases', 'Status', 'infos', 'memorizeUserPassword');


# Default values
# with this, you can retrieve the cgi client like
# the first time you came. Use the url:
# http://www.foo/.../minotaur.cgi?default
# or click on the default button
if (param(-Name=>'Defaults')) {
	CGI::delete_all();
}

($zorglub) = param ;

if (defined($zorglub)) {
	push (@debug,  "param: defined [$zorglub]<BR>");
	$definedParam = 1;
}else{
	push (@debug,  "param: not defined<BR>");
	$definedParam = 0;
}

if (param and ($zorglub ne 'keywords')){
	push (@debug, "param is true <BR>\n",
		join(" ",  param), "<BR>\n",
		" scalar:", scalar(param), "<BR>\n",
	);
	foreach (@checkboxes) {
	       param(-Name=>$_, -Value=>'no') unless param(-Name=>$_);
	       $preferences{$_} = param(-Name=>$_);
	}
	
	#foreach ('aliasWanted', 'Enable_Host_CompleteListe') {
	foreach ('aliasWanted', 'Enable_Host_CompleteListe') {
		$preferences{$_} = join (" ", param(-Name=>$_)) if param(-Name=>$_);
	}
	
	

}else{
	foreach (@checkboxes) {
		param(-Name=>$_, -Value => 
	       		(defined($preferences{$_}) ? $preferences{$_} : $conf{$_})
		);
	}
	
	push (@debug, "aliasWanted : ",
		$preferences{'aliasWanted'}, "<BR>\n",
	);
	#push (@debug, "Enable_Host_CompleteListe : ",
	#	$preferences{'Enable_Host_CompleteListe'}, "<BR>\n",
	#);
	#foreach ('aliasWanted', 'Enable_Host_CompleteListe') {
	foreach ('aliasWanted', ) {
		param(-Name=>$_, -Value => [ split(" ", $preferences{$_}) ] );
	}
}


# update the preferences with the user choice, or the cookie, or the conf
foreach ('refresh',
         'language',
	 'scrollGroupLength',
	 'scrollHostLength',
	 'historicLength',
	 'cookieExpiration',
	 'scrollAliasLength',
	 'historicFilter',
	 'user',
	 'password',
	 'memorizeUserPassword',
	 'aliasSelection',
	) {
	$preferences{$_} = 
	(defined(param($_)))
		? param($_)
		: (defined($preferences{$_}))
			? $preferences{$_}
			: $conf{$_};
}

@allParamreters = param;

$user     = $preferences{'user'};
$password = $preferences{'password'};

# Delete the user and password if needed
if (param('memorizeUserPassword') ne 'yes'){
	$preferences{'user'} = '';
	$preferences{'password'} = '';
}

# I hate systematic cookies so:
# Test if we need to refresh the cookie
$diff = diff(\%cookie, \%preferences);

$debug and  push @debug,
       "diff   : $diff<BR>\n<PRE>";
foreach $key (keys(%preferences)) {
       $debug and  push @debug,
	      sprintf("--> cookie: %-22s: [%s]\n", $key, $cookie{$key}),
	      sprintf("--> prefer: %-22s: [%s]\n\n", $key, $preferences{$key});
}
$debug and  push @debug, "diff terminated</PRE>";

# Flush mode.

$| = 1;

$the_cookie = cookie(-Name=>$cookieName,
		     -Value=>\%preferences,
		     -Expires=>$preferences{'cookieExpiration'}
		    );

$corpus = load($conf{'messagesFile'});
$corpus->language($preferences{'language'});

# The submit and cancel buttons are in several places
push @submitCancel, 
	submit(-Name=>'Go',
		-Value=>$corpus->translate("Submit")
	),
	" ",
	reset(-Value=>$corpus->translate("Cancel")
	),
	" ",
	submit(-Name=>'Defaults',
		-Value=>$corpus->translate("Defaults")
	)
;


# do we have to send the refresh time ?
if ($preferences{'refresh'} eq "none"){
	#$expirePage="now";
	$expirePage="+60s";
	# do we need to refresh the cookie
	if ($diff){
		print header(
		#-Expires=>$expirePage,
		-Cookie=>$the_cookie);
	}else{
		print header(
			#-Expires=>$expirePage
		);
	}
  }else{
  	$expirePage = "+".$preferences{'refresh'}."s";
	#$expirePage="now";
	if ($diff){
		print
		  header(
		  	#-Expires=>$expirePage,
			 -Refresh=>$preferences{'refresh'},
			 -Cookie=>$the_cookie);
	}else{
	       print
	         header(
		 	#-Expires=>$expirePage,
	        	-Refresh=>$preferences{'refresh'});
	}
  }

$debug and print @debug;

}

sub beginTheOutput {
	print start_html(
		-Title=>$corpus->translate('Minotaur from ')
			. $conf{'monserver'}
			. ":"
			. $conf{'monport'}
			. $corpus->translate(' on ')
			. $formatedDate,
		-Author=>'lamiral@mail.dotcom.fr',
		-Meta=>{
			'keywords'=>$corpus->translate('monitoring, Minotaur, MON, HTTP, FTP, NNTP, LDAP, POP3, SMTP, IMAP4'),
			'copyright'=>"Gnu Public Licence, copyleft September 1998 Jim Trocki, Gilles Lamiral"
		},
		-BGCOLOR=>$conf{'pagebgColor'},
	),
	"\n";
}

sub tryToMakeThingsClear {
	# Try to make all things clear...

	# There are :
	# @group 
	# %Watch                  # this W have to be downcased
	# $allGroups
	# %servicesInOneString
	

	# First  : What are the groups ?
	@group = keys(%Watch);
	$allGroups = join(" ", @group);
	$debug and print scalar(@group), " groups : ", "@group", "<BR>\n";

	# Second : What are the services for each group
	foreach $group (@group) {
		@services = keys(%{$Watch{$group}{'service'}});
		$servicesInOneString{$group} = join " ", @services;
		
		$debug and print 
		"Group $group : ", 
		scalar(@services) , 
		" service(s): ", 
		"@services<BR>\n";
	
	
	# Third : What are the priorities to show ?
	# a) Failures
	# b) Disable
	# c) Other
	
	# The rules : 
	# A) If a failure-disable is on a service the entire group is upped
	# B) 
		foreach $service (@services) {
			if(defined($Watch{$group}{'service'}{$service}{'function'}) and
			$Watch{$group}{'service'}{$service}{'function'} eq 'disabled'){
				$Watch{$group}{'service'}{$service}{'order'}{'disabled'}+=1;
				$Watch{$group}{'order'}{'disabled'}+=1;
			}elsif ($Watch{$group}{'service'}{$service}{'opstatus'} == 0){
				$Watch{$group}{'service'}{$service}{'order'}{'failed'}+=1;
				unless($Watch{$group}{'function'} eq 'disabled'){
					$Watch{$group}{'order'}{'failed'}+=1;
				}
			}
			$totalNumberOfServices++;
		}
	  #  print 
	  #    "$group Order : ", 
	  #    $Watch{$group}{'order'}{'failed'},
	  #    ":", 
	  #    $Watch{$group}{'order'}{'disabled'}, 
	  #    "<BR>\n";
	}
	
	# Now we make a list of disable hosts
	#print dump();
	
	foreach $groupList (values(%groups)) {
		$debug and print "groupList: [$groupList]<BR>\n";
		foreach $host (split(/\s+/, $groupList)){
			$host =~ /\A\*?(.*)\Z/;
			$hostWithoutStar = $1;
			next if (defined ( $hostList{$hostWithoutStar}));
		# Here the star "*" is eliminated.
			if ($host =~ /\A\*(.*)\Z/) {
				$hostList{$hostWithoutStar}='';
				push (@hostListDisable, $hostWithoutStar);
	 		}else{
				$hostList{$host}='enable';
			}
		}
	}
	
	($debug) and do {
	       foreach $group (keys(%Watch)){
		       print "<h2>$group</h2>";
		       foreach $host (@{ $Watch{$group}{'hosts'}}) {
			       print "[$host]<BR>\n";
		       }
	       }
	};
}
