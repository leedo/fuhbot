use v5.14;

package Fuhbot::Plugin::Seen  0.1 {
  use Fuhbot::Plugin;
  use Fuhbot::Util;
  use AnyEvent::IRC::Util ();
  use JSON::XS ();


  event privmsg => sub {
    my ($self, $irc, $msg) = @_;
    my $chan = $msg->{params}[0];
    my ($nick) = AnyEvent::IRC::Util::split_prefix $msg->{prefix};
    my $key = join "-", $nick, $chan, $irc->name;
    my $line = "< $nick> $msg->{params}[-1]";
    $self->brain->set(lc $key, JSON::XS::encode_json [time, $line], sub {});
  };

  command qr{seen\s+([^\s]+)} => sub{
    my ($self, $irc, $chan, $nick) = @_;

    if (!$nick) {
      $irc->send_srv(PRIVMSG => $chan, "gimme a nick");
      return;
    }

    my $key = join "-", $nick, $chan, $irc->name;
    $self->brain->get(lc $key, sub {
      my ($data) = @_;

      if (!$data) {
        $irc->send_srv(PRIVMSG => $chan, "$nick has not been seen in $chan");
        return;
      }

      my ($time, $message) = @{ JSON::XS::decode_json $data };
      my $when = Fuhbot::Util::timeago($time);

      $irc->send_srv(PRIVMSG => $chan,
        "$nick was last seen in $chan $when"
      );
      $irc->send_srv(PRIVMSG => $chan, $message);
    });
  };
}

1;
