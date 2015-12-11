package Fuhbot::Plugin::Checkin  0.1 {
  use Fuhbot::Plugin;
  use Fuhbot::Util qw/timeago/;
  use AnyEvent::IRC::Util qw/split_prefix/;
  use List::Util qw{any};
  use DateTime;
  use JSON::XS;

  on event privmsg => sub ($self, $irc, $msg) {
    my ($nick) = split_prefix $msg->{prefix};
    $nick =~ s/_+$//;

    my $watchlist = $self->config("members");

    if (any {lc $_ eq lc $nick} @$watchlist) {
      my $key = lc join "-", "status", $self->config("groupname");
      my $dayend = DateTime->now->add(days => 1)->truncate(to => "day");
      $self->brain->sadd($key, $nick, sub {});
      $self->brain->expireat($key, $dayend->epoch);
    }
  };

  on command qr{status} => sub ($self, $irc, $chan) {
    my $key = lc join "-", "status", $self->config("groupname");

    $self->brain->smembers($key, sub ($members) {
      my $watchlist = $self->config("members");
      my @missing;

      for my $watch (@$watchlist) {
        if (! any {$_ eq $watch} @$members) {
          push @missing, $watch;
        }
      }

      $irc->send_srv(PRIVMSG => $chan, scalar(@missing) . " have not checked in yet!");
      $irc->send_srv(PRIVMSG => $chan, join ", ", @missing) if @missing;
    });
  };
}

1;
