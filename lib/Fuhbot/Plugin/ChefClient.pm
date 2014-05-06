use v5.14;

package Fuhbot::Plugin::ChefClient 0.1 {
  use Fuhbot::Plugin;
  use AnyEvent::Util;
  use Fuhbot::Util qw/gist/;

  sub prepare_plugin {
    my $self = shift;
    $self->{jobs} = {};
  }

  on command qr{deploy (?:cancel (\S+)|(\S+) cancel)} => sub {
    my ($self, $irc, $chan, $target) = @_;

    if ($self->job($target)) {
      delete $self->{jobs}{$target};
      $self->broadcast("$target: deploy canceled");
    }
    else {
      $irc->send_srv(PRIVMSG => $chan, "no $target deploy in progress");
    }
  };

  on command qr{deploy (?:start (\S+)|(\S+) start)} => sub {
    my ($self, $irc, $chan, $target) = @_;

    if ($self->job($target)) {
      $irc->send_srv(PRIVMSG => $chan, "$target deploy already in progress");
    }
    else {
      $self->spawn($target);
    }
  };

  on command qr{deploy (?:status (\S+)|(\S+) status)} => sub {
    my ($self, $irc, $chan, $target) = @_;

    if (my $job = $self->job($target)) {
      $irc->send_srv(PRIVMSG => $chan, "$target: deploy in progress");
      if (scalar @{$job->{errors}}) {
        $irc->send_srv(PRIVMSG => $chan, $_) for map {"$target: $_"} @{$job->{errors}};
      }
    }
    else {
      $irc->send_srv(PRIVMSG => $chan, "$target: no deploy in progress");
    }
  };

  sub job_command {
    my ($self, $target) = @_;
    my $targets = $self->config("targets");
    if (defined $targets and defined $targets->{$target}) {
      return $targets->{$target};
    }
  }

  sub job {
    my ($self, $target) = @_;
    if (defined $self->{jobs}{$target}) {
      return $self->{jobs}{$target};
    }
  }

  sub on_read {
    my ($self, $target) = @_;

    return sub {
      my $job = $self->job($target);
      my @lines = grep {$_} split qr{\015?\012}, $_[0];
      my @errors = map {"$target: \x034\02$_"} grep {/(ERROR|BUG)/} @lines;

      $self->broadcast(@errors);
      push @{$job->{errors}}, @errors;

      if (my $channel = $self->config("output")) {
        $self->announce($channel, $_) for @lines;
      }
    };
  }

  sub on_complete {
    my ($self, $target) = @_;

    return sub {
      my $job = $self->job($target);

      $self->broadcast("$target: deploy complete (" . scalar @{$job->{errors}} . " errors)");
      delete $self->{jobs}{$target};
    };
  }

  sub spawn {
    my ($self, $target) = @_;
    my $command = $self->job_command($target);

    if (!$command) {
      return $self->broadcast("no valid deploy target named $target");
    }

    $self->broadcast("$target: starting deploy");

    $self->{jobs}{$target} = {
      errors => [],
      time  => time,
    };

    $self->{jobs}{$target}{cv} = run_cmd $command,
      '>' => $self->on_read($target);

    $self->{jobs}{$target}{cv}->cb(
      $self->on_complete($target));
  }
}

1;
