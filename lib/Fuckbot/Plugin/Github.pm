use v5.14;

package Fuckbot::Plugin::Github 0.1 {
  use parent 'Fuckbot::Plugin';
  use AnyEvent::HTTPD;
  use JSON::XS;

  sub prepare_plugin {
    my $self = shift;
    my $port = $self->config("port") || 8080;
    $self->{httpd} = AnyEvent::HTTPD->new(port => $port);
    $self->{httpd}->reg_cb("/" => sub { $self->handle_req(@_) });
  }

  sub handle_req {
    my ($self, $httpd, $req) = @_;

    $req->respond({ content => ["text/plain", "o ok"] });
    my $payload = $req->parm("payload");

    if ($payload) {
      my $data = decode_json $payload;
      my $repo = $data->{repository}{name};
      my @commits = map {
        "$_->{author}{name} - $_->{message} ($_->{url})"
      } @{$data->{commits}};

      $self->broadcast(@commits);
    }
  }
}

1;
