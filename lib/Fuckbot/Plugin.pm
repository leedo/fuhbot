use v5.14;

package Fuckbot::Plugin 0.1 {
  sub new {
    my ($class, $config) = @_;
    bless {config => $config}, $class;
  }

  sub config {
    my ($self, $key) = @_;
    if ($key) {
      return $self->{config}{$key};
    }
    return $self->{config};
  }

  sub shutdown {
    my ($self, $cb) = @_;
    $cb->();
  }
}

1;
