#!/usr/local/bin/perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 11;

use Cwd qw(abs_path);
use App::Onsite::Support::WebFile;

sub nopass {
   my %hash;
    foreach my $arg (@_) {
        foreach my $key (keys %$arg) {
            $hash{$key} = $arg->{$key} unless $key =~ /^pass/;
        }
    }   
    return \%hash;
}

sub nopass_list {
    my ($oldlist) = @_;   
    my @list;
    foreach my $item (@$oldlist) {
        push(@list, nopass($item));
    }   
    return \@list;
}

#----------------------------------------------------------------------
# Initialize test directory

$ENV{PATH} = '/bin';
$ENV{REMOTE_USER} = 'admin';

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
              base_url => 'http://onsite.org/',
              template_dir => $template_dir,
              valid_write => "$data_dir",
              data_registry => $data_registry,
             };

BEGIN {use_ok("App::Onsite::UserData");} # test 1

#----------------------------------------------------------------------
# Create test file

my $wf = App::Onsite::Support::WebFile->new(%$params);
my $filename = "$data_dir/user.data";

my $db = <<'EOQ';
user.valid|&
password.valid|&/^\S{6,}$/
password.style|type=password
||
id|0001
user|admin
password|7DwegeKwuWUYI
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
		[user]
DEFAULT_COMMAND = browse
CLASS = App::Onsite::UserData
EOQ

$wf->writer("$template_dir/$data_registry", $registry);

#----------------------------------------------------------------------
# Create object

my $data = App::Onsite::UserData->new(%$params);
$data->{wf}->relocate($data_dir);

isa_ok($data, "App::Onsite::UserData"); # test 2
can_ok($data, qw(browse_data search_data read_data write_data
                 add_data edit_data remove_data check_id)); # test 3

#----------------------------------------------------------------------
# Check id

my $test = $data->check_id('user:0001') ? 1 : 0;
is ($test, 1, "Does have id");  # test 4

$test = $data->check_id('user:0003') ? 1 : 0;
is ($test, 0, "Doesn't have id");  # test 5

#----------------------------------------------------------------------
# Read data

my $r = {
         id => 'user:0001',
         user => 'admin',
         type => 'user',
         summary => "Change name or password of admin",
         password => '7DwegeKwuWUYI',
         password2 => '7DwegeKwuWUYI',
        };

my $d = $data->read_data('user:0001');

is_deeply($d, $r, "Read data"); # Test 6
$r = nopass($r);

#----------------------------------------------------------------------
# Write data

my $s = {
         id => 'user:0002',
         user => "editor",
         password => "editor",
         password2 => "editor",
        };

$data->write_data('user:0002', $s);
$d = $data->read_data('user:0002');
$d = nopass($d);

$s = nopass($r, $s);
$s->{summary} =~ s/admin/editor/;

is_deeply($d, $s, "Write data"); # Test 7

#----------------------------------------------------------------------
# Search data

my $list = $data->search_data({user => 'admin'}, 'user');
$list = nopass_list($list);
is_deeply($list, [$r], "Search data"); # test 8

$list = $data->search_data({user => 'editor'}, 'user', 1);
$list = nopass_list($list);
is_deeply($list, [$s], "Search data with limit"); # test 9

#----------------------------------------------------------------------
# Browse data

$d = $data->browse_data('user');
$d = nopass_list($d);
is_deeply($d, [$s, $r], "Browse data"); # test 10

#----------------------------------------------------------------------
# Remove data

$s->{remote_user} = $ENV{REMOTE_USER};
$data->remove_data('user:0002', $s);
my $found = $data->check_id('user:0002') ? 1 : 0;
is($found, 0, "Remove data"); # Test 11
