use v5.14;

package Fuhbot::HTTPD 0.1 {
  use AnyEvent::HTTPD;
  use Scalar::Util qw/weaken/;

  our $HTTPD = {}; # shared between instances

  sub new {
    my ($class, $port) = @_;
    return $HTTPD->{$port} if defined $HTTPD->{$port};

    my $httpd = AnyEvent::HTTPD->new(port => $port);
    $HTTPD->{$port} = $httpd;
    weaken $HTTPD->{$port};
    return $httpd;
  }
}

1;
