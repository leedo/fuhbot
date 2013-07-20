use v5.14;
use warnings;
use mop;

class Fuhbot::PluginClass extends mop::class {
  has $commands = [];
  has $routes   = [];
  has $events   = [];

  method commands { @$commands }
  method routes   { @$routes }
  method events   { @$events }

  method add_command { push @$commands, [@_] }
  method add_route   { push @$routes, [@_] }
  method add_event   { push @$events, [@_] }
}

class Fuhbot::Plugin metaclass Fuhbot::PluginClass {
  has $broadcast is ro;
  has $brain     is ro;
  has $config;

  method prepare_plugin { }
  method config ($key) { $config->{$key} }

  method broadcast (@msgs) {
    if (@msgs) {
      $broadcast->($_, $config->{ircs}) for @msgs;
    }
  }

  method shorten ($url) {
    my $cb = pop;
    my %args = @_;
    if (my $fmt = $self->config("shorten_format")) {
      $args{format} = $fmt;
    }
    Fuhbot::Util::shorten($url, %args, $cb);
  }
}

1;
