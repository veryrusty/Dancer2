use Test::More;
use strict;
use warnings;

subtest yaml_session_as_object => sub {
    use File::Spec;
    use File::Basename 'dirname';
    use Dancer::Session::YAML;

    my $dir =
      File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), 'sessions'));
    my $s = Dancer::Session::YAML->new(session_dir => $dir);

    ok(-d $dir, 'session dir is created');
    isnt $s->id, '', 'session id is set';

    my $id = $s->id;
    my $file = File::Spec->catfile($dir, "$id.yml");

    $s->write('foo' => 42);
    is($s->read('foo'), 42, 'read');

    ok($s->flush, 'flush session');
    ok(-r $file,  'session file is created');

    my $s2 = $s->retrieve($id);

    is_deeply $s2, $s, "session retrieved with id $id";

    is($s2->read('foo'), 42, 'read');

# cleanup
    unlink $file or die "unable to rm $file : $!";
    rmdir $dir   or die "unable to rmdir $dir : $!";
};

subtest "session from a Dancer app" => sub {
    my $sid;
    {
        package App;
        use Dancer 2;

        set session => 'Simple';
        
        get '/session_id' => sub {
            $sid = session->id;
        };

        get '/set_session' => sub {
            session foo => 42;
        };

        get '/without_session_call' => sub {
            "here"
        };

        get '/with_many_session_calls' => sub {
            session a => 1;
            session b => 2;
            session 'foo';
        };

    }

    use Dancer::Test 'App';

    route_exists '/session_id';
    isnt $sid, undef, "Session id has been set";

    response_headers_are_deeply [GET => '/set_session'],
      [ 'Content-Length' => 2,
        'Content-Type'   => 'text/html; charset=UTF-8',
        'Server'         => 'Perl Dancer',
        "Set-Cookie"     => "dancer.session=$sid; HttpOnly"
      ],
      "The session ID is set only once";
};

done_testing;
