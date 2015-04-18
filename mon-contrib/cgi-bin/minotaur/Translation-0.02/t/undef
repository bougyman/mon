##################
# 4) undef tests #
##################

BEGIN { $| = 1; print "1..3\n"; }
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


$dico1->language('English');
if (	$dico1->translate("Ce warning est normal aussi",'javanais')
		eq "This warning is normal too") {
	print "ok 3\n";
}else{
	warn "not ok 3\n";
};

undef($dico1);

