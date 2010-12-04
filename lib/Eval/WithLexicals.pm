package Eval::WithLexicals;

use Moo;
use Sub::Quote;

has lexicals => (is => 'rw', default => quote_sub q{ {} });

{
  my %valid_contexts = map +($_ => 1), qw(list scalar void);

  has context => (
    is => 'rw', default => quote_sub(q{ 'list' }),
    isa => sub {
      my ($val) = @_;
      die "Invalid context type $val - should be list, scalar or void"
	unless $valid_contexts{$val};
    },
  );
}

has in_package => (
  is => 'rw', default => quote_sub q{ 'Eval::WithLexicals::Scratchpad' }
);

sub eval {
  my ($self, $to_eval) = @_;
  local *Eval::WithLexicals::Cage::current_line;
  local *Eval::WithLexicals::Cage::pad_capture;
  local *Eval::WithLexicals::Cage::grab_captures;
  my $setup = Sub::Quote::capture_unroll('$_[2]', $self->lexicals, 2);
  my $package = $self->in_package;
  local our $current_code = qq!use strictures 1;
${setup}
sub Eval::WithLexicals::Cage::current_line {
package ${package};
${to_eval}
;sub Eval::WithLexicals::Cage::pad_capture { }
BEGIN { Eval::WithLexicals::Util::capture_list() }
sub Eval::WithLexicals::Cage::grab_captures {
  no warnings 'closure'; no strict 'refs';
  package Eval::WithLexicals::Cage;!;
  $self->_eval_do(\$current_code, $self->lexicals);
  my @ret;
  my $ctx = $self->context;
  if ($ctx eq 'list') {
    @ret = Eval::WithLexicals::Cage::current_line();
  } elsif ($ctx eq 'scalar') {
    $ret[0] = Eval::WithLexicals::Cage::current_line();
  } else {
    Eval::WithLexicals::Cage::current_line();
  }
  $self->lexicals({
    %{$self->lexicals},
    %{Eval::WithLexicals::Cage::grab_captures()}
  });
  @ret;
}

sub _eval_do {
  my ($self, $text_ref) = @_;
  local @INC = (sub {
    if ($_[1] eq '/eval_do') {
      open my $fh, '<', $text_ref;
      $fh;
    } else {
      ();
    }
  }, @INC);
  do '/eval_do' or die "Error: $@\nCompiling: $$text_ref";
}

{
  package Eval::WithLexicals::Util;

  use B qw(svref_2object);

  sub capture_list {
    my $pad_capture = \&Eval::WithLexicals::Cage::pad_capture;
    my @names = map $_->PV, grep $_->isa('B::PV'),
      svref_2object($pad_capture)->OUTSIDE->PADLIST->ARRAYelt(0)->ARRAY;
    $Eval::WithLexicals::current_code .=
      '+{ '.join(', ', map "'$_' => \\$_", @names).' };'
      ."\n}\n}\n1;\n";
  }
}

1;
