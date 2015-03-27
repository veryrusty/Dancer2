# ABSTRACT: plugin object keyword and hook registry role
package Dancer2::Core::Role::Plugin;

use Moo::Role;
use Carp 'croak', 'carp';
use Dancer2::Core::Types;
use Dancer2::Core::DSL;

sub plugin_dsl_keywords {
    return +{
        execute_hook     => { is_global => 1 },  # from Role::Hookable
        register_hook    => { is_global => 1 },
        register_plugin  => { is_global => 1 },
        register         => { is_global => 1 },
        on_plugin_import => { is_global => 1, prototype => '&' },
        plugin_setting   => { is_global => 1 },
        plugin_args      => { is_global => 1 },
    };
}

has name => (
    is      => 'ro',
    isa     => Str,
    default => sub { (caller(1))[0] },
);

has keywords => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    default => sub { +{} },
);

has _on_import => (
    is      => 'ro',
    isa     => ArrayRef,
    default => sub { [] },
);

has _supported_hooks => (
    is      => 'ro',
    isa     => ArrayRef,
    default => sub { [] },
);

sub register {
    my ( $self, $keyword, $code, $options ) = @_;

    $options ||= { is_global => 1 };

    $keyword =~ /^[a-zA-Z_]+[a-zA-Z0-9_]*$/
      or croak "You can't use '$keyword', it is an invalid name"
      . ' (it should match ^[a-zA-Z_]+[a-zA-Z0-9_]*$ )';

    exists $self->{keywords}->{$keyword} && croak "Keyword $keyword already registerd";

    if (grep { $_ eq $keyword }
        keys %{ Dancer2::Core::DSL->dsl_keywords }
      )
    {
        croak "You can't use '$keyword', this is a reserved keyword";
    }

    $self->keywords->{$keyword} = {
        code => $code,
        options => $options,
    };
}

sub on_plugin_import {
    my ($self, $code) = @_;
    push @{ $self->_on_import }, $code;
}

sub plugin_args {
    my $self = shift;
    return @_;
};

sub plugin_setting {
    my $self = shift;
    my $caller = caller(3);
    return $caller->dsl->dancer_app->config->{'plugins'}->{$self->name} || {};
}

sub register_hook {
    my ($self, @hooks) = @_;

    my $plugin = $self->name;
    $plugin =~ s/^Dancer2::Plugin:://;
    $plugin =~ s/::/_/g;

    my $base_name = "plugin." . lc($plugin);
    for my $hook (@hooks) {
        my $hook_name = "${base_name}.$hook";

        push @{$self->_supported_hooks}, $hook_name;
        $self->hook_aliases->{$hook} = $hook_name;
    }
}

# supported hooks returns an *array*
sub supported_hooks { @{shift->_supported_hooks} }

sub register_plugin {
    my $self = shift;
    my $plugin = caller(1);

    my $caller = caller(2);
    return if !$caller->can('dsl');

# create the import method of the caller (the actual plugin) in order to make it
# imports all the DSL's keyword when it's used.
    my $import = sub {
        my $plugin = shift;
        my $caller = caller(1);

        # Export keywords to caller
        for my $keyword ( keys %{ $self->keywords } ) {
            $caller->dsl->register($keyword, $self->keywords->{$keyword}->{options});

            my $code = $self->keywords->{$keyword}->{code};
            $self->keywords->{$keyword}->{code} = sub { $code->( $caller->dsl, @_) };
        }
        $self->export_keywords_to($self->keywords, $caller);

        # call on_import subs
        for my $sub ( @{ $self->_on_import } ) {
            $sub->( $caller->dsl );
        }
    };

    {
        no strict 'refs';
        no warnings 'redefine';
        my $original_import = *{"${plugin}::import"}{CODE};
        $original_import ||= sub { };
        *{"${plugin}::import"} = sub {
            $original_import->(@_);
            $import->(@_);
        };
    }
    return 1;    #as in D1

    # The plugin is ready now.
}

1;
