package Fuhbot::Plugin::LogLines {
  use Fuhbot::Plugin;
  use Fuhbot::Util;
  use AnyEvent::IRC::Util qw/prefix_nick split_prefix/;
  use IRC::Formatting::HTML qw/html_to_irc/;

  on event privmsg => sub ($self, $irc, $msg) {
    my ($chan, $text) = @{$msg->{params}};
    my $patterns = [$self->config("patterns") || qr{(https?://[^\s]+)}];
    my ($nick) = split_prefix $msg->{prefix};
    my $key = join "-", $chan, "log";
    for my $pattern (@$patterns) {
      if ($text =~ $pattern) {
        $self->brain->lpush($key, "< $nick> $text", sub {
          $self->brain->ltrim($key, 0, 100, sub {});
        });
      }
    }
  };

  on command qr{hist\s+(.+)$} => sub ($self, $irc, $chan, $search) {
    my $key = join "-", $chan, "log";
    $self->brain->lrange($key, 0, 100, sub($rows) {
      if (my @matches = grep {/\Q$_\E/} @$rows) {
        $irc->send_srv(PRIVMSG => $chan, $_) for @matches;
      }
      else {
        $irc->send_srv(PRIVMSG => $chan, "No matches found");
      }
    });
  };
}
