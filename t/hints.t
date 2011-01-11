use strictures 1;
# Find the hint value that 'use strictures 1' sets on this perl.
my $strictures_hints;
BEGIN { $strictures_hints = $^H }

use Test::More;
use Eval::WithLexicals;

my $eval = Eval::WithLexicals->with_plugins("HintPersistence")->new(prelude => '');

is_deeply(
  [ $eval->eval('$x = 1') ],
  [ 1 ],
  'Basic non-strict eval ok'
);

is_deeply(
  $eval->lexicals, { },
  'Lexical not stored'
);

$eval->eval('use strictures 1');

{
  local $SIG{__WARN__} = sub { };

  ok !eval { $eval->eval('$x') }, 'Unable to use undeclared variable';
  like $@, qr/requires explicit package/, 'Correct message in $@';
}

is_deeply(
  $eval->hints->{q{$^H}}, \$strictures_hints,
 'Hints are set per strictures'
);

is_deeply(
  $eval->lexicals, { },
  'Lexical not stored'
);

# Assumption about perl internals: sort pragma will set a key in %^H.

$eval->eval(q{ { use sort 'stable' } }),
ok !exists $eval->hints->{q{%^H}}->{sort},
  "Lexical pragma used below main scope not captured";

$eval->eval(q{ use sort 'stable' }),
ok exists $eval->hints->{q{%^H}}->{sort},
  "Lexical pragma captured";

done_testing;
