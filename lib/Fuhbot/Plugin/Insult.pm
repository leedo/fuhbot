use v5.14;

package Fuhbot::Plugin::Insult 0.1 {
  use Fuhbot::Plugin;

  command qr{insult\s+([^\s]+)} => sub {
    my ($self, $irc, $chan, $nick) = @_;

    $nick ||= $chan;
    $nick =~ s/^\s+//;
    $nick =~ s/\s+$//;

    $self->brain->srandmember("insults", sub {
      my $insult = $_[0] || "I don't have an insult";
      $irc->send_srv(PRIVMSG => $chan, "hey $nick, $insult");
    });
  };

  command qr{add insult\s+(.+)} => sub {
    my ($self, $irc, $chan, $insult) = @_;
    $self->brain->sadd("insults", $insult, sub {
      $irc->send_srv(PRIVMSG => $chan, "ok!");
    });
  };
}

1;
