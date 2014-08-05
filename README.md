# fuhbot

<pre>
cp config.example.pl config.pl
vim config.pl
carton install
carton exec -Ilib -- bin/fuhbot config.pl
</pre>

fuhbot is a simple IRC bot with a administrative console and plugin
system. Plugins have access to IRC and HTTP events, and can send
messages to users or channels. perl 5.20.0 is required.

## Configuration

The config file is perl. The last statement must return a hash
reference. This hash should contain a `plugins` key with a list
of plugins to load, and an `ircs` key with a list of IRC servers
to connect to. The `listen` key configures where the HTTPD will
listen for requests. By default it will listen on `0.0.0.0:9091`.

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
  listen => "http://127.0.0.1:9091",
}
</pre>

### Limiting plugins to specific IRC networks and channels

To limit a plugin to a specific IRC network add an `ircs` key to
its configuration. Additionally, plugins can be limited by channel
with a trailing `@#channel` after the IRC network name.

The following configuration will only use the `Insult` plugin in
`#plack` on the `perl` network.

<pre>
{
  plugins => [
    { name => "Insult",
      ircs => [qw/perl@#plack/],
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


### Limiting plugins to specific hosts

Some plugins listen for HTTP requests from external services. The
Github plugin does this, for example. It is best to limit these
requests to the hosts you know should be making them. You can do
this by adding an `allow_hosts` key to the plugin's config.

<pre>
{
  plugins => [
    { name => "Github",
      allow_hosts => [
        "192.30.252.0/22",
        "204.232.175.64/27",
      ],
    },
  ],
  ircs => [ ... ],
}
</pre>

If you are running the bot behind an HTTP proxy (e.g. Apache with
ProxyPass), the above won't work because all requests will appear
to be coming from `127.0.0.1`. To fix this, add the `reverse_http_proxy`
key to your config. It will rewrite the remote host to the
`X-Forwarded-For` header for any requests coming from this address.

<pre>
{
  plugins => [ ... ],
  ircs => [ ... ],
  reverse_http_proxy => "127.0.0.1",
}
</pre>

## Writing plugins

Plugins should import `Fuhbot::Plugin`, and can use the
`prepare_plugin` method to setup any attributes when the bot is
started.

### IRC events

Use the `event` function to register IRC event handlers.

This plugin will broadcast a message whenever a topic is changed.

<pre>
  package Fuhbot::Plugin::Topic 0.1 {
    use Fuhbot::Plugin;

    on event topic => sub ($self, $irc, $msg) {
      my ($channel, $topic) = @{$msg->{params}};
      $self->broadcast("$channel has a new topic! $topic");
    };
  }

  1;
</pre>

### IRC commands

Plugins can also register command handlers. This simplifies the
process of parsing commands. Use the `command` function, exported
by `Fuhbot::Plugin` to register commands.

The following plugin responds to the line `fuhbot: insult lee`.

<pre>
  package Fuhbot::Plugin::Insult 0.1 {
    use Fuhbot::Plugin;
    
    on command insult => sub ($self, $irc, $chan, $nick) {
      $irc->send_srv(PRIVMSG => $chan, "fuh $nick");
    }
  }

  1;
</pre>

### HTTP events

Plugins also have access to an HTTP server. This can be useful for
responding to hooks from services such as Github. This example plugin
creates an HTTP handler and broadcasts a message when `/toot` is
requested.

<pre>
  package Fuhbot::Plugin::Toot 0.1 {
    use Fuhbot::Plugin;

    on get "/toot" => sub ($self, $req) {
      $req->respond(["text/plain", "toot!"]);
      $self->broadcast("Someone tooted.");
    };
  }

  1;
</pre>

### Saving state

Plugins have a `brain` method that gives access to a Redis client.
This should be used to save all non-configuration related state.

This plugin implements `quote random` and `quote add` commands.

<pre>
package Fuhbot::Plugin::Quote 0.1 {
  use Fuhbot::Plugin;

  on command "quote random" => sub ($self, $irc, $chan) {
    $self->brain->srandmember("quotes", sub ($quote) {
      $self->send_srv(PRIVMSG => $chan, $quote);
    });
  };

  on command qr{quote add\s+(.+)} => sub ($self, $irc, $chan, $quote) {
    $self->brain->sadd("quotes", $quote, sub {
      $irc->send_srv(PRIVMSG => $chan, "saved!");
    });
  };
}

1;
</pre>

## Accessing the console

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
