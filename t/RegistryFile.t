#!/usr/bin/env perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 10;

use IO::File;
use Cwd qw(abs_path getcwd);
use App::Onsite::Support::WebFile;

#----------------------------------------------------------------------
# Create objext

BEGIN {use_ok("App::Onsite::Support::RegistryFile");} # test 1

#----------------------------------------------------------------------
# Initialize test directory

$ENV{PATH} = '/bin';
my $data_dir = 'test';
system("/bin/rm -rf $data_dir");
mkdir $data_dir;
$data_dir = abs_path($data_dir);

my $wf = App::Onsite::Support::WebFile->new(valid_write => [$data_dir]);
$data_dir = $wf->validate_filename($data_dir, 'w');

#----------------------------------------------------------------------
# Create registry file

my $registry_file = <<"EOQ";
     [type_a]
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
     [type_b]
ONE = 10
# This is parameter two
# It has a multi-line comment
TWO = 2
# The last parameter is a list
LIST = d
LIST = e
LIST = f
EOQ

my $registry_name = 'types.reg';
my $filename = "$data_dir/$registry_name";

my $io = IO::File->new($filename, 'w');
print $io $registry_file;
close($io);

#----------------------------------------------------------------------
# Test read file

my $reg = App::Onsite::Support::RegistryFile->new(template_dir => $data_dir,
                         cache => 'Mock::CachedFile');

my $registry = $reg->read_file($registry_name);

my $registry_data = {
                    type_a => {one => 1,
                               two => 2,
                               three => "first line\nsecond line",
                               list => [qw(a b c)]},
                    type_b => {one => 10,
                               two => 2,
                               list => [qw(d e f)]},
                    };

is_deeply($registry, $registry_data, "Read file"); # test 2

#----------------------------------------------------------------------
# Test read data

$registry = $reg->read_data($registry_name, 'type_a');
is_deeply($registry, $registry_data->{type_a}, "Read type_a data"); # test 3

$registry = $reg->read_data($registry_name, 'type_b');
is_deeply($registry, $registry_data->{type_b}, "Read type_b data"); # test 4

#----------------------------------------------------------------------
# Test search

my @types = $reg->search($registry_name, one => 10);
is_deeply(\@types, ['type_b'], "Scalar search one field one match"); # test 5

@types = $reg->search($registry_name, two => 2);
is_deeply(\@types, ['type_a', 'type_b'], "Scalar search one field two matches"); # test 6

@types = $reg->search($registry_name, list => 'b');
is_deeply(\@types, ['type_a'], "List search one field one match"); # test 7

@types = $reg->search($registry_name, one => 10, two => 2);
is_deeply(\@types, ['type_b'], "Scalar search two fields one match"); # test 8

#----------------------------------------------------------------------
# Test project

my $hash = $reg->project($registry_name, 'one');
is_deeply($hash, {type_a => 1, type_b => 10}, "Test project"); # test 9

$hash = $reg->project($registry_name, 'three');
is_deeply($hash, {type_a => "first line\nsecond line"},
          "Test project with missing field"); # test 10