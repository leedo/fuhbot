use v5.14;

package Fuhbot::Plugin::Parsely 0.1 {
  use parent 'Fuhbot::Plugin';
  use AnyEvent::HTTP;
  use IRC::Formatting::HTML;
  use JSON::XS;
  use List::MoreUtils qw/first_index/;

  sub prepare_plugin {
    my $self = shift;

    die "need API secret and key"
      unless defined $self->config("secret")
         and defined $self->config("key");

    $self->{authors} = [];
    $self->{interval} = $self->config("interval") || 60 * 60;
    $self->{timer} = AE::timer 0, $self->{interval}, sub {
      $self->check_parsely;
    };
  }

  sub api_url {
    my ($self, $path, %params) = @_;

    $params{apikey} ||= $self->config("key");
    $params{secret} ||= $self->config("secret");
    my $query = join "&", map {"$_=$params{$_}"} keys %params;
    
    return "http://api.parsely.com/v2/$path?$query"
  }

  sub check_parsely {
    my $self = shift;
    my $url = $self->api_url("realtime/authors", time => "60m");

    http_get $url, sub {
      my ($body, $headers) = @_;
      if ($headers->{Status} == 200) {
        my $data = decode_json $body;
        my @new = map {$_->{author}} @{$data->{data}};

        $self->broadcast("\037Top authors for last 60 min");

        for my $i (0 .. $#new) {
          my $message = sprintf "%2d. \002%s\002", $i + 1, $new[$i];
          my $prev = first_index {$_ eq $new[$i]} @{$self->{authors}};          

          if ($prev > -1) {
            $message .= sprintf ' \x03%d%+d', $prev < $i ? 4 : 3, $prev - $i;
          }

          $self->broadcast($message);
        }

        $self->{authors} = \@new;
      }
    };
  }
}

1;
