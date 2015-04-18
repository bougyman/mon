######################
# 2) translate tests #
######################
BEGIN { $| = 1; print "1..4\n"; }
END {warn "not ok 1" unless $loaded;}
use Translation ('load', 'translate', 'language');

$loaded = 1;
print "ok 1\n";

$dico1 = load("./t/test.message-1");
if (defined ($dico1)) {
	print "ok 2\n";
}else{
	print "not ok 2\n";	
};

if (	$dico1->translate("No process running","Francais" ) 
		eq "Aucun processus actif") {	
	print "ok 3\n";
}else{
	print "not ok 3";
};

$dico2 = load("./t/test.message-2");
if (defined ($dico2)) {
	if ($dico2->language() eq "Deutsch") {
		print "ok 4\n";
	}else{
		print "not ok 4";
	};
}else{
	print "not ok 4";
};
