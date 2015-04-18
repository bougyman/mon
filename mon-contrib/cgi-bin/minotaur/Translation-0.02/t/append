###################
# 6) append tests #
###################
BEGIN { $| = 1; print "1..1\n"; }
END {warn "not ok 1" unless $loaded;}
use Translation ('load', 'translate', 'language');

$loaded = 1;
print "ok 1\n";

# no default language in this file
$corpus = load("./t/test.message-5");
$corpus->load("./t/test.message-6");

