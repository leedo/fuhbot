use v5.14;

package Fuckbot::Plugin::URLTitle {
  use parent 'Fuckbot::Plugin';

  use AnyEvent::IRC::Util;
  use AnyEvent::HTTP;
  use HTML::Entities;

  sub irc_privmsg {
    my ($self, $irc, $msg) = @_;
    my ($chan, $text) = @{$msg->{params}};
    if ($text =~ m{(https?://[^\s]+)}) {
      my $url = $1;
      if ($chan eq $irc->nick) {
        $chan = AnyEvent::IRC::Util::prefix_nick($msg->{prefix});
      }
      AnyEvent::HTTP::http_get $url, sub {
        my ($body, $headers) = @_;
        if ($headers->{Status} == 200) {
          my ($title) = $body =~ m{<title>([^<]+)<};
          $irc->send_srv(PRIVMSG => $chan, decode_entities $title);
        }
      }
    }
  }
}

1;
