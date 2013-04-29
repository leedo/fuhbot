use v5.14;

package Fuhbot::Plugin 0.1 {
  sub import {
    my ($package) = caller;
    return if $package eq "Fuhbot";

    no strict "refs";
    no warnings 'redefine';

    push @{"$package\::ISA"}, "Fuhbot::Plugin";

    my $stash = {commands => [], routes => [], events => []};
    my $on = sub {
      my ($type, $val) = @_;
      my $handlers = $stash->{$type};
      if (defined $val) {
        push @$handlers, $val;
      }
      return @$handlers;
    };

    *{"$package\::on"}       = $on;
    *{"$package\::events"}   = sub { $on->("events") };
    *{"$package\::commands"} = sub { $on->("commands") };
    *{"$package\::routes"}   = sub { $on->("routes") };
    *{"$package\::command"}  = sub { "commands", [@_] };
    *{"$package\::get"}      = sub { "routes", [get => @_] };
    *{"$package\::post"}     = sub { "routes", [post => @_] };
    *{"$package\::event"}    = sub { "events", [@_] };
  }

  sub new {
    my $class = shift;
    bless {@_}, $class;
  }

  sub prepare_plugin {}

  sub name {
    my $self = shift;
    return $self->config("name");
  }

  sub brain {
    return $_[0]->{brain};
  }

  sub config {
    my ($self, $key) = @_;
    if ($key) {
      return $self->{config}{$key};
    }
    return $self->{config};
  }

  sub broadcast {
    my ($self, @msgs) = @_;
    if (@msgs) {
      $self->{broadcast}->($_, $self->config("ircs")) for @msgs;
    }
  }

  sub shorten {
    my $cb = pop;
    my ($self, $url, %args) = @_;
    if (my $fmt = $self->config("shorten_format")) {
      $args{format} = $fmt;
    }
    Fuhbot::Util::shorten($url, %args, $cb);
  }
}

1;
