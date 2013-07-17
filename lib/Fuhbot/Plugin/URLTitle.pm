use v5.14;

package Fuhbot::Plugin::URLTitle {
  use Fuhbot::Plugin;
  use Fuhbot::Util;

  use AnyEvent::IRC::Util qw/prefix_nick/;
  use HTML::Entities;
  use IRC::Formatting::HTML qw/html_to_irc/;
  use Encode;

  on event privmsg => sub {
    my ($self, $irc, $msg) = @_;
    my ($chan, $text) = @{$msg->{params}};
    if ($text =~ m{(https?://[^\s]+)}) {
      my $url = $1;
      if ($chan eq $irc->nick) {
        $chan = prefix_nick $msg->{prefix};
      }
      Fuhbot::Util::resolve_title $url, sub {
        my $title = shift;
        if ($title) {
          $irc->send_srv(PRIVMSG => $chan, html_to_irc $title);
        }
      }
    }
  };
}

1;
