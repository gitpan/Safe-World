#########################

###use Data::Dumper ; print Dumper( $world ) ;

use Test;
BEGIN { plan tests => 28 } ;

use Safe::World ;

use strict ;
use warnings ;

#########################
{

  my ( $stdout , $stderr ) ;

  my $world = Safe::World->new(
  env    => {
              FOO => 'bar' ,
              BAZ => 'BRAS' ,
            } ,
  stdout => \$stdout ,
  stderr => \$stderr ,
  flush  => 1 ,
  ) ;
  
  $world->eval(q`
    my $time = time  ;
    print "Test1 "  ;
    warn("Alert!!!") ;
    foreach my $Key (sort keys %ENV ) {
      print "<$Key = $ENV{$Key}>" ;
    }
  `);
  
  $stderr =~ s/eval \d+/eval x/gi ;
  
  ok($stdout , "Test1 <BAZ = BRAS><FOO = bar>") ;
  ok($stderr , "Alert!!! at (eval x) line 4.\n") ;

}
#########################
{

  my ( $stdout , $stderr ) ;

  my $world = Safe::World->new(
  stdout => \$stdout ,
  stderr => \$stderr ,
  flush  => 1 ,
  ) ;
  
  $world->eval(q`
    use strict ;
    my @inc = keys %INC ;
    print "\@INC: $#INC\n" if @INC ;
    print "%INC: @inc\n" ;
  `);
  
  $stdout =~ s/\@INC: \d+/\@INC: x/ ;
  
  ok($stdout , "\@INC: x\n\%INC: strict.pm\n");
  ok($stderr , '') ;

}
#########################
{

  my ( $stdout , $stderr ) ;

  my $world = Safe::World->new(
  stdout => \$stdout ,
  stderr => \$stderr ,
  flush  => 1 ,
  ) ;
  
  $world->eval(q`
    sub test { print "SUBTEST <@_> " ; }
  `);
  
  $world->eval(q`
    &test ;
    test(123,456) ;
    test ;
  `);

  $world->call('test','outside');

  ok($stdout , "SUBTEST <> SUBTEST <123 456> SUBTEST <> SUBTEST <outside> ");
  ok($stderr , '') ;

}
#########################
{

  my ( $stdout0 , $stderr0 ) ;

  my $world0 = Safe::World->new(
  stdout => \$stdout0 ,
  stderr => \$stderr0 ,
  flush  => 1 ,
  ) ;
  
  $world0->eval(q`
    use test::shared ;
    
    my @incs = keys %INC ;
    print "incs> @incs\n" ;
    
    $TEST = 'w0' ;
    print ">> $test::shared::VAR\n" ;
    test::shared::method(0) ;
  `);
  
  my ( $stdout1 , $stderr1 ) ;
  
  my $world1 = Safe::World->new(
  stdout => \$stdout1 ,
  stderr => \$stderr1 ,
  flush  => 1 ,
  ) ;
  
  $world1->link_pack("$world0->{ROOT}::test::shared") ;
  
  $world1->eval(q`
    my @incs = keys %INC ;
    print "incs> @incs\n" ;
    
    $TEST = 'w1' ;
    print ">> $test::shared::VAR\n" ;
    test::shared::method(1) ;
  `);
  
  my ( $stdout2 , $stderr2 ) ;
  
  my $world2 = Safe::World->new(
  stdout => \$stdout2 ,
  stderr => \$stderr2 ,
  flush  => 1 ,
  ) ;
  
  $world2->link_pack("$world0->{ROOT}::test::shared") ;
  
  $world2->eval(q`
    my @incs = keys %INC ;
    print "incs> @incs\n" ;
    
    $TEST = 'w2' ;
    print ">> $test::shared::VAR\n" ;
    test::shared::method(2) ;
  `);
  
  ok($stdout0 , "incs> test/shared.pm\n>> foovar\nSHARED[1]! [w0][w0] <<0>>\n");
  ok($stderr0 , '') ;

  ok($stdout1 , "incs> \n>> foovar\nSHARED[2]! [w0][w1] <<1>>\n");
  ok($stderr1 , '') ;

  ok($stdout2 , "incs> \n>> foovar\nSHARED[3]! [w0][w2] <<2>>\n");
  ok($stderr2 , '') ;
  
  ok($INC{'test/shared.pm'} , undef) ;
  
}
#########################
{

  my ( $stdout0 , $stderr0 ) ;

  my $world0 = Safe::World->new(
  stdout => \$stdout0 ,
  stderr => \$stderr0 ,
  flush  => 1 ,
  ) ;
  
  $world0->eval(q`
    use test::shared ;
    my @incs = keys %INC ;
    print "incs> @incs\n" ;
    
    $TEST = 'w0' ;
    print ">> $test::shared::VAR\n" ;
    test::shared::method(0) ;
  `);
  
  $world0->set_sharedpack('test::shared') ;
  
  my ( $stdout1 , $stderr1 ) ;
  
  my $world1 = Safe::World->new(
  stdout => \$stdout1 ,
  stderr => \$stderr1 ,
  flush  => 1 ,
  ) ;
  
  my $lnk = $world1->link_world($world0) ;
  ok($lnk,1) ;
  ok($world0->{WORLD_SHARED}, $world1->{ROOT}) ;
  
  $world1->eval(q`
    my @incs = keys %INC ;
    print "incs> @incs\n" ;
    
    $TEST = 'w1' ;
    print ">> $test::shared::VAR\n" ;
    test::shared::method(1) ;
  `);
  
  $world1->unlink_world($world0) ;
  
  my ( $stdout2 , $stderr2 ) ;
  
  my $world2 = Safe::World->new(
  stdout => \$stdout2 ,
  stderr => \$stderr2 ,
  flush  => 1 ,
  ) ;
  
  $lnk = $world2->link_world($world0) ;
  ok($lnk,1) ;
  ok($world0->{WORLD_SHARED}, $world2->{ROOT}) ;
  
  $world2->eval(q`
    my @incs = keys %INC ;
    print "incs> @incs\n" ;
    
    $TEST = 'w2' ;
    print ">> $test::shared::VAR\n" ;
    test::shared::method(2) ;
  `);
  
  $world1->unlink_world($world0) ;  
  
  ok($stdout0 , "incs> test/shared.pm\n>> foovar\nSHARED[1]! [w0][w0] <<0>>\n");
  ok($stderr0 , '') ;

  ok($stdout1 , "incs> \n>> foovar\nSHARED[2]! [w1][w1] <<1>>\n");
  ok($stderr1 , '') ;

  ok($stdout2 , "incs> \n>> foovar\nSHARED[3]! [w2][w2] <<2>>\n");
  ok($stderr2 , '') ;

}
#########################
{

  my ( $stdout , $stderr ) ;

  my $world = Safe::World->new(
  stdout => \$stdout ,
  stderr => \$stderr ,
  flush  => 1 ,
  on_select => sub { print "SELECT " ; } ,
  on_unselect => sub { print "UNSELECT " ; } ,
  ) ;
  
  $world->eval(q`
    my $time = time ;
    print "Test1 " ;
  `);
  
  ok($stdout , "SELECT UNSELECT SELECT UNSELECT SELECT Test1 UNSELECT ") ;
  ok($stderr , '') ;

}
#########################
{

  my ( $stdout , $stderr , $headout ) ;

  my $world = Safe::World->new(
  stdout => \$stdout ,
  stderr  => \$stderr ,
  headout => \$headout ,
  headspliter => 'HTML' ,
  autohead => 1 ,
  #flush => 1 ,
  
  on_closeheaders => sub {
                       my ( $world ) = @_ ;
                       my $headers = $world->headers ;

                       my $data = $world->stdout_data ;

                       $headers =~ s/[\r\n\012\015]+/\n/gs ;
                       $headers =~ s/^[ \t]+\n/\n/gs ;
                       $headers =~ s/^\n+//s ;
                       $headers =~ s/\n+$//s ;
                       $headers =~ s/\n+/\015\012/gs ;

                       $headers .= "\015\012\015\012" ;
  
                       $world->print( "HEADERS[[\n$headers]]\n" ) ;
                       $world->headers('') ;
                     } ,
  
  on_exit => sub {
               my ( $world ) = @_ ;
               $world->print("<<ON_EXIT_IN>>\n");
               return 0 ;
             } ,
  ) ;
  
  $world->print("headers init!\n") ;
  
  $world->eval(q`
     print "Content-type: text/html\n\n" ; 
     print "<html>\n" ;
     
     print "content1\n" ;
     
     $SAFEWORLD->print_header("1: more headers after close!\n");     
     
     $|=1;
     
     print "content2\n" ;
     
     $SAFEWORLD->print_header("2: more headers after flush!\n");     
     
     $|=0;

     print STDERR "error!\n" ;
     
     warn("warning!!!") ;
     
     print "content3\n" ;     
     
     exit ;
     
     print "end!\n" ;
  `);
  
  $world->close ; ## flush all and exit.
  
  ok($headout , "2: more headers after flush!\n") ;
  
  $stdout =~ s/\r\n?/\n/gs ;

ok($stdout , q`HEADERS[[
headers init!
Content-type: text/html
1: more headers after close!

]]
<html>
content1
content2
content3
<<ON_EXIT_IN>>
end!
`) ;

  $stderr =~ s/eval \d+/eval x/gi ;

  ok($stderr , "error!\nwarning!!! at (eval x) line 19.\n") ;

}
#########################

print "\nThe End! By!\n" ;

1 ;


