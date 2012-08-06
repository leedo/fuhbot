use v5.14;

package Fuhbot::Plugin::CMS 0.1 {
  use parent 'Fuhbot::Plugin';
  use Fuhbot::HTTPD;
  use Fuhbot::Util;
  use IRC::Formatting::HTML;
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
        my $color = do {
          given ($data->{type}) {
            when ("error") { 4 }
            when ("success") { 3 }
            default { 14 }
          }
        };
        my $message = IRC::Formatting::HTML::html_to_irc($data->{message});
        $self->broadcast(encode utf8 => "\x03$color\x02CMS $data->{type}:\x02\x03 $message - $url");
      };
    }
  }
}

1;
