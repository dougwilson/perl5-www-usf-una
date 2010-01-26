#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok('WWW::USF::UNA');
}

diag("Perl $], $^X");
diag("WWW::USF::UNA " . WWW::USF::UNA->VERSION);
