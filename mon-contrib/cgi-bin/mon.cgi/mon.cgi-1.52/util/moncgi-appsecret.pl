#!/usr/local/bin/perl -w
#
# NAME
#  moncgi-appsecret.pl
#
#
# SYNOPSIS
#  moncgi-appsecret.pl filename [min-length] [maxlength]
#
#
# DESCRIPTION
#  This script generates a new app secret (the $app_secret variable) and
#  replaces your specified mon.cgi with one with a new app secret.
#
#  Running this script and replacing your mon.cgi with the new version
#  will log all your users out, except for the default user, who doesn't
#  use a cookie. They can log right back in again though with the same
#  password.
#
#  Default app secret length is a random number between 100 and 200 
#  characters.
#
#
# EXAMPLE
#  Generate a new app secret between 200 and 300 characters for the 
#  file "/home/www/mon.cgi".
#    moncgi-appsecret.pl /home/www/mon.cgi 200 300
#
#
# AUTHOR
# Andrew Ryan <andrewr@nam-shub.com>
# $Id: moncgi-appsecret.pl,v 1.1.1.1 2005/02/18 17:52:14 trockij Exp $
#
#

use Math::TrulyRandom;
srand(truly_random_value());

my $file = $ARGV[0] || "/home/andrewr/mon/mon.cgi";
my $min_length = $ARGV[1] || 100;
my $max_length = $ARGV[2] || 200;

my (@file_new);




if ( ($max_length - $min_length < 1) || ($max_length < 0) || ($min_length < 0) ) {
    die "max_length must be greater than min_length, and must be > 0!";
}

my $length = int(($max_length - $min_length) * rand) + $min_length;

my @chars = ('a','b','c','d','e','f','g','h','i','j','k','l','m',
	     'n','o','p','q','r','s','t','u','v','w','x','y','z',
	     'A','B','C','D','E','F','G','H','I','J','K','L','M',
	     'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
	     '1','2','3','4','5','6','7','8','9','0',
	     '!','@','#','$','%','^','(',')','-','_','=','+','|',
             ,'(',')','-','_','=','+',' ',
             '~','{','}',':',';',',','<','.','>','?');

my $result = join('',&gen_rand_string($length,@chars));
#print "result is $result\n";

if (open(MONCGI,"<$file")) {
    while (<MONCGI>) {
       if (/^\s*\$app_secret/) {
           push(@file_new, "\$app_secret = \'$result\';\n");
       } else {
           push(@file_new, $_);
       }
    }
} else {
    die "Unable to open file $file for reading: $!";
}

if (open(MONCGI,">$file")) {
    print MONCGI @file_new;
} else {
    die "Unable to open file $file for writing: $!";
}


sub gen_rand_string {
    my ($length, @chars) = @_ ;
    my ($i, $index, @jumble);

    for ($i = 0 ; $i < $length ; $i++) {
	$index   = rand @chars;
	push(@jumble, $chars[$index]) ;
    }
    return @jumble;

}
