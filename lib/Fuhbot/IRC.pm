use v5.14;

package Fuhbot::IRC 0.1 {
  use parent 'AnyEvent::IRC::Client';
  use Encode;

  sub new {
    my ($class, $config) = @_;
    die "irc config must include nick" unless defined $config->{nick};
    my $self = $class->SUPER::new;
    $self->{fuhbot_config} = $config;
    $self->setup_events;
    return $self;
  }

  sub setup_events {
    my $self = shift;
    $self->{reconnect_cb} = sub {$self->reconnect};
    $self->reg_cb(registered => sub { $self->join_channels });
    $self->reg_cb(registered => sub { delete $self->{reconnect_timer} });
    $self->reg_cb(disconnect => $self->{reconnect_cb});
  }

  sub shutdown {
    my ($self, $cb) = @_;
    $self->unreg_cb($self->{reconnect_cb});
    $self->reg_cb(disconnect => $cb);
    $self->send_srv(QUIT => "fuhbot");
  }

  sub reconnect {
    my $self = shift;
    $self->{reconnect_timer} = AE::timer 5, 0, sub {
      $self->connect;
    }
  }
  
  sub name { $_[0]->config("name") }

  sub config {
    my ($self, $key) = @_;
    if (defined $key) {
      return $self->{fuhbot_config}{$key};
    }

    return $self->{fuhbot_config};
  }

  sub connect {
    my $self = shift;
    $self->enable_ssl if $self->config("ssl");
    $self->disconnect;

    $self->SUPER::connect(
      $self->config("host"),
      $self->config("port"),
      $self->config,
    );

    # this timer gets canceled connect succeeds
    $self->reconnect; 
  }

  sub join_channels {
    my $self = shift;
    for my $channel (@{$self->config("channels")}) {
      $self->send_srv(JOIN => $channel);
    }
  }

  sub broadcast {
    my ($self, $msg) = @_;
    my $channels = $self->channel_list;
    for my $channel (keys %$channels) {
      $self->send_srv(PRIVMSG => $channel, $msg);
    }
  }

  sub send_srv {
    my $self = shift;
    $self->SUPER::send_srv(map {encode utf8 => $_} @_);
  }
}

1;
