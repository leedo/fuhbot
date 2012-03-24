{
  plugins => [
    {
      name => "Github",
      port => 9091,
    }
  ],
  ircs => [
    {
      name => "perl",
      host => "irc.perl.org",
      port => 6667,
      nick => "fuckbot",
      channels => [qw/#fuckbot/],
    }
  ]
}
