package Eval::WithLexicals::Role::LexicalHints;
use Moo::Role;

our($hints, %hints);

has first_eval => (
  is => 'rw',
  default => sub { 1 },
);

has hints => (
  is => 'rw',
  default => sub { {} },
);

around eval => sub {
  my $orig = shift;
  my($self) = @_;

  local *Eval::WithLexicals::Cage::capture_hints;
  local $Eval::WithLexicals::Cage::hints = { %{$self->hints} };

  my @ret = $orig->(@_);

  $self->hints({ Eval::WithLexicals::Cage::capture_hints() });

  @ret;
};

# XXX: Sub::Quote::capture_unroll without 'my'
use B();
sub _capture_unroll_global {
  my ($from, $captures, $indent) = @_;
  join(
    '',
    map {
      /^([\@\%\$])/
        or die "capture key should start with \@, \% or \$: $_";
      (' ' x $indent).qq{${_} = ${1}{${from}->{${\B::perlstring $_}}};\n};
    } keys %$captures
  );
}

around setup_code => sub {
  my $orig = shift;
  my($self) = @_;
  # Only run the prelude on the first eval, hints will be set after
  # that.
  if($self->first_eval) {
    $self->first_eval(0);
    return $self->prelude, $orig->(@_);
  } else {
    # Seems we can't use the technique of passing via @_ for code in a BEGIN block
    return q[ BEGIN { ], _capture_unroll_global('$Eval::WithLexicals::Cage::hints', $self->hints, 2), q[ } ],
      $orig->(@_);
  }
};

around capture_code => sub {
  my $orig = shift;
  my($self) = @_;

  ( q{ sub Eval::WithLexicals::Cage::capture_hints {
          no warnings 'closure';
          my($hints, %hints);
          BEGIN { $hints = $^H; %hints = %^H; }
          return q{$^H} => \$hints, q{%^H} => \%hints;
        } },
    $orig->(@_) )
};

1;
