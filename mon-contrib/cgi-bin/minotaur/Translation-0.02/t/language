#####################
# 3) language tests #
#####################
BEGIN { $| = 1; print "1..7\n"; }
END {warn "not ok 1" unless $loaded;}
use Translation ('load', 'translate', 'language');

$loaded = 1;
print "ok 1\n";

$dico2 = load("./t/test.message-2");
if (defined ($dico2)) {
	if ($dico2->language() eq "Deutsch") {
		print "ok 2\n";
	}else{
		print "not ok 2\n";
	};
}else{
	print "not ok 2\n";
};

if ($dico2->language() ne "pipo") {
	print "ok 3\n";
}else{
	print "not ok 3\n";
};

# check language affectation
if ($dico2->language("pipo") eq "pipo") {
	print "ok 4\n";
}else{
	print "not ok 4";
};

$dico1 = load("./t/test.message-1");
if (defined ($dico1)) {
	print "ok 5\n";
}else{
	print "not ok 5\n";
}

$dico1->language('Espagnol');
if (	$dico1->translate("No process running") 
		eq "Oy tu, el processor matador disastrosita") {
	print "ok 6\n";
}else{
	print "not ok 6\n";
};

if (	$dico1->translate("This warning is normal\, do not panic !")
		eq "This warning is normal\, do not panic !") {
	print "ok 7\n";
}else{
	print "not ok 7\n";
};
