use v5.14;

package Fuhbot::Plugin::CMS 0.1 {
  use parent 'Fuhbot::Plugin';
  use Fuhbot::HTTPD;
  use Fuhbot::Util;
  use JSON::XS;
  
  sub prepare_plugin {
    my $self = shift;
    my $port = $self->config("port") || 9091;
    $self->{httpd} = Fuhbot::HTTPD->new($port);
    $self->{guard} = $self->{httpd}->reg_cb("/cms" => sub { $self->handle_req(@_) });
  }

  sub handle_req {
    my ($self, $httpd, $req) = @_;

    $req->respond({ content => ["text/plain", "o ok"] });
    my $payload = $req->parm("payload");

    if ($payload) {
      my $data = decode_json $payload;
      Fuhbot::Util::shorten $data->{url}, sub {
        my $url = shift;
        my $color = $data->{type} eq "error" ? 4 : 3;
        $self->broadcast("\x03$color\x02CMS $data->{type}:\x02\x03 $data->{message} - $url");
      };
    }
  }
}

1;
