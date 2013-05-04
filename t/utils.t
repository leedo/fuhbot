use Test::More;
use Fuhbot::Util;

subtest "longest common prefix", sub {
  my @files = qw(
    cookbooks/php/files/default/php.staging.ini
    cookbooks/php/files/default/php.web.ini
    cookbooks/php/recipes/package.rb
  );

  my $file = Fuhbot::Util::longest_common_prefix(@files);
  is $file, "cookbooks/php/", "cookbooks php";

  @files = qw(
    cookbooks/php/test
    cookbooks/nginx/test
    cookbooks/ars/test
  );
  $file = Fuhbot::Util::longest_common_prefix(@files);
  is $file, "cookbooks/", "cookbooks";

  @files = qw(
    recipes/php
    cookbookes/php
  );
  $file = Fuhbot::Util::longest_common_prefix(@files);
  is $file, "", "empty";
};

done_testing();
