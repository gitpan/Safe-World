#############################################################################
## Name:        stdout.pm
## Purpose:     Safe::World::stdout
## Author:      Graciliano M. P.
## Modified by:
## Created:     08/09/2003
## RCS-ID:      
## Copyright:   (c) 2003 Graciliano M. P.
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Safe::World::stdout ;

use strict qw(vars);

our ($VERSION , @ISA) ;
$VERSION = '0.01' ;

######################
# CHECK_HEADSPLITTER #
######################

sub check_headsplitter {
  my $this = shift ;
  $this->{AUTOHEAD_DATA} .= shift ;
  
  my $headsplitter = $this->{HEADSPLITTER} ;

  my ($headers , $end) ;
  
  if ( ref($headsplitter) eq 'CODE' ) {
    ($headers , $end) = &$headsplitter( $Safe::World::NOW , $this->{AUTOHEAD_DATA} ) ;
  }
  elsif ( $this->{AUTOHEAD_DATA} =~ /^(.*?$headsplitter)(.*)/s ) {
    $headers = $1 ;
    $end     = $2 ;
  }
  
  delete $this->{AUTOHEAD_DATA} if $headers ne '' || $end ne '' ;
  
  return ($headers , $end) ;
}

#####################
# HEADSPLITTER_HTML #
#####################

sub headsplitter_html {
  shift ;
  my $headsplitter ;
  
  if ( $_[0] =~ /Content-Type:\s*\S+(.*?)(\015?\012\015?\012|\r?\n\r?\n)/si ) {
    if ($1 !~ /<.*?>/s) { $headsplitter = $2 ;}
  }
  
  ## Try to fix wrong headers:

  elsif ( $_[0] =~ /^(.*?)(?:\015?\012|\r?\n)(<.*?>)(?:\015?\012|\r?\n)/s ) {
    if ($1 !~ /<.*?>/s) { $headsplitter = $2 ;}
  }
  
  elsif ( $_[0] =~ /^(.*?)(<html\s*>\s*<.*?>)/si ) {
    if ($1 !~ /<.*?>/s) { $headsplitter = $2 ;}
  }
  
  elsif ( $_[0] =~ /^(.*?)(<.*?>\s*<.*?>)/s ) {
    if ($1 !~ /<.*?>/s) { $headsplitter = $2 ;}
  }
  
  elsif ( $_[0] =~ /(\015?\012\015?\012|\r?\n\r?\n)/s ) { $headsplitter = $1 ;}
  
  elsif ( $_[0] =~ /(?:\015?\012|\r?\n)([ \t]*<.*?>\s)/s ) { $headsplitter = $1 ;}
  
  my ($headers , $end) ;
  
  if ( $headsplitter ne '' && $_[0] =~ /^(.*?)\Q$headsplitter\E(.*)/s ) {
    $headers = $1 ;
    $end     = $2 ;
    
    if ($headsplitter !~ /^\s+$/s) { $end = "$headsplitter$end" ;}
    else { $headers .= $headsplitter ;}
  }

  return ($headers , $end) ;
}

###########
# HEADERS #
###########

sub headers {
  return '' if ref($_[0]->{HEADOUT}) ne 'SCALAR' ;
  if ($#_ >= 1) { ${$_[0]->{HEADOUT}} = $_[1] ;}
  my $headers = ${ $_[0]->{HEADOUT} } ;
  return $headers ;
}

###############
# STDOUT_DATA #
###############

sub stdout_data {
  my $stdout = (ref($_[0]->{STDOUT}) eq 'SCALAR') ? ${ $_[0]->{STDOUT} } : '' ;
  return $stdout ;
}

#########
# PRINT #
#########

sub print { &PRINT ;}

################
# PRINT_STDOUT #
################

sub print_stdout {
  my $this = shift ; return 1 if $_[0] eq '' ;
  
  my $stdout = $this->{STDOUT} ;
  
  if ( $this->{AUTOHEAD} ) {
    my ($headers , $end) = $this->check_headsplitter($_[0]) ;
    if ($headers ne '' || $end ne '') {
      $this->{AUTOHEAD} = undef ;
      $this->print_headout($headers) if $headers ne '' ;
      $this->print($end) if $end ne '' ;
      return 1 ;
    }
  }
  else {
    
  
    if ( !$this->{HEADER_CLOSED} && $this->{ONCLOSEHEADERS} ) {
      $this->{HEADER_CLOSED} = 1 ;
      my $sel = select( $Safe::World::NOW->{SELECT}{PREVSTDOUT} ) if $Safe::World::NOW->{SELECT}{PREVSTDOUT} ;
      my $oncloseheaders = $this->{ONCLOSEHEADERS} ;
      &$oncloseheaders( $Safe::World::NOW , $this->headers ) ;
      select($sel) if $sel ;
    }
    
    $this->{HEADER_CLOSED} = 1 ;
  
    if ( ref($stdout) eq 'SCALAR' ) { $$stdout .= $_[0] ;}
    elsif ( ref($stdout) eq 'CODE' ) {
      my $sel = select( $Safe::World::NOW->{SELECT}{PREVSTDOUT} ) if $Safe::World::NOW->{SELECT}{PREVSTDOUT} ;
      &$stdout($Safe::World::NOW , $_[0]) ;
      select($sel) if $sel ;
    }
    else { print $stdout $_[0] ;}
  }

  return 1 ;
}

#################
# PRINT_HEADOUT #
#################

sub print_headout {
  my $this = shift ; return 1 if $_[0] eq '' ;
  
  my $headout = $this->{HEADOUT} ;

  return $this->print_stdout($_[0]) if !$headout ;

  if ( ref($headout) eq 'SCALAR' ) { $$headout .= $_[0] ;}
  elsif ( ref($headout) eq 'CODE' ) {
    my $sel = select( $Safe::World::NOW->{SELECT}{PREVSTDOUT} ) if $Safe::World::NOW->{SELECT}{PREVSTDOUT} ;
    &$headout($Safe::World::NOW , $_[0]) ;
    select($sel) if $sel ;
  }
  else { print $headout $_[0] ;}

  return 1 ;
}

#################
# CLOSE_HEADERS #
#################

sub close_headers {
  my $this = shift ;
  return if !$this->{AUTOHEAD} ;
  
  if ( $this->{AUTOHEAD_DATA} ne '' ) {
    $this->{AUTOHEAD} = undef ;
    $this->print_headout( delete $this->{AUTOHEAD_DATA} ) ;
  }
  
  $this->{AUTOHEAD} = undef ;
  
  $this->{HEADER_CLOSED} = 1 ;
  
  if ( $this->{ONCLOSEHEADERS} ) {
    my $sel = select( $Safe::World::NOW->{SELECT}{PREVSTDOUT} ) if $Safe::World::NOW->{SELECT}{PREVSTDOUT} ;
    my $oncloseheaders = $this->{ONCLOSEHEADERS} ;
    &$oncloseheaders( $Safe::World::NOW , $this->headers ) ;
    select($sel) if $sel ;
  }
  
  return 1 ;
}

#########
# FLUSH #
#########

sub flush {
  my $this = shift ;

  if ( $this->{BUFFER} ne '' ) {
    $this->print_stdout( delete $this->{BUFFER} ) ;
    return 1 ;
  }
  
  return ;
}

#############
# TIEHANDLE #
#############

sub TIEHANDLE {
  my $class = shift ;
  my ($root , $stdout , $flush , $headout , $autohead , $headsplitter , $oncloseheaders) = @_ ;

  my $this = {
  ROOT => $root ,
  STDOUT => $stdout ,
  HEADOUT => $headout ,
  AUTOHEAD => $autohead ,
  HEADSPLITTER => $headsplitter ,
  ONCLOSEHEADERS => $oncloseheaders ,
  AUTO_FLUSH => $flush ,
  } ;

  bless($this , $class) ;
  return( $this ) ;
}

sub PRINT {
  my $this = shift ;
  
  if ( !$| && !$this->{AUTO_FLUSH} && !$this->{AUTOHEAD} ) { $this->{BUFFER} .= join("", (@_[0..$#_])) ;}
  else {
    $this->flush if $this->{BUFFER} ne '' ;
    $this->print_stdout( join("", (@_[0..$#_])) ) ;
  }

  return 1 ;
}

sub PRINTF { &PRINT($_[0],sprintf($_[1],@_[2..$#_])) ;}

sub READ {}
sub READLINE {}
sub GETC {}
sub WRITE {}

sub FILENO {
  #my $this = shift ;
  #my $n = $this + 1 ;  
  #return $n ;
}

sub CLOSE {
  my $this = shift ;
  $this->close_headers ;
  $this->flush ;
}

sub DESTROY {
  &CLOSE ;
}

#######
# END #
#######

1;


