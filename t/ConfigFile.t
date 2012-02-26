#!/usr/bin/env perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 10;

use IO::File;

#----------------------------------------------------------------------
# Create objext

BEGIN {use_ok("CMS::Onsite::Support::ConfigFile");} # test 1

#----------------------------------------------------------------------
# Initialize test directory

$ENV{PATH} = '/bin';
my $data_dir = 'test';
system("/bin/rm -rf $data_dir");
mkdir $data_dir;

#----------------------------------------------------------------------
# Create configuration file

my $config = <<"EOQ";
# This is parameter one
ONE = 1
# This is parameter two
# It has a multi-line comment
TWO = 2
# This is parameter three
# It has a multi-line value
THREE = first line
second line
# The last parameter is a list
LIST = a
LIST = b
LIST = c
EOQ

my @config_lines = map {"$_\n"} split(/\n/, $config);

#----------------------------------------------------------------------
# Test parsing

my $filename = "$data_dir/config.dat";
my $cf = CMS::Onsite::Support::ConfigFile->new(config_file => $filename,
                         cache => 'Mock::CachedFile');

my $lines;
@$lines = @config_lines;
my ($value, $field) = $cf->read_field($lines);
is($value, "# This is parameter one", "Parse simple comment"); # test 2
is($field, undef, "Parse comment flag"); # test 3

($value, $field) = $cf->read_field($lines);
is($field, 'one', "Parse simple value name"); # test 4
is($value, 1, "Parse simple value"); # test 4

($value, $field) = $cf->read_field($lines);
is($value, "# This is parameter two\n# It has a multi-line comment",
    "Multi-line comment"); # test 6

($value, $field) = $cf->read_field($lines);
($value, $field) = $cf->read_field($lines);
($value, $field) = $cf->read_field($lines);
is($value, "first line\nsecond line", "Multi-line value"); # test 7

#----------------------------------------------------------------------
# Test io

my $io = IO::File->new($filename, 'w');
print $io $config;
close($io);

$lines = $cf->read_lines();
is_deeply($lines, \@config_lines, "Read lines"); # test 8

my %configuration = $cf->read_file();
my $configuration_result = {
                            one => 1,
                            two => 2,
                            three => "first line\nsecond line",
                            list => [qw(a b c)],
                            };
is_deeply(\%configuration, $configuration_result, "Read file"); #test 9

$cf->write_file(\%configuration);
$lines = $cf->read_lines();
is_deeply($lines, \@config_lines, "Write file"); # test 10
