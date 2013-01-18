use v5.14;

package Fuhbot::Plugin::Seen  0.1 {
  use parent 'Fuhbot::Plugin';

  use AnyEvent::IRC::Util ();
  use JSON::XS ();

  sub commands {
    qr{seen\s+([^\s]+)} => sub{shift->seen(@_)}
  }

  sub irc_privmsg {
    my ($self, $irc, $msg) = @_;
    my $chan = $msg->{params}[0];
    my ($nick) = AnyEvent::IRC::Util::split_prefix $msg->{prefix};
    my $key = join "-", $nick, $chan, $irc->name;
    $self->brain->set(lc $key, JSON::XS::encode_json [time, $msg->{params}[-1]], sub {});
  }

  sub seen {
    my ($self, $irc, $chan, $nick) = @_;

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

      my ($time, $message) = @{ JSON::XS::decode_json $data };

      my $min = 60;
      my $hour = $min * 60;
      my $day = $hour * 24;

      my @when;
      my $seconds = time - $time;

      my $days    = int($seconds / $day);
      if ($days) {
        $seconds -= ($days * $day);
        push @when, "$days days";
      }
      
      my $hours   = int($seconds / $hour);
      if ($hours) {
        $seconds -= ($hours * $hour);
        push @when, "$hours hour" . ($hours != 1 ? "s" : "");
      }

      my $minutes = int($seconds / $min);
      if ($minutes) {
        $seconds -= ($minutes * $min);
        push @when, "$minutes minute" . ($minutes != 1 ? "s" : "");
      }

      if ($seconds) {
        push @when, "$seconds second" . ($seconds != 1 ? "s" : "");
      }
      
      if (@when > 1) {
        $when[-1] = "and $when[-1]";
      }
      elsif (@when == 0) {
        push @when, "0 seconds";
      }


      $irc->send_srv(PRIVMSG => $chan,
        "$nick was last seen in $chan " . join(", ", @when) . " ago"
      );
      $irc->send_srv(PRIVMSG => $chan, "< $nick> $message");
    });
  }
}

1;
