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
    $self->brain->srandmember("insults", sub {
      my $insult = shift;
      $irc->send_srv(PRIVMSG => $chan, "hey $nick, $insult");
    });
  }

  sub add_insult {
    my ($self, $irc, $chan, $insult) = @_;
    $self->brain->sadd("insults", $insult);
    $irc->send_srv(PRIVMSG => $chan, "ok!");
  }
}

1;
