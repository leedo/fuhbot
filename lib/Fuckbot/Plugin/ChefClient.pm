use v5.14;

package Fuckbot::Plugin::ChefClient 0.1 {
  use parent 'Fuckbot::Plugin';
  use AnyEvent::Util ();

  sub commands {qw/deploy/}

  sub deploy {
    my ($self, $irc, $chan, $action) = @_;

    given ($action) {
      when ("cancel") {
        if ($self->{cv}) {
          delete $self->{cv};
          $self->broadcast("deploy canceled");
        }
        else {
          $irc->send_srv(PRIVMSG => $chan, "no deploy in progress");
        }
      }
      when ("start") {
        $irc->send_srv(PRIVMSG => $chan, "deploy already in progress");
      }
      default {
        if ($self->{cv}) {
          $irc->send_srv(PRIVMSG => $chan, "deploying");
          if ($self->{last_line}) {
            $irc->send_srv(PRIVMSG => $chan, "last line: " . $self->{last_line});
          }
        }
        else {
          $irc->send_srv(PRIVMSG => $chan, "idle");
        }
      }
    }
  }


  sub spawn_deploy {
    my $self = shift;
    $self->{cv} = AnyEvent::Util::run_cmd [qw/chef-client/],
      on_prepare => sub {
        $self->broadcast("starting deploy");
      },
      '>' => sub {
        my @lines = split "\n", shift;
        $self->{last_line} = $lines[-1];
      },
      '2>' => sub {
        my @lines = split "\n", shift;
        $self->broadcast(@_) for @lines;
        $self->{last_line} = $lines[-1];
      };

    $self->{cv}->cb(sub {
      delete $self->{cv};
      delete $self->{last_line};
      $self->broadcast("deploy complete");
    });
  }
}