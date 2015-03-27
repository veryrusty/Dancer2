# ABSTRACT: Role for exporting methods into callers
package Dancer2::Core::Role::Exporter;

use Moo::Role;
use Carp 'croak';

# exports new symbol to caller - requires C<keywords>.
sub export_symbols_to {
    my ($self, $caller, $args) = @_;
    my $keywords = $args->{keywords} || $self->keywords;
    my $exports = $self->_construct_export_map( $keywords, $args );
    return $self->export_keywords_to($exports, $caller);
}

sub export_keywords_to {
    my ( $self, $exports, $caller) = @_;

    ## no critic
    foreach my $export ( keys %{$exports} ) {
        no strict 'refs'; ## no critic (TestingAndDebugging::ProhibitNoStrict)
        my $existing = *{"${caller}::${export}"}{CODE};

        next if defined $existing;
        
        *{"${caller}::${export}"} = $self->_apply_prototype(
            $exports->{$export}->{code}, $exports->{$export}->{options}
        );
    }
    ## use critic

    return keys %{$exports};
}

# private
sub _compile_keyword {
    my ( $self, $keyword, $opts ) = @_;

    return $opts->{is_global}
               ? sub { $self->$keyword(@_) }
               : sub {
            croak "Function '$keyword' must be called from a route handler"
                unless defined $Dancer2::Core::Route::REQUEST;

            $self->$keyword(@_);
        };
}

sub _apply_prototype {
    my ($self, $code, $opts) = @_;

    # set prototype if one is defined for the keyword. undef => no prototype
    my $prototype;
    exists $opts->{'prototype'} and $prototype = $opts->{'prototype'};
    return Scalar::Util::set_prototype( \&$code, $prototype );
}

sub _construct_export_map {
    my ( $self, $keywords, $args ) = @_;
    my %map;
    foreach my $keyword ( keys %$keywords ) {
        # check if the keyword were excluded from importation
        $args->{ '!' . $keyword } and next;
        $map{$keyword} = {
            code => $self->_compile_keyword( $keyword, $keywords->{$keyword} ),
            options => $keywords->{$keyword},
        };
    }
    return \%map;
}

1;
