use v5.14;
use AnyEvent;
use common::sense;

package Fuckbot 0.1 {
  use Class::Load;
  use Fuckbot::IRC;

  sub new {
    my ($class, @argv) = @_;
    die "config must passed in as the first arg" unless @argv;
    bless {
      config_file => $argv[0],
      ircs => [],
      plugins => [],
      config => {},
    }, $class;
  }

  sub run {
    my $self = shift;
    my $cv = AE::cv;
    my $sigs = AE::signal INT => sub { $cv->send };

    say "loading config...";
    $self->load_config;

    say "loading plugins...";
    $self->load_plugins;

    say "loading ircs...";
    $self->load_ircs;

    $cv->recv;
    $self->cleanup;
  }

  sub cleanup {
    my $self = shift;

    say "\ndisconnecting ircs and unregistering plugins...";
    my $cv = AE::cv;

    for my $irc (grep {$_->is_connected} $self->ircs) {
      $cv->begin;
      $irc->reg_cb(disconnect => sub { $cv->end });
      $irc->send_srv(QUIT => "fuckbot");
    }

    for my $plugin ($self->plugins) {
      $cv->begin;
      $plugin->shutdown(sub { $cv->end });
    }

    my $t = AE::timer 5, 0, sub {
      $cv->croak("timeout shutting down plugins");
    };

    $cv->recv;
  }

  sub load_ircs {
    my $self = shift;
    for my $config (@{$self->config("ircs")}) {
      my $irc = Fuckbot::IRC->new($config);
      $irc->reg_cb("irc_*" => sub { $self->irc_line(@_) });
      $irc->connect;
      push $self->{ircs}, $irc;
    }
  }

  sub load_plugins {
    my $self = shift;
    for my $config (@{$self->config("plugins")}) {
      my $class = "Fuckbot::Plugin::$config->{name}";
      my ($success, $error) = Class::Load::try_load_class($class);
      if ($success) {
        my $plugin = $class->new($config);
        $plugin->prepare_plugin;
        push $self->{plugins}, $plugin;
      }
      else {
        die "error loading $config->{name} plugin\n  $error";
      }
    }
  }

  sub irc_line {
    my ($self, $irc, $msg) = @_;
    my $method = lc "irc_$msg->{command}";

    for my $plugin ($self->plugins) {
      $plugin->$method($irc, $msg) if $plugin->can($method);
    }
  }

  sub load_config {
    my $self = shift;
    if (!-r $self->{config_file}) {
      die "config file is not readable";
    }

    $self->{config} = do $self->{config_file};
  }

  sub ircs { @{$_[0]->{ircs}} }
  sub plugins { @{$_[0]->{plugins}} }

  sub config {
    my ($self, $key) = @_;
    if ($key) {
      return $self->{config}{$key};
    }
    return $self->{config};
  }
}

1;
