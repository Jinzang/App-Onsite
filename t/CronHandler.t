#!/usr/bin/env perl
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 6;

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

my $msg = $o->run("value=15");
is($msg, "Value in bounds: 15", "valid request"); # test 4

$msg = $o->run("value=25");
is($msg, "ERROR Value out of bounds: 25", "invalid request"); # test 5

$msg = $o->run("foo=bar");
is($msg, "Value not set\n", "die from invalid request"); # test 6
