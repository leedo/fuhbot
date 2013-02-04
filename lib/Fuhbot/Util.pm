use v5.14;

package Fuhbot::Util 0.1 {
  use AnyEvent::HTTP;
  use URI::Escape;
  use JSON::XS;

  our $shorten_format = "http://is.gd/api.php?longurl=%s";

  sub timeago {
    my $time = shift;

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

    return join(", ", @when) . " ago";
  }
  
  sub shorten {
    my $cb = pop;
    my ($long, %args) = @_;
    my $format = $args{shorten_format} || $shorten_format;
    my $url = sprintf $format, uri_escape($long);

    http_get $url, sub {
      my ($body, $headers) = @_;
      $headers->{Status} == 200 ? $cb->($body) : $cb->();
    }
  }
 
  sub gist {
    my ($name, $content, $cb) = @_;
    http_post "https://api.github.com/gists",
      encode_json({
        public => JSON::XS::false,
        files => {$name => {content => $content}},
      }),
      sub {
        my ($body, $headers) = @_;
        my $data = decode_json $body;
        $cb->($data->{html_url});
      };
  }

}

1;
