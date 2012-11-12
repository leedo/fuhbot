use v5.14;

package Fuhbot::Plugin::Github 0.1 {
  use parent 'Fuhbot::Plugin';
  use Fuhbot::Util;
  use Fuhbot::HTTPD;
  use AnyEvent::HTTP;
  use JSON::XS;

  sub commands {
    "github status" => sub {shift->status(@_)},
  }

  sub status {
    my ($self, $irc, $chan) = @_;

    my %headings = (
      'good' => "\x033Battle station fully operational",
      'minorproblem' => "\x037Partial service outage",
      'majorproblem' => "\x034Major service outage",
    ); 

    http_get "https://status.github.com/status.json" => sub {
      my ($body, $headers) = @_;
      if ($headers->{Status} == 200) {
        my $data = decode_json $body;
        $irc->send_srv(PRIVMSG => $chan, $headings{$data->{status}});
        for my $day (@{$data->{days}}) {
          if ($day->{date} eq "Today") {
            my @msgs = map  {s/<[^>]+>/ /g; $_}
                       grep {$_}
                       split "\n", $day->{message};
            $irc->send_srv(PRIVMSG => $chan, $_) for @msgs;
          }
        }
      }
    };

    http_get "https://status.github.com/realtime.json" => sub {
      my ($body, $headers) = @_;
      if ($headers->{Status} == 200) {
        my $data = decode_json $body;
        my $msg = join " \x03| ", map {
          ($data->{$_} ? "\x033" : "\x034") . $_;
        } keys %$data;
        $irc->send_srv(PRIVMSG => $chan, $msg);
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
