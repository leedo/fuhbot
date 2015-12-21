package Fuhbot::Plugin::Checkin  0.1 {
  use Fuhbot::Plugin;
  use AnyEvent::IRC::Util qw{split_prefix};
  use List::Util qw{any};
  use DateTime;

  on event privmsg => sub ($self, $irc, $msg) {
    my $watch = $self->config("watch");
    my $chan = $msg->{params}[0];

    return unless lc $chan eq lc $watch;

    my $members = $self->config("members");
    my ($nick) = split_prefix $msg->{prefix};
    $nick =~ s/_+$//;

    if (any {lc $_ eq lc $nick} @$members) {
      my $key = lc join "-", "status", $self->config("groupname");
      my $dayend = DateTime->now->add(days => 1)->truncate(to => "day");
      $self->brain->sadd($key, $nick, sub {});
      $self->brain->expireat($key, $dayend->epoch);
    }
  };

  on command qr{status} => sub ($self, $irc, $chan) {
    my $masters = $self->config("masters");
    my $key = lc join "-", "status", $self->config("groupname");

    return unless any { lc $chan eq lc $_ } @$masters;

    $self->brain->smembers($key, sub ($members) {
      my $members = $self->config("members");
      my @missing;

      for my $watch (@$members) {
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
