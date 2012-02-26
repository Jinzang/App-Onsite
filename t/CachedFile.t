#!/usr/bin/env perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 18;

use IO::File;
use Cwd qw(abs_path);

#----------------------------------------------------------------------
# Create objext

BEGIN {use_ok("CMS::Onsite::Support::CachedFile");} # test 1

#----------------------------------------------------------------------
# Initialize test directory

$ENV{PATH} = '/bin';
my $data_dir = 'test';
system("/bin/rm -rf $data_dir");
mkdir $data_dir;

#----------------------------------------------------------------------
# Create test files

my $i = 0;
foreach my $filename (qw(one two three four)) {
    my $fd = IO::File->new("$data_dir/$filename", 'w')
        or die "Can't create $filename: $!";
    print $fd ++ $i, "\n";
    close $fd;
}

my $cache = CMS::Onsite::Support::CachedFile->new(expires => 2);
isa_ok($cache, "CMS::Onsite::Support::CachedFile"); # test 2
can_ok($cache, qw(fetch save free flush)); # test 3

#----------------------------------------------------------------------
# Save and fetch files to cache

chdir($data_dir);
foreach my $filename (qw(one three)) {
    my $fd = IO::File->new($filename, 'r')
        or die "Can't read $filename: $!";

    my $value = <$fd>;
    chomp $value;
    $cache->save($filename, $value);

    my $newvalue = $cache->fetch($filename);
    is($newvalue, $value, "Cache save and fetch"); # test 4 & 6

    my $newname = abs_path($filename);
    $newvalue = $cache->fetch($newname);
    is($newvalue, $value, "Fetch absolute name"); # test 5 & 7
}

#----------------------------------------------------------------------
# Test not in cache

foreach my $filename (qw(two four five)) {
    my $value = $cache->fetch($filename);
    is($value, undef, "Fetch value not in cache"); # test 8-10
}

#----------------------------------------------------------------------
# Remove from cache

foreach my $filename (qw(three four)) {
    $cache->free($filename);
    my $value = $cache->fetch($filename);
    is($value, undef, "Fetch value not in cache"); # test 11 & 12
}

#----------------------------------------------------------------------
# Update time, invalidate cache

sleep 2;
my $value = $cache->fetch("one");
is($value, undef, "Invalid cache"); # test 13

#----------------------------------------------------------------------
# Flush the cache

$cache->flush;
$value = $cache->fetch("one");
is($value, undef, "Flushed cache"); # test 14

#----------------------------------------------------------------------
# Backstop cache

foreach my $filename (qw(two four)) {
    my $fd = IO::File->new($filename, 'r')
        or die "Can't read $filename: $!";

    my $value = <$fd>;
    chomp $value;
    $cache->save($filename, $value);
}

foreach my $filename (qw(one two three four)) {
    my $fd = IO::File->new($filename, 'r')
        or die "Can't read $filename: $!";

    my $value = <$fd>;
    chomp $value;

    my $newvalue = $cache->fetch($filename) || $value;
    is($newvalue, $value, "Backstop cache"); # test 15-18
}
