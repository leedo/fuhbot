use v5.14;

package Fuckbot::Plugin::Insult 0.1 {
  use parent 'Fuckbot::Plugin';

  sub commands {
    my $self = shift;
    ( ["insult" => sub { $self->insult(@_) }],
      ["add insult" => sub { $self->add_insult(@_) }],
    );
  }

  sub insult {
    my ($self, $irc, $chan, $nick) = @_;

    $nick ||= $chan;
    $nick =~ s/^\s+//;
    $nick =~ s/\s+$//;

    my $insult = $self->brain->srandmember("insults");
    $irc->send_srv(PRIVMSG => $chan, "hey $nick, $insult");
  }

  sub add_insult {
    my ($self, $irc, $chan, $insult) = @_;
    $self->brain->sadd("insults", $insult);
    $irc->send_srv(PRIVMSG => $chan, "ok!");
  }
}

1;
