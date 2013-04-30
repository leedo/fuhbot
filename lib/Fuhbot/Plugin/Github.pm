use v5.14;

package Fuhbot::Plugin::Github 0.1 {
  use Fuhbot::Plugin;
  use Fuhbot::Util qw/shorten/;
  use AnyEvent::HTTP;
  use JSON::XS;

  on command "github status" => sub {
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
  };

  on post "/github" => sub {
    my ($self, $req) = @_;

    $req->respond({ content => ["text/plain", "o ok"] });
    my $payload = $req->parm("payload");

    if ($payload) {
      my $data = decode_json $payload;
      my $repo = $data->{repository}{name};
      my $branch = (split "/", $data->{ref})[-1];

      for my $commit (reverse @{$data->{commits}}) {
        http_post "http://git.io",
          "url=$commit->{url}",
          sub {
            my ($body, $headers) = @_;
            my $url = $headers->{location} || $commit->{url};
            my (@lines) = split "\n", $commit->{message};
            my $id = substr $commit->{id}, 0, 7;
            my @files = map {@{$commit->{$_}}} qw/modified removed added/;
            my $file = @files > 1 ? "(" . scalar(@files) . " files)" : $files[0];
            my $name = $commit->{author}{username} || $commit->{author}{name};
            my $prefix = "$repo/$branch:";
            $self->broadcast("$prefix " . join " | ", $id, $name, $file);
            $self->broadcast("$prefix $_") for @lines;
            $self->broadcast("$prefix review: $url");
          };
      }
    }
  };
}

1;
