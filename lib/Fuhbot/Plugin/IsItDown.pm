use v5.14;
use warnings;
use mop;

use AnyEvent::HTTP;
use MIME::Base64 ();

class Fuhbot::Plugin::IsItDown extends Fuhbot::Plugin {
  method isitdown ($irc, $chan, $site) is command(qr{isitdown (.+)}) {
    $self->check_site($irc, $chan, $site);
  }

  method isdown ($irc, $chan, $alias) is command(qr{is([^\s]+)down}) {
    if (my $site = ($self->config("sites") || {})->{$alias}) {
      $self->check_site($irc, $chan, $site);
    }
  }

  method check_site ($irc, $chan, $site) {
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
