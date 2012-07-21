use v5.14;

package Fuhbot::Util 0.1 {
  use AnyEvent::HTTP;
  use URI::Escape;
  use JSON::XS;

  sub shorten {
    my ($url, $cb) = @_;
    $url = uri_escape($url);
    http_get "http://is.gd/api.php?longurl=$url", sub {
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
