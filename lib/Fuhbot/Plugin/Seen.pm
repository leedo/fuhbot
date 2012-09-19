use v5.14;

package Fuhbot::Plugin::Seen  0.1 {
  use parent 'Fuhbot::Plugin';

  sub commands {qw/seen/}

  sub irc_privmsg {
    my ($self, $irc, $msg) = @_;
    my $chan = $msg->{params}[0];
    my ($nick) = split_prefix $msg->{prefix};
    $self->brain->set(join "-", $nick, $chan, $irc->name, sub {});
  }

  sub seen {
    my ($self, $irc, $chan, $nick) = @_;
    $self->brain->get(join "-", $nick, $chan, $irc->name, sub {
      my ($data) = @_;
      if (!$data) {
        $irc->send_srv(PRIVMSG => $chan, "$nick has not been seen in $chan");
      }
      my ($time, $message) = decode_json $data;
      my $diff = time - $time;
      $irc->send_srv(PRIVMSG => $chan, "$nick was last seen in $chan $diff seconds ago: $message");
    });
  }
}

1;
