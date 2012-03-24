use v5.14;

package Fuckbot::Plugin::Github 0.1 {
  use parent 'Fuckbot::Plugin';
  use AnyEvent::HTTPD;

  sub prepare_plugin {
    my $self = shift;
    my $port = $self->config("port") || 8080;
    $self->{httpd} = AnyEvent::HTTPD->new(port => $port);
    $self->{httpd}->reg_cb("/" => sub { $self->handle_req(@_) });
  }

  sub handle_req {
    my ($self, $httpd, $req) = @_;
    $req->respond({ content => ["text/plain", "hai"] });
  }

  sub irc_privmsg {
    my ($self, $irc, $msg) = @_;
  }
}

1;
