#!/usr/bin/perl -w

$defaultLanguage="en";
@languages = qw(en de nl fr es da no se pt ca it ro);
#@languages = qw(en fr);

print <<HEADER;

# This file contains the common rules


HEADER

print <<HEAD;
##################################################
# To generate the html format in a one only file #
##################################################

HEAD

foreach $language (@languages, "") {
	$languageUsed = ($language eq "") ? $defaultLanguage : $language;
	$tiret = ($language eq "") ? "" : "-";
	print <<EOF;
%$tiret$language.htm :: ../sgml/%$tiret$language.sgml
	sgml2html \\
		--language=$languageUsed \\
		--dosnames \\
		--charset=latin \\
		--papersize=a4 \\
		--split=0 \\
		\$\< 
	-tidy -m -q \$\*$tiret$language.htm
	\@echo  tidy errors are normal since it is tidy\\'s job to correct them.

EOF
}

print <<HEAD;
#######################################################
# To generate the html format with a table of content #
#######################################################

HEAD

foreach $language (@languages, "") {
	$languageUsed = ($language eq "") ? $defaultLanguage : $language;
	$tiret = ($language eq "") ? "" : "-";
	print <<EOF;
%$tiret$language.html :: ../sgml/%$tiret$language.sgml
	sgml2html \\
		--language=$languageUsed \\
		--charset=latin \\
		--papersize=a4 \\
		\$\<
	-tidy -m -q \$\*$tiret$language\*.html
	\@echo  tidy errors are normal since it is tidy\\'s job to correct them.

EOF
}

print <<HEAD;
##########################################################
# To generate ascii format lynx is better than sgmltools #
##########################################################

HEAD

foreach $language (@languages, "") {
	$languageUsed = ($language eq "") ? $defaultLanguage : $language;
	$tiret = ($language eq "") ? "" : "-";
	print <<EOF;
%$tiret$language.txt :: ../sgml/%$tiret$language.sgml
	cp \$\< tmp.sgml;\\
	sgml2html \\
		-s 0 \\
		--language=$languageUsed \\
		--charset=latin \\
		tmp;\\
	tidy -m -q tmp.html;\\
	lynx -dump -nolist tmp.html > \$\@;\\
	rm -f tmp.html tmp.sgml

EOF
}


print <<HEAD;
######################
# Device independent #
######################

HEAD

foreach $language (@languages, "") {
	$languageUsed = ($language eq "") ? $defaultLanguage : $language;
	$tiret = ($language eq "") ? "" : "-";
	print <<EOF;
%$tiret$language.dvi :: ../sgml/%$tiret$language.sgml
	sgml2latex  \\
		--language=$languageUsed \\
		--charset=latin \\
		--papersize=a4 \\
		\$\<

EOF
}


print <<HEAD;
####################
# Rich Text Format #
####################

HEAD

foreach $language (@languages, "") {
	$languageUsed = ($language eq "") ? $defaultLanguage : $language;
	$tiret = ($language eq "") ? "" : "-";
	print <<EOF;
%$tiret$language.rtf :: ../sgml/%$tiret$language.sgml
	sgml2rtf  \\
		--language=$languageUsed \\
		--charset=latin \\
		--papersize=a4 \\
		\$\<

EOF
}

print <<HEAD;
####################
# Postscript adobe #
####################

HEAD

foreach $language (@languages, "") {
	$languageUsed = ($language eq "") ? $defaultLanguage : $language;
	$tiret = ($language eq "") ? "" : "-";
	print <<EOF;
%$tiret$language.ps :: ../sgml/%$tiret$language.sgml
	sgml2latex  \\
		--language=$languageUsed \\
		--output=ps \\
		--charset=latin \\
		--papersize=a4 \\
		\$\<

EOF
}

print <<HEAD;
##############
# Tex output #
##############

HEAD

foreach $language (@languages, "") {
	$languageUsed = ($language eq "") ? $defaultLanguage : $language;
	$tiret = ($language eq "") ? "" : "-";
	print <<EOF;
%$tiret$language.tex :: ../sgml/%$tiret$language.sgml
	sgml2latex  \\
		--language=$languageUsed \\
		--output=tex \\
		--charset=latin \\
		--papersize=a4 \\
		\$\<

EOF
}

print <<HEAD;
###############
# Info output #
###############

HEAD

foreach $language (@languages, "") {
	$languageUsed = ($language eq "") ? $defaultLanguage : $language;
	$tiret = ($language eq "") ? "" : "-";
	print <<EOF;
%$tiret$language.info :: ../sgml/%$tiret$language.sgml
	sgml2info  \\
		--language=$languageUsed \\
		--charset=latin \\
		--papersize=a4 \\
		\$\<

EOF
}

print <<HEAD;
##############
# LyX outout #
##############

HEAD

foreach $language (@languages, "") {
	$languageUsed = ($language eq "") ? $defaultLanguage : $language;
	$tiret = ($language eq "") ? "" : "-";
	print <<EOF;
%$tiret$language.lyx :: ../sgml/%$tiret$language.sgml
	sgml2lyx  \\
		--language=$languageUsed \\
		--charset=latin \\
		--papersize=a4 \\
		\$\<

EOF
}


