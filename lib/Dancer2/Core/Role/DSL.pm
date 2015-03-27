package Dancer2::Core::Role::DSL;
# ABSTRACT: Role for DSL

use Moo::Role;
use Dancer2::Core::Types;
use Carp 'croak';
use Scalar::Util qw();

with 'Dancer2::Core::Role::Hookable', 'Dancer2::Core::Role::Exporter';

has app => ( is => 'ro', required => 1 );

has keywords => (
    is      => 'rw',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_dsl_keywords',
);

sub supported_hooks { }

sub _build_dsl_keywords {
    my ($self) = @_;
    $self->can('dsl_keywords')
      ? $self->dsl_keywords
      : {};
}

sub register {
    my ( $self, $keyword, $is_global ) = @_;
    my $keywords = $self->keywords;
    my $pkg = ref($self);
    $pkg =~ s/__WITH__.+$//;

    if ( exists $keywords->{$keyword} ) {
        my $reg_pkg = $keywords->{$keyword}{'pkg'};
        $reg_pkg =~ s/__WITH__.+$//;
        $reg_pkg eq $pkg and return;

        croak "[$pkg] Keyword $keyword already registered by $reg_pkg";
    }

    $keywords->{$keyword} = { is_global => $is_global, pkg => $pkg };
}

sub dsl { $_[0] }

1;
