use v5.14;

package Fuhbot::Plugin::ChefClient 0.1 {
  use parent 'Fuhbot::Plugin';
  use AnyEvent::Util ();
  use Fuhbot::Util;

  sub prepare_plugin {
    my $self = shift;
    $self->{command} = $self->config("command") || "chef-client";
    $self->{lines}  = [];
  }

  sub commands {
    "deploy cancel" => sub { shift->cancel(@_) },
    "deploy start"  => sub { shift->start(@_) },
    "deploy status" => sub { shift->status(@_) },
  }

  sub cancel {
    my ($self, $irc, $chan) = @_;

    if ($self->{cv}) {
      delete $self->{cv};
      $self->broadcast("deploy canceled");
    }
    else {
      $irc->send_srv(PRIVMSG => $chan, "no deploy in progress");
    }
  }

  sub start {
    my ($self, $irc, $chan) = @_;

    if ($self->{cv}) {
      $irc->send_srv(PRIVMSG => $chan, "deploy already in progress");
    }
    else {
      $self->broadcast("starting deploy");
      $self->spawn;
    }
  }

  sub status {
    my ($self, $irc, $chan) = @_;

    if ($self->{cv}) {
      $irc->send_srv(PRIVMSG => $chan, "deploying (" . scalar $self->errors . " errors)");
      $irc->send_srv($_) for @{$self->{lines}}[-5 .. -1]);
    }
    else {
      $irc->send_srv(PRIVMSG => $chan, "idle");
    }
  }

  sub errors {
    my $self = shift;
    grep {/ERROR: /} @{$self->{lines}};
  }

  sub spawn {
    my $self = shift;

    $self->{lines} = [];
    $self->{time} = time;

    $self->{cv} = AnyEvent::Util::run_cmd $self->{command},
      '>' => sub {
        my @lines = split "\n", shift;
        $self->broadcast(map {"\x034\02$_"} grep {/ERROR: /} @lines);
        push @{$self->{lines}}, @lines;
      };

    $self->{cv}->cb(sub {
      delete $self->{cv};
      $self->broadcast("deploy complete (" . scalar $self->errors . " errors)");
      Fuhbot::Util::gist "deploy-$self->{time}.txt",
        join("\n", @{$self->{lines}}),
        sub { $self->broadcast(shift) };
    });
  }
}

1;
