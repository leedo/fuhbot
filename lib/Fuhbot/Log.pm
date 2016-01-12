use v5.20;
use experimental 'signatures';

package Fuhbot::Log 0.1 {

  sub info ($line) {
    Fuhbot::Log::_print($line);
  }

  sub _print ($line) {
    my $date = DateTime->now;
    printf STDERR "%s %s - %s\n", $date->ymd, $date->hms, $line;
  }
}

1;
