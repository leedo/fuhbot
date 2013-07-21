use v5.14;
use warnings;
use mop;

use Fuhbot::Plugin;
use AnyEvent::HTTP;
use JSON::XS;

class Fuhbot::Plugin::Parsely extends Fuhbot::Plugin {
  has $top_author = "";
  has $timer;

  method prepare_plugin {
    die "need API secret and key"
      unless defined $self->config("secret")
         and defined $self->config("key");

    my $interval = $self->config("interval") || 60 * 5;
    $timer = AE::timer $interval, $interval, sub {
      $self->check_parsely;
    };
  }

  method api_url ($path, %params) {
    $params{apikey} ||= $self->config("key");
    $params{secret} ||= $self->config("secret");
    my $query = join "&", map {"$_=$params{$_}"} keys %params;
    
    return "http://api.parsely.com/v2/$path?$query";
  }

  method check_parsely {
    my $url = $self->api_url("realtime/authors", time => "24h");

    http_get $url, sub {
      my ($body, $headers) = @_;
      if ($headers->{Status} == 200) {
        my $data = decode_json $body;
        my @authors = map {$_->{author}} @{$data->{data}};
        if (@authors and $authors[0] ne $top_author) {
          $top_author = $authors[0];
          my $message = "\x0314\x02Parse.ly info:\x02\x03 new top author $top_author";
          $self->broadcast($message);
        }
      }
    };
  }
}

1;
