use v5.14;

package Fuhbot 0.1 {
  use AnyEvent;
  use AnyEvent::IRC::Util;
  use Fuhbot::IRC;
  use AnyEvent::Redis;
  use List::Util qw/first/;

  sub new {
    my ($class, @argv) = @_;
    die "config must passed in as the first arg" unless @argv;
    bless {
      ircs     => [],
      plugins  => [],
      config   => {},
      brain    => AnyEvent::Redis->new,
      config_file => $argv[0],
    }, $class;
  }

  sub run {
    my $self = shift;
    $self->{cv} = AE::cv;
    my $sigs = AE::signal INT => sub { $self->shutdown };

    say "loading config...";
    $self->load_config;

    say "loading plugins...";
    $self->load_plugins;

    say "loading ircs...";
    $self->load_ircs;

    $self->{cv}->recv;
    $self->cleanup;
  }

  sub shutdown { $_[0]->{cv}->send }

  sub cleanup {
    my $self = shift;

    say "\ndisconnecting ircs and unregistering plugins...";
    my $cv = AE::cv;

    for my $irc (grep {$_->is_connected} $self->ircs) {
      $cv->begin;
      $irc->shutdown(sub { $cv->end });
    }

    for my $plugin ($self->plugins) {
      $cv->begin;
      $plugin->shutdown(sub { $cv->end });
    }

    my $t = AE::timer 5, 0, sub {
      $cv->croak("timed out shutting down plugins");
    };

    $cv->recv;
  }

  sub broadcast {
    my ($self, $msg, $networks) = @_;
    for my $irc ($self->ircs($networks)) {
      $irc->broadcast($msg);
    }
  }

  sub broadcast_cb {
    my $self = shift;
    $self->{broadcast_cb} ||= sub {$self->broadcast(@_)};
  }

  sub load_ircs {
    my $self = shift;
    for my $config (@{$self->config("ircs")}) {
      my $irc = Fuhbot::IRC->new($config);
      $irc->reg_cb("irc_*" => sub { $self->irc_line(@_) });
      $irc->reg_cb("publicmsg" => sub { $self->channel_msg(@_) });
      $irc->reg_cb("privatemsg" => sub { $self->private_msg(@_) });
      $irc->connect;
      push $self->{ircs}, $irc;
    }
  }

  sub load_plugins {
    my $self = shift;
    for my $config (@{$self->config("plugins")}) {
      $self->load_plugin($config);
    }
  }

  sub load_plugin {
    my ($self, $config) = @_;

    my $class = "Fuhbot::Plugin::$config->{name}";
    eval "use $class";
    die $@ if $@;
    
    my $plugin = $class->new(
      config    => $config,
      brain     => $self->{brain},
      broadcast => $self->broadcast_cb,
    );

    $plugin->prepare_plugin;
    push $self->{plugins}, $plugin;
  }

  sub reload_plugin {
    my ($self, $name) = @_;
    delete $INC{"Fuhbot/Plugin/$name.pm"};

    my $orig = [ $self->plugins ];
    $self->{plugins} = [grep {$_->name ne $name} $self->plugins];

    my @configs = grep {$_->{name} eq $name} @{$self->config("plugins")};
    eval { $self->load_plugin($_) for @configs };

    if ($@) {
      $self->{plugins} = $orig;
      die "error reloading $name plugin: $@";
    }
  }

  sub irc_line {
    my ($self, $irc, $msg) = @_;
    my $method = lc "irc_$msg->{command}";

    for my $plugin ($self->plugins($irc->name)) {
      $plugin->$method($irc, $msg) if $plugin->can($method);
    }
  }

  sub channel_msg {
    my ($self, $irc, $chan, $msg) = @_;
    my $text = $msg->{params}[-1];
    my $nick = $irc->nick;

    if ($text =~ s/^(?:!|\Q$nick\E[:,\s]+)//) {
      $self->handle_command($irc, $chan, $text);
    }
  }

  sub private_msg {
    my ($self, $irc, $nick, $msg) = @_;
    my $text = $msg->{params}[-1];
    my $sender = AnyEvent::IRC::Util::prefix_nick $msg->{prefix};
    $self->handle_command($irc, $sender, $text);
  }

  sub handle_command {
    my ($self, $irc, $chan, $text) = @_;

    for my $command ($self->commands($irc->name)) {
      my ($pattern, $cb) = @{$command};
      if ($text =~ s/^$pattern\s*//) {
        $cb->($irc, $chan, $text);
        return;
      }
    }
  }

  sub commands {
    my ($self, $network) = @_;
    return map {$_->command_callbacks} $self->plugins($network);
  }

  sub load_config {
    my $self = shift;
    if (!-r $self->{config_file}) {
      die "config file is not readable";
    }

    $self->{config} = do $self->{config_file};
  }

  sub ircs {
    my ($self, $networks) = @_;
    return @{$self->{ircs}} unless $networks;
    grep {
      my $n = $_->name;
      first {$_ eq $n} @$networks
    } @{$self->{ircs}}
  }

  sub plugins {
    my ($self, $network) = @_;
    return @{$self->{plugins}} unless $network;
    grep {
      my $i = $_->config("ircs");
      !$i || first {$_ eq $network} @{$i}
    } @{$self->{plugins}};
  }

  sub config {
    my ($self, $key) = @_;
    if ($key) {
      return $self->{config}{$key};
    }
    return $self->{config};
  }
}

1;
