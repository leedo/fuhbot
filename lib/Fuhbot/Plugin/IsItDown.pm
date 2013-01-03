package Fuhbot::Plugin::IsItDown;

use parent 'Fuhbot::Plugin';

use AnyEvent::HTTP;
use Mime::Base64 ();

sub commands {
  my $self = shift;
  my %sites = %{ $self->config("sites") || {} };

  (
    qr{isitdown (.+)} => sub { shift->isitdown(@_) },
    map {
      my $k = $_;
      "is$k"."down" => sub {
        shift->isitdown(@_, $sites{$k})
      }
    } keys %sites,
  );
}

sub isitdown {
  my ($self, $irc, $chan, $site) = @_;
  my %headers;

  if ($site =~ s{^https?://([^:]+:[^:]+)@}{}) {
    $headers{Authorization} = "Basic " . MIME::Base64::encode_base64($1);
  }

  $site = "http://$site" unless $site =~ m{^https?://};

  http_get $site, headers => \%headers, sub {
    my (undef, $headers) = @_;
    my $state = $headers->{Status} == 200 ? "up" : "down ($headers->{Reason})";
    $irc->send_srv(PRIVMSG => $chan, "$site is $state");
  };
}

1;
