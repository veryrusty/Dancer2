use strict;
use warnings;
use Test::More tests => 10;

use Dancer::Core::Hook;

my $h = Dancer::Core::Hook->new(name => 'before_template', code => sub { 'BT' });
is $h->name, 'before_template_render';
is $h->code->(), 'BT';

{
    package Foo;
    use Moo;
    with 'Dancer::Core::Role::Hookable';
}

my $f = Foo->new;

use Try::Tiny;
try   { $f->execute_hooks()                         }
catch { like $_, qr{execute_hook needs a hook name} };

try   { $f->execute_hooks('foobar')               }
catch { like $@, qr{Hook 'foobar' does not exist} };

my $count = 0;
my $some_hook = Dancer::Core::Hook->new(
    name => 'foobar',
    code => sub {
        $count++;
    }
);

try   { $f->add_hook($some_hook) }
catch { like $_, qr{Hook 'foobar' must be installed first};

$f->install_hooks('foobar');

try   { $f->install_hooks('foobar') }
catch { like $_, qr{Hook 'foobar' is already registered, please use another name};

eval { $f->add_hook($some_hook)};
is $@, '';

$f->execute_hooks('foobar');
is $count, 1;

eval { $f->replace_hooks('doesnotexist', []) };
like $@, qr{Hook 'doesnotexist' must be installed first};

my $new_hooks = [sub {$count--}, sub {$count--}, sub {$count--}];
$f->replace_hooks('foobar',$new_hooks);
$f->execute_hooks('foobar');
is $count, -2;
