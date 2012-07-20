use v5.14;

package Fuckbot::Plugin 0.1 {
  sub new {
    my $class = shift;
    bless {@_}, $class;
  }

  sub prepare_plugin {}
  sub commands {()}

  sub command_callbacks {
    my $self = shift;

    # build commands list
    $self->{commands} ||= do {
      my @commands;
      for my $command ($self->commands) {
        if (ref($command) eq "ARRAY") {
          push @commands, $command;
        }
        else {
          my $method = $command;
          $command =~ s/_/ /g;
          push @commands, [$command, sub { $self->$method(@_) }];
        }
      }
      [@commands];
    };

    return @{$self->{commands}};
  }

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

  sub shutdown {
    my ($self, $cb) = @_;
    $cb->();
  }
}

1;
