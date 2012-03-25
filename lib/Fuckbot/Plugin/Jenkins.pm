use v5.14;

package Fuckbot::Plugin::Jenkins 0.1 {
  use parent 'Fuckbot::Plugin';
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

    $self->respond({ content => ["text/plain", "o ok"] });
    my $payload = $req->parm("payload");

    if ($payload) {
      my $data = decode_json $payload;
      $self->broadcast("build #$data{number} of job has $build{phase} $build{status}");
    }
  }
}

1;
