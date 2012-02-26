#!/usr/bin/env perl
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 7;

#----------------------------------------------------------------------
# Create objext

BEGIN {use_ok("CMS::Onsite::Support::CronHandler");} # test 1

my $base_dir = '/tmp';
my $uname = `which uname`;
chomp $uname;

my $params = {
                min => 0,
                max => 20,
                namecmd => $uname,
                base_dir => $base_dir,
                handler => 'Mock::MinMax'
             };

my $o = CMS::Onsite::Support::CronHandler->new(%$params);

isa_ok($o, "CMS::Onsite::Support::CronHandler"); # test 2
can_ok($o, qw(run)); # test 3

my $msg = $o->run(15);
is($msg, "Value in bounds", "valid request"); # test 4

$msg = $o->run(25);
is($msg, "Value out of bounds", "invalid request"); # test 5

$o->{handler}{die} = 1;
$msg = $o->run(15);
is($msg, "Debug dump\n", "die during valid request"); # test 6

$msg = $o->run(25);
is($msg, "Value out of bounds\n", "die during invalid request"); # test 7
