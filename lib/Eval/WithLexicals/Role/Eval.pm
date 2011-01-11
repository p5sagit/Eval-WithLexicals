package Eval::WithLexicals::Role::Eval;
use Moo::Role;
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

has prelude => (
  is => 'rw', default => quote_sub q{ 'use strictures 1;' }
);

sub setup_code {
  my ($self) = @_;

  return Sub::Quote::capture_unroll('$_[2]', $self->lexicals, 2);
}

sub capture_code {
  ( qq{ BEGIN { Eval::WithLexicals::Util::capture_list() } } )
}

sub eval {
  my ($self, $to_eval) = @_;
  local *Eval::WithLexicals::Cage::current_line;
  local *Eval::WithLexicals::Cage::pad_capture;
  local *Eval::WithLexicals::Cage::grab_captures;

  my $package = $self->in_package;
  my $setup_code = join '', $self->setup_code;
  my $capture_code = join '', $self->capture_code;

  local our $current_code = qq!
${setup_code}
sub Eval::WithLexicals::Cage::current_line {
package ${package};
#line 1 "(eval)"
${to_eval}
;sub Eval::WithLexicals::Cage::pad_capture { }
${capture_code}
sub Eval::WithLexicals::Cage::grab_captures {
  no warnings 'closure'; no strict 'vars';
  package Eval::WithLexicals::VarScope;!;
  # rest is appended by Eval::WithLexicals::Util::capture_list, called
  # during parsing by the BEGIN block from capture_code.

  $self->_eval_do(\$current_code, $self->lexicals, $to_eval);
  $self->_run(\&Eval::WithLexicals::Cage::current_line);
}

sub _run {
  my($self, $code) = @_;

  my @ret;
  my $ctx = $self->context;
  if ($ctx eq 'list') {
    @ret = $code->();
  } elsif ($ctx eq 'scalar') {
    $ret[0] = $code->();
  } else {
    $code->();
  }
  $self->lexicals({
    %{$self->lexicals},
    %{$self->_grab_captures},
  });
  @ret;
}

sub _grab_captures {
  my ($self) = @_;
  my $cap = Eval::WithLexicals::Cage::grab_captures();
  foreach my $key (keys %$cap) {
    my ($sigil, $name) = $key =~ /^(.)(.+)$/;
    my $var_scope_name = $sigil.'Eval::WithLexicals::VarScope::'.$name;
    if ($cap->{$key} eq eval "\\${var_scope_name}") {
      delete $cap->{$key};
    }
  }
  $cap;
}

sub _eval_do {
  my ($self, $text_ref, $lexical, $original) = @_;
  local @INC = (sub {
    if ($_[1] eq '/eval_do') {
      open my $fh, '<', $text_ref;
      $fh;
    } else {
      ();
    }
  }, @INC);
  do '/eval_do' or die $@;
}

{
  package Eval::WithLexicals::Util;

  use B qw(svref_2object);

  sub capture_list {
    my $pad_capture = \&Eval::WithLexicals::Cage::pad_capture;
    my @names = grep $_ ne '&', map $_->PV, grep $_->isa('B::PV'),
      svref_2object($pad_capture)->OUTSIDE->PADLIST->ARRAYelt(0)->ARRAY;
    $Eval::WithLexicals::Role::Eval::current_code .=
      '+{ '.join(', ', map "'$_' => \\$_", @names).' };'
      ."\n}\n}\n1;\n";
  }
}

1;
