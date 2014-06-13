package Eval::WithLexicals::WithPackagePersistence;
use Moo::Role;
use Sub::Quote;

our $VERSION = '1.002000'; # 1.2.0
$VERSION = eval $VERSION;

around eval => sub {
  my $orig = shift;
  my($self) = @_;

  local *Eval::WithLexicals::Cage::package;
  my @ret = $orig->(@_);
  $self->in_package(Eval::WithLexicals::Cage::package());
  @ret;
};

around capture_code => sub {
  my $orig = shift;
  my($self) = @_;

  return (
    q{
      sub Eval::WithLexicals::Cage::package {
        __PACKAGE__;
      }
    },
    $orig->(@_),
  )
};

1;
