use v5.14;

package Fuhbot::Plugin::Github 0.1 {
  use Fuhbot::Plugin;
  use Fuhbot::Util qw/timeago/;
  use AnyEvent::HTTP;
  use Date::Parse;
  use JSON::XS;

  on command "github status" => sub {
    my ($self, $irc, $chan) = @_;

    my %colors = (
      'good' => "\x033",
      'minor' => "\x037",
      'major' => "\x034",
    ); 

    http_get "https://status.github.com/api/messages.json" => sub {
      my ($body, $headers) = @_;
      if ($headers->{Status} == 200) {
        my $data = decode_json $body;
        my $now = time;
        my $day = 60 * 60 * 24;
        for my $event (@$data) {
          my $time = str2time $event->{created_on};
          if ($now - $time < $day) {
            $irc->send_srv(PRIVMSG => $chan, "\002" . timeago $time);
            $irc->send_srv(PRIVMSG => $chan, "$colors{$event->{status}}$event->{body}");
          }
        }
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

            my @files = map {@{$commit->{$_}}} qw/modified removed added/;
            my $file = Fuhbot::Util::longest_common_prefix(@files);
            $file = "/" unless $file;
            $file .= " (" . scalar(@files) . " files)" if @files > 1;

            my (@lines) = split "\n", $commit->{message};
            my $id = substr $commit->{id}, 0, 7;
            my $name = $commit->{author}{username} || $commit->{author}{name};
            my $prefix = $branch eq "master" ? $repo : "$repo/$branch";

            $self->broadcast("$prefix: " . join " | ", $id, $name, $file);
            $self->broadcast("$prefix: $_") for @lines;
            $self->broadcast("$prefix: review: $url");
          };
      }
    }
  };
}

1;
