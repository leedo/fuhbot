use v5.16;
use warnings;
use mop;

use AnyEvent;
use AnyEvent::IRC::Util;
use AnyEvent::HTTPD;
use AnyEvent::Redis;
use Scalar::Util qw/weaken/;
use List::Util qw/first/;
use List::MoreUtils qw/any/;

use Fuhbot::IRC;
use Fuhbot::Plugin;

class Fuhbot {
  has $ircs    = [];
  has $plugins = [];
  has $config  = {};
  has $cv      = do { AE::cv };

  has $brain;
  has $httpd;

  method brain {
    $brain //= AnyEvent::Redis->new(
      on_error => sub {
        warn $_[0] unless $_[0] =~ /^Broken pipe/;
      }
    );
  }

  method httpd {
    $httpd //= do {
      my $listen = $self->config('listen') || "http://0.0.0.0:9091";
      my ($proto, $host, $port) = $listen =~ m{^(https?)://([^:]+):(\d+)};

      my $httpd = AnyEvent::HTTPD->new(
        ssl  => $proto eq "https",
        host => $host,
        port => $port,
      );

      say "listening at $listen";

      $httpd;
    };
  }

  method run {
    my $sigs = AE::signal INT => sub { $self->shutdown };

    say "loading plugins...";
    $self->load_plugins;

    if ($self->routes) {
      $self->httpd->reg_cb("" => sub { $self->handle_http_req($_[1]) });
    }

    say "loading ircs...";
    $self->load_ircs;

    $cv->recv;
    $self->cleanup;
  }

  method shutdown { $cv->send }

  method cleanup {
    say "\ndisconnecting ircs...";
    $cv = AE::cv;

    for my $irc (grep {$_->is_connected} $self->ircs) {
      $cv->begin;
      $irc->shutdown(sub { $cv->end });
    }

    my $t = AE::timer 5, 0, sub {
      $cv->croak("timed out disconnecting from IRCs");
    };

    $cv->recv;
  }

  method broadcast ($msg, $networks) {
    my %map = map {my ($n, @c) = split "@"; lc $n, @c ? \@c : undef} @{$networks || []};
    for my $irc ($self->ircs(keys %map)) {
      $irc->broadcast($msg, $map{lc $irc->name});
    }
  }

  method load_ircs {
    for my $config (@{$self->config("ircs")}) {
      my $irc = Fuhbot::IRC->new($config);
      $irc->reg_cb("irc_*" => sub { $self->handle_irc_line(@_) });
      $irc->reg_cb("publicmsg" => sub { $self->channel_msg(@_) });
      $irc->reg_cb("privatemsg" => sub { $self->private_msg(@_) });
      $irc->connect;
      push @$ircs, $irc;
    }
  }

  method load_plugins {
    $self->load_plugin($_) for @{$self->config("plugins")};
  }

  method load_plugin ($plugin_config) {
    my $plugin_class = "Fuhbot::Plugin::$plugin_config->{name}";
    eval "use $plugin_class";
    die $@ if $@;
    
    my $plugin = $plugin_class->new(
      config    => $plugin_config,
      brain     => $self->brain,
      broadcast => sub { $self->broadcast(@_) },
    );

    weaken (my $weak = $plugin);
    $weak->prepare_plugin;

    push @$plugins, $plugin;
  }

  method reload_plugin ($name) {
    delete $INC{"Fuhbot/Plugin/$name.pm"};

    my $orig = [ @$plugins ];
    $plugins = [ grep {$_->name ne $name} @$plugins ];

    my @reload = grep {$_->{name} eq $name} @{$self->config("plugins")};
    eval { $self->load_plugin($_) for @reload };

    if ($@) {
      $plugins = $orig;
      die "error reloading $name plugin: $@";
    }
  }

  method channel_msg ($irc, $chan, $msg) {
    my $text = $msg->{params}[-1];
    my $nick = $irc->nick;

    if ($text =~ s/^(?:!|\Q$nick\E[:,\s]+)//) {
      $self->handle_command($irc, $chan, $text);
    }
  }

  method private_msg ($irc, $nick, $msg) {
    my $text = $msg->{params}[-1];
    my $sender = AnyEvent::IRC::Util::prefix_nick $msg->{prefix};
    $self->handle_command($irc, $sender, $text);
  }

  method handle_irc_line ($irc, $msg) {
    # XXX awful method of finding channel name... better?
    my $chan = first {$irc->is_channel_name($_)} @{$msg->{params}};

    for my $event ($self->events($irc->name, $chan)) {
      my ($plugin, $method, $event) = @$event;
      if (lc $msg->{command} eq $event) {
        $plugin->$method($irc, $msg);
      }
    }
  }

  method handle_http_req ($req) {
    my $url = $req->url->path_query;
    for my $route ($self->routes) {
      my ($plugin, $method, $pattern) = @$route;
      if (lc $req->method eq $method and $url =~ m{^$pattern}) {
        return $plugin->method($req);
      }
    }
    $req->respond([404, "not found", {"Content-Type" => "text/plain"}, 'not found']);
  }

  method handle_command ($irc, $chan, $text) {
    for my $command ($self->commands($irc->name, $chan)) {
      my ($plugin, $method, $pattern) = @{$command};
      if (my @args = $text =~ m{^$pattern}) {
        # ugh, if no captures in regex @args is (1)
        @args = $1 ? @args : ();
        $plugin->$method($irc, $chan, @args);
      }
    }
  }

  method events {
    my $p;
    return map {$p = $_; map {[$p, @$_]} mop::get_meta($p)->events} $self->plugins(@_);
  }

  method routes {
    my $p;
    return map {$p = $_; map {[$p, @$_]} mop::get_meta($p)->routes} $self->plugins;
  }

  method commands {
    my $p;
    return map {$p = $_; map {[$p, @$_]} mop::get_meta($p)->commands} $self->plugins(@_);
  }

  method ircs (@networks) {
    return @$ircs unless @networks;
    grep {
      my $n = $_->name;
      any {lc $_ eq lc $n} @networks
    } @$ircs
  }

  method plugins ($network, $chan) {
    return @$plugins unless $network;
    grep {
      my $i = $_->config("ircs");
      !$i || any {
        lc $_->[0] eq lc $network
          && (!$chan || (!$_->[1] || lc $_->[1] eq lc $chan))
      } map {[split "@"]} @$i;
    } @$plugins;
  }

  method config ($key) {
    if ($key) {
      return $config->{$key};
    }
    return $config;
  }
}

1;
