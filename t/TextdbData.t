#!/usr/local/bin/perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 15;

use Cwd qw(abs_path);
use App::Onsite::Support::WebFile;

#----------------------------------------------------------------------
# Initialize test directory

$ENV{PATH} = '/bin';
my $data_dir = 'test';
system("/bin/rm -rf $data_dir");

mkdir $data_dir;
$data_dir = abs_path($data_dir);
my $template_dir = "$data_dir/templates";
my $data_registry = 'data.reg';

#----------------------------------------------------------------------
my $params = {
              script_url => 'test.cgi',
              data_dir => $data_dir,
              base_url => 'http://www.stsci.edu/~bsimon/nova',
              template_dir => $template_dir,
              valid_write => "$data_dir",
              data_registry => $data_registry,
             };

BEGIN {use_ok("App::Onsite::TextdbData");} # test 1

#----------------------------------------------------------------------
# Create test file

my $wf = App::Onsite::Support::WebFile->new(%$params);
my $filename = "$data_dir/test.data";

my $db = <<'EOQ';
title.valid|&string
body.valid|&html
author.valid|string
||
id|0001
title|A title
body|The Content
author|An author
||
EOQ

$wf->writer($filename, $db);

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
		[textdb]
EXTENSION = data
CLASS = App::Onsite::TextdbData
EOQ

$wf->writer("$template_dir/$data_registry", $registry);

#----------------------------------------------------------------------
# Create object

my $data = App::Onsite::TextdbData->new(%$params);
$data->{wf}->relocate($data_dir);

isa_ok($data, "App::Onsite::TextdbData"); # test 2
can_ok($data, qw(browse_data search_data read_data write_data
                 add_data edit_data remove_data check_id next_id)); # test 3

#----------------------------------------------------------------------
# Check id

my $test = $data->check_id('test:0001') ? 1 : 0;
is ($test, 1, "Does have id");  # test 4

$test = $data->check_id('test:0002') ? 1 : 0;
is ($test, 0, "Doesn't have id");  # test 5

#----------------------------------------------------------------------
# Next id

my $id2 = $data->next_id('test');
is ($id2, 'test:0002', "Next id");  # test 6

#----------------------------------------------------------------------
# Read data

my $r = {title => "A title",
         body => "The Content",
         summary => "The Content",
         author => "An author",
         id => 'test:0001',
        };

my $d = $data->read_data('test:0001');

is_deeply($d, $r, "Read data"); # Test 7

#----------------------------------------------------------------------
# Write data

delete $d->{summary};
$d->{title} =~ s/A/New/;
$d->{body} =~ s/The/New/;
$d->{author} =~ s/An/New/;

my $s;
%$s = %$d;
$s->{id} = 'test:0002';
$s->{summary} = $d->{body};

$data->write_data('test:0002', $d);
$d = $data->read_data('test:0002');

is_deeply($d, $s, "Write data"); # Test 8

#----------------------------------------------------------------------
# Field info

$d = $data->field_info('test:0001');
my $i = [
    {NAME => 'author', valid => 'string'},
    {NAME => 'body', valid => '&html'},
    {NAME => 'title', valid => '&string'},
];

is_deeply ($d, $i, "Field info"); # Test 9

#----------------------------------------------------------------------
# Search data

my $list = $data->search_data({author => 'author'}, 'test');
is_deeply($list, [$r, $s], "Search data"); # test 10

$list = $data->search_data({author => 'author'}, 'test', 1);
is_deeply($list, [$s], "Search data with limit"); # test 11

$list = $data->search_data({author => 'An'}, 'test');
is_deeply($list, [$r], "Search data single term"); # test 12

$list = $data->search_data({body =>'New', title => 'New'}, 'test');
is_deeply($list, [$s], "Search data multiple terms"); # test 13

#----------------------------------------------------------------------
# Browse data

$d = $data->browse_data('test');
is_deeply($d, [$s, $r], "Browse data"); # test 14

#----------------------------------------------------------------------
# Remove data

$data->remove_data('test:0002', $s);
my $found = $data->check_id('test:0002') ? 1 : 0;
is($found, 0, "Remove data"); # Test 15
