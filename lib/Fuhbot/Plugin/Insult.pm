use v5.14;

package Fuhbot::Plugin::Insult 0.1 {
  use Fuhbot::Plugin;
  use Encode;

  on command qr{insult\s*(.*)} => sub {
    my ($self, $irc, $chan, $nick) = @_;
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
  };

  on command qr{add insult\s+(.+)} => sub {
    my ($self, $irc, $chan, $insult) = @_;
    $self->brain->sadd("insults", $insult, sub {
      $irc->send_srv(PRIVMSG => $chan, "ok!");
    });
  };
}

1;
