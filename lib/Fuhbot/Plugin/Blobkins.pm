use v5.14;

package Fuhbot::Plugin::Blobkins 0.1 {
  use Fuhbot::Plugin;

  on command "brodkin" => sub { 
    my ($self, $irc, $chan) = @_;
    my @first_mix = qw{n rb};
    my $first = "J" . vowels() . rands(@first_mix);
    my @last_mix = qw{l r k};
    my $last = "B" . rands(@last_mix) . vowels() . "kins";
    $irc->send_srv(PRIVMSG => $chan, "$first $last");
  };

  sub rands {
    @_[int(rand(@_))];
  }

  sub vowels {
    my @vowels = qw{a e i o u};
    join "", map {$vowels[int(rand(@vowels))]} 0..rand(shift || 5);
  }
}

1;
