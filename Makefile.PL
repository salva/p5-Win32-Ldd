use 5.024001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile( NAME              => 'Win32::Ldd',
               VERSION_FROM      => 'lib/Win32/Ldd.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
               ABSTRACT_FROM     => 'lib/Win32/Ldd.pm', # retrieve abstract from module
               AUTHOR            => 'Salvador Fandiño <sfandino@yahoo.com>',
               LICENSE           => 'gpl',
               LIBS              => ['-limagehlp'],
               DEFINE            => '',
               INC               => '-I.',
               OBJECT            => '$(O_FILES)' );
