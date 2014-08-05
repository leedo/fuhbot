package Fuhbot::Plugin::Seen  0.1 {
  use Fuhbot::Plugin;
  use Fuhbot::Util qw/timeago/;
  use AnyEvent::IRC::Util qw/split_prefix/;
  use JSON::XS;

  on event privmsg => sub  ($self, $irc, $msg) {
    my $chan = $msg->{params}[0];
    my ($nick) = split_prefix $msg->{prefix};
    $nick =~ s/_+$//;
    my $key = join "-", $nick, $chan, $irc->name;
    my $line = "< $nick> $msg->{params}[-1]";
    $self->brain->set(lc $key, encode_json [time, $line], sub {});
  };

  on command qr{seen\s+([^\s]+)} => sub  ($self, $irc, $chan, $nick) {
    $nick =~ s/_+$//;

    my $key = join "-", $nick, $chan, $irc->name;
    $self->brain->get(lc $key, sub  ($data) {

      if (!$data) {
        $irc->send_srv(PRIVMSG => $chan, "$nick has not been seen in $chan");
        return;
      }

      my ($time, $message) = @{ decode_json $data };
      my $when = timeago $time;

      $irc->send_srv(PRIVMSG => $chan, "$nick was last seen in $chan $when");
      $irc->send_srv(PRIVMSG => $chan, $message);
    });
  };
}

1;
