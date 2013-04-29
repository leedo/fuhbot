use v5.14;

package Fuhbot::Plugin::IsItDown 0.1 {
  use Fuhbot::Plugin;
  use AnyEvent::HTTP;
  use MIME::Base64 ();

  on command qr{isitdown (.+)} => sub {
    my ($self, $irc, $chan, $site) = @_;
    $self->check_site($irc, $chan, $site);
  };

  on command qr{is([^\s]+)down} => sub {
    my ($self, $irc, $chan, $alias) = @_;
    if (my $site = ($self->config("sites") || {})->{$alias}) {
      $self->check_site($irc, $chan, $site);
    }
  };

  sub check_site {
    my ($self, $irc, $chan, $site) = @_;
    my %headers;

    if ($site =~ s{^https?://([^:]+:[^:]+)@}{}) {
      $headers{Authorization} = "Basic " . MIME::Base64::encode($1);
    }

    $site = "http://$site" unless $site =~ m{^https?://};

    http_get $site, headers => \%headers, sub {
      my (undef, $headers) = @_;
      my $state = $headers->{Status} == 200 ? "up" : "down ($headers->{Reason})";
      $irc->send_srv(PRIVMSG => $chan, "$site is $state");
    };
  }
}

1;
