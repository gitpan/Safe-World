#############################################################################
## Name:        stderr.pm
## Purpose:     Safe::World::stderr
## Author:      Graciliano M. P.
## Modified by:
## Created:     08/09/2003
## RCS-ID:      
## Copyright:   (c) 2003 Graciliano M. P.
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Safe::World::stderr ;

use strict qw(vars);

our ($VERSION , @ISA) ;
$VERSION = '0.02' ;

##########
# SCOPES #
##########

  use vars qw($Safe_World_NOW) ;
  
  *Safe_World_NOW = \$Safe::World::NOW ;

#########
# PRINT #
#########

sub print { &PRINT ;}

################
# PRINT_STDERR #
################

sub print_stderr {
  my $this = shift ;
  my $stderr = $this->{STDERR} ;
  
  $this->{LAST_ERROR} = $_[0] ;
  
  if ( ref($stderr) eq 'SCALAR' ) { $$stderr .= $_[0] ;}
  elsif ( ref($stderr) eq 'CODE' ) {
    my $sel = select( $Safe_World_NOW->{SELECT}{PREVSTDOUT} ) if $Safe_World_NOW->{SELECT}{PREVSTDOUT} ;
    &$stderr($Safe_World_NOW , $_[0]) ;
    select($sel) if $sel ;
  }
  else {
    my $sel = \*main::STDERR ;
    *main::STDERR = $Safe_World_NOW->{SELECT}{PREVSTDERR} if $Safe_World_NOW->{SELECT}{PREVSTDERR} ;
    print $stderr $_[0] ;
    *main::STDERR = $sel if $Safe_World_NOW->{SELECT}{PREVSTDERR} ;
  }

  return 1 ;
}

#############
# TIEHANDLE #
#############

sub TIEHANDLE {
  my $class = shift ;
  my ($root , $stderr) = @_ ;

  my $this = {
  ROOT => $root ,
  STDERR => $stderr ,
  } ;

  bless($this , $class) ;
  return( $this ) ;
}

sub PRINT {
  my $this = shift ;
  $this->print_stderr( join("", (@_[0..$#_])) ) ;
  return 1 ;
}

sub PRINTF { &PRINT($_[0],sprintf($_[1],@_[2..$#_])) ;}

sub READ {}
sub READLINE {}
sub GETC {}
sub WRITE {}

sub FILENO {}

sub CLOSE {}

sub DESTROY {}

#######
# END #
#######

1;


