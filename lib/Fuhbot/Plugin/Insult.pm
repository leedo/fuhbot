use v5.14;
use warnings;
use mop;

class Fuhbot::Plugin::Insult extends Fuhbot::Plugin {
  method insult ($irc, $chan, $nick) is command(qr{insult\s*(.*)}) {
    if (!$nick) {
      my @nicks = keys %{$irc->channel_list($chan) || {}};
      return unless @nicks;
      $nick = @nicks[rand @nicks];
    }
    $nick =~ s/^\s+//;
    $nick =~ s/\s+$//;
    $self->brain->srandmember("insults", sub {
      my $insult = $_[0] || "I don't have an insult";
      $irc->send_srv(PRIVMSG => $chan, "hey $nick, $insult");
    });
  }

  method add ($irc, $chan, $insult) is command(qr{add insult\s+(.+)}) {
    $self->brain->sadd("insults", $insult, sub {
      $irc->send_srv(PRIVMSG => $chan, "ok!");
    });
  }
}

1;
