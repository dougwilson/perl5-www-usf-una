#!/usr/bin/env perl -T

use v5.10.1;
use strict;
use warnings 'all';

use Const::Fast qw(const);
use IO::Prompter 0.001001;
use WWW::USF::UNA;

const my $EXIT_SUCCESS => 0;

# Prompt user for NetID
my $netid = prompt(
	-prompt => 'NetID: ',
	-must   => { 'be specified' => sub { length shift } },
	-verbatim,
);
# Need to force string because of IO::Prompter design
$netid = "$netid";

# Prompt for password
my $password = prompt(
	-prompt => 'Password: ',
	-echo   => '*',
	-must   => { 'be specified' => sub { length shift } },
	-verbatim,
);
# Need to force string because of IO::Prompter design
$password = "$password";

# Get the account
my $account = WWW::USF::UNA->new->get_account(
	username => $netid,
	password => $password,
);

{
	# Remember the current password
	my $current_password = $password;

	foreach my $new_suffix (qw[! @ $ ^ * !A @B $C ^D *E @@0]) {
		# Add the suffix onto the new of the password
		my $new_password = $password . $new_suffix;

		say "Setting password to your password + $new_suffix";

		# Change the password
		$account->set_password($new_password);
	}

	say 'Setting password back to original';

	# Change the password back to the original
	$account->set_password($password);
}

exit $EXIT_SUCCESS;
