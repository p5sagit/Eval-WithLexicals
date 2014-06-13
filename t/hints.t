use strictures ();
my $strictures_hints;
BEGIN {
  local $ENV{PERL_STRICTURES_EXTRA} = 0;
  strictures->VERSION(1); strictures->import();
  # Find the hint value that 'use strictures 1' sets on this perl.
  $strictures_hints = $^H;
}
use strictures 1;

use Test::More;
use Eval::WithLexicals;
use lib 't/lib';

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
$eval->eval(q{ { use hint_hash_pragma 'param' } }),
ok !exists $eval->hints->{q{%^H}}->{hint_hash_pragma},
  "Lexical pragma used below main scope not captured";

$eval->eval(q{ use hint_hash_pragma 'param' }),
is $eval->hints->{q{%^H}}->{hint_hash_pragma}, 'param',
  "Lexical pragma captured";

done_testing;
