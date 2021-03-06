package Fuhbot::Plugin::RunCmd 0.1 {
  use Fuhbot::Plugin;
  use AnyEvent::Util;

  sub prepare_plugin ($self) {
    $self->{jobs} = {};

    if (my $commands = $self->config("commands")) {
      for my $command (@$commands) {
        my ($name, $pattern, $line) = @$command;
        on command $pattern => sub ($self, $irc, $chan, @args) {
          if ($self->{jobs}{$name}) {
            return $irc->send_srv(PRIVMSG => $chan, "$name is already running");
          }

          if (ref $line and ref $line eq "CODE") {
            my @lines = $line->(@args);
            $irc->send_srv(PRIVMSG => $chan, $_) for @lines;
            return;
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
