use v5.14;

package Fuhbot::Plugin::URLTitle {
  use parent 'Fuhbot::Plugin';

  use AnyEvent::IRC::Util;
  use AnyEvent::HTTP;
  use HTML::Entities;
  use IRC::Formatting::HTML;
  use Encode;

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
          if (my ($title) = $body =~ m{<title>(.+?)</title>}) {
            $title = IRC::Formatting::HTML::html_to_irc($title);
            my $encoded = encode "utf8", decode_entities decode "utf8", $title;
            $irc->send_srv(PRIVMSG => $chan, $encoded);
          }
        }
      }
    }
  }
}

1;
