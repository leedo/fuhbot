use v5.20;
use experimental 'signatures';

{
  use AnyEvent::IRC::Connection;
  use AnyEvent::IRC::Util qw/parse_irc_msg/;
  use Fuhbot::Log;
  use Encode;
  no warnings;

  # YUCK!!!
  *AnyEvent::IRC::Connection::_feed_irc_data = sub ($self, $line) {
    my $m = parse_irc_msg (decode ("utf8", $line));
    $self->event (read => $m);
    $self->event ('irc_*' => $m);
    $self->event ('irc_' . (lc $m->{command}), $m);
  };

  my $mk_msg = sub {encode "utf8", AnyEvent::IRC::Util::mk_msg(@_)};
  *AnyEvent::IRC::Connection::mk_msg = $mk_msg;
  *AnyEvent::IRC::Client::mk_msg = $mk_msg;
}

package Fuhbot::IRC 0.1 {
  use parent 'AnyEvent::IRC::Client';
  use Encode;

  sub new ($class, $config) {
    die "irc config must include nick" unless defined $config->{nick};
    my $self = $class->SUPER::new;
    $self->{fuhbot_config} = $config;
    $self->setup_events;
    return $self;
  }

  sub setup_events ($self) {
    my $self = shift;
    $self->ctcp_auto_reply ('VERSION', ['VERSION', 'irssi v0.8.15']);
    $self->{reconnect_cb} = sub { $self->reconnect };
    $self->reg_cb(registered => sub { $self->join_channels });
    $self->reg_cb(registered => sub { delete $self->{reconnect_timer} });
    $self->reg_cb(disconnect => $self->{reconnect_cb});
  }

  sub shutdown ($self, $cb) {
    Fuhbot::Log::info("IRC shutting down " . $self->name);
    $self->unreg_cb($self->{reconnect_cb});
    $self->reg_cb(disconnect => $cb);
    $self->send_srv(QUIT => "fuhbot");
  }

  sub reconnect ($self) {
    Fuhbot::Log::info("IRC reconnecting to " . $self->name);
    $self->{reconnect_timer} = AE::timer 5, 0, sub {
      $self->connect;
    }
  }
  
  sub name { $_[0]->config("name") }

  sub config ($self, $key=undef) {
    if (defined $key) {
      return $self->{fuhbot_config}{$key};
    }

    return $self->{fuhbot_config};
  }

  sub connect ($self) {
    Fuhbot::Log::info("IRC connecting to " . $self->name);
    $self->enable_ssl if $self->config("ssl");
    $self->disconnect if $self->is_connected;

    $self->SUPER::connect(
      $self->config("host"),
      $self->config("port"),
      $self->config,
    );

    # this timer gets canceled connect succeeds
    $self->reconnect; 
  }

  sub join_channels ($self) {
    Fuhbot::Log::info("IRC connected to " . $self->name);
    for my $channel (@{$self->config("channels")}) {
      $self->send_srv(JOIN => split /\s+/, $channel);
    }
  }

  sub broadcast ($self, $msg, $channels) {
    $channels ||= [keys %{$self->channel_list}];
    for my $channel (@$channels) {
      $self->send_srv(PRIVMSG => $channel, $msg);
    }
  }
}

1;
