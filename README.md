# fuhbot

<pre>perl -Ilib bin/fuhbot config.pl</pre>

fuhbot is a simple IRC bot with a administrative console and plugin
system.  Plugins have access to IRC events and can broadcast messages
to all channels.

## config

The config file is perl. The last statement must return a hash
reference.  This hash should contain a `plugins` key with a list
of plugins to load, and an `ircs` key with a list of IRC servers
to connect to.

This is a very simple config that loads the `Insult` plugin.

<pre>
{
  plugins => [
    { name => "Insult" },
  ],
  ircs => [
    { name => "perl",
      host => "irc.perl.org,
      port => 6667,
      nick => "fuhbot",
    }
  ],
}
</pre>

### limiting plugins to specific IRC networks

To limit a plugin to a specific IRC network add an `ircs` key to
it's configuration. The following configuration will only use the
`Insult` plugin on the `perl` network.

<pre>
{
  plugins => [
    { name => "Insult",
      ircs => [qw/perl/],
    },
  ],
  ircs => [
    { name => "perl",
      host => "irc.perl.org",
      port => 6667,
      nick => "fuhbot",
    },
    { name => "freenode",
      host => "irc.freenode.com",
      port => 6667,
      nick => "fuhbot",
    },
  ],
}
</pre>



## writing plugins

Plugins should inherit from `Fuhbot::Plugin`, and can use the
`prepare_plugin` method to setup any attributes when the bot is
started.

### IRC events

Any methods prefixed with `irc_` will be treated as IRC event
handlers (e.g. `irc_001` responds to the 001 event). The method
will recieve the IRC client and parsed message as arguments.

This plugin will broadcast a message whenever a topic is changed.

<pre>
  use v5.14;

  package Fuhbot::Plugin::Topic 0.1 {
    use parent "Fuhbot::Plugin";

    sub irc_topic {
      my ($self, $irc, $msg) = @_;
      my ($channel, $topic) = @{$msg->{params}};
      $self->broadcast("$channel has a new topic! $topic");
    }
  }

  1;
</pre>

### IRC commands

Plugins can also register command handlers. This simplifies the
process of parsing commands. To register command handlers, override
the `commands` method, and return a list of command names and
callbacks. When a the command matches it will be called, and be
passed the IRC connection, channel name, and any text after the
command.

The following plugin responds to the line `fuhbot: insult lee`.

<pre>
  use v5.14

  package Fuhbot::Plugin::Insult 0.1 {
    use parent "Fuhbot::Plugin";
    
    sub commands {
      insult => sub { shift->insult(@_) }
    }
    
    sub insult {
      my ($self, $irc, $chan, $nick) = @_;
      $irc->send_srv(PRIVMSG => $chan, "fuh $nick");
    }
  }

  1;
</pre>

### HTTP events

Plugins also have access to an HTTP server. This can be useful for
responding to hooks from services such as Github. This example plugin
creates an HTTP server and broadcasts a message when `/toot` is
requested.

<pre>
  use v5.14;

  package Fuhbot::Plugin::Toot 0.1 {
    use parent "Fuhbot::Plugin";
    use Fuhbot::HTTPD;

    sub prepare_plugin {
      my $self = shift;
      $self->{httpd} = Fuhbot::HTTPD->new(8080);
      $self->{httpd}->reg_cb("/toot", sub {
        my ($httpd, $req) = @_;
        $req->respond(["text/plain", "toot!"]);
        $self->broadcast("Someone tooted.");
      });
    }
  }

  1;
</pre>

### saving state

Plugins have a `brain` method that gives access to a Redis client.
This should be used to save all non-configuration related state.

This plugin implements `quote random` and `quote add` commands.

<pre>
use v5.14;

package Fuhbot::Plugin::Quote 0.1 {
  sub commands {
    qr{quote random}   => sub { shift->random(@_) },
    qr{quote add (.+)} => sub { shift->add(@_) },
  }

  sub random {
    my ($self, $irc, $chan) = @_;
    $self->brain->srandmember("quotes", sub {
      my $quote = shift;
      $self->send_srv(PRIVMSG => $chan, $quote);
    });
  }

  sub add {
    my ($self, $irc, $chan, $quote) = @_;
    $self->brain->sadd("quotes", $quote, sub {
      $irc->send_srv(PRIVMSG => $chan, "saved!");
    });
  }
}

1;
</pre>

## console

When the bot is started a unix socket is created. Any perl statements
sent to the socket will be evaluated. `bin/console` provides a
simple readline interface to do this. The bot is available from the
console as `$::fuhbot`.

Here is a simple console session that lists all the IRC servers
that the bot is connected to.

<pre>
> map {$_->name} grep {$_->is_connected} $::fuhbot->ircs

perl
freenode
ars
</pre>

The console is also useful for reloading plugins. This statement
will reload the Insult plugin.

<pre>
> $::fuhbot->reload_plugin("Insult")
</pre>
