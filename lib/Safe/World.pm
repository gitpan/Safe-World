#############################################################################
## Name:        World.pm
## Purpose:     Safe::World
## Author:      Graciliano M. P.
## Modified by:
## Created:     08/09/2003
## RCS-ID:      
## Copyright:   (c) 2003 Graciliano M. P.
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Safe::World ;

use Safe::World::Compartment ;
use Safe::World::ScanPack ;

use Safe::World::select ;
use Safe::World::stdout ;
use Safe::World::stdoutsimple ;
use Safe::World::stderr ;

use strict qw(vars);

our ($VERSION , @ISA) ;
$VERSION = '0.03' ;

########
# VARS #
########

  use vars qw($NOW $EVALX) ;

  my ($COMPARTMENT_X , $SAFE_WORLD_SELECTED_STATIC) ;
  
  my $COMPARTMENT_NAME = 'SAFEWORLD' ;
  
  my @DENY_OPS = qw(chroot syscall exit dump fork lock threadsv) ;
  
  ########
  # KEYS #
  ########
  ## STDOUT          ## stdout ref (GLOB|SCALAR|CODE)
  ## STDIN           ## stdin ref (GLOB)
  ## STDERR          ## stderr ref (GLOB|SCALAR|CODE)
  ## HEADOUT         ## the output of the headers (GLOB|SCALAR|CODE)
  ## TIESTDOUT       ## The tiestdout object
  ## TIESTDERR       ## The tiestderr object
  
  ##                 ## Auto flush (BOOL)
  ## AUTOHEAD        ## If STDOUT start printing the headers, until HEADSPLITTER (like CGI). Def: 1 if HEADOUT
  ## HEADSPLITTER    ## The splitter (REGEXP|CODE) between headers and output. Def: \r\n\r\n (like CGI)
  ## ONCLOSEHEADERS  ## Function to call on close headers block.
  
  ## ENV             ## Internal %ENV
  
  ## ROOT            ## root name
  ## SAFE            ## the Safe object
  ## SHAREDPACK      ## what package to share in this WORLD when it's linked with other>> \@
      
  ## INSIDE          ## bool >> if is running code inside the compartment

  ## LINKED_PACKS{}  ## shared packages
  ## SHARING{}       ## shared vars
  ## WORLD_SHARED    ## if this world is shared and the name of the holder.
  ## SELECT{}        ## Safe::World::select keys.

  ## NO_CLEAN        ## If will not clean the pack.

  ## DESTROIED       ## if DESTROY() was alredy called.
  ## CLEANNED        ## if the pack was cleanned.
  ## EXIT            ## exit or die has been called. No more evals!
  
  ##########
  # EVENTS #
  ##########
  ## on_closeheaders  ## When the headers are closeds.
  ## on_exit          ## When exit() is called.
  ## on_select        ## When the WORLD is selected to evaluate codes inside it.
  ## on_unselect      ## When the WORLD is unselected, just after evaluate the codes.
  
  ###############
  # COMPARTMENT #
  ###############
  ## SAFEWORLDx::WORLDSHARE::  ## used to link and unlink a WORLD with other WORLD.

  
  my ($NULL , @NULL , %NULL) ;
  local(*NULL) ;

########
# EXIT #
########

sub EXIT {
  if ( $NOW && ref($NOW) eq 'Safe::World' ) {
    my $exit ;
    if ( $NOW->{ONEXIT} ) {
      my $sel = select( $Safe::World::NOW->{SELECT}{PREVSTDOUT} ) if $Safe::World::NOW->{SELECT}{PREVSTDOUT} ;
        my $sub = $NOW->{ONEXIT} ;
        $exit = &$sub($NOW , @_) ;
      select($sel) if $sel ;
    }
    die('#CORE::GLOBAL::exit#') unless $exit eq '0' ;
  }
  else { CORE::exit(@_) ;}
}

#########
# BEGIN #
#########

sub BEGIN {
  *CORE::GLOBAL::exit = \&EXIT ;
}

#########
# ALIAS #
#########

sub root { $_[0]->{ROOT} ;}
sub safe { $_[0]->{SAFE} ;}

sub tiestdout { $_[0]->{TIESTDOUT} ;}
sub tiestderr { $_[0]->{TIESTDERR} ;}

sub headers {
  my $this = shift ;
  return $this->{TIESTDOUT}->headers(@_) ;
}

sub stdout_data { return $_[0]->{TIESTDOUT}->stdout_data ; }

#######
# NEW # root , stdout , stdin , stderr , env , headout , headsplitter , autohead , &on_closeheaders , &on_exit , &on_select , &on_unselect , sharepack , flush , no_clean
#######

sub new {
  my $class = shift ;
  my $this = bless({} , $class) ;
  my ( %args ) = @_ ;
  
  $this->{STDOUT}  = $args{stdout} || \*main::STDOUT ;
  $this->{STDIN}   = $args{stdin} || \*main::STDIN ;
  $this->{STDERR}  = $args{stderr} || \*main::STDERR ;
  $this->{HEADOUT} = $args{headout} ;
  
  if ( !ref($this->{STDOUT}) )                      { $this->{STDOUT}  = \*{$this->{STDOUT}} ;}
  if ( !ref($this->{STDIN}) )                       { $this->{STDIN}   = \*{$this->{STDIN}} ;}
  if ( !ref($this->{STDERR}) )                      { $this->{STDERR}  = \*{$this->{STDERR}} ;}
  if ( $this->{HEADOUT} && !ref($this->{HEADOUT}) ) { $this->{HEADOUT} = \*{$this->{HEADOUT}} ;}
  
  if ( ref($this->{STDOUT})  !~ /^(?:GLOB|SCALAR|CODE)$/ ) { $this->{STDOUT}  = undef ;}
  if ( ref($this->{STDIN})   !~ /^(?:GLOB)$/ )             { $this->{STDIN}   = undef ;}
  if ( ref($this->{STDERR})  !~ /^(?:GLOB|SCALAR|CODE)$/ ) { $this->{STDERR}  = undef ;}  
  if ( ref($this->{HEADOUT}) !~ /^(?:GLOB|SCALAR|CODE)$/ ) { $this->{HEADOUT} = undef ;}
  
  ${$this->{STDOUT}}  .= '' if ref($this->{STDOUT}) eq 'SCALAR' ;
  ${$this->{STDERR}}  .= '' if ref($this->{STDERR}) eq 'SCALAR' ;
  ${$this->{HEADOUT}} .= '' if ref($this->{HEADOUT}) eq 'SCALAR' ;
  
  ####

  $this->{FLUSH} = $args{flush} ;
  
  $this->{AUTOHEAD} = $args{autohead} ;
  $this->{AUTOHEAD} = 1 if ($this->{HEADOUT} && !exists $args{autohead}) ;
  
  $this->{HEADSPLITTER} = $args{headsplitter} || qr/(?:\r\n\r\n|\012\015\012\015|\n\n|\015\015|\r\r|\012\012)/s if $this->{AUTOHEAD} ;
  if ( $this->{HEADSPLITTER} eq 'HTML' ) { $this->{HEADSPLITTER} = \&Safe::World::stdout::headsplitter_html ;}
  
  ####
  
  
  $this->{ONCLOSEHEADERS} = $args{on_closeheaders} if (ref($args{on_closeheaders}) eq 'CODE') ;
  $this->{ONEXIT} = $args{on_exit} if (ref($args{on_exit}) eq 'CODE') ;

  $this->{ONSELECT} = $args{on_select} if (ref($args{on_select}) eq 'CODE') ;
  $this->{ONUNSELECT} = $args{on_unselect} if (ref($args{on_unselect}) eq 'CODE') ;
  
  ####
  
  $this->{SHAREDPACK} = $args{sharepack} ;
  if ( $this->{SHAREDPACK} && ref($this->{SHAREDPACK}) ne 'ARRAY' ) { $this->{SHAREDPACK} = [$this->{SHAREDPACK}] ;}
  
  $this->{ENV} = $args{env} || $args{ENV} ;
  if ( ref($this->{ENV}) ne 'HASH') { $this->{ENV} = undef ;}

  my $packname = $args{root} || $COMPARTMENT_NAME . ++$COMPARTMENT_X ;
  $this->{ROOT} = $packname ;
  
  $this->{NO_CLEAN} = 1 if $args{no_clean} ;
  
  $this->{SAFE} = Safe::World::Compartment->new($packname) ;
  $this->{SAFE}->deny_only(@DENY_OPS) ;

  *{"$packname\::$packname\::"} = *{"$packname\::"} ;
  *{"$packname\::main::"} = *{"$packname\::"} ;
  
  if ( $this->{SHAREDPACK} ) {
    $this->{SAFE}->reval(q`package WORLDSHARE ;`);
  }
  
  ###
  
  if ( $this->{FLUSH} && !$this->{HEADOUT} && !$this->{AUTOHEAD} ) {
    $this->{TIESTDOUT} = tie(*{"$packname\::STDOUT"} => 'Safe::World::stdoutsimple' , $this->{ROOT} , $this->{STDOUT} ) ;
  }
  else {
    $this->{TIESTDOUT} = tie(*{"$packname\::STDOUT"} => 'Safe::World::stdout' , $this->{ROOT} , $this->{STDOUT} , $this->{FLUSH} , $this->{HEADOUT} , $this->{AUTOHEAD} , $this->{HEADSPLITTER} , $this->{ONCLOSEHEADERS} ) ;
  }

  $this->{TIESTDERR} = tie(*{"$packname\::STDERR"} => 'Safe::World::stderr' , $this->{ROOT} , $this->{STDERR} ) ;
  
  *{"$packname\::STDIN"}  = $this->{STDIN}  if $this->{STDIN} ;
  
  ###
  
  $this->link_pack('UNIVERSAL') ;
  $this->link_pack('attributes') ;
  $this->link_pack('DynaLoader') ;
  $this->link_pack('IO') ;
  
  $this->link_pack('Exporter') ;
  $this->link_pack('warnings') ;
  $this->link_pack('CORE') ;  
  
  $this->link_pack('<none>') ;  
  
  $this->link_pack('Apache') if defined *{"Apache::"} ;
  $this->link_pack('Win32') if defined *{"Win32::"} ;

  $this->share_vars( 'main' , [
  '@INC' , '%INC' ,
  '$@','$|','$_', '$!',
  #'$-', , '$/' ,'$!','$.' ,
  ]) ;

  $this->select_static ;

  $this->set_vars(
  '%SIG' => \%SIG ,
  '$/' => $/ ,
  '$"' => $" ,
  '$;' => $; ,
  '$$' => $$ ,
  '$^W' => 0 ,
  ( $this->{ENV} ? ('%ENV' => $this->{ENV}) : () ) ,
  ) ;

  $this->set('%INC',{}) ;
  
  $this->eval("no strict ;") ; ## just to load strict inside the compartment.
  
  $this->unselect_static ;

  return $this ;
}

##############
# SYNC_EVALX #
##############

sub sync_evalx {
  eval("=1") ;
  my ($evalx) = ( $@ =~ /\(eval (\d+)/s );
  $Safe::World::EVALX = $evalx ;
}

#########
# RESET #
#########

sub reset {
  my $this = shift ;
  my ( %args ) = @_ ;
  
  my $packname = $this->{ROOT} ;
  
  $this->{EXIT}      = undef ;
  $this->{DESTROIED} = undef ;
  $this->{CLEANNED}  = undef ;
  
  $this->{STDOUT}  = $args{stdout} if $args{stdout} ;
  $this->{STDIN}   = $args{stdin} if $args{stdin} ;
  $this->{STDERR}  = $args{stderr} if $args{stderr} ;
  $this->{HEADOUT} = $args{headout} if $args{headout} ;
  
  if ( $this->{STDOUT}  && !ref($this->{STDOUT}) )   { $this->{STDOUT}  = \*{$this->{STDOUT}} ;}
  if ( $this->{STDIN}   && !ref($this->{STDIN}) )    { $this->{STDIN}   = \*{$this->{STDIN}} ;}
  if ( $this->{STDERR}  && !ref($this->{STDERR}) )   { $this->{STDERR}  = \*{$this->{STDERR}} ;}
  if ( $this->{HEADOUT} && !ref($this->{HEADOUT}) )  { $this->{HEADOUT} = \*{$this->{HEADOUT}} ;}
  
  if ( ref($this->{STDOUT})  !~ /^(?:GLOB|SCALAR|CODE)$/ ) { $this->{STDOUT}  = undef ;}
  if ( ref($this->{STDIN})   !~ /^(?:GLOB)$/ )             { $this->{STDIN}   = undef ;}
  if ( ref($this->{STDERR})  !~ /^(?:GLOB|SCALAR|CODE)$/ ) { $this->{STDERR}  = undef ;}  
  if ( ref($this->{HEADOUT}) !~ /^(?:GLOB|SCALAR|CODE)$/ ) { $this->{HEADOUT} = undef ;}
  
  ${$this->{STDOUT}}  .= '' if ref($this->{STDOUT}) eq 'SCALAR' ;
  ${$this->{STDERR}}  .= '' if ref($this->{STDERR}) eq 'SCALAR' ;
  ${$this->{HEADOUT}} .= '' if ref($this->{HEADOUT}) eq 'SCALAR' ;
  
  my $env = $args{env} || $args{ENV} ;
  
  if ( $env ) {
    $this->{ENV} = $env ;
    if ( ref($this->{ENV}) ne 'HASH') { $this->{ENV} = undef ;}  
  }
  
  $this->set_vars(
  '%SIG' => \%SIG ,
  '$/' => $/ ,
  '$"' => $" ,
  '$;' => $; ,
  '$$' => $$ ,
  '$^W' => 0 ,
  ( $env ? ('%ENV' => $this->{ENV}) : () ) ,
  ) ;
  
  untie(*{"$packname\::STDOUT"}) ;
  untie(*{"$packname\::STDERR"}) ;
  
  if ( $this->{FLUSH} && !$this->{HEADOUT} && !$this->{AUTOHEAD} ) {
    $this->{TIESTDOUT} = tie(*{"$packname\::STDOUT"} => 'Safe::World::stdoutsimple' , $this->{ROOT} , $this->{STDOUT} ) ;
  }
  else {
    $this->{TIESTDOUT} = tie(*{"$packname\::STDOUT"} => 'Safe::World::stdout' , $this->{ROOT} , $this->{STDOUT} , $this->{FLUSH} , $this->{HEADOUT} , $this->{AUTOHEAD} , $this->{HEADSPLITTER} , $this->{ONCLOSEHEADERS} ) ;
  }

  $this->{TIESTDERR} = tie(*{"$packname\::STDERR"} => 'Safe::World::stderr' , $this->{ROOT} , $this->{STDERR} ) ;
  
  *{"$packname\::STDIN"}  = $this->{STDIN}  if $this->{STDIN} ;
  
  sync_evalx() ;
  
  return 1 ;
}

#################
# SELECT_STATIC #
#################

sub select_static {
  if ( !$SAFE_WORLD_SELECTED_STATIC && $NOW != $_[0] ) {
    $SAFE_WORLD_SELECTED_STATIC = Safe::World::select->new(@_[0]) ;
    return 1 ;
  }
  return ;
}

###################
# UNSELECT_STATIC #
###################

sub unselect_static {
  if ( $SAFE_WORLD_SELECTED_STATIC && $NOW == $_[0] ) {
    $SAFE_WORLD_SELECTED_STATIC = undef ;
    return 1 ;
  }
  return ;
}

########
# EVAL #
########

sub eval {

  if ( $_[0]->{WORLD_SHARED} && !$_[0]->{DESTROIED} && $NOW != $_[0] ) {
    $_[0]->warn("Don't evaluate inside a linked pack (shared with $_[0]->{WORLD_SHARED})! Please unlink first." , 1) ;
  }
  elsif ( $_[0]->{EXIT} && !$_[0]->{DESTROIED} && $NOW != $_[0] ) {
    $_[0]->warn("Can't evaluate after exit!" , 1) ;
    return ;
  }

  ##print "[[$_[1]]]\n" ;
  if ( $_[0]->{INSIDE} ) {
    #print "EVAL>> INSIDE\n" ;
    ++$Safe::World::EVALX ;
    return eval("no strict;\@_ = () ; package main ; $_[1]") ;
  }
  else {
    #print "EVAL>> OUT $Safe::World::NOW [$_]\n" ;
    my $SAFE_WORLD_selected ;
    if ( $NOW != $_[0] ) { $SAFE_WORLD_selected = Safe::World::select->new($_[0]) ;}
    
    $_[0]->{INSIDE} = 1 ;
    
    if ( wantarray ) {
      my @ret = $_[0]->{SAFE}->reval("\@_ = () ; $_[1]") ;    
      $NOW->{INSIDE} = 0 ;
      return @ret ;
    }
    else {
      my $ret = $_[0]->{SAFE}->reval("\@_ = () ; $_[1]") ;    
      $NOW->{INSIDE} = 0 ;
      return $ret ;
    }
  }
}

#############
# EVAL_PACK #
#############

sub eval_pack { $_[0]->eval("package $_[1] ; $_[2]") ;}

########
# CALL #
########

sub call {
  my $this = shift ;
  my $sub = shift ;
  
  my $tmp = $_ ;
  $_ = \@_ ;
  
  my ( @ret , $ret ) ;
  
  if ( wantarray ) { @ret = $this->eval("return $sub(\@{\$_}) ;") ;}
  else { $ret = $this->eval("return $sub(\@{\$_}) ;") ;}

  $_ = $tmp ;
  
  return( @ret ) if wantarray ;
  return $ret ;
}

#######
# GET #
#######

sub get { &eval ;}

############
# GET_FROM #
############

sub get_from { &eval($_[0] , "package $_[1] ;\n$_[2]") ;}

###########
# GET_REF #
###########

sub get_ref {
  my $this = shift ;
  my ( $varfull ) = @_ ;
  
  my $pack = $this->{ROOT} ;
  
  my ($var_tp,$var) = ( $varfull =~ /([\$\@\%\*])(\S+)/ ) ;
  $var =~ s/^{'(\S+)'}$/$1/ ;
  $var =~ s/^main::// ;

  if ($var_tp eq '$') { return \${$pack.'::'.$var} ;}
  elsif ($var_tp eq '@') { return \@{$pack.'::'.$var} ;}
  elsif ($var_tp eq '%') { return \%{$pack.'::'.$var} ;}
  elsif ($var_tp eq '*') { return \*{$pack.'::'.$var} ;}
  else                   { ++$Safe::World::EVALX ; return eval("package $pack ; \\$varfull") ;}
}

################
# GET_REF_COPY #
################

sub get_ref_copy {
  my $this = shift ;
  my ( $varfull ) = @_ ;
  
  my $pack = $this->{ROOT} ;
  
  my ($var_tp,$var) = ( $varfull =~ /([\$\@\%\*])(\S+)/ ) ;
  $var =~ s/^{'(\S+)'}$/$1/ ;
  $var =~ s/^main::// ;

  if ($var_tp eq '$') {
    my $scalar = ${$pack.'::'.$var} ;
    return \$scalar ;
  }
  elsif ($var_tp eq '@') { return [@{$pack.'::'.$var}] ;}
  elsif ($var_tp eq '%') { return {%{$pack.'::'.$var}} ;}
  elsif ($var_tp eq '*') { return \*{$pack.'::'.$var} ;}
  else                   { ++$Safe::World::EVALX ; return eval("package $pack ; \\$varfull") ;}
}

#######
# SET #
#######

sub set {
  my $this = shift ;
  my ( $var , undef , $no_parse_ref) = @_ ;
  
  if ( $no_parse_ref ) {
    my $tmp = $_ ;
    $_ = $_[1] ;
    $this->eval("$var = \$_ ;") ;
    $_ = $tmp ;
  }
  else {
    my $val = (ref($_[1])) ? $_[1] : ( $_[1] eq '' ? \undef : \$_[1]) ;
    my $tmp = $_ ;
    
    $_ = $val ;
    my $ref = ref($val) ;
    
    if ( $ref eq 'SCALAR' || $ref eq 'REF' ) {
      $this->eval("$var = \${\$_} ;") ;
    }
    elsif ( $ref eq 'ARRAY' ) {
      $this->eval("$var = \@{\$_} ;") ;
    }
    elsif ( $ref eq 'HASH' ) {
      $this->eval("$var = \%{\$_} ;") ;
    }
    elsif ( $ref eq 'GLOB' ) {
      $this->eval("$var = \*{\$_} ;") ;
    }
    else {
      $this->eval("$var = \$_ ;") ;
    }
    
    $_ = $tmp ;
  }
  

  return ;
}

############
# SET_VARS #
############

sub set_vars {
  my $this = shift ;
  my ( %vars ) = @_ ;
  
  my $SAFE_WORLD_selected ;
  if ( $NOW != $this ) { $SAFE_WORLD_selected = Safe::World::select->new($this) ;}
  
  my $pack = $this->{ROOT} ;
  
  my ($var_tp,$var) ;
  
  foreach my $Key ( keys %vars ) {
    ($var_tp,$var) = ( $Key =~ /([\$\@\%\*])(\S+)/ );
    $var =~ s/^{'(\S+)'}$/$1/ ;
    $var =~ s/^main::// ;

    if ($var_tp eq '$') {
      if    (ref($vars{$Key}) eq 'SCALAR') { ${$pack.'::'.$var} = ${$vars{$Key}} ;}
      else                                 { ${$pack.'::'.$var} = $vars{$Key} ;}
    }
    elsif ($var_tp eq '@') {
      if    (ref($vars{$Key}) eq 'ARRAY') { @{$pack.'::'.$var} = @{$vars{$Key}} ;}
      elsif (ref($vars{$Key}) eq 'HASH')  { @{$pack.'::'.$var} = %{$vars{$Key}} ;}
      else                                { @{$pack.'::'.$var} = $vars{$Key} ;}
    }
    elsif ($var_tp eq '%') {
      if    (ref($vars{$Key}) eq 'HASH')  { %{$pack.'::'.$var} = %{$vars{$Key}} ;}
      elsif (ref($vars{$Key}) eq 'ARRAY') { %{$pack.'::'.$var} = @{$vars{$Key}} ;}
      else                                { %{$pack.'::'.$var} = $vars{$Key} ;}
    }
    elsif ($var_tp eq '*') {
      if    (ref($vars{$Key}) eq 'GLOB')  { *{$pack.'::'.$var} = $vars{$Key} ;}
      else                                { *{$pack.'::'.$var} = \*{$vars{$Key}} ;}
    }
    else { ++$Safe::World::EVALX ; eval("$Key = \$vars{\$Key} ;") ;}
  }
  
  return 1 ;
}

##############
# SHARE_VARS #
##############

sub share_vars {
  my $this = shift ;
  if ( $this->{INSIDE} ) { return ;}
  
  my ( $from_pack , $vars ) = @_ ;
  if ( ref($vars) ne 'ARRAY' ) { return ;}
  
  $from_pack =~ s/^:+//s ;
  $from_pack =~ s/:+$//s ;

  $this->{SAFE}->share_from($from_pack , $vars) ;
  
  foreach my $var ( @$vars ) {
    next if ($var eq '$_' || $var eq '$|' || $var eq '$@' || $var eq '$!') ;
    
    if ( $var !~ /^\W[\w:]+$/ ) {
      my ($t , $n) = ( $var =~ /^(\W)(.*)/s );
      $var = "$t\{'$from_pack\::$n'}" ;
    }
    else {
      $var =~ s/^(\W)/$1$from_pack\::/ ;    
    }

    $this->{SHARING}{$var} = { IN => undef , OUT => undef } ;
  }

  return 1 ;
}

################
# UNSHARE_VARS #
################

sub unshare_vars {
  my $this = shift ;
  if ( $this->{INSIDE} ) { return ;}
    
  my $pack = $this->{ROOT} ;
  
  foreach my $var ( keys %{ $this->{SHARING} } ) {
    my ($var_tp,$name) = ( $var =~ /([\$\@\%\*])(\S+)/ );
    $name =~ s/^{'(\S+)'}$/$1/ ;
    $name =~ s/^main::// ;
    
    if    ($var_tp eq '$') { *{$pack.'::'.$name} = \$NULL ;}
    elsif ($var_tp eq '@') { *{$pack.'::'.$name} = \@NULL ;}
    elsif ($var_tp eq '%') { *{$pack.'::'.$name} = \%NULL ;}
    elsif ($var_tp eq '*') { *{$pack.'::'.$name} = \*NULL ;}
  }
}

#############
# LINK_PACK #
#############

sub link_pack {
  my $this = shift ;
  if ( $this->{INSIDE} ) { return ;}
  my ( $pack ) = @_ ;
  
  my $pack_alise = $pack ;
  $pack_alise =~ s/^$COMPARTMENT_NAME\d+::// ;

  *{"$this->{ROOT}\::$pack_alise\::"} = *{"$pack\::"} ;
  
  $this->{LINKED_PACKS}{$pack_alise} = 1 ;
  
  return 1 ;
}

###############
# UNLINK_PACK #
###############

sub unlink_pack {
  my $this = shift ;
  if ( $this->{INSIDE} ) { return ;}
  my ( $pack ) = @_ ;
  
  my $packname = $this->{ROOT} ;

  *{"$packname\::$pack\::"} = *{"$packname\::PACKNULL::"} ;
  undef %{"$packname\::$pack\::"} ;
  undef *{"$packname\::$pack\::"} ;
  return 1 ;
}

###################
# UNLINK_PACK_ALL #
###################

sub unlink_pack_all {
  my $this = shift ;
  if ( $this->{INSIDE} ) { return ;}
  
  my $packname = $this->{ROOT} ;

  foreach my $pack ( keys %{$this->{LINKED_PACKS}} ) {
    *{"$packname\::$pack\::"} = *{"$packname\::PACKNULL::"} ;
    undef %{"$packname\::$pack\::"} ;
    undef *{"$packname\::$pack\::"} ;
  }
  
  $this->{LINKED_PACKS} = {} ;
  return 1 ;
}

##################
# SET_SHAREDPACK #
##################

sub set_sharedpack {
  my $this = shift ;
  my ( @packs ) = @_ ;
  
  my @shared_pack = @{$this->{SHAREDPACK}} ;
  my %shared_pack = map { ("$_\::" => 1) } @shared_pack ;
  
  foreach my $packs_i ( @packs ) {
    next if ($shared_pack{$packs_i} || $packs_i eq '') ;
    push(@{$this->{SHAREDPACK}} , $packs_i) ;
  }
  
  return 1 ;
}

####################
# UNSET_SHAREDPACK #
####################

sub unset_sharedpack {
  my $this = shift ;
  my ( @packs ) = @_ ;

  my %packs = map { ("$_\::" => 1) } @packs ;  
  
  my @sets ;
  foreach my $shared_pack_i ( @{$this->{SHAREDPACK}} ) {
    push(@sets , $shared_pack_i) unless $packs{$shared_pack_i} ;
  }
  
  @{$this->{SHAREDPACK}} = @sets ;
  
  return 1 ;
}

##############
# LINK_WORLD #
##############

sub link_world {
  my $this = shift ;
  my $world = shift ;
  if ( $this->{INSIDE} || ref($world) ne 'Safe::World' || $world->{WORLD_SHARED} ) { return ;}

  my $world_root = $world->{ROOT} ;
  my $root = $this->{ROOT} ;
  
  my @shared_pack = @{$world->{SHAREDPACK}} ;
  my %shared_pack = map { ("$_\::" => 1) } @shared_pack ;

  foreach my $shared_pack ( @shared_pack ) {
    $this->link_pack("$world_root\::$shared_pack") ;
  }
  
  my $table = *{"$world_root\::"}{HASH} ;
  
  foreach my $Key ( keys %$table ) {
    if ( !$shared_pack{$Key} && $$table{$Key} =~ /^\*(?:main|$world_root)::/ && $Key !~ /^(?:STDOUT|STDERR|.*?::)$/ && $Key !~ /[^\w:]/s) {
      *{"$world_root\::WORLDSHARE::$Key"} = \${"$world_root\::$Key"} ;
      *{"$world_root\::WORLDSHARE::$Key"} = \@{"$world_root\::$Key"} ;
      *{"$world_root\::WORLDSHARE::$Key"} = \%{"$world_root\::$Key"} ;
      *{"$world_root\::WORLDSHARE::$Key"} = \*{"$world_root\::$Key"} ;
      $$table{$Key} = "*$root\::$Key" ;
    }
  }
  
  $world->{WORLD_SHARED} = $root ;
  
  return 1 ;
}

################
# UNLINK_WORLD #
################

sub unlink_world {
  my $this = shift ;
  my $world = shift ;
  if ( $this->{INSIDE} || ref($world) ne 'Safe::World' || !$world->{WORLD_SHARED} ) { return ;}

  my $world_root = $world->{ROOT} ;
  my $root = $this->{ROOT} ;
  
  my @shared_pack = @{$world->{SHAREDPACK}} ;
  my %shared_pack = map { ("$_\::" => 1) } @shared_pack ;

  foreach my $shared_pack ( @shared_pack ) {
    $this->unlink_pack("$world_root\::$shared_pack") ;
  }

  my $table = *{"$world_root\::"}{HASH} ;
  
  foreach my $Key ( keys %$table ) {
    if ( !$shared_pack{$Key} && $$table{$Key} =~ /^\*(?:main|$root)::(.*)/ && $Key !~ /^(?:STDOUT|STDERR|.*?::)$/ && $Key !~ /[^\w:]/s) {
      $$table{$Key} = "*$world_root\::WORLDSHARE::$1" ;
    }
  }
  
  $world->{WORLD_SHARED} = undef ;
  
  return 1 ;
}

#############
# SCANPACKS #
#############

sub scanpacks {
  if ( ref($_[0]) && $_[0]->{INSIDE} ) { return ;}
  my $scan = Safe::World::ScanPack->new( ref($_[0]) ? $_[0]->{ROOT} : $_[0] ) ;
  return reverse $scan->packages ;
}

##################
# SCANPACK_TABLE #
##################

sub scanpack_table {
  my $this = shift if ref($_[0]) ;
  if ( ref($this) && $this->{INSIDE} ) { return ;}

  my ( $packname ) = @_ ;
  
  $packname = $this->{ROOT} . "::$packname" if $this ;
  
  $packname .= '::' unless $packname =~ /::$/ ;
  no strict "refs" ;
  my $package = *{$packname}{HASH} ;
  return unless defined $package ;
  
  no warnings ;
  local $^W = 0 ;
  
  my @table ;
  
  my $fullname ;
  foreach my $symb ( keys %$package ) {
    $fullname = "$packname$symb" ;
    if ( $symb !~ /::$/ && $symb !~ /[^\w:]/ ) {
      if (defined $$fullname) { push(@table , "\$$fullname") ;}
      if (defined %$fullname) { push(@table , "\%$fullname") ;}
      if (defined @$fullname) { push(@table , "\@$fullname") ;}
      if (defined &$fullname) { push(@table , "\&$fullname") ;}
      if (*{$fullname}{IO} && fileno $fullname) {
        push(@table , "\*$fullname") ;
      }
    }
  }

  return( @table ) ;
}

#########
# PRINT #
#########

sub print {
  my $this = shift ;
  
  my $SAFE_WORLD_selected ;
  if ( $NOW != $this ) { $SAFE_WORLD_selected = Safe::World::select->new($this) ;}
  
  $this->{TIESTDOUT}->print(@_) ;
}

################
# PRINT_STDOUT #
################

sub print_stdout { &print ;}

################
# PRINT_STDERR #
################

sub print_stderr {
  my $this = shift ;
  
  my $SAFE_WORLD_selected ;
  if ( $NOW != $this ) { $SAFE_WORLD_selected = Safe::World::select->new($this) ;}
  
  $this->{TIESTDERR}->print(@_) ;
}

########
# WARN #
########

sub warn {
  my $this = shift ;
  my @call = caller($_[1]) ;
  
  my %keys = (
  package  => 0 ,
  file     => 1 ,
  line     => 2 ,
  sub      => 3 ,
  evaltext => 6 ,
  ) ;
  
  my $caller ;
  
  foreach my $Key (sort { $keys{$a} <=> $keys{$b} } keys %keys ) {
    my $val = $call[$keys{$Key}] ;
    next if $val eq '' ;
    my $s = '.' x (7 - length($Key)) ;
    $val = "\"$val\"" if $val =~/\s/s ;
    $caller .= "  $Key$s: $val\n" ;
  }
  
  #my $caller = qq`package="$call[0]" ; file="$call[1]" ; line="$call[2]" ; sub="$call[3]" ; evaltext="$call[6]"`;
  
  $this->print_stderr("$_[0] CALLER(\n$caller)\n") ;
}

################
# PRINT_HEADER #
################

sub print_header {
  my $this = shift ;
  
  my $SAFE_WORLD_selected ;
  if ( $NOW != $this ) { $SAFE_WORLD_selected = Safe::World::select->new($this) ;}
  
  $this->{TIESTDOUT}->print_headout(@_) ;
}

#########
# FLUSH #
#########

sub flush {
  my $this = shift ;
  my ( $set ) = @_ ;
  
  if ( $#_ == 0 ) {
    if ( $set ) { $this->set('$|',1) ;}
    else { $this->set('$|',0) ;}
  }

  $this->{TIESTDOUT}->flush ;
}

###################
# CLOSE_TIESTDOUT #
###################

sub close_tiestdout {
  my $this = shift ;
  
  my $SAFE_WORLD_selected ;
  if ( $NOW != $this ) { $SAFE_WORLD_selected = Safe::World::select->new($this) ;}

  $this->{TIESTDOUT}->CLOSE ;
}

###################
# CLOSE_TIESTDERR #
###################

sub close_tiestderr {
  my $this = shift ;
  
  my $SAFE_WORLD_selected ;
  if ( $NOW != $this ) { $SAFE_WORLD_selected = Safe::World::select->new($this) ;}

  $this->{TIESTDERR}->CLOSE ;
}

#########
# CLOSE #
#########

sub close {
  my $this = shift ;

  $this->{EXIT} = undef ;
  
  $this->close_tiestdout ;
  $this->close_tiestderr ;  

  $this->set('$SAFEWORLD',\undef) ;
  $this->flush(1) ;
  
  $this->{EXIT} = 1 ;
  
  return 1 ;
}

###########
# DESTROY #
###########

sub DESTROY {
  my $this = shift ;
  return if $this->{DESTROIED} ;

  $this->close ;

  $this->{DESTROIED} = 1 ;
  
  $this->{LINKED_PACKS}{$this->{ROOT}} = 1 ;
  $this->{LINKED_PACKS}{main} = 1 ;
  
  $this->unlink_pack_all ;

  $this->CLEAN ;
}

#########
# CLEAN #
#########

sub CLEAN {
  my $this = shift ;
  return if ($this->{CLEANNED} , $this->{NO_CLEAN}) ;
  $this->{CLEANNED} = 1 ;
  
  $this->DESTROY ;
  
  ## Too slow to unshare the variables, since you change Symbol Table.
  ## Also too slow to use Safe::World::select. Better save and reset.
  
  ############ SAVE main:: SHAREDS
    foreach my $var ( keys %{ $this->{SHARING} } ) {
      my ($var_tp,$var_name) = ( $var =~ /([\$\@\%\*])(\S+)/ ) ;
      $var_name =~ s/^{'(\S+)'}$/$1/ ;
      $var_name =~ s/^main::// ;
    
      if ($var_tp eq '$') {
        my $scalar = ${'main::'.$var_name} ;
        $this->{SHARING}{$var} = \$scalar ;
      }
      elsif ($var_tp eq '@') { $this->{SHARING}{$var} = [@{'main::'.$var_name}] ;}
      elsif ($var_tp eq '%') { $this->{SHARING}{$var} = {%{'main::'.$var_name}} ;}
      elsif ($var_tp eq '*') { $this->{SHARING}{$var} = \*{'main::'.$var_name} ;}
    }
  ############
  
  my $packname = $this->{ROOT} ;
  
  foreach my $packs_i ( $this->scanpacks ) {
    $this->undef_pack($packs_i) ;
  }

  my $main_packname = "main::$packname\::" ;

  undef %{*{$main_packname}{HASH}} ;
  undef *{$main_packname} ;
  *{$main_packname} = *{"PACKNULL::"} ;
  delete *{'main::'}{HASH}{"$packname\::"} ;
  
  ############ RESET main:: SHAREDS
    foreach my $var ( keys %{ $this->{SHARING} } ) {
      my ($var_tp,$var_name) = ( $var =~ /([\$\@\%\*])(\S+)/ ) ;
      $var_name =~ s/^{'(\S+)'}$/$1/ ;
      $var_name =~ s/^main::// ;

      if ($var_tp eq '$')    { ${'main::'.$var_name} = ${ $this->{SHARING}{$var} } ;}
      elsif ($var_tp eq '@') { @{'main::'.$var_name} = @{ $this->{SHARING}{$var} } ;}
      elsif ($var_tp eq '%') { %{'main::'.$var_name} = %{ $this->{SHARING}{$var} } ;}
      elsif ($var_tp eq '*') { *{'main::'.$var_name} = $this->{SHARING}{$var} ;}
    }
  ############
  
  return 1 ;
}

##############
# UNDEF_PACK #
##############

sub undef_pack {
  my $this = shift ;
  my ( $packname ) = @_ ;
  
  $packname .= '::' unless $packname =~ /::$/ ;
  no strict "refs" ;
  my $package = *{$packname}{HASH} ;
  return unless defined $package ;

  my $tmp_sub = sub{} ;
  
  no warnings ;
  local $^W = 0 ;
  
  my ($fullname) ;
  foreach my $symb ( keys %$package ) {
    $fullname = "$packname$symb" ;
    if ( $symb !~ /::$/ && $symb !~ /[^\w:]/ ) {
      #print main::STDOUT "$packname>> $symb >> $fullname\n" ;

      if (defined &$fullname) {
        if (my $p = prototype $fullname) { ++$Safe::World::EVALX ; *{$fullname} = eval "sub ($p) {}" ;}
        else                             { *{$fullname} = $tmp_sub ;}
        undef &$fullname ;
      }

      if (*{$fullname}{IO}) { close $fullname ;}
      
      #if (defined @$fullname) { undef @$fullname ;}
      if (defined *{$fullname}{ARRAY}) { undef @$fullname ;}
      #undef @$fullname ;

      #if (defined %$fullname) { undef %$fullname ;}
      if (defined *{$fullname}{HASH}) { undef %$fullname ;}
      #undef %$fullname ;
      
      #if (defined $$fullname) { undef $$fullname ;}
      undef $$fullname ;
      
      undef *{$fullname} ;
    }
  }

  undef %{*{$packname}{HASH}} ;
  undef *{$packname} ;
}

#######
# END #
#######

1;

__END__

=head1 NAME

Safe::World - Create multiple virtual instances of a Perl interpreter that can be assembled together.

=head1 DESCRIPTION

With I<Safe::World> you can create multiple virtual instances/compartments of a Perl interpreter,
that will work/run without touch the other instances/compartments and mantaining the main interpreter normal.

Each instance (WORLD object) has their own STDOUT, STDERR and STDIN handlers, also has a fake HEADOUT output for the headers implemented inside the STDOUT.
Soo, you can use this to redirect the outputs of the WORLD object to a FILEHANDLER, SCALAR or a SUB.

The module I<Safe::World> was created for 3 purposes:

=over 10

=item 1. A Safe compartment that can be "fully" cleanned.

This enable a way to run multiple scripts in one Perl interpreter process,
saving memory and time. After each execution the Safe compartment is "fully" cleanned,
saving memory for the next compartment.

=item 2. A Safe compartment with the output handlers implemented, creating a full WORLD, working as a normal Perl Interpreter from inside.

A normal I<Safe> objects doesn't have the output handlers, actually is just a compartment to run codes that can't go outsied of it.
Having a full WORLD implemented, with the STDOUT, STDERR, STDIN and HEADERS handlers, the output can be redirected to any kind of listener.
Also the error outputs (STDERR) can be catched via I<sub> (I<CODE>), that can be displayed in the STDOUT in a nice way,
or in the case of HTML output, be displayed inside I<comment> tags, instead to go to an error log.

But to implement a full WORLD warn(), die() and exit() need to be overwrited too.
Soo you can control if exit() will really exit from the virtual interpreter, and redirect the warn messages.

=item 3. A WORLD object (a virtual Perl interpreter) that can be linked/assembled with other WORLD objects, and work/run as if the objects where only one, then be able to unlink/disassemble them.

This is the advanced purpose, that need all the previous resources, and most important thing of I<Safe::World>.
Actually this was projected to work with I<mod_perl>, soo the Perl codes can be runned in different compartments,
but can have some part of the code cached in memory, specially the Perl Modules (Classes) that need to be loaded all the time.

Soo, you can load your classes in one World, and your script/page in other World, then link them and run your code normally.
Then after run it you unlink the 2 Worlds, and only CLEAN the World with your script/page,
and now you can keep the 1st World with your Classes cached, to link it again with the next script/page to run.

Here's how to implement that:

=over 10

=item 1 Cache World.

A cache world is created, where all the classes common to the all the different scripts/pages are loaded.

=item 1 Execution World.

For each script/page is created a world, each time that is executed (unless a script need to be persistent).
Inside this worlds only the main code of the scripts/pages are loaded.

=item 1 Linking 2 WORLDS.

Using the method I<link_world()>, two worlds can be assembled. Actually one world is imported inside another.
In this case the I<Cache World> is linked to the I<Execution World>.
Now you can't evaluate codes in the I<Cache World>, since it's shared, and evaluation is only accepted in the I<Execution World>.

  my $world_cache = Safe::World->new(sharepack => ['DBI','DBD::mysql']) ;
  $world_cache->eval(" use DBI ;") ;
  $world_cache->eval(" use DBD::mysql ;") ;
  
  my ( $stdout , $stderr ) ;
  
  my $world_exec = Safe::World->new(
  stdout => \$stdout ,
  stderr => \$stderr ,
  ) ;
  
  $world_exec->link_world($world_cache) ;
  
  $world_exec->eval(q`
      $dbh = DBI->connect("DBI:mysql:database=$db;host=$host", 'user' , 'pass') ;
  `);

=back

=back

=head1 USAGE

See the I<test.pl> script for more examples.

  use Safe::World ;

  my $world = Safe::World->new(
  stdout => \$stdout ,     ## - redirect STDOUT to this scalar.
  stderr  => \$stderr ,    ## - redirect STDERR to this scalar.
  headout => \$headout ,   ## - SCALAR to hold the headers.
  autohead => 1 ,          ## - tell to handle headers automatically.
  headsplitter => 'HTML' , ## - will split the headers from the content handling
                           ##   the output as HTML.
  flush => 1 ,             ## - output is flushed, soo don't need to wait exit to
                           ##   have all the data inside $stdout.
  
  on_closeheaders => sub { ## sub to call when headers are closed (when content start).
                       my ( $world ) = @_ ;
                       my $headers = $world->headers ;

                       $headers =~ s/\r\n?/\n/gs ;
                       $headers =~ s/\n+/\n/gs ;
                       $headers .= "\015\012\015\012" ; ## add the headers end.
  
                       $world->print($headers) ; ## print the headers to STDOUT
                       $world->headers('') ; ## clean the headers scalar.
                     } ,
  
  on_exit => sub { ## sub to call when exit() happens.
               my ( $world ) = @_ ;
               $world->print("<!-- ON_EXIT_IN -->\n");
               return 0 ; ## 0 make exit() to be skiped. 1 make exit() work normal.
             } ,
  ) ;
  
  ## Evaluate some code:
  $world->eval(q`
     print "Content-type: text/html\n\n" ; 
     
     print "<html>\n" ;
     print "content1\n" ;
     
     ## print some header after print the content,
     ## but need to be before flush the output!
     $SAFEWORLD->print_header("Set-Cookie: FOO=BAR; domain=foo.com; path=/;\n") ;
     
     print "content2\n" ;
     print "</html>\n" ;
     
     warn("some alert to STDERR!") ;
     
     exit;
  `);
  
  $world->close ; ## ensure that everything is finished and flushed.
  
  print $socket $stdout ; ## print the output to some client socket.
  print $log $stderr ; ## print errors to a log.
  
  $world = undef ; ## Destroy the world. Here the compartment is cleanned.


=head1 METHODS

=head2 new

Create the World object.

B<Arguments:>

=over 10

=item root

The name of the package where the compartment will be created.

By default is used I<SAFEWORLD>B<x>, where x will increse: SAFEWORLD1, SAFEWORLD2, SAFEWORLD3...

=item stdout (GLOB|SCALAR|CODE ref)

The STDOUT target. Can be another GLOB/FILEHANDLER, a SCALAR reference, or a I<sub> reference.

DEFAULT: I<\*main::STDOUT>

=item stderr (GLOB|SCALAR|CODE ref)

The STDERR target. Can be another GLOB/FILEHANDLER, a SCALAR reference, or a I<sub> reference.

DEFAULT: I<\*main::STDERR>

=item stdin (GLOB ref)

The STDIN handler. Need to be a IO handler.

DEFAULT: I<\*main::STDIN>

=item headout (GLOB|SCALAR|CODE)

The HEADOUT target. Can be another GLOB/FILEHANDLER, a SCALAR reference, or a I<sub> reference.

=item env (HASH ref)

The HASH reference for the internal I<%ENV> of the World.

=item flush (bool)

If TRUE tell that STDOUT will be always flushed ( $| = 1 ).

=item no_clean (bool)

If TRUE tell that the compartment wont be cleaned when destroyed.

=item autohead (bool)

If TRUE tell that the STDOUT will handler automatically the handlers in the output, using I<headsplitter>.

=item headsplitter (REGEXP|CODE)

A REGEXP or CODE reference to split the header from the content.

Example of REGEXP:

  my $splitter = qr/(?:\r\n\r\n|\012\015\012\015|\n\n|\015\015|\r\r|\012\012)/s ; ## This is the DEFAULT

Example of SUB:

  sub splitter {
    my ( $world , $data ) = @_ ;
    
    my ($headers , $rest) = split(/\r\n?\r\n?/s , $data) ;
  
    return ($headers , $rest) ;
  }

=item sharepack (LIST)

When a World is linked to another you need to tell what packages inside it can be shared:

  my $world_cache = Safe::World->new(sharepack => ['DBI','DBD::mysql']) ;

=item on_closeheaders (CODE)

I<Sub> to be called when the headers are closed.

=item on_exit (CODE)

I<Sub> to be called when exit() is called.

=item on_select (CODE)

I<Sub> to be called when the WORLD is selected to evaluate codes inside it.

=item on_unselect (CODE)

I<Sub> to be called when the WORLD is unselected, just after evaluate the codes.

=back

=head2 CLEAN

Call DESTROY() and clean the compartment.

** Do not use the World object after this!

=head2 call (SUBNAME , @ARGS)

Call a I<sub> inside the World and returning their values.

  my @ret0 = $world->call('foo::methodx', $var1 , time()); ## foo::methodx($var1 , time())
  
  my @ret1 = $world->call('methodz', 123); ## main::methodz(123)

=head2 close

Ensure that everything is finished and flushed. You can't evaluate codes after this!

=head2 close_tiestdout()

Close the tied STDOUT.

=head2 close_tiestderr()

Close the tied STDERR.

=head2 eval (CODE)

Evaluate a code inside the World and return their values.

=head2 eval_pack (PACKAGE , CODE)

Evaluate inside some package.

Same as:

  my $code = "print time ;" ;
  $world->eval("package foo ; $code") ;

=head2 flush (bool)

Set $| to 1 or 0 if I<bool> is defined.

Also flush STDOUT. Soo, if some sata exists in the buffer it will be flushed to the output.

=head2 get (VAR)

Return some variable value from the World:

  my $document_root = $world->get('$ENV{DOCUMENT_ROOT}') ;

=head2 get_from (PACKAGE , VAR)

Return some variable value inside some package in the World:

  my $document_root = $world->get('Foo' , '$VERSION') ;

=head2 get_ref (VAR)

Return reference of to a variable:

  my $env = $world->get_ref('%ENV') ;
  $$env{ENV}{DOCUMENT_ROOT} = '/home/httpd/www' ; ## Set the value inside the World.

=head2 get_ref_copy (VAR)

Return reference B<copy> of a variable:

  my $env = $world->get_ref_copy('%ENV') ;

** Note that the reference inside $env is not pointing to a variable inside the World.

=head2 headers

Return the headers data.

** Note that this will only return data if I<HEADOUT> is defined as SCALAR.

=head2 link_pack (PACKAGE)

Link some package to the world.

  $world->link_pack("Win32") ;

=head2 unlink_pack (PACKAGE)

Unlink a package.

=head2 link_world (WORLD)

Link the compartment of a world to another.

  $world->link_world( $world_shared ) ;

=head2 unlink_world (WORLD)

Unlink/disassemble a World from another.

=head2 print (STRING)

Print some data to the STDOUT of the world.

=head2 print_header (STRING)

Print some data to the HEADOUT of the world.

=head2 print_stderr (STRING)

Print some data to the STDERR of the world.

=head2 print_stdout (STRING)

Same as I<print>.

Print some data to the STDOUT of the world.

=head2 reset

Reset the object flags. Soo, if it was closed (exited) can be reused.

You can redefine this flags (sending this arguments):

=over 10

=item stdout (GLOB|SCALAR|CODE ref)

The STDOUT target. Can be another GLOB/FILEHANDLER, a SCALAR reference, or a I<sub> reference.

DEFAULT: I<\*main::STDOUT>

=item stderr (GLOB|SCALAR|CODE ref)

The STDERR target. Can be another GLOB/FILEHANDLER, a SCALAR reference, or a I<sub> reference.

DEFAULT: I<\*main::STDERR>

=item stdin (GLOB ref)

The STDIN handler. Need to be a IO handler.

DEFAULT: I<\*main::STDIN>

=item headout (GLOB|SCALAR|CODE)

The HEADOUT target. Can be another GLOB/FILEHANDLER, a SCALAR reference, or a I<sub> reference.

=item env (HASH ref)

The HASH reference for the internal I<%ENV> of the World.

=back

=head2 root

Return the root name of the compartment of the World.

=head2 safe

Return the I<Safe> object of the World.

=head2 scanpack_table (PACKAGE)

Scan the elements of a symbol table of a package.

=head2 scanpacks

Return the package list of a World.

=head2 select_static

Select static a World to make multiple evaluations faster:

  $world->select_static ;
    $world->eval("... 1 ...") ;
    $world->eval("... 2 ...") ;
    $world->eval("... 3 ...") ;
  $world->unselect_static ;  

=head2 unselect_static

Unselect the world. Should be called after I<select_static()>.

=head2 set (VAR , VALUE_REF) || (VAR , VALUE , 1)

Set the value of a varaible inside the World:

    my @inc = qw('.','./lib') ;
    $world->set('@INC' , \@inc) ;
    
    ## To set a value that is a reference, like an object:
    
    $world->set('$objectx' , $objecty , 1) ;    

=head2 set_sharedpack (PACKAGE)

Set a package inside a world SHARED, soo, when this World is linked to another this package is imported.

** See argument I<sharepack> at I<new()>.

=head2 unset_sharedpack (PACKAGE)

Unset a SHARED package.

=head2 set_vars (VARS_VALUES_LIST)

  $world->set_vars(
  '%SIG' => \%SIG ,
  '$/' => $/ ,
  '$"' => $" ,
  '$;' => $; ,
  '$$' => $$ ,
  '$^W' => 0 ,
  ) ;

=head2 share_vars (PACKAGE , VARS_LIST)

Set a list of variables to be shared:

  $world->share_vars( 'main' , [
  '@INC' , '%INC' ,
  '$@','$|','$_', '$!',
  ]) ;

=head2 unshare_vars (PACKAGE , VARS_LIST)

Unshare a list of variables

=head2 stdout_data

Return the stdout data.

** Note that this will only return data if I<STDOUT> is defined as SCALAR.

=head2 tiestdout

The tiehandler of STDOUT.

=head2 tiestderr

The tiehandler of STDERR.


=head2 unlink_pack_all

Unlink all the packages linked to this World.

** You shouldn't call this by your self. This is only used by DESTROY().

=head2 warn

Send some I<warn> message to the world, that will be redirected to the STDERR of the World.


=head1 SEE ALSO

L<HPL>, L<Safe>.

=head1 NOTES

This module was made to work with I<HPL> and I<mod_perl>,
enabling multiple executions of scripts in one Perl interpreter,
and also brings a way to cache loaded modules, making the execution of multiple
scripts and mod_perl pages faster and with less memory.

Actually this was first writed as I<HPL::PACK module>, then I haved moved it to I<Safe::World> to be shared with other projects. ;-P

** Note that was hard to implement all the enverioment inside I<Safe::World>,
soo if you have ideas or suggestions to make this work better, please send them. ;-P

=head1 AUTHOR

Graciliano M. P. <gm@virtuasites.com.br>

I will appreciate any type of feedback (include your opinions and/or suggestions). ;-P

Enjoy!

=head1 THANKS

Thanks to:

Elizabeth Mattijsen <liz@dijkmat.nl>, to test it in different Perl versions and report bugs.


=head1 COPYRIGHT

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

