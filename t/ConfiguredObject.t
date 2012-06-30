#!/usr/bin/env perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 11;

use Mock::TestObject;
use Mock::TestObject2;

#----------------------------------------------------------------------
# Create object

BEGIN {use_ok("CMS::Onsite::Support::ConfiguredObject");} # test 1

my %parameters = (
    two => 2,
    three => 3,
    list => [qw(a b c)],
);

#----------------------------------------------------------------------
# Test new

my $co = CMS::Onsite::Support::ConfiguredObject->new(cf => 'Mock::ConfigFile');
can_ok($co, qw(new parameters)); #test 2
is(ref($co->{cf}), 'Mock::ConfigFile', "Creation"); # test 3

my $to = Mock::TestObject->new(cf => 'Mock::ConfigFile');
is_deeply($to, {one => 0, two => 0, list => []}, "No Configuration"); # test 4

$co->{cf}->write_file(\%parameters);
$to = Mock::TestObject->new(cf => 'Mock::ConfigFile');
is_deeply($to, {one => 0, two => 2, list => [qw(a b c)]}, "With Configuration"); # test 5

$to = Mock::TestObject->new(cf => 'Mock::ConfigFile', one => 1, two => 20);
is_deeply($to, {one => 1, two => 20, list => [qw(a b c)]}, "Some Configuration"); # test 6

$parameters{list} = 'x';
$co->{cf}->write_file(\%parameters);
$to = Mock::TestObject->new(cf => 'Mock::ConfigFile', one => 1);
is_deeply($to, {one => 1, two => 2, list => [qw(x)]}, "List Promotion"); # test 7

$parameters{two} = [qw(a b c)];
$co->{cf}->write_file(\%parameters);
$to = eval {Mock::TestObject->new(cf => 'Mock::ConfigFile')};
is ($@, "Field type mismatch for two in Mock::TestObject\n",
    "Array type mismatch"); # test 8

$to = eval {Mock::TestObject->new(cf => [1])};
is ($@, "Field type mismatch for cf in CMS::Onsite::Support::ConfiguredObject\n",
    "Hash type mismatch"); # test 9

$co->{cf}->write_file({one => 1, two => 2, three => 3, list => [qw(x y z)]});
$to = Mock::TestObject2->new(cf => 'Mock::ConfigFile');
is(ref($to->{mo}), 'Mock::TestObject', "Subobject creation"); # test 10
is(ref($to->{mu}), 'Mock::TestObject2', "Subobject recursion"); # test 11
