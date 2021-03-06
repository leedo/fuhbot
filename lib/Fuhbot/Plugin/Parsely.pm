package Fuhbot::Plugin::Parsely 0.1 {
  use Fuhbot::Plugin;
  use AnyEvent::HTTP;
  use JSON::XS;

  sub prepare_plugin ($self) {
    die "need API secret and key"
      unless defined $self->config("secret")
         and defined $self->config("key");

    $self->{top_author} = "";

    my $interval = $self->config("interval") || 60 * 60;
    $self->{timer} = AE::timer $interval, $interval, sub {
      $self->check_parsely;
    };
  }

  sub api_url ($self, $path, %params) {
    $params{apikey} ||= $self->config("key");
    $params{secret} ||= $self->config("secret");
    my $query = join "&", map {"$_=$params{$_}"} keys %params;
    
    return "http://api.parsely.com/v2/$path?$query";
  }

  sub check_parsely ($self) {
    my $url = $self->api_url("realtime/authors", time => "1h");

    http_get $url, sub ($body, $headers) {
      if ($headers->{Status} == 200) {
        my $data = decode_json $body;
        my @authors = map {$_->{author}} @{$data->{data}};
        if (@authors and $authors[0] ne $self->{top_author}) {
          $self->{top_author} = $authors[0];
          my $message = "\x0314\x02Parse.ly info:\x02\x03 new top author $self->{top_author}";
          $self->broadcast($message);
        }
      }
    };
  }
}

1;
