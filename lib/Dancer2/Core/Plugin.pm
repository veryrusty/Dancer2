# ABSTRACT: Dancer2 plugin keyword/hook registry
package Dancer2::Core::Plugin;
use Moo;

use Dancer2::Core::Types;

# Both Dancer2::Core::Role::Hookable and
# Dancer2::Core::Role::Plugin define hook_aliases.
# Explicitly define it here to resolve the conflict
has hook_aliases => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { +{} },
);

with 'Dancer2::Core::Role::Plugin',
     'Dancer2::Core::Role::Hookable',
     'Dancer2::Core::Role::Exporter';

1;
