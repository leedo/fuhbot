use Test::More;
use Fuhbot::Util;

my @files = qw(
  cookbooks/php/files/default/php.staging.ini
  cookbooks/php/files/default/php.web.ini
  cookbooks/php/recipes/package.rb
);

my $file = Fuhbot::Util::longest_common_prefix(@files);

is $file, "cookbooks/php/", "longest common prefix";

done_testing();
