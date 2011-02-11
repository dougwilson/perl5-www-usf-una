#!/usr/bin/env perl

use v5.10.1;
use strict;
use warnings 'all';

# MODULE IMPORTS
use Const::Fast qw(const);
use Getopt::Long 2.32 ();
use IO::Prompter 0.001001 ();
use Try::Tiny;
use WWW::USF::UNA 0.001 ();

# CONSTANTS
const my $EXIT_SUCCESS => 0;
const my $EXIT_FAILURE => 1;

# Command line variables
my $netid;
my $password;

# Parse command line
my $cmd_prase_successful = Getopt::Long::GetOptions(
	'netid=s'    => \$netid,
	'password=s' => \$password,
);

if (!$cmd_prase_successful) {
	# Command parse failed; error message already sent to STDERR
	exit $EXIT_FAILURE;
}

# Prompt for NetID and password (if needed)
($netid, $password) = _get_netid_and_password($netid, $password);

# Create a UNA object
my $una = WWW::USF::UNA->new;

# The account for the user
my $account;

AUTHENTICATE:
while (!defined $account) {
	try {
		# Get the UNA account
		$account = $una->get_account(
			username => $netid,
			password => $password,
		);
	}
	catch {
		# Pass-through error unless authentication had failed
		die $_ unless m{Authentication \s failed}msx;

		# Attempt to parse out the failure message, if any
		my ($message) = $_ =~ m{failed: \s (\S.+) \s at \s}msx;

		if (!defined $message) {
			say {*STDERR} "Password for $netid is incorrect";
		}
		else {
			# The NetID will not authenticate, so exit
			say {*STDERR} "Unable to authenticate with $netid: $message";
			exit $EXIT_FAILURE;
		}

		# NetID and/or password is wrong; prompt for new password
		(undef, $password) = _get_netid_and_password($netid);
	};
}

my $show_menu = 1;
my %main_menu = (
	'Set official e-mail address' => \&set_official_email_address,
	'Exit'                        => sub { $show_menu = 0; },
);

MENU:
while ($show_menu) {
	# The main menu loop
	my $sub_program = IO::Prompter::prompt(
		-prompt => 'Account management',
		-number,
		-menu => [(sort grep { $_ ne 'Exit' } keys %main_menu), 'Exit'], q{>},
		-verbatim,
	);

	# Run the sub program with the account
	$main_menu{$sub_program}->($account);
}

exit $EXIT_SUCCESS;

sub set_official_email_address {
	my ($account) = @_;

	say q{};
	say 'The current official e-mail address is ',
		$account->default_email_address;
	say q{};

	# Show the e-mail address menu
	my $new_email_address = IO::Prompter::prompt(
		-prompt => 'Select new official e-mail address',
		-number,
		-menu => [$account->all_email_addresses, 'Cancel'], q{>},
		-verbatim,
	);

	if ($new_email_address ne 'Cancel') {
		# Set the new official e-mail address
		$account->default_email_address($new_email_address);

		# Show a confirmation message
		say q{};
		say "The official e-mail address has been changed to $new_email_address";
		say q{};
	}
}

sub _get_netid_and_password {
	my ($netid, $password) = @_;

	# The password prompt
	my $password_prompt = 'Password: ';

	if (!defined $netid) {
		# Prompt for the NetID since it is needed
		$netid = IO::Prompter::prompt(
			-prompt => 'NetID: ',
			-must   => { 'be specified' => sub { length shift } },
			-verbatim,
		);
	}
	else {
		# Password prompt has NetID since it was not prompted for
		$password_prompt = sprintf 'Password for %s: ', $netid;
	}

	if (!defined $password) {
		# Prompt for the password since it is needed
		$password = IO::Prompter::prompt(
			-prompt => $password_prompt,
			-echo   => '*',
			-must   => { 'be specified' => sub { length shift } },
			-verbatim,
		);
	}

	return ("$netid", "$password");
}
