use v5.14;

package Fuhbot::Console 0.1 {
  use AnyEvent::Debug;
  use Cwd;

  my $sock = getcwd . "/fuhbot.sock";
  unlink $sock if -e $sock;
  AnyEvent::Debug::shell "unix/", $sock;

  END { unlink $sock }
}

1;
