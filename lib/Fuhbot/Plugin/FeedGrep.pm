use v5.14;

package Fuhbot::Plugin::FeedGrep 0.1 {
  use Fuhbot::Plugin;
  use AnyEvent::HTTP;
  use List::Util qw/max/;
  use XML::Feed;

  sub prepare_plugin {
    my $self = shift;
    $self->{timer} = AE::timer 0, 60 * 15, sub { $self->check_feeds };
    $self->{latest} = {};
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
      my $latest = $self->{latest}{$url} || 0;
      my ($host) = $url =~ m{^https?://([^/]+)};

      http_get $url, sub {
        my ($body, $headers) = @_;
        my $feed = XML::Feed->parse(\$body);

        my @entries = grep {
          $_->issued->epoch > $latest &&
          ($_->title =~ $pattern || $_->content =~ $pattern || $_->link =~ $pattern)
        } $feed->entries;

        $self->{latest}{$url} = max map { $_->issued->epoch } $feed->entries;
        $self->broadcast(sprintf('"%s" appeared on %s', $_->title, $host)) for @entries;
      };
    }
  }
}

1;
