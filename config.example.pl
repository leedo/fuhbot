{
  plugins => [
    {
      name => "Github",
      port => 9091,
    },
    {
      name => "Jenkins",
      port => 9091,
      url  => "http://localhost/",
    },
    {
      name => "Insult",
    },
  ],
  ircs => [
    {
      name => "perl",
      host => "irc.perl.org",
      port => 6667,
      nick => "fuhbot",
      channels => [qw/#fuhbot/],
    }
  ]
}
