use v5.14;

package Fuhbot::Plugin::AdBlockLog 0.1 {
  use Fuhbot::Plugin;
  use AnyEvent::HTTP;
  use List::Util qw/max/;
  use XML::Feed;

  sub prepare_plugin {
    my $self = shift;
    $self->{url} = "https://hg.adblockplus.org/easylist/rss-log";
    $self->{timer} = AE::timer 0, 60 * 15, sub { $self->check_feed; };
    $self->{latest} = 0;
    $self->{filter} = qr{arstechnica};
  }

  sub check_feed {
    my $self = shift;
    http_get $self->{url}, sub {
      my ($body, $headers) = @_;
      my $feed = XML::Feed->parse(\$body);
      my @entries = grep {
        $_->issued->epoch > $self->{latest} && (
          $_->title =~ $self->{filter} ||
          $_->content =~ $self->{filter} )
      } $feed->entries;
      $self->{latest} = max map { $_->issued->epoch } $feed->entries;
      $self->broadcast(sprintf("%s (%s)", $_->title, $_->link)) for @entries;
    };
  }
}

1;
