use v5.14;

package Fuhbot::Plugin::URLTitle {
  use Fuhbot::Plugin;

  use AnyEvent::IRC::Util qw/prefix_nick/;
  use AnyEvent::HTTP;
  use HTML::Entities;
  use IRC::Formatting::HTML qw/html_to_irc/;
  use Encode;

  event privmsg => sub {
    my ($self, $irc, $msg) = @_;
    my ($chan, $text) = @{$msg->{params}};
    if ($text =~ m{(https?://[^\s]+)}) {
      my $url = $1;
      if ($chan eq $irc->nick) {
        $chan = prefix_nick $msg->{prefix};
      }
      http_get $url, sub {
        my ($body, $headers) = @_;
        if ($headers->{Status} == 200) {
          $body = decode utf8 => $body;
          if (my ($title) = $body =~ m{<title>(.+?)</title>}) {
            $title = html_to_irc decode_entities $title;
            $irc->send_srv(PRIVMSG => $chan, $title);
          }
        }
      }
    }
  };
}

1;
