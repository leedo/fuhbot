package Fuhbot::Plugin::Sets 0.1 {
  use Fuhbot::Plugin;

  on command qr{^add ([^\s]+) (.+)$} => sub ($self, $irc, $chan, $key, $value) {
    $self->brain->sadd($key, $value, sub {
      $irc->send_serv(PRIVMSG => $chan, "ok!");
    });
  };

  on commend qr{^rem ([^\s]+) (.+)$} => sub ($self, $irc, $chan, $key, $value) {
    $self->brain->srem($key, $value, sub {
      $irc->send_srv(PRIVMSG => $chan, "ok!");
    });
  };

  on command qr{^([^\s]+)$} => sub ($self, $irc, $chan, $key) {
    $self->brain->srandmember($key, sub ($value) {
      $irc->send_srv(PRIVMSG => $chan, $value) if defined $value;
    });
  };
}

1;
