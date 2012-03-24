use v5.14;

package Fuckbot::IRC 0.1 {
  use parent 'AnyEvent::IRC::Client';

  sub new {
    my ($class, $config) = @_;
    die "irc config must include nick" unless defined $config->{nick};
    my $self = $class->SUPER::new;
    $self->{fuckbot_config} = $config;
    $self->setup_events;
    return $self;
  }

  sub setup_events {
    my $self = shift;
    $self->reg_cb(registered => sub { $self->join_channels });
  }

  sub config {
    my ($self, $key) = @_;
    if (defined $key) {
      return $self->{fuckbot_config}{$key};
    }

    return $self->{fuckbot_config};
  }

  sub connect {
    my $self = shift;
    $self->enable_ssl if $self->config("ssl");
    $self->SUPER::connect(
      $self->config("host"),
      $self->config("port"),
      $self->config,
    );
  }

  sub join_channels {
    my $self = shift;
    for my $channel (@{$self->config("channels")}) {
      $self->send_srv(JOIN => $channel);
    }
  }
}

1;
