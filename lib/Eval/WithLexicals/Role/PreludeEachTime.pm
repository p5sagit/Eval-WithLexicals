package Eval::WithLexicals::Role::PreludeEachTime;
use Moo::Role;

around setup_code => sub {
  my $orig = shift;
  my($self) = @_;
  ($self->prelude, $orig->(@_));
};

1;
