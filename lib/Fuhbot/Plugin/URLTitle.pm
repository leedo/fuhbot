package Fuhbot::Plugin::URLTitle {
  use Fuhbot::Plugin;
  use Fuhbot::Util;
  use AnyEvent::IRC::Util qw/prefix_nick/;
  use IRC::Formatting::HTML qw/html_to_irc/;

  on event privmsg => sub ($self, $irc, $msg) {
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
