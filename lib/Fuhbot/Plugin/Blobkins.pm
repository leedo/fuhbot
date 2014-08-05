use v5.14;

package Fuhbot::Plugin::Blobkins 0.1 {
  use Fuhbot::Plugin;

  on command "brodkin" => sub  ($self, $irc, $chan) {
    my $first = rands(qw{G J}) . vowels(3) . rands(qw{n rb});
    my $last = "B" . rands(qw{l r}) . vowels(4) . rands(qw{k bk lk dk}) . vowels(1) . rands("n", "ns");
    $irc->send_srv(PRIVMSG => $chan, "$first $last");
  };

  sub rands {
    @_[int(rand(@_))];
  }

  sub maybe_umlaut {
    rand > 0.05 ? $_[0] : "$_[0]\x{034F}\x{0308}";
  }

  sub vowels {
    my $limit = shift;
    my @vowels = (qw{a e i o u}, "\x{00F8}");
    join "", map {maybe_umlaut(rands(@vowels))} 0..int(rand($limit));
  }
}

1;
