fuckbot
=======

<pre>perl -Ilib bin/fuckbot config.pl</pre>

fuckbot is a simple IRC bot with a administrative console and plugin
system.  Plugins have access to IRC events and can broadcast messages
to all channels.

config
------

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
      nick => "fuckbot",
    }
  ],
}
</pre>


plugins
-------

Plugins should inherit from `Fuckbot::Plugin`, and can use the
`prepare_plugin` method to setup any attributes when the bot is
started.

Any methods prefixed with `irc_` will be treated as IRC event
handlers (e.g. `irc_001` responds to the 001 event). The method
will recieve the IRC client and parsed message as arguments.

This plugin will broadcast a message whenever a topic is changed.

<pre>
  use v5.14;
  package Fuckbot::Plugin::Topic 0.1 {
    use parent "Fuckbot::Plugin";

    sub irc_topic {
      my ($self, $irc, $msg) = @_;
      my ($channel, $topic) = @{$msg->{params}};
      $self->broadcast("$channel has a new topic! $topic");
    }
  }

  1;
</pre>

Plugins also have access to an HTTP server. This can be useful for
responding to hooks from services such as Github. This example plugin
creates an HTTP server and broadcasts a message when `/toot` is
requested.

<pre>
  use v5.14;
  package Fuckbot::Plugin::Toot 0.1 {
    use parent "Fuckbot::Plugin";
    use Fuckbot::HTTPD;

    sub prepare_plugin {
      my $self = shift;
      $self->{httpd} = Fuckbot::HTTPD->new(8080);
      $self->{httpd}->reg_cb("/toot", sub {
        my ($httpd, $req) = @_;
        $req->respond(["text/plain", "toot!"]);
        $self->broadcast("Someone tooted.");
      });
    }
  }

  1;
</pre>

console
-------

When the bot is started a unix socket is created. Any perl statements
sent to the socket will be evaluated. `bin/console` provides a
simple readline interface to do this. The bot is available from the
console as `$::fuckbot`.

Here is a simple console session that lists all the IRC servers
that the bot is connected to.

<pre>
> map { $_->config("name") } grep {$_->is_connected} $::fuckbot->ircs

perl
freenode
ars
</pre>
