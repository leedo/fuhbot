use v5.14;

package Fuckbot::Plugin::Insult 0.1 {
  use parent 'Fuckbot::Plugin';
  use List::Util;

  our @INSULTS = ("fuck you", "eat shit");

  sub irc_privmsg {
    my ($self, $irc, $msg) = @_;

    my ($dest, $text) = @{$msg->{params}};
    my $nick = $irc->nick;

    if ($text =~ /^$nick:?\s*insult\s+(\S+)/) {
      my $nick = $1;
      my $insult = (List::Util::shuffle @INSULTS)[0];
      $irc->send_srv(PRIVMSG => $dest, "hey $nick, $insult");
    }
  }
}

1;
