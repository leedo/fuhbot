use v5.14;

package Fuckbot::Plugin::Insult 0.1 {
  use parent 'Fuckbot::Plugin';

  sub commands {qw/insult add_insult/}

  sub insult {
    my ($self, $irc, $chan, $nick) = @_;

    $nick ||= $chan;
    $nick =~ s/^\s+//;
    $nick =~ s/\s+$//;

    my $insult = $self->brain->srandmember("insults");
    if ($insult) {
      $irc->send_srv(PRIVMSG => $chan, "hey $nick, $insult");
    }
    else {
      $irc->send_srv(PRIVMSG => $chan, "I don't have any insults yet");
    }
  }

  sub add_insult {
    my ($self, $irc, $chan, $insult) = @_;
    $self->brain->sadd("insults", $insult);
    $irc->send_srv(PRIVMSG => $chan, "ok!");
  }
}

1;
