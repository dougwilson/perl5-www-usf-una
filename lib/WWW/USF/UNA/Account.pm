package WWW::USF::UNA::Account;

use 5.008001;
use strict;
use warnings 'all';

###########################################################################
# METADATA
our $AUTHORITY = 'cpan:DOUGDUDE';
our $VERSION   = '0.001';

###########################################################################
# MOOSE
use Moose 0.89;
use MooseX::StrictConstructor 0.08;

###########################################################################
# MOOSE TYPES
use MooseX::Types::Email qw(EmailAddress);
use MooseX::Types::Moose qw(ArrayRef);
use MooseX::Types::URI qw(Uri);

###########################################################################
# ALL IMPORTS BEFORE THIS WILL BE ERASED
use namespace::clean 0.04 -except => [qw(meta)];

###########################################################################
# ATTRIBUTES
has 'default_email_address' => (
	is  => 'rw',
	isa => EmailAddress,

	documentation => q{The default e-mail address},
	trigger       => \&_set_default_email_address,
	builder       => '_build_default_email_address',
	lazy          => 1,
);
has 'email_addresses' => (
	is      => 'ro',
	isa     => ArrayRef[EmailAddress],
	traits  => ['Array'],
	handles => {
		all_email_addresses => 'elements',
	},

	documentation => q{The e-mail addresses assigned to this account},
	builder       => '_build_email_addresses',
	lazy          => 1,
);
has 'first_name' => (
	is  => 'ro',
	isa => 'Str',

	documentation => q{The first name of the person the account belongs to},
	builder       => '_build_first_name',
	lazy          => 1,
);
has 'last_name' => (
	is  => 'ro',
	isa => 'Str',

	documentation => q{The last name of the person the account belongs to},
	builder       => '_build_last_name',
	lazy          => 1,
);
has 'nams_id' => (
	is  => 'ro',
	isa => 'Int',

	documentation => q{The Network Access Management System ID of the account},
	builder       => '_build_nams_id',
	lazy          => 1,
);
has 'usf_id' => (
	is  => 'ro',
	isa => 'Str',

	documentation => q{The university ID number of the account (USF ID)},
	builder       => '_build_usf_id',
	lazy          => 1,
);

###########################################################################
# CONSTRUCTOR
sub BUILD {
	my ($self) = @_;

	if (!$self->_is_user_agent_authenticated) {
		Moose->throw_error('Provided user agent must be authenticated');
	}

	return;
}

###########################################################################
# PRIVATE ATTRIBUTES
has '_sajax' => (
	is  => 'rw',
	isa => 'Net::SAJAX',

	builder => '_build_sajax',
	lazy    => 1,
);
has '_una_url' => (
	is  => 'ro',
	isa => Uri,
	init_arg => 'una_url',

	coerce  => 1,
	default => 'https://netid.usf.edu/una/',
	trigger => sub { shift->_sajax->url(shift); }, # Update the SAJAX URL
);
has '_user_agent' => (
	is  => 'ro',
	isa => 'LWP::UserAgent',
	init_arg => 'authenticated_user_agent',

	required => 1,
	trigger  => sub { shift->_sajax->user_agent(shift); }, # Update the SAJAX UA
);

###########################################################################
# METHODS
sub set_password {
	my ($self, $new_password) = @_;

	# Attempt to set the password to the new password
	my $result = $self->_sajax->call(
		function  => 'SetPassword',
		method    => 'POST',
		arguments => [$new_password],
	);

	if ($result == 1) {
		# Success short-circuit
		return $self;
	}

	if ($result =~ m{in \s your \s password \s history}msx) {
		# Password history error here
		Moose->throw_error('Password in password history');
	}
	else {
		Moose->throw_error($result);
	}
}

###########################################################################
# PRIVATE BUILDERS
sub _build_all_names {
	my ($self, $want) = @_;

	my $name = $self->_sajax->call(
		function => 'getnamebybadge',
		method   => 'POST',
	);

	$self->{first_name} = $name->{0};
	$self->{last_name } = $name->{1};

	return $self->{$want};
}
sub _build_default_email_address {
	return $_[0]->_sajax->call(
		function => 'getdefaultemailaddress',
		method   => 'POST',
	);
}
sub _build_email_addresses {
	my ($self) = @_;

	my @addresses = values %{
		$self->_sajax->call(
			function => 'getassignedemailaddresses',
			method   => 'POST',
		)
	};

	return \@addresses;
}
sub _build_first_name {
	return $_[0]->_build_all_names('first_name');
}
sub _build_last_name {
	return $_[0]->_build_all_names('last_name');
}
sub _build_nams_id {
	my ($self) = @_;

	return $self->_sajax->call(
		function => 'GetNamsid',
		method   => 'POST',
	);
}
sub _build_sajax {
	my ($self) = @_;

	# This will return a SAJAX object with default options
	return Net::SAJAX->new(
		url => $self->_una_url->clone,
	);
}
sub _build_usf_id {
	my ($self) = @_;

	return $self->_sajax->call(
		function => 'getUsfid',
		method   => 'POST',
	);
}

###########################################################################
# PRIVATE METHODS
sub _is_user_agent_authenticated {
	my ($self) = @_;

	return !!$self->_sajax->call(
		function => 'GetAuthStatus',
		method   => 'POST',
	);
}
sub _set_default_email_address {
	my ($self, $new_default_email_address, $old_default_email_address) = @_;

	# Set the new default e-mail address (UNA states this updates SQL)
	my $set_status = $self->_sajax->call(
		arguments => [$new_default_email_address],
		function  => 'updatedefaultemailaddress',
		method    => 'POST',
	);

	if (!$set_status) {
		# Setting failed; revert default e-mail address
		$self->{default_email_address} = $old_default_email_address;
	}

	# Set the new default e-mail address (UNA states this updates LDAP)
	$set_status = $self->_sajax->call(
		arguments => [$new_default_email_address],
		function  => 'updatedefaultemailaddress_netid',
		method    => 'POST',
	);

	if (!$set_status) {
		# Setting failed; revert default e-mail address
		$self->{default_email_address} = $old_default_email_address;
	}

	return;
}

###########################################################################
# MAKE MOOSE OBJECT IMMUTABLE
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

WWW::USF::UNA::Account - Representation of an account on the UNA site

=head1 VERSION

Version 0.001

=head1 SYNOPSIS

  # The account object is typically created by WWW::USF::UNA
  my $account = ...

  # Print the name of the person
  say $account->first_name, q{ }, $account->last_name;

  # University identification number?
  say $account->usf_id;

  # Check the password of the account
  say $account->is_password($password) ? 'That is the password'
                                       : 'That is not the password'
                                       ;

  # Set a new password
  $account->set_password($password, $new_password);

=head1 DESCRIPTION

This provides a way to view and change details of an account through the UNA
system.

=head1 CONSTRUCTOR

This is fully object-oriented, and as such before any method can be used, the
constructor needs to be called to create an object to work with.

=head2 new

This will construct a new object.

=over

=item B<new(%attributes)>

C<%attributes> is a HASH where the keys are attributes (specified in the
L</ATTRIBUTES> section).

=item B<new($attributes)>

C<$attributes> is a HASHREF where the keys are attributes (specified in the
L</ATTRIBUTES> section).

=back

=head1 ATTRIBUTES

  # Set an attribute
  $object->attribute_name($new_value);

  # Get an attribute
  my $value = $object->attribute_name;

=head2 default_email_address

This is the default e-mail address for the account.

=head2 first_name

B<Read-only>

The first name of the person the account belongs to.

=head2 last_name

B<Read-only>

The last name of the person the account belongs to.

=head2 nams_id

B<Read-only>

The Network Access Management System ID of the account.

=head2 usf_id

B<Read-only>

The university ID number of the account (USF ID).

=head1 METHODS

=head2 all_email_addresses

This returns a list of all the e-mail addresses that are associated with
the account.

=head2 set_password

This method takes the new password to set as the only argument and returns
the object on success. On failure, an error with the reason for the failure
is thrown.

=head1 DEPENDENCIES

=over 4

=item * L<Moose|Moose> 0.89

=item * L<MooseX::StrictConstructor|MooseX::StrictConstructor> 0.08

=item * L<MooseX::Types::Email|MooseX::Types::Email>

=item * L<MooseX::Types::Moose|MooseX::Types::Moose>

=item * L<MooseX::Types::URI|MooseX::Types::URI>

=item * L<namespace::clean|namespace::clean> 0.04

=back

=head1 AUTHOR

Douglas Christopher Wilson, C<< <doug at somethingdoug.com> >>

=head1 BUGS AND LIMITATIONS

There are no intended limitations, and so if you find a feature in UNA that is
not implemented here, please let me know.

Please report any bugs or feature requests to
C<bug-www-usf-una at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-USF-UNA>. I
will be notified, and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

  perldoc WWW::USF::UNA::Account

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-USF-UNA>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-USF-UNA>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-USF-UNA>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-USF-UNA/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Douglas Christopher Wilson, all rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back
