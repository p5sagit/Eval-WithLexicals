use strictures ();
use Test::More;
use Eval::WithLexicals;
use lib 't/lib';

use strictures 1;
use get_strictures_hints qw($strictures_hints $strictures_warn);

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

  ok !eval { $eval->eval('${"x"}') }, 'Unable to use undeclared variable';
  like $@, qr/Can't use string .* as a SCALAR ref/,
  'Correct message in $@';
}

is(
  ${$eval->hints->{q{$^H}}}, $strictures_hints,
 'Hints are set per strictures'
);

is(
  (unpack "H*", ${$eval->hints->{q{${^WARNING_BITS}}}}),
  (unpack "H*", $strictures_warn),
  'Warning bits are set per strictures'
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
