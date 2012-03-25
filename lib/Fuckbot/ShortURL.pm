use v5.14;

package Fuckbot::ShortURL 0.1 {
  use AnyEvent::HTTP;
  use URI::Escape;

  sub shorten {
    my ($url, $cb) = @_;
    $url = uri_escape($url);
    http_get "http://is.gd/api.php?longurl=$url", sub {
      my ($body, $headers) = @_;
      $headers->{Status} == 200 ? $cb->($body) : $cb->();
    }
  }
}

1;
