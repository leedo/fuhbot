use v5.14;

package Fuckbot::Plugin::Jenkins 0.1 {
  use parent 'Fuckbot::Plugin';
  use Fuckbot::ShortURL;
  use Fuckbot::HTTPD;
  use JSON::XS;
  
  sub prepare_plugin {
    my $self = shift;
    my $port = $self->config("port") || 9091;
    $self->{httpd} = Fuckbot::HTTPD->new($port);
    $self->{httpd}->reg_cb("/jenkins" => sub { $self->handle_req(@_) });
  }

  sub handle_req {
    my ($self, $httpd, $req) = @_;

    $req->respond({ content => ["text/plain", "o ok"] });
    my ($payload) = $req->vars; # wut

    if ($payload) {
      my $data = decode_json $payload;
      my $build = $data->{build};
      my $name = $data->{name};
      my $prefix = $self->config("url");
      Fuckbot::ShortURL::shorten "$prefix/$build->{url}", sub {
        my $url = shift;
        $self->broadcast("build #$build->{number} of $name has $build->{phase} $build->{status} - $url");
      };
    }
  }
}

1;
