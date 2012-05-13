#!/usr/bin/env perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 12;

use IO::File;
use Cwd qw(abs_path getcwd);
use CMS::Onsite::Support::WebFile;

#----------------------------------------------------------------------
# Initialize test directory

$ENV{PATH} = '/bin';
my $data_dir = 'test';
system("/bin/rm -rf $data_dir");

mkdir $data_dir;
$data_dir = abs_path($data_dir);
my $template_dir = "$data_dir/templates";
my $data_registry = 'data.reg';

my $params = {
              script_url => 'test.cgi',
              data_dir => $data_dir,
              template_dir => $template_dir,
              base_url => 'http://www.stsci.edu/~bsimon/nova',
              valid_write => $data_dir,
              data_registry => $data_registry,
             };

#----------------------------------------------------------------------
# Create test files

my $wf = CMS::Onsite::Support::WebFile->new(%$params);

my $hash = {
    'title' => 'A title',
    'body' => 'The Content',
    'author' => 'An author',
};

my $filename = "$data_dir/a-title.dump";
$filename = $wf->validate_filename($filename, 'w');

my $dumper = Data::Dumper->new([$hash], ['hash']);
my $output = $dumper->Dump();

$wf->writer($filename, $output);

my $registry = <<'EOQ';
        [file]
SEPARATOR = :
INDEX_NAME = index
ID_FIELD = title
SORT_FIELD = id
SUMMARY_FIELD = body
ID_LENGTH = 63
INDEX_LENGTH = 4
HAS_SUBFOLDERS = 0
PARENT_COMMANDS = browse
PARENT_COMMANDS = search
COMMANDS = browse
COMMANDS = add
COMMANDS = edit
COMMANDS = remove
COMMANDS = search
        [dumper]
EXTENSION = dump
CLASS = CMS::Onsite::DumperData
EOQ

$wf->writer("$template_dir/$data_registry", $registry);

#----------------------------------------------------------------------
# Create object

BEGIN {use_ok("CMS::Onsite::DumperData");} # test 1

my $data = CMS::Onsite::DumperData->new(%$params);
isa_ok($data, "CMS::Onsite::DumperData"); # test 2
can_ok($data, qw(browse_data search_data read_data write_data
                 add_data edit_data remove_data check_id next_id)); # test 3

$wf->relocate($data_dir);

#----------------------------------------------------------------------
# Test id to filename

my $id = $data->filename_to_id($filename);
is($id, 'a-title', "Filename to id"); # test 4

my ($file, $extra) = $data->id_to_filename("$id:0002");
is($file, $filename, "Id to filename"); # test 5
is($extra, '0002', "Id to filename extra"); # test 6

#----------------------------------------------------------------------
# Check id

my $test = $data->check_id('new-title') ? 1 : 0;
is ($test, 0, "Doesn't have id");  # test 7

$test = $data->check_id('a-title') ? 1 : 0;
is ($test, 1, "Does have id");  # test 8

#----------------------------------------------------------------------
# Test redirect url

my $url = $data->redirect_url('a-title');
is($url, $params->{base_url}, "Redirect url"); # test 9

#----------------------------------------------------------------------
# Read data

my $r = {title => "A title",
         body => "The Content",
         author => "An author",
         summary => "The Content",
         id => 'a-title',
        };

my $d = $data->read_data('a-title');
is_deeply($d, $r, "Read data"); # Test 10

#----------------------------------------------------------------------
# Write data

$d->{title} =~ s/A/New/;
$d->{body} =~ s/The/New/;
$d->{author} =~ s/An/New/;

my $s;
%$s = %$d;
$s->{id} = 'new-title';

$data->write_data('new-title', $d);
$d = $data->read_data('new-title');

is_deeply($d, $s, "Write data"); # Test 11

#----------------------------------------------------------------------
# Field info

my $i = [
        {NAME => 'author'},
        {NAME => 'body'},
        {NAME => 'title'},
        ];
$d = $data->field_info('a-title');
is_deeply($d, $i, "Field Info"); # Test 12
