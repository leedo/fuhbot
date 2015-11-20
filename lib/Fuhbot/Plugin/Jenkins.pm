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
      my $prefix = $self->config("url");

      $self->broadcast(
        sprintf "build #%s of %s has %s [%s] - %s",
          $build->{number}, $data->{name},
          lc($build->{phase}), lc($build->{status} =~ s/_/ /gr),
          "$prefix/$build->{url}"
      );
    }
  };
}

1;
