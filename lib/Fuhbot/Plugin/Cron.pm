package Fuhbot::Plugin::Cron 0.1 {
  use Fuhbot::Plugin;
  use DateTime::Event::Cron;

  sub prepare_plugin ($self) {
    warn "setting up timer";
    $self->{timer} = AE::timer 0, 60, $self->cron;
  }

  sub cron ($self) {
    return sub {
      warn "running cron";
      my $jobs = $self->config("jobs");
      for my $job (@$jobs) {
        my $c = DateTime::Event::Cron->new($job->[0]);
        warn $job->[0];
        if ($c->match) {
          warn "match";
          $job->[1]($self);
        }
      }
    };
  }
}

1;
