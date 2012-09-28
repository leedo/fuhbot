use v5.14;

package Fuhbot::Plugin::Seen  0.1 {
  use parent 'Fuhbot::Plugin';

  use AnyEvent::IRC::Util ();
  use JSON::XS ();

  sub commands {qw/seen/}

  sub irc_privmsg {
    my ($self, $irc, $msg) = @_;
    my $chan = $msg->{params}[0];
    my ($nick) = AnyEvent::IRC::Util::split_prefix $msg->{prefix};
    my $key = join "-", $nick, $chan, $irc->name;
    $self->brain->set($key, JSON::XS::encode_json [time, $msg->{params}[-1]], sub {});
  }

  sub seen {
    my ($self, $irc, $chan, $nick) = @_;

    if (!$nick) {
      $irc->send(PRIVMSG => $chan, "gimme a nick");
      return;
    }

    my $key = join "-", $nick, $chan, $irc->name;
    $self->brain->get($key, sub {
      my ($data) = @_;

      if (!$data) {
        $irc->send_srv(PRIVMSG => $chan, "$nick has not been seen in $chan");
        return;
      }

      my ($time, $message) = @{ JSON::XS::decode_json $data };
      my @date = (localtime($time))[4,3,5,2,1];
      $date[2] += 1900;
      my $when = sprintf "on %02d/%02d/%02d at %02d:%02d", @date;

      $irc->send_srv(PRIVMSG => $chan, "$nick was last seen in $chan $when");
      $irc->send_srv(PRIVMSG => $chan, "< $nick> $message");
    });
  }
}

1;
