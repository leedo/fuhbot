use v5.14;

package Fuhbot::Plugin::FeedGrep 0.1 {
  use Fuhbot::Plugin;
  use AnyEvent::HTTP;
  use List::MoreUtils qw/any/;
  use Encode;
  use XML::Feed;

  sub prepare_plugin {
    my $self = shift;
    $self->{timer} = AE::timer 0, 60 * 15, sub { $self->check_feeds };
  }

  sub check_feeds {
    my $self = shift;

    for (qw/patterns feeds/) {
      die "no $_ defined"
        unless defined $self->config($_) and
          ref $self->config($_) eq "ARRAY";
    }

    my $patterns = $self->config("patterns");
    my $feeds = $self->config("feeds");

    for my $url (@$feeds) {
      http_get $url, sub {
        my ($body, $headers) = @_;
        my $body = decode "utf-8", $body;
        my $feed = XML::Feed->parse(\$body);

        if (!$feed) {
          warn "unable to parse feed: $url",
               XML::Feed->errstr;
          return;
        }

        my @entries = grep {
          my $e = $_;
          any {
            my $t = $e->$_;
            any { $t =~ /$_/ } @$patterns;
          } qw{title content link};
        } $feed->entries;

        for my $entry (@entries) {
          $self->brain->sismember("feedgrep-$url", $entry->link, sub {
            my $seen = shift;
            if (!$seen) {
              $self->broadcast(sprintf('"%s" appeared on %s', $entry->title, $feed->link));
              $self->brain->sadd("feedgrep-$url", $entry->link, sub {});
            }
          });
        }
      };
    }
  }
}

1;
