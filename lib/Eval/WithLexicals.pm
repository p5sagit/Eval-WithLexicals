package Eval::WithLexicals;

use Moo;
use Sub::Quote;

our $VERSION = '1.001000'; # 1.1.0
$VERSION = eval $VERSION;

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
#line 1 "(eval)"
${to_eval}
;sub Eval::WithLexicals::Cage::pad_capture { }
BEGIN { Eval::WithLexicals::Util::capture_list() }
sub Eval::WithLexicals::Cage::grab_captures {
  no warnings 'closure'; no strict 'vars';
  package Eval::WithLexicals::VarScope;!;
  $self->_eval_do(\$current_code, $self->lexicals, $to_eval);
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
  my ($self, $text_ref, $lexicals, $original) = @_;
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
    $Eval::WithLexicals::current_code .=
      '+{ '.join(', ', map "'$_' => \\$_", @names).' };'
      ."\n}\n}\n1;\n";
  }
}

=head1 NAME

Eval::WithLexicals - pure perl eval with persistent lexical variables

=head1 SYNOPSIS

  # file: bin/tinyrepl

  #!/usr/bin/env perl

  use strictures 1;
  use Eval::WithLexicals;
  use Term::ReadLine;
  use Data::Dumper;

  $SIG{INT} = sub { warn "SIGINT\n" };

  { package Data::Dumper; no strict 'vars';
    $Terse = $Indent = $Useqq = $Deparse = $Sortkeys = 1;
    $Quotekeys = 0;
  }

  my $eval = Eval::WithLexicals->new;
  my $read = Term::ReadLine->new('Perl REPL');
  while (1) {
    my $line = $read->readline('re.pl$ ');
    exit unless defined $line;
    my @ret; eval {
      local $SIG{INT} = sub { die "Caught SIGINT" };
      @ret = $eval->eval($line); 1;
    } or @ret = ("Error!", $@);
    print Dumper @ret;
  }

  # shell session:

  $ perl -Ilib bin/tinyrepl 
  re.pl$ my $x = 0;
  0
  re.pl$ ++$x;
  1
  re.pl$ $x + 3;
  4
  re.pl$ ^D
  $

=head1 METHODS

=head2 new

  my $eval = Eval::WithLexicals->new(
    lexicals => { '$x' => \1 },      # default {}
    in_package => 'PackageToEvalIn', # default Eval::WithLexicals::Scratchpad
    context => 'scalar',             # default 'list'
  );

=head2 eval

  my @return_value = $eval->eval($code_to_eval);

=head2 lexicals

  my $current_lexicals = $eval->lexicals;

  $eval->lexicals(\%new_lexicals);

=head2 in_package

  my $current_package = $eval->in_package;

  $eval->in_package($new_package);

=head2 context

  my $current_context = $eval->context;

  $eval->context($new_context); # 'list', 'scalar' or 'void'

=head1 AUTHOR

Matt S. Trout <mst@shadowcat.co.uk>

=head1 CONTRIBUTORS

David Leadbeater <dgl@dgl.cx>

=head1 COPYRIGHT

Copyright (c) 2010 the Eval::WithLexicals L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.

=cut

1;
