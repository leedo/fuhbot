use v5.14;

package Fuhbot 0.1 {
  use AnyEvent;
  use AnyEvent::IRC::Util;
  use Fuhbot::IRC;
  use AnyEvent::HTTPD;
  use AnyEvent::Redis;
  use Net::CIDR::Lite;
  use Scalar::Util qw/weaken/;
  use List::Util qw/first/;
  use List::MoreUtils qw/any/;

  sub new {
    my ($class, $file) = @_;
    die "config required" unless $file;

    my $config = do $file;
    my $redis = AnyEvent::Redis->new(
      on_error => sub {
        warn $_[0] unless $_[0] =~ /^Broken pipe/;
      }
    );

    bless {
      ircs     => [],
      plugins  => [],
      config   => {},
      brain    => $redis,
      config   => $config,
    }, $class;
  }

  sub run {
    my $self = shift;
    $self->{cv} = AE::cv;
    my $sigs = AE::signal INT => sub { $self->shutdown };

    say "loading plugins...";
    $self->load_plugins;

    $self->build_httpd if $self->routes;

    say "loading ircs...";
    $self->load_ircs;

    $self->{cv}->recv;
    $self->cleanup;
  }

  sub build_httpd {
    my $self = shift;

    my $listen = $self->config('listen') || "http://0.0.0.0:9091";
    my ($proto, $host, $port) = $listen =~ m{^(https?)://([^:]+):(\d+)};
    my $reverse = $self->config("reverse_http_proxy");

    my $httpd = AnyEvent::HTTPD->new(
      ssl  => $proto eq "https",
      host => $host,
      port => $port,
    );

    say "listening at $listen";

    $httpd->reg_cb("" => sub {
      if (defined $_[1]->headers->{"x-forwarded-for"} and $_[1]->client_host eq $reverse) {
        ($_[1]->{host},) = $_[1]->headers->{"x-forwarded-for"} =~ /([^,\s]+)/;
      }
      $self->handle_http_req(@_)
    });
    $self->{httpd} = $httpd;
  }

  sub shutdown { $_[0]->{cv}->send }

  sub cleanup {
    my $self = shift;

    say "\ndisconnecting ircs...";
    my $cv = AE::cv;

    for my $irc (grep {$_->is_connected} $self->ircs) {
      $cv->begin;
      $irc->shutdown(sub { $cv->end });
    }

    my $t = AE::timer 5, 0, sub {
      $cv->croak("timed out disconnecting from IRCs");
    };

    $cv->recv;
  }

  sub broadcast {
    my ($self, $msg, $networks) = @_;
    my %map = map {my ($n, @c) = split "@"; lc $n, @c ? \@c : undef} @{$networks || []};
    for my $irc ($self->ircs(keys %map)) {
      $irc->broadcast($msg, $map{lc $irc->name});
    }
  }

  sub load_ircs {
    my $self = shift;
    for my $config (@{$self->config("ircs")}) {
      my $irc = Fuhbot::IRC->new($config);
      $irc->reg_cb("irc_*" => sub { $self->handle_irc_line(@_) });
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
    
    $self->{broadcast_cb} ||= sub {$self->broadcast(@_)};

    my $plugin = $class->new(
      config    => $config,
      brain     => $self->{brain},
      broadcast => $self->{broadcast_cb},
    );

    weaken (my $weak = $plugin);
    $weak->prepare_plugin;

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

  sub handle_irc_line {
    my ($self, $irc, $msg) = @_;
    # XXX awful method of finding channel name... better?
    my $chan = first {$irc->is_channel_name($_)} @{$msg->{params}};

    for my $event ($self->events($irc->name, $chan)) {
      my ($plugin, $event, $cb) = @$event;
      if (lc $msg->{command} eq $event) {
        weaken (my $weak = $plugin);
        $cb->($weak, $irc, $msg);
      }
    }
  }

  sub handle_http_req {
    my ($self, $httpd, $req) = @_;
    my $url = $req->url->path_query;
    for my $route ($self->routes) {
      my ($plugin, $method, $pattern, $cb) = @$route;

      if (my $allowed = $plugin->config("allow_hosts")) {
        my $cidr = Net::CIDR::Lite->new(@$allowed);
        unless ($cidr->find($req->client_host)) {
          return $req->respond([403, 'forbidden', {}, 'forbidden']);
        }
      }

      if (lc $req->method eq $method and $url =~ m{^$pattern}) {
        weaken (my $weak = $plugin);
        $cb->($weak, $req);
        return;
      }
    }
    $req->respond([404, "not found", {"Content-Type" => "text/plain"}, 'not found']);
  }

  sub handle_command {
    my ($self, $irc, $chan, $text) = @_;

    for my $command ($self->commands($irc->name, $chan)) {
      my ($plugin, $pattern, $cb) = @{$command};
      if (my @args = $text =~ m{^$pattern}) {
        # ugh, if no captures in regex @args is (1)
        @args = $1 ? @args : ();
        weaken (my $weak = $plugin);
        return $cb->($weak, $irc, $chan, @args);
      }
    }
  }

  sub events {
    my $self = shift;
    my $p;
    return map {$p = $_; map {[$p, @$_]} $p->events} $self->plugins(@_);
  }

  sub routes {
    my $self = shift;
    my $p;
    return map {$p = $_; map {[$p, @$_]} $p->routes} $self->plugins;
  }

  sub commands {
    my $self = shift;
    my $p;
    return map {$p = $_; map {[$p, @$_]} $p->commands} $self->plugins(@_);
  }

  sub ircs {
    my ($self, @networks) = @_;
    return @{$self->{ircs}} unless @networks;
    grep {
      my $n = $_->name;
      any {lc $_ eq lc $n} @networks
    } @{$self->{ircs}}
  }

  sub plugins {
    my ($self, $network, $chan) = @_;
    return @{$self->{plugins}} unless $network;
    grep {
      my $i = $_->config("ircs");
      !$i || any {
        lc $_->[0] eq lc $network
          && (!$chan || (!$_->[1] || lc $_->[1] eq lc $chan))
      } map {[split "@"]} @$i;
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
