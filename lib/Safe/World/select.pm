#############################################################################
## Name:        select.pm
## Purpose:     Safe::World::select
## Author:      Graciliano M. P.
## Modified by:
## Created:     08/09/2003
## RCS-ID:      
## Copyright:   (c) 2003 Graciliano M. P.
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Safe::World::select ;

use strict qw(vars);

our ($VERSION , @ISA) ;
$VERSION = '0.01' ;

#######
# NEW #
#######

sub new {
  return undef if $_[1]->{DESTROIED} ;

  #my @call = caller ; print "SELECT NEW>> $_[1] [$Safe::World::NOW] @call\n" ;

  my $this = bless({} , __PACKAGE__) ;
  
  $this->{PREVWORLD} = $Safe::World::NOW ;
  $Safe::World::NOW = $this->{WORLD} = $_[1] ;
  
  $this->{WORLD}->{SELECT}  = {} if !$this->{WORLD}->{SELECT} ;
  $this->{WORLD}->{SHARING} = {} if !$this->{WORLD}->{SHARING} ;
  
  my $prevstdout = select( \*{"$this->{WORLD}->{ROOT}\::STDOUT"} ) ;
  $this->{WORLD}->{SELECT}{PREVSTDOUT} = $this->{PREVSTDOUT} = \*{$prevstdout} ;
  
  $this->{WORLD}->{SELECT}{PREVSTDERR} = $this->{PREVSTDERR} = *main::STDERR{IO} ;
  $this->{WORLD}->{SELECT}{PREVSUBWARN} = $this->{PREVSUBWARN} = $SIG{__WARN__} ;
  $this->{WORLD}->{SELECT}{PREVSUBDIE} = $this->{PREVSUBDIE} = $SIG{__DIE__} ;

  open (STDERR,">&$this->{WORLD}->{ROOT}::STDERR") ;
  $SIG{__WARN__} = \&print_stderr ;
  $SIG{__DIE__} = \&handle_die ;
  
  foreach my $var ( keys %{ $this->{WORLD}->{SHARING} } ) {
    $this->{WORLD}->{SHARING}{$var}{OUT} = &out_get_ref_copy($var) ;
    if ( $this->{WORLD}->{SHARING}{$var}{IN} ) {
      &out_set($var , $this->{WORLD}->{SHARING}{$var}{IN}) ;
      $this->{WORLD}->{SHARING}{$var}{IN} = undef ;
    }
  }
  
  if ( $this->{WORLD}->{TIESTDOUT}->{AUTO_FLUSH} ) { $| = 1 ;}

  $this->{WORLD}->set('$SAFEWORLD', $this->{WORLD} , 1 ) ;

  if ( $this->{WORLD}->{ONSELECT} ) {
    my $sub = $this->{WORLD}->{ONSELECT} ;
    &$sub($this->{WORLD}) ;
  }
  
  Safe::World::sync_evalx() ;

  return $this ;
}

###########
# DESTROY #
###########

sub DESTROY {
  my $this = shift ;
  
  ##print "SELECT DESTROY>> $this\n" ;  
  
  %{$this->{WORLD}->{SELECT}} = () ;
  
  $this->{WORLD}->set('$SAFEWORLD', \undef) ;
  
  if ( $this->{WORLD}->{ONUNSELECT} ) {
    my $sub = $this->{WORLD}->{ONUNSELECT} ;
    &$sub($this->{WORLD}) ;
  }

  *main::STDERR = $this->{PREVSTDERR} ;
  $SIG{__WARN__} = $this->{PREVSUBWARN} ;
  $SIG{__DIE__} = $this->{PREVSUBDIE} ;

  foreach my $var ( keys %{ $this->{WORLD}->{SHARING} } ) {
    $this->{WORLD}->{SHARING}{$var}{IN} = &out_get_ref_copy($var) ;
    if ( $this->{WORLD}->{SHARING}{$var}{OUT} ) {
      &out_set($var , $this->{WORLD}->{SHARING}{$var}{OUT}) ;
      $this->{WORLD}->{SHARING}{$var}{OUT} = undef ;
    }
  }
  
  select($this->{PREVSTDOUT}) ;

  $Safe::World::NOW = (ref($this->{PREVWORLD}) eq 'Safe::World') ? $this->{PREVWORLD} : undef ;
  
  Safe::World::sync_evalx() ;
  
  return ;
}

####################
# OUT_GET_REF_COPY #
####################

sub out_get_ref_copy {
  my ( $varfull ) = @_ ;
  
  my ($var_tp,$var) = ( $varfull =~ /([\$\@\%\*])(\S+)/ ) ;
  $var =~ s/^{'(\S+)'}$/$1/ ;
  $var =~ s/^main::// ;

  if ($var_tp eq '$') { return ${'main::'.$var} ;}
  elsif ($var_tp eq '@') { return [@{'main::'.$var}] ;}
  elsif ($var_tp eq '%') { return {%{'main::'.$var}} ;}
  elsif ($var_tp eq '*') { return \*{'main::'.$var} ;}
  else                   { ++$Safe::World::EVALX ; return eval("package main ; \\$varfull") ;}
}

###########
# OUT_SET #
###########

sub out_set {
  my ( $var , $val ) = @_ ;

  my ($var_tp,$name) = ( $var =~ /([\$\@\%\*])(\S+)/ );
  $name =~ s/^{'(\S+)'}$/$1/ ;
  $name =~ s/^main::// ;
  
  if    ($var_tp eq '$') { ${'main::'.$name} = $val ;}
  elsif ($var_tp eq '@') { @{'main::'.$name} = @{$val} ;}
  elsif ($var_tp eq '%') { %{'main::'.$name} = %{$val} ;}
  elsif ($var_tp eq '*') { *{'main::'.$name} = $val ;}
  else  { ++$Safe::World::EVALX ; eval("$var = \$val ;") ;}
}

################
# PRINT_STDERR #
################

sub print_stderr { $Safe::World::NOW->print_stderr(@_) ;  return ;}

##############
# HANDLE_DIE #
##############

sub handle_die {
  $Safe::World::NOW->{EXIT} = 1 ;
  $Safe::World::NOW->print_stderr(@_) if $_[0] !~ /#CORE::GLOBAL::exit#/ ;
  $Safe::World::NOW->close ;
  return ;
}

#######
# END #
#######

1;

