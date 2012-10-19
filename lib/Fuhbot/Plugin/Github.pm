use v5.14;

package Fuhbot::Plugin::Github 0.1 {
  use parent 'Fuhbot::Plugin';
  use Fuhbot::Util;
  use Fuhbot::HTTPD;
  use AnyEvent::HTTP;
  use JSON::XS;

  sub commands {qw/github_status/}

  sub github_status {
    my ($self, $irc, $chan) = @_;
    http_get "https://status.github.com/realtime.json" => sub {
      my ($body, $headers) = @_;
      if ($headers->{Status} == 200) {
        my $data = decode_json $body;
        for my $service (keys %$data) {
          my $msg = ($data->{$service} ? "\x033" : "\x034") . $service;
          $irc->send_srv(PRIVMSG => $chan, $msg);
        }
      }
    };
  }

  sub prepare_plugin {
    my $self = shift;
    my $port = $self->config("port") || 9091;
    $self->{httpd} = Fuhbot::HTTPD->new($port);
    $self->{guard} = $self->{httpd}->reg_cb("/github" => sub { $self->handle_req(@_) });
  }

  sub handle_req {
    my ($self, $httpd, $req) = @_;

    $req->respond({ content => ["text/plain", "o ok"] });
    my $payload = $req->parm("payload");

    if ($payload) {
      my $data = decode_json $payload;
      my $repo = $data->{repository}{name};
      my $branch = (split "/", $data->{ref})[-1];

      for my $commit (reverse @{$data->{commits}}) {
        Fuhbot::Util::shorten $commit->{url}, sub {
          my $url = shift;
          $self->broadcast("[$repo $branch] $commit->{message} ($commit->{author}{name}) - $url");
        };
      }
    }
  }
}

1;
