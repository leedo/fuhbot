package Fuhbot::Plugin::IsItDown;

use parent 'Fuhbot::Plugin';

use AnyEvent::HTTP;

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
  $site = "http://$site" unless $site =~ m{^https?://};
  http_get $site, sub {
    my (undef, $headers) = @_;
    my $state = $headers->{Status} == 200 ? "up" : "down ($headers->{Reason})";
    $irc->send_srv(PRIVMSG => $chan, "$site is $state");
  };
}

1;
