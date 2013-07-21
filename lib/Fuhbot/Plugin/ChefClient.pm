use v5.14;
use warnings;
use mop;

use AnyEvent::Util;
use Fuhbot::Util qw/gist/;

class Fuhbot::Plugin::ChefClient extends Fuhbot::Plugin {
  has $lines = [];
  has $time;
  has $cv;

  method cancel ($irc, $chan) is command("deploy cancel") {
    if ($cv) {
      undef $cv;
      $self->broadcast("deploy canceled");
    }
    else {
      $irc->send_srv(PRIVMSG => $chan, "no deploy in progress");
    }
  }

  method start ($irc, $chan) is command("deploy start") {
    if ($cv) {
      $irc->send_srv(PRIVMSG => $chan, "deploy already in progress");
    }
    else {
      $self->broadcast("starting deploy");
      $self->spawn;
    }
  }

  method status ($irc, $chan) is command("deploy status") {
    if ($cv) {
      $irc->send_srv(PRIVMSG => $chan, "deploying (" . scalar $self->errors . " errors)");
      $irc->send_srv($_) for @$lines[-5 .. -1];
    }
    else {
      $irc->send_srv(PRIVMSG => $chan, "idle");
    }
  };

  method errors {
    grep {/ERROR: /} @$lines;
  }

  method spawn {
    $lines = [];
    $time = time;

    my $command = $self->config("command") || "chef-client";

    $cv = run_cmd $command,
      '>' => sub {
        my @lines = split "\n", shift;
        $self->broadcast(map {"\x034\02$_"} grep {/ERROR: /} @lines);
        push @$lines, @lines;
      };

    $cv->cb(sub {
      undef $cv;
      $self->broadcast("deploy complete (" . scalar $self->errors . " errors)");
      gist "deploy-$time.txt",
        join("\n", @$lines),
        sub { $self->broadcast(shift) };
    });
  }
}

1;
