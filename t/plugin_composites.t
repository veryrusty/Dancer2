use strict;
use warnings;
use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common;
use JSON;

subtest 'plugins calling plugins' => sub {
    {
        package Composite::App;
        use Dancer2;
        use t::lib::CompositePlugin;

        get '/' => sub {
            foo_wrap_request->env->{'PATH_INFO'};
        };

        get '/app' => sub { app->name };

        get '/plugin_setting' => sub { to_json(composite) };
    }

    my $app = Composite::App->to_app;
    is( ref $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb = shift;

        is(
            $cb->( GET '/plugin_setting' )->content,
            encode_json( { plugin => "42" } ),
            'plugin_setting returned the expected config'
        );
    };
};

done_testing();
