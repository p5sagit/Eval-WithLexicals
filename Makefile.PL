use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME => 'Eval::WithLexicals',
  VERSION_FROM => 'lib/Eval/WithLexicals.pm',
  ABSTRACT_FROM => 'lib/Eval/WithLexicals.pm',
  AUTHOR => 'Matt S Trout <mst@shadowcat.co.uk>',
  LICENSE => 'perl',
  PREREQ_PM => { Moo => '0.009' },
  EXE_FILES => [ 'bin/tinyrepl' ],
);
