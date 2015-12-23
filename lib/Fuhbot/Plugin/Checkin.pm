package Fuhbot::Plugin::Checkin  0.1 {
  use Fuhbot::Plugin;
  use AnyEvent::IRC::Util qw{split_prefix};
  use List::Util qw{any};
  use DateTime;

  sub prepare_plugin ($self) {
    if (my $alerts = $self->config("alerts")) {
      for (@$alerts) {
        on cron $_->{schedule} => $self->handle_cron($_->{sendto});
      }
    }
  }

  sub handle_cron ($self, $sendto) {
    return sub {
      $self->brain->smembers($self->key, sub ($seen) {
        my $members = $self->config("members");
        my @missing;

        for my $member (@$members) {
          if (! any {$_ eq $member} @$seen) {
            push @missing, $member;
          }
        }

        $self->announce($sendto, scalar(@missing) . " have not checked in yet!");
        $self->announce($sendto, join ", ", @missing) if @missing;
      });
    };
  }

  sub key ($self) {
    my $key = lc join "-", "status", $self->config("groupname");
    return $key
  }

  on event privmsg => sub ($self, $irc, $msg) {
    my $watch = $self->config("watch");
    my $chan = $msg->{params}[0];

    return unless lc $chan eq lc $watch;

    my $members = $self->config("members");
    my ($nick) = split_prefix $msg->{prefix};
    $nick =~ s/_+$//;

    if (any {lc $_ eq lc $nick} @$members) {
      my $dayend = DateTime->now->add(days => 1)->truncate(to => "day");
      $self->brain->sadd($self->key, $nick, sub {});
      $self->brain->expireat($key, $dayend->epoch);
    }
  };

  on command qr{status} => sub ($self, $irc, $chan) {
    my $masters = $self->config("masters");

    return unless any { lc $chan eq lc $_ } @$masters;

    $self->brain->smembers($self->key, sub ($seen) {
      my $members = $self->config("members");
      my @missing;

      for my $member (@$members) {
        if (! any {$_ eq $member} @$seen) {
          push @missing, $member;
        }
      }

      $irc->send_srv(PRIVMSG => $chan, scalar(@missing) . " have not checked in yet!");
      $irc->send_srv(PRIVMSG => $chan, join ", ", @missing) if @missing;
    });
  };
}

1;
