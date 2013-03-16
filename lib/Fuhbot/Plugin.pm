use v5.14;

package Fuhbot::Plugin 0.1 {
  sub import {
    my ($package) = caller;
    return if $package eq "Fuhbot";

    no strict "refs";
    no warnings 'redefine';
    push @{"$package\::ISA"}, "Fuhbot::Plugin";

    @{"$package\::COMMANDS"} = ();
    *{"$package\::command"}  = sub { push @{"$package\::COMMANDS"}, [@_] };
    *{"$package\::commands"} = sub { return @{"$package\::COMMANDS"} };

    @{"$package\::ROUTES"} = ();
    *{"$package\::get"} = sub { push @{"$package\::ROUTES"}, [get => @_] };
    *{"$package\::post"} = sub { push @{"$package\::ROUTES"}, [ post => @_] };
    *{"$package\::routes"} = sub { return @{"$package\::ROUTES"} };

    @{"$package\::EVENTS"} = ();
    *{"$package\::event"} = sub { push @{"$package\::EVENTS"}, [@_] };
    *{"$package\::events"} = sub { return @{"$package\::EVENTS"} };
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
      $args{shorten_format} = $fmt;
    }
    Fuhbot::Util::shorten($url, %args, $cb);
  }
}

1;
