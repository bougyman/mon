##############
# 6) ? tests #
##############
BEGIN { $| = 1; print "1..3\n"; }
END {warn "not ok 1" unless $loaded;}
use Translation ('load', 'translate', 'language');

$loaded = 1;
print "ok 1\n";

# no default language in this file
$corpus = load("./t/test.message-4");

if (	$corpus->translate("Est tu sur bonhomme ?") 
		eq "Est tu sur bonhomme ?") {
	print "ok 2\n";
}else{
	print "not ok 2\n";
};

# This message does not exist in the file ./t/test.message-4
if (	$corpus->translate("Essaye de traduire ça") 
		eq "Essaye de traduire ça") {
	print "ok 3\n";
}else{
	print "not ok 3\n";
};
