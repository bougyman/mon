#######################
# 5) load other tests #
#######################

BEGIN { $| = 1; print "1..5\n"; }
END {warn "not ok 1" unless $loaded;}
use Translation ('load', 'translate', 'language');

$loaded = 1;
print "ok 1\n";

$dico4 = load("./t/test.message-1");
if (defined ($dico4)) {
	print "ok 2\n";
}else{
	print "not ok 2\n";
};

$status = $dico4->load("./t/test.message-3");
if (defined ($status)) {
	print "ok 3\n";
}else{
	print "not ok 3\n";
};

if (	$dico4->translate("No process running","Francais" ) 
		eq "Aucun processus actif") {
	print "ok 4\n";
}else{
	print "not ok 4\n";
};

if (	$dico4->translate("No process running man","Francais" ) 
		eq "Est tu sur bonhomme ?") {
	print "ok 5\n";
}else{
	print "not ok 5";
};
