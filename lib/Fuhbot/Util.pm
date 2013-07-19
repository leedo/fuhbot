use v5.14;

package Fuhbot::Util 0.1 {
  use AnyEvent::HTTP ();
  use URI::Escape;
  use JSON::XS;
  use Exporter qw/import/;
  use Encode;
  use HTML::Parser;
  use HTML::Entities;

  our @EXPORT_OK = qw/timeago shorten gist longest_common_prefix/;
  our $shorten_format = "http://is.gd/api.php?longurl=%s";

  my %defaults = (
    headers => {
      "Referer"   => "http://www.google.com/",
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.71 Safari/537.36",
    }
  );

  sub http_get {
    my $cb = pop;
    my ($url, %opts) = @_;

    for (%defaults) {
      $opts{$_} = $defaults{$_} unless defined $opts{$_};
    }

    $opts{cookie_jar} = {} unless defined $opts{cookie_jar};

    AnyEvent::HTTP::http_get $url, %opts, sub {
      my ($body, $headers) = @_;

      my $enc = $headers->{"content-encoding"};
      if (defined $enc and $enc eq "gzip") {
        eval { "use IO::Uncompress::Gunzip qw{gunzip};" };
        die "missing IO::Uncompress::Gunzip" if $@;
        my $unzipped;
        IO::Uncompress::Gunzip::gunzip(\$body, \$unzipped);
        $body = $unzipped;
      }

      $cb->($body, $headers);
    };
  }

  sub timeago {
    my $time = shift;

    my $min = 60;
    my $hour = $min * 60;
    my $day = $hour * 24;

    my @when;
    my $seconds = time - $time;

    my $days    = int($seconds / $day);
    if ($days) {
      $seconds -= ($days * $day);
      push @when, "$days days";
    }

    my $hours   = int($seconds / $hour);
    if ($hours) {
      $seconds -= ($hours * $hour);
      push @when, "$hours hour" . ($hours != 1 ? "s" : "");
    }

    my $minutes = int($seconds / $min);
    if ($minutes) {
      $seconds -= ($minutes * $min);
      push @when, "$minutes minute" . ($minutes != 1 ? "s" : "");
    }

    if ($seconds) {
      push @when, "$seconds second" . ($seconds != 1 ? "s" : "");
    }

    if (@when > 1) {
      $when[-1] = "and $when[-1]";
    }
    elsif (@when == 0) {
      push @when, "0 seconds";
    }

    return join(", ", @when) . " ago";
  }
  
  sub shorten {
    my $cb = pop;
    my ($long, %args) = @_;
    my $format = $args{format} || $shorten_format;
    my $url = sprintf $format, uri_escape($long);

    AnyEvent::HTTP::http_get $url, sub {
      my ($body, $headers) = @_;
      $headers->{Status} == 200 ? $cb->($body) : $cb->($long);
    }
  }
 
  sub gist {
    my ($name, $content, $cb) = @_;
    AnyEvent::HTTP::http_post "https://api.github.com/gists",
      encode_json({
        public => JSON::XS::false,
        files => {$name => {content => $content}},
      }),
      sub {
        my ($body, $headers) = @_;
        my $data = decode_json $body;
        $cb->($data->{html_url});
      };
  }

  sub longest_common_prefix {
    my $prefix = shift;
    for (@_) {
      $prefix =~ s/.$// while ! m{^\Q$prefix};
      last if $prefix eq "";
    }
    return $prefix;
  }

  sub resolve_title {
    my ($url, $cb) = @_;
    Fuhbot::Util::http_get $url, sub {
      my ($body, $headers) = @_;
      my ($in_title, $title);
      if ($headers->{Status} == 200) {
        my $p = HTML::Parser->new(
          api_version => 3,
          start_h => [
            sub {
              $in_title = 1 if $_[1] eq "title";
              if ($_[1] eq "meta" and $_[2]->{property} eq "og:title") {
                $title = decode_entities $_[2]->{content};
                $_[0]->eof;
              }
            },
            "self,tag,attr",
          ],
          text_h  => [
            sub {
              if ($in_title) {
                $title = decode_entities $_[1];
              }
            },
            "self,dtext",
          ],
          end_h => [
            sub {
              $_[0]->eof if $_[1] eq "/head";
              $in_title = 0 if $_[1] eq "/title";
            },
            "self,tag",
          ],
        );
        $p->parse(decode "utf8", $body);
        $p->eof;
      }
      # cleanup
      if ($title) {
        $title =~ s/[\n\t]//g;
        $title =~ s/^\s+//g;
        $title =~ s/\s+$//g;
      }
      $cb->($title);
    };
  }
}

1;
