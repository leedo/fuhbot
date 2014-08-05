package Fuhbot::Plugin::CMS 0.1 {
  use Fuhbot::Plugin;
  use Fuhbot::Util;
  use IRC::Formatting::HTML qw/html_to_irc/;
  use JSON::XS;
 
  on post "/cms" => sub  ($self, $req) {

    $req->respond({ content => ["text/plain", "o ok"] });
    my $payload = $req->parm("payload");

    if ($payload) {
      my $data = decode_json $payload;
      $self->shorten($data->{url}, sub {
        my $url = shift;
        my $color = do {
          given ($data->{type}) {
            when ("error") { 4 }
            when ("success") { 3 }
            default { 14 }
          }
        };
        my $message = html_to_irc $data->{message};
        $self->broadcast("\x03$color\x02CMS $data->{type}:\x02\x03 $message - $url");
      });
    }
  };
}

1;
