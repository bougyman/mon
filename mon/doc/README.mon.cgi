Introduction to mon.cgi
--------------------------------------------------------
This interface, along with mon itself, is available from
ftp://ftp.kernel.org/pub/software/admin/mon/

Development versions of mon.cgi can be found at
http://www.nam-shub.com/files/
--------------------------------------------------------
mon.cgi is a web-based GUI for mon. Its purpose is twofold:
 1) To provide an easy-to-read visual display of all the status items
 that mon keeps track of, and
 2) To provide an easy-to-use web administration interface to allow users to
 perform all mon administration tasks from any web browser.

This package and the documentation assumes that you have at least a
basic familiarity with mon.

-----------------------------------------------------------------
mon.cgi v.1.52
21-May-2001
by Andrew Ryan <andrewr@nam-shub.com>

This interface, along with mon itself, is available from
ftp://ftp.kernel.org/pub/software/admin/mon/

Development versions of mon.cgi can be found at
http://www.nam-shub.com/files/
-----------------------------------------------------------------
This is the latest stable version of mon.cgi, meant to be used only
with mon 0.38-21 and above, and a version of Mon::Client that is
0.11 or higher. The chief reason that you will need the new
version is for the "test config" functionality.

This release has 4 new features of note:
1) Access control. Using the 'watch' keyword in the config file, you
   can restrict access to a particular configuration on a
   per-hostgroup basis. 'watch' keywords can be regular
   expressions. Original idea and keyword name stolen from monshow :)

2) 'watch' keywords can either be implemented "softly" -- by default
   only certain hostgroups are shown, but all can be accessed --
   or "strictly" -- only the hostgroups explicitly allowed by 'watch'
   keywords can be accessed in any way. Using strict access control,
   an organization using mon to watch systems belonging to multiple
   customers to be able to segregate those different customers' 
   monitoring completely.

3) There's now a login button. The people have spoken!

4) mon.cgi now checks for the proper version of Mon::Client before
   it starts. This was a major support problem.

Plus many other bug fixes and small improvements, as usual.


This release should be considered stable until proven otherwise :)

Please see the CHANGES file for more information about this release.

Thanks to all who report bugs, submit patches, and give feedback. 
Andrew Ryan <andrewr@nam-shub.com>

Installing mon.cgi
------------------
Instructions for installing mon.cgi are located in the header of the
mon.cgi file itself. Roughly speaking, the order of events is:
 1) Install mon and get it working, set up monpasswd and auth.cf
 files and get them verifiably working if you're using mon.cgi
 authentication (hint: you should be!).
 2) Install a web server, preferably Apache, and preferably with
 mod_perl built in. Start the web server and verify that it works.
 3) Put mon.cgi in your cgi-bin directory and make sure it is
 executable by the apache user (make it 0755 or 0555).
 4) Edit your mon.cgi file to change default values to match your
 environment (e.g. contact email, your company logo, your company
 name, etc.). 
 5) If you're requiring users to log in (highly recommended), you must
 change the default app secret variable $app_secret in your copy of
 mon.cgi, and install the Crypt::TripleDES module from CPAN on the
 machine which will be running mon.cgi. 
 6) If you want to easily customize the look and feel of mon.cgi, as
 well as various other configuration options, copy the sample
 mon.cgi.cf file (in the /config directory of this distribution) into
 a location where your webserver can read it, and edit the line
 beginning '$moncgi_config_file = ""' to reflect the path to your
 config file. You can then change the look and feel of mon.cgi, as
 well as implement access controls, directly from this file.


mon.cgi Design Goals
--------------------
1) Provide 100% of the functionality of mon in a graphical user
   interface. Ideally, there will be some things that the GUI is better
   for, and inevitably, some things that the command line will always win
   out for. 

2) Maintain 100% compatibility with mon and Mon::Client. If a patch to
   mon or Mon::Client is required to get a piece of mon.cgi functionality
   working, we write it, submit it, and get it folded in to the main
   distribution before making it official in mon.cgi.

3) Expose mon to the largest number of people possible in the most
   useful way. It is the author's belief that mon is a very useful piece of
   monitoring software, and it is also my belief that the best way to
   insure the growth and support of this software is to expose it to a
   large number of people in your organization in a way that will
   cause them to reach the same conclusion. A web client is the most
   universal way to achieve this goal at the present time, as a web
   client can be run on any network that mon would be.

4) Simplicity and lightness. In other words: Compatibility on a large
   number of client browser sizes, versions, and resolutions; No
   frames! ;  Adhering to as many of the standard good usability
   conventions as possible ; Keeping mon.cgi all one file, with a very
   short setup time ; No special modules required past those needed
   to run mon, and optional additional modules kept to a minimum ;
   100% text browser compatibility ; Performance and speed ; Low
   resource utilization.

Sometimes these design goals work against one another, but hopefully
we come out ahead when tradeoffs are made.



Alternatives to mon.cgi
-----------------------
If you don't like mon.cgi but you would still like a web GUI, you have
2 alternatives. Your first alternative is Jim's monshow, which ships with
mon in the clients/ subdirectory of the mon distribution. The second
alternative is Gilles Lamiral's Minotaure, which can be found at
ftp://ftp.kernel.org/pub/software/admin/mon/contrib/. Both of these
are fully functional and may suit your needs better than mon.cgi. You
are encouraged to take a look at them both and decide which is best
for you.


SITE CUSTOMIZATION
------------------

mon.cgi has always been "customizable," in that the source was
available and you were encouraged to substitute your own parameters
(e.g., mon host, mon port, company logo, etc.). But this meant that 
with each new version, you had to go back and re-edit the source
code. Not a big deal, but still something of a pain.

As of v1.49, mon.cgi includes some features which are meant to
facilitate these changes and make site-specific customizations easier
to perform, especially as mon and mon.cgi continue to evolve.


Creating Your Own Config File
-----------------------------
Previous to v.1.49 of mon.cgi, you could customize the look of the
page, but all customizations had to be done in the source itself. This
has numerous disadvantages, so 1.49 introduces an *optional* config
file which will be read only as necessary and will allow you to
specify custom values for parameters without having to touch the
source code each time. You can still edit the source each time if you
want, but if you want to set up a config file, follow these steps:

1) Copy the config file (included with the mon.cgi distribution)
   config/mon.cgi.cf to a location of your choice. It's best to start
   with a sample config file, because the config file format is very
   simple, and it will give you a chance to see how it works and
   experiment with parameters.

2) Edit the mon.cgi source code to find the line that specifies the
   variable "$moncgi_config_file". Change the value to the filesystem
   path of your copy of your mon.cgi config file.

3) Now you can edit the config file and make changes at will. Every
   time you change the mtime of the file (e.g., by saving it in a text
   editor, or touch'ing the file), mon.cgi will re-read the config
   file and the changes will take effect. If there are errors in
   parsing the config file, they will go to STDERR, which in most
   setups will end up in your web server's error log. Look in the
   errors file if your config isn't working like you expect it to
   work.


Adding A New Row And Custom Commands To The Command Button Bar
--------------------------------------------------------------
Adding a new row to the command button bar, with corresponding custom
commands, is quite a bit more involved than the relatively simple
matter of changing a config file. If you've developed, or are
interested in developing your own custom commands, however, this
functionality might be just what you needed.

In the following example, we add a command called "ack_all" to the
button bar, and also add the routine to do the ack'ing. The actual
guts of the ack_all routine aren't included, but the goal of these
instructions is to give you enough to start off.

The first step is to create your own moncgi_custom_print_bar
function. A stub function exists in the mon.cgi code, and the below
code shows you how you would put in your own function that has one
button, labeled "Acknowledge All Failures".

Sample moncgi_custom_print_bar subroutine:
sub moncgi_custom_print_bar {
    #
    # This is a sample routine, which adds a third row to the
    # command table, with one command: "Acknowledge All Failures"
    #
    my ($face)= (@_);

    $webpage->print("<tr>\n");
    $webpage->print("\t<td colspan=7 align=center><font
    FACE=\"$face\"><a
    href=$url?${monhost_and_port_args}command=ack_all>Acknowledge
    All Failures</a></font></td>\n");
    $webpage->print("</tr>\n");
}


The next step is to tell mon.cgi that you are using your own custom
commands, by creating your own moncgi_custom_commands
subroutine. Again, there is a sample function in the mon.cgi code
which you can replace with your own.

Sample moncgi_custom_commands subroutine:
sub moncgi_custom_commands
{
       if ($command eq "ack_all")
       {
	       #
	       # Set up the page
	       #
               &setup_page("Acknowledge All Alarms");
	       #
	       # Note: you would have to write the "ack all"
	       #       command yourself!
               &moncgi_ack_all;
       }
       else
       {
	       #
	       # We didn't find anything, return
	       #
	       return 0;
       }
       return 1; # we did find something, suppress further command processing
}


The last step is to create the actual subroutines which will do the
custom work you want them to do (assuming you weren't just calling
existing commands in a different way. In our example, this means we
have to write a function that actually goes out and acks all existing
failures. We won't do this here, but hopefully this gives you an idea
of how to proceed.

sub moncgi_ack_all {
    #
    # Here is where the actual code to do the "ack all" would go
    #
}

When future releases of mon.cgi come out, you can copy and paste your
custom subroutines and be up and running with the new version in
minimal time. At least, that is what this was designed for.


Credits
-------
The current maintainer is Andrew Ryan <andrewr@nam-shub.com>. Report
all bugs to him or the mon users mailing list.
+ Originally by: Arthur K. Chan <artchan@althem.com>
+ Based on the Mon program by Jim Trocki <trockij@arctic.org>. 
  	http://www.kernel.org/software/mon/
+ Rewritten to support Mon::Client, mod_perl, taint mode,
  authentication, the strict pragma, and other visual/functional 
  enhancements by Andrew Ryan <andrewr@nam-shub.com>.
+ Downtime logging contributed by Martha H Greenberg <marthag@mit.edu>
+ Site customization extensions by Ed Ravin <eravin@panix.com>
+ The contributions of members of the mon-users mailing list have been
invaluable in many ways.

