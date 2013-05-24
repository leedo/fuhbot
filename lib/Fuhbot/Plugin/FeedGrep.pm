use v5.14;

package Fuhbot::Plugin::FeedGrep 0.1 {
  use Fuhbot::Plugin;
  use AnyEvent::HTTP;
  use List::Util qw/max/;
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

    my $patterns = join "|", @{$self->config("patterns")};
    my $feeds = $self->config("feeds");
    my $pattern = qr{$patterns}i;

    for my $url (@$feeds) {
      my ($host) = $url =~ m{^https?://([^/]+)};

      http_get $url, sub {
        my ($body, $headers) = @_;
        my $feed = XML::Feed->parse(\$body);

        my @entries = grep {
          $_->title =~ $pattern || $_->content =~ $pattern || $_->link =~ $pattern
        } $feed->entries;

        for my $entry (@entries) {
          $self->brain->sismember("feedgrep", $entry->link, sub {
            my $seen = shift;
            if (!$seen) {
              $self->broadcast(sprintf('"%s" appeared on %s', $entry->title, $host));
              $self->brain->sadd("feedgrep", $entry->link, sub {});
            }
          });
        }
      };
    }
  }
}

1;
