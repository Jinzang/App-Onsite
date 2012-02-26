#!/usr/local/bin/perl
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 7;

use Cwd qw(abs_path getcwd);
use CMS::Onsite::Support::WebFile;

#----------------------------------------------------------------------
# Create object

BEGIN {use_ok("CMS::Onsite::Support::CgiHandler");} # test 1

my $params = {
              min => 0,
              max => 20,
              handler => 'Mock::MinMax',
              script_url => 'http://www.test.org/test.cgi',
             };

my $o = CMS::Onsite::Support::CgiHandler->new(%$params);

isa_ok($o, "CMS::Onsite::Support::CgiHandler"); # test 2
can_ok($o, qw(run)); # test 3

#----------------------------------------------------------------------
# Update config

my $h = $o->{handler};
is($h->{script_url}, $params->{script_url}, "Script url configuration"); # test 4
is($h->{base_url}, 'http://www.test.org/', "Base url configuration"); # test 5

my $cwd = getcwd();
is($h->{data_dir}, "$cwd/t", "Data dir configuration"); # test 6
is($h->{template_dir}, "$cwd/t/templates", "Templates dir configuration"); # test 7

#----------------------------------------------------------------------
# TODO: finish

my $request = {value => 15};
my $response = $o->run($request);
is($response->{results}, "Value in bounds", "valid request"); # test  8

$request->{value} = 25;
$response = $o->run($request);
is($response->{results}, "Value out of bounds", "invalid request"); # test 5

$request = {foo => 'bar'};
$response = $o->run($request);
is($response, "Value not set", "empty request"); # test 6

$request->{value} = 15;
$o->{handler}{die} = 1;
$response = $o->run($request);
is($response, "Debug dump", "die during valid request"); # test 7

$request->{value} = 25;
$response = $o->run($request);
is($response, "Value out of bounds\n",
   "die during invalid request"); # test 8

$response = $o->run(foo => 'bar');
is($response, "Value not set\n", "die during empty request"); # test 9

$o->{handler}{die} = 2;
$response = $o->run(value => 25);
ok($response =~ /Error while handling error/,
   "die during error handling"); # test 10
