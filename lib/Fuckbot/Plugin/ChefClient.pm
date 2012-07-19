use v5.14;

package Fuckbot::Plugin::ChefClient 0.1 {
  use parent 'Fuckbot::Plugin';
  use AnyEvent::Util ();

  sub prepare_plugin {
    my $self = shift;
    $self->{command} = $self->config("command") || "chef-client";
    $self->{errors} = [];
  }

  sub commands {
    qw/deploy deploy_cancel deploy_start deploy_status/
  }

  sub deploy_cancel {
    my ($self, $irc, $chan) = @_;

    if ($self->{cv}) {
      delete $self->{cv};
      delete $self->{last_line};
      $self->broadcast("deploy canceled");
    }
    else {
      $irc->send_srv(PRIVMSG => $chan, "no deploy in progress");
    }
  }

  sub deploy_start {
    my ($self, $irc, $chan) = @_;

    if ($self->{cv}) {
      $irc->send_srv(PRIVMSG => $chan, "deploy already in progress");
    }
    else {
      $self->broadcast("starting deploy");
      $self->spawn_deploy;
    }
  }

  sub deploy_status {
    my ($self, $irc, $chan) = @_;

    if ($self->{cv}) {
      $irc->send_srv(PRIVMSG => $chan, "deploying");
      $irc->send_srv(PRIVMSG => $chan, scalar @{$self->{errors}} . " errors");
      $irc->send_srv(PRIVMSG => $chan, "last line: " . $self->{last_line});
    }
    else {
      $irc->send_srv(PRIVMSG => $chan, "idle");
    }
  }

  sub deploy { deploy_status @_ }

  sub spawn_deploy {
    my $self = shift;
    $self->{errors} = [];
    $self->{cv} = AnyEvent::Util::run_cmd [split " ", $self->{command}],
      '>' => sub {
        my @lines = split "\n", shift;
        $self->{last_line} = $lines[-1];
      },
      '2>' => sub {
        my @lines = split "\n", shift;
        $self->broadcast(@lines);
        push @{$self->{errors}}, @lines;
        $self->{last_line} = $lines[-1];
      };

    $self->{cv}->cb(sub {
      $self->broadcast("deploy complete");
      $self->broadcast($_) for @{$self->{errors}};
      delete $self->{cv};
      delete $self->{last_line};
    });
  }
}

1;
