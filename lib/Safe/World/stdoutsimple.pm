#############################################################################
## Name:        stdoutsimple.pm
## Purpose:     Safe::World::stdoutsimple
## Author:      Graciliano M. P.
## Modified by:
## Created:     08/09/2003
## RCS-ID:      
## Copyright:   (c) 2003 Graciliano M. P.
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Safe::World::stdoutsimple ;

use strict qw(vars);

our ($VERSION , @ISA) ;
$VERSION = '0.02' ;

##########
# SCOPES #
##########

  use vars qw($Safe_World_NOW) ;
  
  *Safe_World_NOW = \$Safe::World::NOW ;

###########
# HEADERS #
###########

sub headers {}

#########
# PRINT #
#########

sub print { &PRINT ;}

################
# PRINT_STDOUT #
################

sub print_stdout {
  my $this = shift ;
  my $stdout = $this->{STDOUT} ;
  
  if ( ref($stdout) eq 'SCALAR' ) { $$stdout .= $_[0] ;}
  elsif ( ref($stdout) eq 'CODE' ) {
    my $sel = select( $Safe_World_NOW->{SELECT}{PREVSTDOUT} ) if $Safe_World_NOW->{SELECT}{PREVSTDOUT} ;
    &$stdout($Safe_World_NOW , $_[0]) ;
    select($sel) if $sel ;
  }
  else { print $stdout $_[0] ;}

  return 1 ;
}

#################
# PRINT_HEADOUT #
#################

sub print_headout {}

#################
# CLOSE_HEADERS #
#################

sub close_headers {
  my $this = shift ;
  $this->{HEADER_CLOSED} = 1 ;
  return 1 ;
}

#########
# FLUSH #
#########

sub flush {}

#############
# TIEHANDLE #
#############

sub TIEHANDLE {
  my $class = shift ;
  my ($root , $stdout) = @_ ;

  my $this = {
  ROOT => $root ,
  STDOUT => $stdout ,
  } ;

  bless($this , $class) ;
  return( $this ) ;
}

sub PRINT {
  my $this = shift ;
  
  if ( $this->{REDIRECT} ) {
    ${$this->{REDIRECT}} .= join("", (@_[0..$#_])) ;
  }
  else {
    $this->print_stdout( join("", (@_[0..$#_])) ) ;
  }

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

