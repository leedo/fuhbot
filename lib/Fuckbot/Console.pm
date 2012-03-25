use v5.14;

package Fuckbot::Console 0.1 {
  use AnyEvent::Debug;
  use Cwd;

  my $guard;

  sub import {
    my $sock = getcwd . "/fuckbot.sock";
    unlink $sock if -e $sock;
    AnyEvent::Debug::shell "unix/", $sock;
    $guard = bless [$sock], "Fuckbot::Console";
  }

  sub DESTROY {
    unlink $guard->[0];
  }
}

1;
