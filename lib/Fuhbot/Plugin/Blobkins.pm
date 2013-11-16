use v5.14;

package Fuhbot::Plugin::Blobkins 0.1 {
  use Fuhbot::Plugin;

  on command "brodkin" => sub { 
    my ($self, $irc, $chan) = @_;
    my $first = rands(qw{G J}) . vowels() . rands(qw{n rb});
    my $last = "B" . rands(qw{l r k}) . vowels() . rands(qw{k bk}) . "ins";
    $irc->send_srv(PRIVMSG => $chan, "$first $last");
  };

  sub rands {
    @_[int(rand(@_))];
  }

  sub vowels {
    my @vowels = qw{a e i o u};
    join "", map {$vowels[int(rand(@vowels))]} 0..rand(shift || 4);
  }
}

1;
