#############################################################################
## Name:        Scope.pm
## Purpose:     Safe::World::Scope
## Author:      Graciliano M. P.
## Modified by:
## Created:     15/12/2003
## RCS-ID:      
## Copyright:   (c) 2003 Graciliano M. P.
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Safe::World::Scope ;

use strict qw(vars);

our ($VERSION , @ISA) ;
$VERSION = '0.01' ;

my ($HOLE) ;

#######
# NEW # package
#######

sub new {
  my $class = shift ;
  my $this = bless({} , $class) ;
  my ($package) = @_ ;
  
  $package =~ s/[^\w:]//gs ;
  $package =~ s/[:\.]+/::/gs ;
  $package =~ s/^:+//g ;
  $package =~ s/:+$//g ;
  
  $this->{PACKAGE} = $package ;
  
  $this->{HOOK} = new_hook($package) ;
  
  $this->{STASH} = $this->_STASH_REF_NOW ;
  
  return $this ;
}

##################
# _STASH_REF_NOW #
##################

sub _STASH_REF_NOW { \%{ $_[0]->{PACKAGE} . '::' } ;}

############
# NEW_HOOK #
############

sub new_hook {
  my $class = shift ;
  my $this = bless({} , $class) ;
  
  $this->{PACKAGE} = $class ;
  
  my $hook_sub = "$class\::__SAFEWORLD_HOOK__" ;
  
  if ( !defined &$hook_sub ) {
    *{$hook_sub} = \&__SAFEWORLD_HOOK__ ;
  }
  
  my @table = &scanpack_table($class) ;
  
  foreach my $table_i ( @table ) {
    if ( $table_i =~ /^([\$\@\%\*\&])(\Q$class\E:*)(.*)/ ) {
      my ($tp , $sub , $name) = ($1,"$2$3",$3) ;
      next if $name eq '__SAFEWORLD_HOOK__' ;
      
      if    ( $tp eq '$' )  { $this->{$tp}{$name} = \$$sub ;}
      elsif ( $tp eq '@' )  { $this->{$tp}{$name} = \@$sub ;}
      elsif ( $tp eq '%' )  { $this->{$tp}{$name} = \%$sub ;}
      elsif ( $tp eq '*' )  { $this->{$tp}{$name} = \&$sub ;}
      elsif ( $tp eq '&' )  { $this->{$tp}{$name} = \&$sub ;}      
    }
  }

  return $this ;
}

##################
# SCANPACK_TABLE # Copy from Safe::World::scanpack_table, since this package need to be scope independent!
##################

sub scanpack_table {
  my ( $packname ) = @_ ;
  
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

######################
# __SAFEWORLD_HOOK__ #
######################

sub __SAFEWORLD_HOOK__ {
  my $__HOOK__ = shift ;

  if ( $_[0] eq 'call' ) { shift ;
    my $name = shift ;
    my $sub = $__HOOK__->{'&'}{$name} ;
    return &$sub(@_) if $sub ;
    die("Undefined subroutine &$__HOOK__->{PACKAGE}\::$name") ;
    return undef ;
  }
  
  elsif ( $_[0] eq 'get' ) { shift ;
    if    ( $_[0] eq '$' )  { return ${ $__HOOK__->{'$'}{$_[1]} } ;}
    elsif ( $_[0] eq '@' )  { return @{ $__HOOK__->{'@'}{$_[1]} } ;}
    elsif ( $_[0] eq '%' )  { return %{ $__HOOK__->{'%'}{$_[1]} } ;}
    elsif ( $_[0] eq '*' )  { return *{ $__HOOK__->{'*'}{$_[1]} } ;}
    elsif ( $_[0] eq '\$' ) { return $__HOOK__->{'$'}{$_[1]} ;}
    elsif ( $_[0] eq '\@' ) { return $__HOOK__->{'@'}{$_[1]} ;}
    elsif ( $_[0] eq '\%' ) { return $__HOOK__->{'%'}{$_[1]} ;}
    elsif ( $_[0] eq '\*' ) { return $__HOOK__->{'*'}{$_[1]} ;}
  }
  
  elsif ( $_[0] eq 'set' ) { shift ;
    my $__REF__ = ref($_[2]) ;
    if    ( $_[0] eq '$' )  { return ${ $__HOOK__->{'$'}{$_[1]} } = $__REF__ eq 'SCALAR' ? ${$_[2]} : $__REF__ eq 'ARRAY' ? @{$_[2]} : $__REF__ eq 'HASH' ? %{$_[2]} : $_[2] ;}
    elsif ( $_[0] eq '@' )  { return @{ $__HOOK__->{'@'}{$_[1]} } = $__REF__ eq 'SCALAR' ? ${$_[2]} : $__REF__ eq 'ARRAY' ? @{$_[2]} : $__REF__ eq 'HASH' ? %{$_[2]} : $_[2] ;}
    elsif ( $_[0] eq '%' )  { return %{ $__HOOK__->{'%'}{$_[1]} } = $__REF__ eq 'SCALAR' ? ${$_[2]} : $__REF__ eq 'ARRAY' ? @{$_[2]} : $__REF__ eq 'HASH' ? %{$_[2]} : $_[2] ;}
    elsif ( $_[0] eq '*' )  { return *{ $__HOOK__->{'*'}{$_[1]} } = $__REF__ eq 'SCALAR' ? ${$_[2]} : $__REF__ eq 'ARRAY' ? @{$_[2]} : $__REF__ eq 'HASH' ? %{$_[2]} : $_[2] ;}
  }
  
  return ;
}

#######
# NEW #
#######

sub NEW {
  my $this = shift ;
  $this->call_hole('new',$this->{PACKAGE},@_) ;
}

#############
# CALL_HOLE #
#############

sub call_hole {
  my $this = shift ;
  my $sub = shift ;
  
  &_load_HOLE if !$HOLE ;
  
  if ( $this->_STASH_REF_NOW != $this->{STASH} ) {
    my $sub_ref = $this->{HOOK}->{'&'}{$sub} ;
    return $HOLE->call($sub_ref,@_) ;
  }
  
  return $this->{HOOK}->__SAFEWORLD_HOOK__('call',$sub,@_) ;
}

##############
# _LOAD_HOLE #
##############

sub _load_HOLE {
  if ( !$HOLE ) {
    require Safe::Hole ;
    $HOLE = new Safe::Hole ;
  }
}

########
# CALL #
########

sub call {
  my $this = shift ;
  my $sub = shift ;
  return $this->{HOOK}->__SAFEWORLD_HOOK__('call',$sub,@_) ;
}

#######
# GET #
#######

sub get {
  my $this = shift ;
  my ($tp,$var) = ( $_[0] =~ /^(\\?[\$\@\%\*])(\w+(?:::\w+)*)/ );
  $this->{HOOK}->__SAFEWORLD_HOOK__('get',$tp,$var) ;
}

#######
# SET #
#######

sub set {
  my $this = shift ;
  my $toset = shift ;
  my ( undef , $keep_ref ) = @_ ;

  my ($tp,$var) = ( $toset =~ /^(\\?[\$\@\%\*])(\w+(?:::\w+)*)/ ) ;
  
  my $ref ;
  
  if ( $keep_ref ) { $ref = \$_[0] ;}
  else { $ref = $_[0] ;}
  
  $this->{HOOK}->__SAFEWORLD_HOOK__('set',$tp,$var,$ref) ;
}

#######
# END #
#######

1;

__END__

=head1 NAME

Safe::World::Scope - Enable access to a package scope not shared by a World.

=head1 DESCRIPTION

This enable the access to a not shared scopes. Soo, if you want
to have an object created outside inside a World, but without share the
packages of the object, you can design it to have access to sub-classes through
scope access.

=head1 BEHAVIOR

B<The best way to understand what it does and why it exists, is to know the behavior
of an object created outside of a World, but running it inside a World:>

When an object created outside is used inside a World, for example,
when you call a method, the object can see the scope of were the method/sub were created:

    $world->eval(q`
      $object->foo();
    `);

Soo, $object can call foo(), and foo() will see the scope of the package of $object,
even if this package doesn't exists inside the World.

But let's say that foo() call some other package:

  #### THIS IS CODE OUTSIDE OF THE WORLD:
  
  package object ;
  
  use Data::Dumper qw() ;
  
  sub foo {
    my $this = shift ;
    my $dump = Data::Dumper($this) ;
  }

B<Now foo() call Data::Dumper(), but the package Data::Dumper exists only outside of the World and is not shared!>

Here we will get an error, since foo can't have access to the scope of Data::, since it will try to get the sub inside
the World, at SAFEWORLD1::Data::Dumper, and not at main::Data::Dumper (where it really exists).

Soo, to make the object work, you can design it to access outside scopes through a I<Scope> object:

  #### THIS IS CODE OUTSIDE OF THE WORLD:
  
  package object ;
  
  use Data::Dumper qw() ;

  my $SCOPE_Data = new Safe::World::Scope('Data') ;
  
  sub foo {
    my $this = shift ;
    my $dump = $SCOPE_Data->call('Dumper',$this) ;
  }

Now with this design you can use $object inside the World without share any other package, what make it much more safer.

This is how the I<HPL> object works inside the compartment, and this was created specially for it.

=head1 NEW

To call the method I<new()> of a package you should use I<NEW()> and not I<call()> for 2 reasons. One beaceus NEW() paste the extra argument automatically (package name):

  ## Foo->new using call():
  $SCOPE_Foo->call('new','Foo',@args) ;

  ## Foo->new using NEW():
  $SCOPE_Foo->NEW(@args) ;

The 2nd reason is beacuse if you call Foo->new inside a World,
bless() will create an object pointing to a package reference inside the World,
and not to the rigth package where I<Foo::new()> really exists.

Soo, using I<NEW()> a I<call_hole()> is made to ensure that bless() works fine.

=head1 USAGE

  package foo ;
    use vars qw($var);
    $var = 'foo var!' ;
    sub test { print "TEST!!! @_\n" ; }
  
  package main ;
  
    use Safe::World ;
    use Safe::World::Scope ;
  
    my $scope = new Safe::World::Scope('foo') ;
    
    my $world = new Safe::World(flush=>1) ;
    
    $world->set('$scope' , $scope , 1) ; ## Set the object inside the World.
    
    $world->eval(q`
      $scope->call('test','argmunet') ;
      
      my $v = $scope->get('$var') ;
      print "var: $v\n" ;
      
      $scope->set('$var', '123' ) ;
      
      $v = $scope->get('$var') ;
      print "var after set: $v\n" ;
    `);


=head1 METHODS

=head2 new (PACKAGE)

Create a new Scope object. Has only one argmunet, the I<PACKAGE> name.

=head2 call (SUB , ARGS)

Call a sub inside the scope:

  ## calling the sub test():
  $scope->call('test','arg1','arg2') ;

=head2 call_hole (SUB , ARGS)

Same as I<call()>, but ensure that the sub will be executed outside of the World, at the original main STASH.

=head2 get (VAR)

Get a variable value:

  my $val = $scope->get('$foo') ;

=head2 set (VAR , VALUEREF , KEEPREF)

Set the value of a variable. I<VALUEREF> should be a reference to the new value:

  $scope->set('$var', '123' ) ;

If you need to set a reference, like an object, use the 3rd argument I<KEEPREF>:

  $scope->set('$object', $outside_object , 1 ) ;

=head2 NEW

Make a I<new()> call in the package of the scope:

  my $foo = new Foo(123) ;
  ## or:
  my $foo = Foo->new(123) ;
  
  ## Equal to:
  
  my $SCOPE_Foo = new Safe::World::Scope('Foo') ;
  my $foo = $SCOPE_Foo->NEW(123) ;

I<** Note that if the call is made inside the World,
a call_hole() will be used to ensure that bless() is made to the rigth package. Or in other case, bless() will create an object pointing to a package reference inside the World, what create an object without reference to any method, since they are declared outside the World!>

=head1 ACCESS REFERENCE

Note that you only can have access to the scope if it was already created.
Soo, if new variables, subs, or any other symbols are added to the package table, created after create the I<Scope> object, you won't have access to them!.

=head1 SEE ALSO

L<Safe::World>, L<HPL>, L<Safe::Hole>, L<Safe>.

=head1 AUTHOR

Graciliano M. P. <gm@virtuasites.com.br>

I will appreciate any type of feedback (include your opinions and/or suggestions). ;-P

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut


