use v5.14;

package Fuhbot::Plugin::Insult 0.1 {
  use Fuhbot::Plugin;
  use Encode;

  on command qr{(insult|praise)\s*(.*)} => sub {
    my ($self, $irc, $chan, $action, $nick) = @_;
    if (!$nick) {
      my @nicks = keys %{$irc->channel_list($chan) || {}};
      return unless @nicks;
      $nick = @nicks[rand @nicks];
    }
    $nick =~ s/^\s+//;
    $nick =~ s/\s+$//;
    $self->brain->srandmember($action . "s", sub {
      my $insult = $_[0] || "I don't have an $action";
      $irc->send_srv(PRIVMSG => $chan, "hey $nick, $insult");
    });
  };

  on command qr{add (insult|praise)\s+(.+)} => sub {
    my ($self, $irc, $chan, $action, $insult) = @_;
    $self->brain->sadd($action . "s", $insult, sub {
      $irc->send_srv(PRIVMSG => $chan, "ok!");
    });
  };
}

1;
