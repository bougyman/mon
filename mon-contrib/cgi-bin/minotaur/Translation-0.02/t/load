#################
# 1) load tests #
#################

BEGIN { $| = 1; print "1..3\n"; }
END {warn "not ok 1" unless $loaded;}
use Translation ('load', 'translate', 'language');

$loaded = 1;
print "ok 1\n";

$dico = load("./thisFileSurelyNoExist");
unless (defined ($dico)) {
	print "ok 2\n";
}else{
	warn "not ok 2";
}

$dico1 = load("./t/test.message-1");
if (defined ($dico1)) {
	print "ok 3\n";
}else{
	warn "not ok 3";
};
