###############
# MAKEFILE.PL #
###############

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'          => 'Safe::World' ,
    'VERSION_FROM'  => 'lib/Safe/World.pm' ,
    #'PREREQ_PM'     => {'Object::MultiType'  => 0.03} ,
    ($] >= 5.005 ?
      ( ABSTRACT_FROM => 'lib/Safe/World.pm',
        AUTHOR        => 'Graciliano M. P. <gm@virtuasites.com.br>'
       ) : ()
     ),
);

1;

