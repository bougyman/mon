#
# $Id: Makefile.PL,v 1.1.1.1 2004/06/18 14:25:16 trockij Exp $
#

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'      => 'Mon',
    'VERSION'   => "1.0000",
);

# version 1.0000 == 1.0.0
#           ^^^^
#           | |
#           | 3rd digit in 1.0.x
#           2nd digit in 1.x.0
