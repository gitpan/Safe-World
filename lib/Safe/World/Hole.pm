# Safe::Hole/0.08 was copied to Safe::World::Hole to keep compatiblity,
# since Safe::Hole/0.09 breaks behavior of *INC for Safe::World.
#
# Do not use this directly. For direct use see Safe::Hole
#

package Safe::World::Hole ;

require 5.005 ;

use strict;
use vars qw($VERSION @ISA);
$VERSION = '0.08';

{ package Safe::World ;
require DynaLoader ;
@ISA = qw(DynaLoader);
bootstrap Safe::World $Safe::World::VERSION ;
}

sub new {
	my($class, $package) = @_;
	my $self = {};
	$self->{PACKAGE} = $package || 'main';
	no strict 'refs';
	$self->{STASH} = \%{$self->{PACKAGE} . '::'};
	bless $self, $class;
}

sub call {
	my($self, $coderef, @args) = @_;
	return Safe::World::_hole_call_sv($self->{STASH}, $coderef, \@args);
}

sub root {
	my $self = shift;
	$self->{PACKAGE};
}

1;

__END__

=head1 NAME

Clone of Safe::Hole to keep compatiblity, since Safe::Hole/0.09+ breaks behavior of *INC for Safe::World.

=head1 USE

Do not use this directly. See L<Safe::Hole>.

=head1 ORIGINAL VERSION

Safe::Hole/0.08

=head1 ORIGINAL AUTHOR

Sey Nakajima <nakajima@netstock.co.jp>, Brian McCauley <nobull@cpan.org>

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

