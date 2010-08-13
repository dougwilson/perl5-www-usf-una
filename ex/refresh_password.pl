#!/usr/bin/env perl -T

use 5.010;
use strict;
use warnings 'all';

use IO::Prompter 0.001001;
use Readonly 1.03;
use WWW::USF::UNA;

Readonly my $EXIT_SUCCESS => 0;

# Prompt user for NetID
my $netid = prompt(
	-prompt => 'NetID: ',
	-must   => { 'be specified' => sub { length shift } },
);

# Prompt for password
my $password = prompt(
	-prompt => 'Password: ',
	-echo   => '*',
	-must   => { 'be specified' => sub { length shift} },
);

# Get the account
my $account = WWW::USF::UNA->new->get_account($netid, $password);

{
	# Remember the current password
	my $current_password = $password;

	foreach my $new_suffix (qw[! @ $ ^ *]) {
		# Add the suffix onto the new of the password
		my $new_password = $password . $new_suffix;

		# Change the password
		$account->change_password($current_password, $new_password);
	}

	# Change the password back to the original
	$account->change_password($current_password, $password);
}

exit $EXIT_SUCCESS;
