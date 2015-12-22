package Fuhbot::Plugin::Cron 0.1 {
  use Fuhbot::Plugin;
  use DateTime::Event::Cron;

  sub prepare_plugin ($self) {
    $self->{timer} = AE::timer 0, 60, $self->cron;
  }

  sub cron ($self) {
    return sub {
      my $jobs = $self->config("jobs");
      for my $job (@$jobs) {
        my $c = DateTime::Event::Cron->new($job->[0]);
        if ($c->match) {
          $job->[1]($self);
        }
      }
    };
  }
}

1;
