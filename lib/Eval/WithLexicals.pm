package Eval::WithLexicals;

use Moo;

our $VERSION = '1.001000'; # 1.1.0
$VERSION = eval $VERSION;

with 'Eval::WithLexicals::Role::Eval';
with 'Eval::WithLexicals::Role::PreludeEachTime';

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
    prelude => 'use warnings',       # default 'use strictures 1'
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

=head2 prelude

Code to run before evaling code. Loads L<strictures> by default.

  my $current_prelude = $eval->prelude;

  $eval->prelude(q{use warnings}); # only warnings, not strict.

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
