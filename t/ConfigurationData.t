#!/usr/bin/env perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 11;

use IO::File;
use Cwd qw(abs_path);

#----------------------------------------------------------------------
# Initialize test directory

$ENV{PATH} = '/bin';
my $data_dir = 'test';
system("/bin/rm -rf $data_dir");

mkdir $data_dir;
$data_dir = abs_path($data_dir);

#----------------------------------------------------------------------
# Create object

BEGIN {use_ok("CMS::Onsite::ConfigurationData");} # test 1

my $params = {
              data_dir => $data_dir,
              config_file => 'editor.cfg',
              valid_write => "$data_dir",
             };

my $data = CMS::Onsite::ConfigurationData->new(%$params);

isa_ok($data, "CMS::Onsite::ConfigurationData"); # test 2
can_ok($data, qw(browse_data search_data read_data write_data
                 add_data edit_data remove_data check_id next_id)); # test 3

#----------------------------------------------------------------------
# Create test file

my $config = <<'EOQ';
# Length of time until cache expires
EXPIRES = 600
# Length of Summary
SUMMARY_LENGTH = 300
EOQ

my $filename = "$data_dir/editor.cfg";
$filename = $data->{wf}->validate_filename($filename, 'w');

$data->{wf}->relocate($data_dir);
$data->{wf}->writer($filename, $config);

#----------------------------------------------------------------------
# Test id to filename

my $id = $data->filename_to_id($filename);
is($id, 'editor', "Filename to id"); # test 4

my ($file, $extra) = $data->id_to_filename($id);
is($file, $filename, "Id to filename"); # test 5

#----------------------------------------------------------------------
# Check id

my $test = $data->check_id('editor', 'r');
is($test, 1, "Check id, read mode"); # test 6

$test = $data->check_id('editor', 'w');
is($test, 1, "Check id, write mode"); # test 7

$test = $data->check_id('foobar', 'r');
is($test, undef, "Check id, bad id"); # test 8

#----------------------------------------------------------------------
# Read data

my $r = {expires => 600,
         title => 'Editor Configuration',
         summary => 'Make changes to the editor configuration',
         summary_length => 300,
         id => 'editor'};

my $d = $data->read_data('editor');
is_deeply($d, $r, "Read data"); # Test 9

#----------------------------------------------------------------------
# Edit data

$d->{expires} = 1000;
$d->{summary_length} = 500;

$data->edit_data('editor', $d);
my $s = $data->read_data('editor');

is_deeply($s, $d, "Edit data"); # Test 10

#----------------------------------------------------------------------
# Field info

my $i = [
        {NAME => 'expires',
         VALUE => 1000,
         title => 'Length of time until cache expires'},
        {NAME => 'summary_length',
         VALUE => 500,
         title => 'Length of Summary'},
        ];

$d = $data->field_info('editor.cfg');
is_deeply($d, $i, "Field Info"); # Test 11
