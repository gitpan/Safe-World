#############################################################################
## Name:        Compartment.pm
## Purpose:     Safe::World::Compartment
## Author:      Graciliano M. P.
## Modified by:
## Created:     04/12/2003
## RCS-ID:      
## Copyright:   (c) 2003 Graciliano M. P.
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Safe::World::Compartment ;

use strict qw(vars);

######### *** Don't declare any lexicals above this point ***

sub reval {
  my $__ExPr__ = $_[1] ;
  no strict ;

  $Safe::World::EVALX += 2 ;

  return Opcode::_safe_call_sv(
    $_[0]->{Root},
    $_[0]->{Mask},
    eval("package ". $_[0]->{Root} ."; sub {\@_=(); my \$EVALX = $Safe::World::EVALX; eval \$__ExPr__; }")
  );
}

#############################################################################

use vars qw($VERSION @ISA) ;

$VERSION = '0.01' ;

use Opcode 1.01, qw(
  opset opset_to_ops opmask_add
  empty_opset full_opset invert_opset verify_opset
  opdesc opcodes opmask define_optag opset_to_hex
);

*ops_to_opset = \&opset ;   # Temporary alias for old Penguins

my $default_share = ['*_'] ;

#############################################################################

sub new {
  my($class, $root) = @_;
  my $obj = bless({} , $class) ;

  $obj->{Root} = $root ;

  return undef if !defined($root) ;

  $obj->permit_only(':default') ;
  $obj->share_from('main', $default_share) ;
  
  Opcode::_safe_pkg_prep($root) if($Opcode::VERSION > 1.04);
  
  return $obj;
}

sub deny {
  my $obj = shift;
  $obj->{Mask} |= opset(@_);
}
sub deny_only {
  my $obj = shift;
  $obj->{Mask} = opset(@_);
}

sub permit {
  my $obj = shift;
  $obj->{Mask} &= invert_opset opset(@_);
}

sub permit_only {
  my $obj = shift;
  $obj->{Mask} = invert_opset opset(@_);
}

sub share_from {
  my $obj = shift;
  my $pkg = shift;
  my $vars = shift;

  my $root = $obj->{Root} ;

  return undef if ref($vars) ne 'ARRAY' ;
  
  no strict 'refs';
  
  return undef unless keys %{"$pkg\::"} ;

  my $arg;
  foreach $arg (@$vars) {
    next unless( $arg =~ /^[\$\@%*&]?\w[\w:]*$/ || $arg =~ /^\$\W$/ ) ;

    my ($var, $type);
    $type = $1 if ($var = $arg) =~ s/^(\W)// ;

    *{$root."::$var"} = (!$type) ?
      \&{$pkg."::$var"} : ($type eq '&') ?
        \&{$pkg."::$var"} : ($type eq '$') ?
          \${$pkg."::$var"} : ($type eq '@') ?
            \@{$pkg."::$var"} : ($type eq '%') ?
              \%{$pkg."::$var"} : ($type eq '*') ?
                *{$pkg."::$var"} : undef ;
  }
}

#######
# END #
#######

1;


