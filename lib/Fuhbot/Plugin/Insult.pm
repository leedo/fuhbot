use v5.14;

package Fuhbot::Plugin::Insult 0.1 {
  use Fuhbot::Plugin;

  on command qr{(insult|praise)\s*(.*)} => sub {
    my ($self, $irc, $chan, $type, $nick) = @_;
    if (!$nick) {
      my @nicks = keys %{$irc->channel_list($chan) || {}};
      return unless @nicks;
      $nick = @nicks[rand @nicks];
    }
    $nick =~ s/^\s+//;
    $nick =~ s/\s+$//;
    $self->brain->srandmember($type . "s", sub {
      my $insult = $_[0];
      if ($insult) {
        $self->brain->setex("last-$chan-$type", 300, $insult);
        $irc->send_srv(PRIVMSG => $chan, "hey $nick, $insult");
      }
      else {
        $irc->send_srv(PRIVMSG => $chan, "I don't have any");
      }
    });
  };

  on command qr{(add|rem) (insult|praise)\s+(.+)} => sub {
    my ($self, $irc, $chan, $action, $type, $insult) = @_;
    my $m = "s$action";
    $self->brain->$m($type . "s", $insult, sub {
      $self->brain->setex("last-$chan-$type", 300, $insult);
      $irc->send_srv(PRIVMSG => $chan, "ok!");
    });
  };

  on command qr{rem last(insult|praise)} => sub {
    my ($self, $irc, $chan, $type) = @_;
    $self->brain->get("last-$chan-$type", sub {
      my $insult = $_[0];
      if ($insult) {
        $self->brain->srem($type."s", $insult, sub {
          $self->brain->del("last-$chan-$type");
          $irc->send_srv(PRIVMSG => $chan, "removed \"$insult\"");
        });
      }
      else {
        $irc->send_srv(PRIVMSG => $chan, "no recent insult to remove");
      }
    });
  };
}

1;
