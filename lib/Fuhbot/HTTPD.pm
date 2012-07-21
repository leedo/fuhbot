use v5.14;

package Fuhbot::HTTPD 0.1 {
  use AnyEvent::HTTPD;
  use Scalar::Util qw/weaken/;

  our $HTTPD = {}; # shared between instances

  sub new {
    my ($class, $port) = @_;
    return $HTTPD->{$port} if defined $HTTPD->{$port};

    $HTTPD->{$port} = AnyEvent::HTTPD->new(port => $port);
    weaken $HTTPD->{$port};
    return $HTTPD->{$port};
  }
}

1;
