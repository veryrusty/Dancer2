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

sub _count_header {
    my ($route, $header) = @_;
    
    my $counter = 0;
    my $resp = dancer_response($route);
    for (my $i = 0; $i < scalar(@{$resp->headers_to_array}); $i += 2) {
        my ($name, $value) =
          ($resp->headers_to_array->[$i], $resp->headers_to_array->[$i + 1]);
        $counter++ if $name eq $header;
    }
    return $counter;
}

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

    my $counter;

    # make sure we have only one Set-Cookie header
    $counter = _count_header('/set_session', 'Set-Cookie');
    is $counter, 1, "Set-Cookie was seen only once for /set_session";
    
    $counter = _count_header('/without_session_call', 'Set-Cookie');
    is $counter, 1, "... and also for /without_session_call";

    $counter = _count_header('/with_many_session_calls', 'Set-Cookie');
    is $counter, 1, "... and also for /with_many_session_calls";
};

done_testing;
