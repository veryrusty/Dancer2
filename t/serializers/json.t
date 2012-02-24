use strict;
use warnings;
use Test::More;

use Dancer::Factory::Engine;

plan tests => 3;

my $serializer = Dancer::Factory::Engine->create(
    serializer => 'JSON', 
);

ok $serializer;
is $serializer->content_type, 'application/json';

my $data = {foo => 'bar'};

is $serializer->serialize($data), '{"foo":"bar"}';