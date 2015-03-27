package Dancer2::Plugin;
# ABSTRACT: Extending Dancer2's DSL with plugins

use Moo::Role;
with 'Dancer2::Core::Role::Exporter';

use Carp 'carp';
use Dancer2::Core::Plugin;
use Dancer2::Core::DSL;
use Import::Into;

my $dsl_deprecation_wrapper = 0;
sub import {
    my $class  = shift;
    my $plugin = caller;
    my $caller = caller(1);

    $_->import::into($plugin) for qw(strict warnings utf8);

    my $dsl = _get_dsl();

    my $plugin_obj = Dancer2::Core::Plugin->new(
        name => $plugin,
    );
    # Export plugin DSL into $plugin
    $plugin_obj->export_symbols_to( $plugin, { keywords => $plugin_obj->plugin_dsl_keywords } );

    # Support for Dancer 1 syntax for plugin.
    # Then, compile Dancer 2's DSL keywords into self-contained keywords for the
    # plugin (actually, we call all the symbols by giving them $caller->dsl as
    # their first argument).
    # These modified versions of the DSL are then exported in the namespace of the
    # plugin.
    if ($dsl && ! grep { $_ eq ':no_dsl' } @_) {
        my $dsl_keywords = {};
        for my $symbol ( keys %{ $dsl->keywords } ) {

            # get the original symbol from the real DSL
            no strict 'refs';
            no warnings 'once';
            my $code = *{"Dancer2::Core::DSL::$symbol"}{CODE};

            # compile it with $caller->dsl
            my $compiled = sub {
                carp
                  "DEPRECATED: $plugin calls '$symbol' instead of '\$dsl->$symbol'.";
                $code->( $dsl, @_ );
            };

            $dsl_keywords->{$symbol} = {
                 code => $compiled,
                 options => {},
            };

            $dsl_deprecation_wrapper = $compiled if $symbol eq 'dsl';
        }
        $plugin_obj->export_keywords_to( $dsl_keywords, $plugin );
    }

    # register plugin if there is a dsl
    # some of the tests use plugins that are not part of Dancer2 apps.
    $dsl && $dsl->dancer_app->register_plugin( $plugin_obj );
}

sub _get_dsl {
    my $dsl;
    my $deep = 2;
    while ( my $caller = caller( $deep++ ) ) {
        my $caller_dsl = $caller->can('dsl');
        next if ! $caller_dsl || $caller_dsl == $dsl_deprecation_wrapper;
        $dsl = $caller->dsl;
        last if defined $dsl && length( ref($dsl) );
    }

    return $dsl;
}

1;

__END__

=head1 DESCRIPTION

You can extend Dancer2 by writing your own plugin. A plugin is a module that
exports a bunch of symbols to the current namespace (the caller will see all
the symbols defined via C<register>).

Note that you have to C<use> the plugin wherever you want to use its symbols.
For instance, if you have Webapp::App1 and Webapp::App2, both loaded from your
main application, they both need to C<use FooPlugin> if they want to use the
symbols exported by C<FooPlugin>.

For a more gentle introduction to Dancer2 plugins, see L<Dancer2::Plugins>.

=method register

    register 'my_keyword' => sub { ... } => \%options;

Allows the plugin to define a keyword that will be exported to the caller's
namespace.

The first argument is the symbol name, the second one the coderef to execute
when the symbol is called.

The coderef receives as its first argument the Dancer2::Core::DSL object.

Plugins B<must> use the DSL object to access application components and work
with them directly.

    sub {
        my $dsl = shift;
        my @args = @_;

        my $app     = $dsl->app;
        my $request = $app->request;

        if ( $app->session->read('logged_in') ) {
            ...
        }
    };

As an optional third argument, it's possible to give a hash ref to C<register>
in order to set some options.

The option C<is_global> (boolean) is used to declare a global/non-global keyword
(by default all keywords are global). A non-global keyword must be called from
within a route handler (eg: C<session> or C<param>) whereas a global one can be
called from everywhere (eg: C<dancer_version> or C<setting>).

    register my_symbol_to_export => sub {
        # ... some code
    }, { is_global => 1} ;

=method on_plugin_import

Allows the plugin to take action each time it is imported.
It is prototyped to take a single code block argument, which will be called
with the DSL object of the package importing it.

For example, here is a way to install a hook in the importing app:

    on_plugin_import {
        my $dsl = shift;
        $dsl->app->add_hook(
            Dancer2::Core::Hook->new(
                name => 'before',
                code => sub { ... },
            )
        );
    };

=method register_plugin

A Dancer2 plugin must end with this statement. This lets the plugin register all
the symbols defined with C<register> as exported symbols:

    register_plugin;

Register_plugin returns 1 on success and undef if it fails.

=head3 Deprecation note

Earlier version of Dancer2 needed the keyword <for_version> to indicate for
which version of Dancer the plugin was written, e.g.

    register_plugin for_versions => [ 2 ];

Today, plugins for Dancer2 are only expected to work for Dancer2 and the
C<for_versions> keyword is ignored. If you try to load a plugin for Dancer2
that does not meet the requirements of a Dancer2 plugin, you will get an error
message.

=method plugin_args

Simple method to retrieve the parameters or arguments passed to a
plugin-defined keyword. Although not relevant for Dancer 1 only, or
Dancer 2 only, plugins, it is useful for universal plugins.

  register foo => sub {
     my ($dsl, @args) = plugin_args(@_);
     ...
  }

Note that Dancer 1 will return undef as the DSL object.

=method plugin_setting

If C<plugin_setting> is called inside a plugin, the appropriate configuration
will be returned. The C<plugin_name> should be the name of the package, or,
if the plugin name is under the B<Dancer2::Plugin::> namespace (which is
recommended), the remaining part of the plugin name.

Configuration for plugin should be structured like this in the config.yml of
the application:

  plugins:
    plugin_name:
      key: value

Enclose the remaining part in quotes if it contains ::, e.g.
for B<Dancer2::Plugin::Foo::Bar>, use:

  plugins:
    "Foo::Bar":
      key: value

=method register_hook

Allows a plugin to declare a list of supported hooks. Any hook declared like so
can be executed by the plugin with C<execute_hook>.

    register_hook 'foo';
    register_hook 'foo', 'bar', 'baz';

=method execute_hook

Allows a plugin to execute the hooks attached at the given position

    execute_hook 'some_hook';

Arguments can be passed which will be received by handlers attached to that
hook:

    execute_hook 'some_hook', $some_args, ... ;

The hook must have been registered by the plugin first, with C<register_hook>.

=head1 EXAMPLE PLUGIN

The following code is a dummy plugin that provides a keyword 'logout' that
destroys the current session and redirects to a new URL specified in
the config file as C<after_logout>.

  package Dancer2::Plugin::Logout;
  use Dancer2::Plugin;

  register logout => sub {
    my $dsl  = shift;
    my $app  = $dsl->app;
    my $conf = plugin_setting();

    $app->destroy_session;

    return $app->redirect( $conf->{after_logout} );
  };

  register_plugin for_versions => [ 2 ] ;

  1;

And in your application:

    package My::Webapp;

    use Dancer2;
    use Dancer2::Plugin::Logout;

    get '/logout' => sub { logout };

=cut
