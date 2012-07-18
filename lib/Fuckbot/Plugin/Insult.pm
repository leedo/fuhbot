use v5.14;

package Fuckbot::Plugin::Insult 0.1 {
  use parent 'Fuckbot::Plugin';

  sub commands {qw/insult add_insult/}

  sub insult {
    my ($self, $irc, $chan, $nick) = @_;

    $nick ||= $chan;
    $nick =~ s/^\s+//;
    $nick =~ s/\s+$//;

    my $cv = $self->brain->srandmember("insults");
    $cv->cb(sub {
      my $insult = $_[1] || "I don't have an insult";
      $irc->send_srv(PRIVMSG => $chan, "hey $nick, $insult");
    });
  }

  sub add_insult {
    my ($self, $irc, $chan, $insult) = @_;
    my $cv = $self->brain->sadd("insults", $insult);
    $cv->cb(sub {
      $irc->send_srv(PRIVMSG => $chan, "ok!");
    });
  }
}

1;
