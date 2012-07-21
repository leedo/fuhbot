use v5.14;

package Fuhbot::HTTPD 0.1 {
  use AnyEvent::HTTPD;
  my $httpds = {}; # shared between instances

  sub new {
    my ($class, $port) = @_;
    $httpds->{$port} ||= AnyEvent::HTTPD->new(port => $port);
  }
}

1;
