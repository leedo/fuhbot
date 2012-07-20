use v5.14;

package Fuckbot::Plugin::ChefClient 0.1 {
  use parent 'Fuckbot::Plugin';
  use AnyEvent::Util ();
  use Fuckbot::Util;

  sub prepare_plugin {
    my $self = shift;
    $self->{command} = $self->config("command") || "chef-client";
    $self->{lines}  = [];
  }

  sub commands {
    qw/deploy_cancel deploy_start deploy_status/
  }

  sub deploy_cancel {
    my ($self, $irc, $chan) = @_;

    if ($self->{cv}) {
      delete $self->{cv};
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
      $irc->send_srv(PRIVMSG => $chan, "deploying (" . scalar $self->errors . " errors)");
      Fuckbot::Util::gist "deploy-$self->{time}.txt",
        join("\n", @{$self->{lines}}),
        sub { $self->broadcast(shift) };
    }
    else {
      $irc->send_srv(PRIVMSG => $chan, "idle");
    }
  }

  sub errors {
    my $self = shift;
    grep {/ERROR: /} @{$self->{lines}};
  }

  sub spawn_deploy {
    my $self = shift;

    $self->{lines} = [];
    $self->{time} = time;

    $self->{cv} = AnyEvent::Util::run_cmd $self->{command},
      '>' => sub {
        my @lines = split "\n", shift;
        $self->broadcast($_) for grep {/ERROR: /} @lines;
        push @{$self->{lines}}, @lines;
      };

    $self->{cv}->cb(sub {
      delete $self->{cv};
      $self->broadcast("deploy complete (" . scalar $self->errors . " errors)");
      Fuckbot::Util::gist "deploy-$self->{time}.txt",
        join("\n", @{$self->{lines}}),
        sub { $self->broadcast(shift) };
    });
  }
}

1;
