package WWW::USF::UNA;

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
use MooseX::Types::URI qw(Uri);

###########################################################################
# MODULE IMPORTS
use Net::SAJAX 0.102;
use URI;
use WWW::USF::UNA::Account;
use WWW::USF::WebAuth;

###########################################################################
# ALL IMPORTS BEFORE THIS WILL BE ERASED
use namespace::clean 0.04 -except => [qw(meta)];

###########################################################################
# ATTRIBUTES
has 'una_url' => (
	is  => 'rw',
	isa => Uri,

	documentation => q{This is the URL of the UNA page were the requests are made},
	coerce  => 1,
	default => 'https://netid.usf.edu/una/',
	trigger => sub { shift->_sajax->url(shift); }, # Update the SAJAX URL
);

###########################################################################
# PRIVATE ATTRIBUTES
has '_sajax' => (
	is  => 'rw',
	isa => 'Net::SAJAX',

	builder => '_build_sajax',
	lazy    => 1,
	handles => {
		user_agent => 'user_agent',
	},
);

###########################################################################
# METHODS
sub get_account {
	my ($self, %args) = @_;

	# Make a copy of the user agent to give to the new account object
	my $user_agent = $self->_sajax->user_agent->clone;

	# Make sure there is a cookie jar
	if (!defined $user_agent->cookie_jar) {
		$user_agent->cookie_jar({});
	}

	# Make a WebAuth object to log in with
	my $webauth = WWW::USF::WebAuth->new(
		netid      => $args{username},
		password   => $args{password},
		user_agent => $user_agent,
	);

	# Attempt to authenticate with UNA
	my $response = $webauth->authenticate(service => $self->una_url);

	if (!$response->is_success) {
		Moose->throw_error('Authentication failed'
			. ($response->has_notification ? ': ' . $response->notification : q{}));
	}

	# Make the user agent navigate to the destination to get any cookies.
	$user_agent->get($response->destination);

	# Create a new account
	return WWW::USF::UNA::Account->new(
		authenticated_user_agent => $user_agent,
		una_url                  => $self->una_url->clone,
	);
}

###########################################################################
# PRIVATE BUILDERS
sub _build_sajax {
	my ($self) = @_;

	# This will return a SAJAX object with default options
	return Net::SAJAX->new(
		url => URI->new($self->una_url->clone),
	);
}

###########################################################################
# MAKE MOOSE OBJECT IMMUTABLE
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

WWW::USF::UNA - Access to USF's University Network Access site

=head1 VERSION

Version 0.001

=head1 SYNOPSIS

  use WWW::USF::UNA;

  my $una = WWW::USF::UNA->new;

  # Get an account (returns WWW::USF::UNA::Account)
  my $account = $una->get_account(
      username => $username,
      password => $password,
  );

=head1 DESCRIPTION

This provides a way in which you can access the and interact with the
University Network Access (UNA) site provided by the University of South
Florida to manage user credentials.

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

=head2 una_url

This is the URL that commands are sent to in order to interact with UNA. This
can be a L<URI|URI> object or a string. This will always return a L<URI|URI>
object.

=head1 METHODS

=head2 get_account

This method will get an account object from UNA. The method takes a hash of
arguments with the following keys:

=over 4

=item password

This is the password for the account to be fetched. This is required if
L</username> is specified.

=item username

This is the user name for the account to be fetched.

=back

=head1 DEPENDENCIES

=over 4

=item * L<Moose|Moose> 0.89

=item * L<MooseX::StrictConstructor|MooseX::StrictConstructor> 0.08

=item * L<MooseX::Types::URI|MooseX::Types::URI>

=item * L<Net::SAJAX|Net::SAJAX> 0.102

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

  perldoc WWW::USF::UNA

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
