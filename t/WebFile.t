#!/usr/bin/env perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 15;

use IO::File;
use Cwd qw(abs_path getcwd);
use App::Onsite::Support::NestedTemplate;

#----------------------------------------------------------------------
# Initialize test directory

$ENV{PATH} = '/bin';
my $data_dir = 'test';
my $script_dir = 'test/script';
system("/bin/rm -rf $data_dir");
mkdir $data_dir;
mkdir $script_dir;

$data_dir = abs_path($data_dir);
$script_dir = abs_path($script_dir);

#----------------------------------------------------------------------
# Create object

BEGIN {use_ok("App::Onsite::Support::WebFile");} # test 1

my $params = {
              index_length => 3,
              data_dir => $data_dir,
              valid_write => [$data_dir, $script_dir,],
             };

my $wf = App::Onsite::Support::WebFile->new(%$params);
my $nt = App::Onsite::Support::NestedTemplate->new();

isa_ok($wf, "App::Onsite::Support::WebFile"); # test 2
can_ok($wf, qw(relocate reader writer validate_filename)); # test 3

#----------------------------------------------------------------------
# relocate

$wf->relocate($data_dir);
my $dir = getcwd();
is($dir, $data_dir, "relocate"); # test 4

#----------------------------------------------------------------------
# validate_filename

my $filename = 'page001.html';
my $required_filename = "$data_dir/$filename";
$filename = $wf->validate_filename($filename, 'w');
is($filename, $required_filename, "validate_filname in data dir"); # test 5

$filename = 'script/template.htm';
$required_filename = "$data_dir/$filename";
$filename = $wf->validate_filename($filename, 'r');
is($filename, $required_filename, "validate_filname in script dir"); # test 6

$filename = '../forbidden.html';
eval {
    $filename = $wf->validate_filename($filename, 'r');
};

is($@, "Invalid filename: $filename\n",
   "validate_filename outside dir"); # test 7

$filename = 'Forbidden.html';
eval {
    $filename = $wf->validate_filename($filename, 'r');
};

is($@, "Invalid filename: $filename\n",
   "validate_filename with hidden filename"); # test 8

#----------------------------------------------------------------------
# Relative and Absolute pathnames

$filename = 'data/page001.html';
my $path = $wf->rel2abs($filename);
$path = $wf->abs2rel($path);

is($path, $filename, "Relative and Absolute pathnames"); # test 9

#----------------------------------------------------------------------
# Clear directory

$wf->remove_directory($script_dir);
ok(! -e $script_dir, "Remove directory"); # test 10

#----------------------------------------------------------------------
# Create test files

my $pagename = "$data_dir/page001.html";
my $templatename = "$script_dir/page.htm";

my $page = <<'EOQ';
<html>
<head>
<!-- begin header -->
<title>A title</title>
<!-- end header -->
</head>
<body bgcolor=\"#ffffff\">
<div id = "container">
<div  id="content">
<h1>Index template file</h1>
<!-- begin content -->
<h1>The Content</h2>
<!-- end content -->
</div>
<div id="sidebar">
<!-- begin sidebar -->
<p>A sidebar</p>
<!-- end sidebar -->
</div>
</div>
</body>
</html>
EOQ

my $template =<<'EOQ';
<html>
<head>
<!-- begin header -->
<title>{{title}}</title>
<!-- end header -->
</head>
<body bgcolor=\"#ffffff\">
<div id = "container">
<div  id="content">
<h1>Index template file</h1>
<!-- begin content -->
<h1><!-- begin title required -->
Title
<!-- end title --></h1>

<!-- begin body html multiline required -->
<p>Body text
across multiple lines</p>
<!-- end body -->
<div><!-- begin author -->
Bernie Simon
<!-- end author --></div>
<!-- end content -->
</div>
<div id="sidebar">
<!-- begin sidebar -->
<ul>
<!-- with others -->
<li><a href="{{url}}">{{title}}</a></li>
<!-- end others -->
</ul>
<!-- end sidebar -->
</div>
</div>
</body>
</html>
EOQ

# Write files

$wf->writer($pagename, $page);
$wf->writer($templatename, $template);

my $src = $wf->reader($pagename);
my $hash = $nt->data($src);

my $r = {
         header => "<title>A title</title>",
         content => "<h1>The Content</h2>",
         sidebar => "<p>A sidebar</p>",
        };

is_deeply($hash, $r, "Read/Write"); #test 11

my $nestedname = "data/dir002/dir001/dir001/page001.html";
$wf->writer($nestedname, $page);

$src = $wf->reader($nestedname);
$hash = $nt->data($src);
is_deeply($hash, $r, "Write nested directories"); # test 12

#----------------------------------------------------------------------
# Test file visitor

my $files = [];
my $visitor = $wf->visitor($data_dir, 1, 'date');
while (my $file = &$visitor()) {
    push(@$files, $file);
}

my $visit_result = [
                    "$data_dir",
                    "$data_dir/data",
                    "$data_dir/page001.html",
                    "$data_dir/script",
                    "$data_dir/data/dir002",
                    "$data_dir/data/dir002/dir001",
                    "$data_dir/data/dir002/dir001/dir001",
                    "$data_dir/data/dir002/dir001/dir001/page001.html",
                    "$data_dir/script/page.htm",
                    ];
is_deeply($files, $visit_result, "File visitor"); # test 13

#----------------------------------------------------------------------
# Test rename file

my $new_nested = $nestedname;
$new_nested =~ s/page001/page002/;
$wf->rename_file($nestedname, $new_nested);
ok(-e $new_nested, "Rename file"); # test 14

#----------------------------------------------------------------------
# Test remove file

$wf->remove_file($pagename);
ok(! -e $pagename, "Remove file"); #test 15
