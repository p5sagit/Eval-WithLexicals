package Eval::WithLexicals::WithHintPersistence;
use Moo::Role;
use Sub::Quote;

our $VERSION = '1.002000'; # 1.2.0
$VERSION = eval $VERSION;

# Used localised
our($hints, %hints);

has hints => (
  is => 'rw',
  default => quote_sub q{ {} },
);

has _first_eval => (
  is => 'rw',
  default => quote_sub q{ 1 },
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

sub setup_code {
  my($self) = @_;
  # Only run the prelude on the first eval, hints will be set after
  # that.
  if($self->_first_eval) {
    $self->_first_eval(0);
    return $self->prelude;
  } else {
    # Seems we can't use the technique of passing via @_ for code in a BEGIN
    # block
    return q[ BEGIN { ],
      _capture_unroll_global('$Eval::WithLexicals::Cage::hints', $self->hints, 2),
      q[ } ],
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

=head1 NAME

Eval::WithLexicals::WithHintPersistence - Persist compile hints between evals

=head1 SYNOPSIS

 use Eval::WithLexicals;

 my $eval = Eval::WithLexicals->with_plugins("HintPersistence")->new;

=head1 DESCRIPTION

Persist pragams and other compile hints between evals (for example the
L<strict> and L<warnings> flags in effect).

Saves and restores the C<$^H> and C<%^H> variables.

=head1 METHODS

=head2 hints

 $eval->hints('$^H')

Returns the internal hints hash, keys are C<$^H> and C<%^H> for the hint bits
and hint hash respectively.

=cut

1;
