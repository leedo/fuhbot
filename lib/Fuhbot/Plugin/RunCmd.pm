use v5.14;

package Fuhbot::Plugin::RunCmd 0.1 {
  use Fuhbot::Plugin;
  use AnyEvent::Util;

  sub prepare_plugin {
    my $self = shift;
    $self->{jobs} = {};

    if (my $commands = $self->config("commands")) {
      for my $command (@$commands) {
        my ($name, $pattern, $line) = @$command;
        on command $pattern => sub {
          my ($self, $irc, $chan, @args) = @_;
          if ($self->{jobs}{$name}) {
            return $irc->send_srv(PRIVMSG => $chan, "$name is already running");
          }

          $self->{jobs}{$name} = run_cmd sprintf($line, @args),
            '>' => sub {
              my @lines = grep {$_} split qr{\015?\012}, $_[0];
              $irc->send_srv(PRIVMSG => $chan, $_) for @lines;
            };

          $self->{jobs}{$name}->cb(sub {
            delete $self->{jobs}{$name};
          });
        };
      }
    }
  }
}

1;
