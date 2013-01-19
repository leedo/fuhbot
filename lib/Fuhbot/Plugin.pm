use v5.14;

package Fuhbot::Plugin 0.1 {
  sub import {
    my ($package) = caller;
    return if $package eq "Fuhbot";
    no strict "refs";
    no warnings 'redefine';
    push @{"$package\::ISA"}, "Fuhbot::Plugin";
    @{"$package\::COMMANDS"} = ();
    *{"$package\::command"}  = sub { push @{"$package\::COMMANDS"}, @_ };
    *{"$package\::commands"} = sub { return @{"$package\::COMMANDS"} };
  }

  sub new {
    my $class = shift;
    bless {@_}, $class;
  }

  sub prepare_plugin {}

  sub command_callbacks {
    my $self = shift;

    # build commands list
    $self->{commands} ||= do {
      my @commands;
      my %commands = $self->commands;
      while (my ($command, $cb) = each %commands) {
        push @commands, [$command, sub {$cb->($self, @_)}];
      }
      \@commands;
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
    $cb->() if $cb;
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
