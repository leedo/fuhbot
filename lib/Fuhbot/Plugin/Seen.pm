use v5.14;
use warnings;
use mop;

use Fuhbot::Util qw/timeago command event/;
use AnyEvent::IRC::Util qw/split_prefix/;
use JSON::XS;

class Fuhbot::Plugin::Seen extends Fuhbot::Plugin {
  method privmsg ($irc, $msg) is event {
    my $chan = $msg->{params}[0];
    my ($nick) = split_prefix $msg->{prefix};
    my $key = join "-", $nick, $chan, $irc->name;
    my $line = "< $nick> $msg->{params}[-1]";
    $self->brain->set(lc $key, encode_json [time, $line], sub {});
  }

  method seen ($irc, $chan, $nick) is command(qr{seen\s+([^\s]+)}) {
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

      my ($time, $message) = @{ decode_json $data };
      my $when = timeago $time;

      $irc->send_srv(PRIVMSG => $chan, "$nick was last seen in $chan $when");
      $irc->send_srv(PRIVMSG => $chan, $message);
    });
  }
}

1;
