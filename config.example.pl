{
  plugins => [
    {
      name => "Github",
      allow_hosts => [
        "192.30.252.0/22",
        "204.232.175.64/27",
      ],
    },
    {
      name => "Jenkins",
      url  => "http://localhost/",
    },
    {
      name => "Insult",
    },
  ],
  listen => "http://0.0.0.0/9091",
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
