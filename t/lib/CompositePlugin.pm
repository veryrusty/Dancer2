package t::lib::CompositePlugin;
use Dancer2::Plugin;

use t::lib::FooPlugin;
use t::lib::Hookee;

register 'composite' => sub {
    return p_config; # From FooPlugin  
};

register_plugin;

1;