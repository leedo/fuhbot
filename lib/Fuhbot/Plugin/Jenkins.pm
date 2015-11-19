package Fuhbot::Plugin::Jenkins 0.1 {
  use Fuhbot::Plugin;
  use Fuhbot::Util qw/shorten/;
  use JSON::XS;
 
  on post "/jenkins" => sub ($self, $req) {
    $req->respond({ content => ["text/plain", "o ok"] });
    my ($payload) = $req->content;

    if ($payload) {
      my $data = decode_json $payload;
      my $build = $data->{build};
      my $name = $data->{name};
      my $prefix = $self->config("url");
      shorten "$prefix/$build->{url}", sub {
        my $url = shift;
        $self->broadcast("build #$build->{number} of $name has $build->{phase} $build->{status} - $url");
      };
    }
  };
}

1;
