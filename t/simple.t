use strictures 1;
use Test::More;
use Eval::WithLexicals;

my $eval = Eval::WithLexicals->new;

is_deeply(
  [ $eval->eval('my $x; $x++; $x;') ],
  [ 1 ],
  'Basic eval ok'
);

is_deeply(
  $eval->lexicals, { '$x' => \1 },
  'Lexical stored ok'
);

is_deeply(
  [ $eval->eval('$x+1') ],
  [ 2 ],
  'Use lexical ok'
);

is_deeply(
  [ $eval->eval('{ my $x = 0 }; $x') ],
  [ 1 ],
  'Inner scope plus lexical ok'
);

done_testing;
