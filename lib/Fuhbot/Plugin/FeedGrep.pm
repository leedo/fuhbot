use v5.14;

package Fuhbot::Plugin::FeedGrep 0.1 {
  use Fuhbot::Plugin;
  use AnyEvent::HTTP;
  use List::MoreUtils qw/any/;
  use Encode;
  use XML::Feed;
  use HTML::Parser;

  sub prepare_plugin {
    my $self = shift;
    $self->{timer} = AE::timer 0, 60 * 15, sub { $self->check_feeds };
  }

  sub grep_entry {
    my ($self, $entry) = @_;
    my $patterns = $self->config("patterns") || [];

    return () unless @$patterns;
    return $entry->link if any { $entry->link =~ $_ } @$patterns;

    for my $field (qw{summary content}) {
      my $url;
      my $p = HTML::Parser->new(
        api_version => 3,
        start_h => [
          sub {
            return unless $_[1] eq "a";
            if (any { $_[2]->{href} =~ $_ } @$patterns) {
              $url = $_[2]->{href};
              $_[0]->eof;
            }
          },
          "self,tag,attr"
        ]
      );
      $p->parse($entry->$field->body);
      $p->eof;
      return $url if $url;
    }

    return ();
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

    my $cv = AE::cv;
    my @matches;

    for my $url (@$feeds) {
      $cv->begin;
      http_get $url, sub {
        my ($body, $headers) = @_;
        return () unless $headers->{Status} == 200;

        my $body = decode "utf-8", $body;
        my $feed = XML::Feed->parse(\$body);
        $cv->end;

        if (!$feed) {
          warn "unable to parse feed: $url",
               XML::Feed->errstr;
          return;
        }

        for my $entry ($feed->entries) {
          if (my $link = $self->grep_entry($entry)) {
            $cv->begin;
            Fuhbot::Util::resolve_title $link, sub {
              my $title = $_[0] || $link;
              push @matches, [$title, $entry, $feed];
              $cv->end;
            };
          }
        }
      };
    }

    $cv->cb(sub {
      for my $match (@matches) {
        my ($title, $entry, $feed) = @$match;
        my $url = $feed->link;
        $self->brain->sismember("feedgrep-$url", $entry->id, sub {
          my $seen = shift;
          if (!$seen) {
            $self->broadcast(sprintf('"%s" appeared on %s - %s', $title, map { decode "utf8", $_ } $feed->title, $feed->link));
            $self->brain->sadd("feedgrep-$url", $entry->id, sub {});
          }
        });
      }
    });
  }
}

1;
