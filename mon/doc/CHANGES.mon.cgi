mon.cgi v1.52 21-May-2001
-------------------------
	+ added check for sufficient Mon::Client version
        + added optional "watch" keyword to config file that allows users
        to see only the groups they are configured to be allowed to
        see, by regex.
        + added optional keyword "show_watch_strict" that, when set to
        "yes", will enforce watch keywords strictly, and not allow
        the mon.cgi user to see any detail about any other hostgroup.
        + query_groups added summary/ack information to failed services
        + query_groups: now prints red or yellow as appropriate,
        instead of just red, for failed services.
        + added "log in" link to mon.cgi base page
        + moncgi_get_params: Fixed bug with bug with null values
        of $monhost and $monport getting through.
        + fixed moncgi_reset bug - keepstate & no-keepstate are reversed
        + moncgi_authform: passwd dialog s cleared after unsuccessful
        password entry.
        + new function: moncgi_login - allow user to log in prior to
        having to execute a privileged action.
        + new config parameter: logo_link. logo_link is a URI that
        will be linked to the logo picture, if logo is defined.
        + New function: can_show_group(groupname), to test if
        a group can be shown according to the "watch" directives.
        + The following functions were updated to reflect the new
        watch keyword access control routines :
        list_alerthist, list_dtlog, query_group, list_disabled,
        svc_details, mon_test_service, moncgi_test_all, mon_enable,
        mon_disable, mon_ack
        + fixed numerous warnings, did some code cleanup and
        improved comments.
        + Fixed another mod_perl bug in monhost/monport parsing
        + Updated moncgi-appsecret.pl, in the util directory, to
        reflect new code.

mon.cgi v1.51 22-Mar-2001
-------------------------
        + Fixed taint-checking problem with monhost and monport args
        (Mon::Client was complaining under TaintMode/-T).

mon.cgi v1.50 15-Mar-2001
-------------------------
	+ Config file parsing support was not working properly. This
	has been fixed, and a new subroutine was introduced:
	initialize_config_globals.

mon.cgi v1.49 14-Mar-2001
-------------------------
        + Add test_config option on main menu bar (new 0.38.21 command)
        + change reset to single button, with follow-up page, giving
        two choices -- reset keepstate and reset.
        + new function - moncgi_reset to allow users to choose which
        type of reset they would like to execute.
        + Patch from Ed Ravin (eravin@panix.com) to accomodate a
        site-specific custom toolbar row and site-specific menu
        commands.
        + added a optional config file that lets users specify their
        own mon.cgi parameters.
        + added TVA color scheme to the distro (from tbates@tva.gov)
        + Use HTML::Entities to escape HTML submitted as ack messages,
        avoiding cross-site scripting attacks/javascript
        and ensure proper encoding of characters entered as ack
        messages. HTML scrubbing can be skipped by setting the variable
	untaint_ack_msgs to "no".
        + remove all <pre>'s and replace with
        <font face="$fixed_font_face">. Important messages were
        often getting cut off the screen by the use of <pre>.
        + make $monhost and $monport optional CGI params as 'h' and
        'p' respectively
        + added "test service" and "test-all" to query_group page

mon.cgi v1.48 01-Dec-2000
-------------------------
	+ Have ability to do mass disabling/enabling of hosts and
	services in hostgroup.
	+ query_group: have radio button for enabled/disabled status
	(facilitates mass en/disabling)
	+ query_group: added a table on to show services for that group,
	enabled/disabled with radio button.
	+ query_group: now includes service status on this page
	+ query_group: mass dis/enabling of svcs requires a new function,
	mon_state_change
	+ svc_details: widened the table
	+ main: Command matching changed to use exact matches instead of
	regex matches (duh).
	+ main: fix bug with Revision tag in $VERSION
	+ list_disabled: Also added mass disabling
	+ mon_state_change_enable_only: new function to support
	list_disabled mass re-enabling.
	+ list_pids: cleaned up function and formatting
	+ added mon_state_change function for mass state changing
	+ added mon_list_opstatus function
	+ query_opstatus: moved legend to below main table
	+ query_opstatus: changed legend to use bgcolor instead of font color
	+ query_opstatus: ack message is now included in summary
	+ query_opstatus: increased main table width to 100%
	+ query_opstatus: can now test svcs from this page
	+ ability to do multiple tests at the same time for a single
	hostgroup
	+ moncgi_test_all: new function to test all svcs in group
	+ Ran mon.cgi through 'tidy' (http://www.w3.org/People/Raggett/tidy/)
	for improved HTML compliance. Most common pages are OK now (I think)
	except for table summary attributes. I'll get to them eventually. 
	+ added last_ok time for failed services in "Last Check" column
	+ color of UNCHECKED services is now midnight blue by default,
	unchecked services are now readable in the default color scheme!



mon.cgi v1.46 20-Aug 2000
-------------------------
	+ Fixed bug in list_dtlog that would show min and max failure time
	as "-1" seconds if no failures had been seen on that service. Also
	the table is now not printed at all instead of being a 0-row table.
	+ Made it easier for users to get themselves out of the situation
	where they enter in a valid username and an invalid password.
	+ Made the summary info MUCH easier to see when a service is in
	the failure state.
	+ alert_details is now "svc_details", a much more descriptive name,
	since it shows success as well as failure details.
	+ svc_details [nee alert_details] got a little bit of a cleanup 
	(not much).
	+ list_dtlog now has a configurable maximum number of entries per
	page that it will display, defaults at 100. Large downtime logs 
	would not render well in most browsers, and would not render at
	all with Netscape's table drawing algorithm.
	+ Added optional $monport argument, in case you don't run mon 
	on port 2583.
	+ Trap watches are now correctly handled and printed (thanks
	to Ed Ravin <eravin@panix.com> for the bug report and fix).
	+ Fixed bug in pp_sec that would cause "1 days" to be printed
	out instead of "1 day".


mon.cgi v1.45 05-Jun 2000
-------------------------
	+ query_opstatus: Built an "amber level" alert for services 
	that have failed  but never issued an alert
	+ query_opstatus: Changed "Last Checked" and "Est. Next Check" 
	times to be deltas instead of absolute times, both relative to 
	servertime and not localtime.
	+ Added ACK (and re-ack) feature
	+ query_opstatus: Added additional visual warnings if scheduler 
	is not running or cannot be contacted.
	+ Changed default app secret
	+ Button bar at top of each page is cleaner
	+ Fixed bug with scheduler falsely claiming to be stopped if you try
	to stop the scheduler and aren't authenticated, or if the server is
	not running. 
	+ Fixed bug where multiple auth failures are displayed if a user
	is not authenticated (should only notify once)
	+ Made it easier to not hit "reset server" button accidentally
	+ Made font on ONDS check times size -1
	+ Show the downtime log as an option on query_group
	+ Fixed "test immediately" stuff so it tests and then shows right
	status
	+ list_opstatus: hostgroup column no longer goes white if svc is 
	unchecked
	+ alert_details is MUCH spiffier
	+ alert_details now checks to see if a monitor for that service/group
	is currently running, and as such, the status reported is subject
	to change very soon.
	+ Added more decriptive text to service status table in alert_details
	alert_details.
	+ Changed default return screen on enable_service to be alert_details
	if that's where the user last came from.
	+ Added new 0.38-18 data types for alert_details
	+ list_dtlog: Display median in addition to mean failure time 
	to lessen effects of
	downtime outliers.
	+ Added a Refresh button on alert_details page
	+ Cleaned up the list_disabled function
	+ Got rid of backwards() function, unused relic from old mon.cgi
	+ Fixed the META REFRESH tags so that it works on all browsers (put
	it in the header where it belongs) and handles more cases 
	(alert_details, test_service)
	+ Started using servertime in places instead of time on local web
	server
	+ Visual enhancements for this version submitted by
	Brian Doherty <bdoherty@mailsvr.icon.palo-alto.med.va.gov>
	+ Fixed a bug in the "failure-free operation %" calculation if
	you had an extremely large number of failures in a time period, %
	could show up as negative.


mon.cgi v1.38 18-Feb 2000
-------------------------
	+ MAJOR speedup, only use one Mon connection per page view.
	  Pages typically load 2-3x faster.
	+ list_opstatus in Summary mode is now more brief. All "OK, 
	  Non-Disabled Services" (ONDS) for any given hostgroup are
	  now aggregated in a single line.
	  If you monitor a lot of services on each of your host 
	  groups, this will save you a lot of screen real estate.
	  Services which are disabled and/or failing are still broken
	  out individually.
	+ added FAILED flag to Status box , moved DISABLED flag, so
	  mon.cgi works with Lynx & w3m or any other text browser
	  that supports tables (only Lynx and w3m tested, looks great
	  with w3m by the way).
	+ changed default path of cookie to "/" to avoid lynx complaining
	  about "invalid cookie path".
	+ changed alert_details to use a table, include "view downtime log"
	+ on query_group page, turn box gray if host is disabled.
	+ fixed a div0 bug if you have no entries in your dtlog and ask
	  to view it
	+ changed disabled host in query_group to sort alpha even when
	  hosts are disabled.
	+ alert_details function now auto-detects failure/success, doesn't
	  need to be told which one to look for ("test service immediately"
	  would show inconsistent results from this behavior, since it
	  is impossible to know the results of a test before you run it!)


mon.cgi v.1.35
--------------
+ Downtime log viewing/querying support.
+ Disabled services/hosts/watches now appear as gray-colored boxes on
the main display screen. This makes it easier to see what is disabled.
+ Fixed loadstate and savestate bugs again. These commands now work.
+ I finally have sort of a release process, so hopefully my releases
will not be littered with formatting code that is specific to my
environment, and they will run fine out of the box when you get them.
+ Fixed a few routines to work with changing ways Mon::Client asks you
to do things.
+ Also, if you are logged in as an authenticated user (not the
"default user", if one is defined), your username will appear on each
page, so you always know who you are authenticated as.
+ Added a logout button. 
+ Added ability to do "reset keepstate" as well as "reset" from the
web interface.
+ The command bar is now 2 lines instead of one. Even on my 21"
monitor, 13 buttons was too much to have on 1 line (let alone my poor
800x600 laptop LCD!).
+ Mon::Client::test is broken in v0.7. To make it work in the way that
mon.cgi expects it to, change line 1470 in Client.pm v0.7 from:
>     if ($what !~ /^alert|startupalert|upalert$/) {
to
<     if ($what !~ /^monitor|alert|startupalert|upalert$/) {


mon.cgi 1.32.1.2 01-Feb 2000
----------------------------
+ Fixed loadstate and savestate to not be NOOPs.
+ Established a "default" user for when authentication was required but
you don't want to make users log in just to list status.
+ Along with the default user, there is also now a "switch user" feature
that offers the user the chance to re-authenticate to a user of higher
privilege if they are denied the running of a command due to a lack
of authorization.
+ Fixed HTML bugs with hardcoded colors in font and table tags scattered
throughout code (patch courtesy of Martha H Greenberg <marthag@MIT.EDU>,
thanks!). This makes it possible to run mon.cgi in colors other than the
default scheme. mon.cgi users take note however, testing color schemes is
not part of my QA process (such as it is) and so if you find something
broken, let me know and I'll fix it.


