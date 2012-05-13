#!/usr/local/bin/perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 21;

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
my $config_file = "$data_dir/editor.cfg";
my $data_registry = 'data.reg';

#----------------------------------------------------------------------
# Create object

BEGIN {use_ok("CMS::Onsite::DirData");} # test 1

my $params = {
              data_dir => $data_dir,
              template_dir => $template_dir,
              config_file => $config_file,
              script_url => 'test.cgi',
              base_url => 'http://www.stsci.edu',
              valid_write => [$data_dir, $template_dir],
              data_registry => $data_registry,
             };

#----------------------------------------------------------------------
# Create test files

my $wf = CMS::Onsite::Support::WebFile->new(%$params);

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
		[page]
EXTENSION = html
CLASS = CMS::Onsite::PageData
SUPER = dir
SORT_FIELD = id
CREATE_TEMPLATE =create_page.htm
UPDATE_TEMPLATE =update_page.htm
COMMANDS = browse
COMMANDS = add
COMMANDS = edit
COMMANDS = remove
COMMANDS = search
COMMANDS = view
        [dir]
CLASS = CMS::Onsite::DirData
SUPER = dir
HAS_SUBFOLDERS = 1
CREATE_TEMPLATE = create_page.htm
UPDATE_TEMPLATE = update_dir.htm
EOQ

my $dir = <<'EOQ';
<html>
<head>
<!-- begin meta -->
<title><!-- begin title -->A title
<!-- end title --></title>
<!-- end meta -->
</head>
<body bgcolor=\"#ffffff\">
<div id = "container">
<div id="header">
<ul>
<!-- begin toplinks -->
<!-- begin data -->
<!-- set id [[]] -->
<!-- set url [[http://www.stsci.edu/index.html]] -->
<li><a href="http://www.stsci.edu/index.html"><!--begin title -->
Home
<!-- end title --></a></li>
<!-- end data -->
<!-- end toplinks -->
</ul>

</div>
<div  id="content">
<!-- begin primary -->
<!-- begin dirdata -->
<h1><!-- begin title -->
A title
<!-- end title --></h1>
<p><!-- begin body -->
The Content
<!-- end body --></p>
<div><!-- begin author -->
An author
<!-- end author --></div>
<!-- end dirdata -->
<!-- end primary -->
<!-- begin secondary -->
<!-- end secondary -->
</div>
<div id="sidebar">
<ul>
<!-- begin parentlinks -->
<!-- begin data -->
<!-- set id [[]] -->
<!-- set url [[http://www.stsci.edu/index.html]] -->
<li><a href="http://www.stsci.edu/index.html"><!--begin title -->
A Title
<!-- end title --></a></li>
<!-- end data -->
<!-- end parentlinks -->
<!-- begin pagelinks -->
<!-- end pagelinks -->
<!-- begin commandlinks -->
<ul>
<!-- begin data -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a><!-- set url [[]] --></li>
<!-- end data -->
</ul>
<!-- end commandlinks -->
</ul>
</div>
</div>
</body>
</html>
EOQ

my $create_dir = <<'EOQ';
<html>
<head>
<!-- begin meta -->
<title>{{title}}</title>
<!-- end meta -->
</head>
<body bgcolor=\"#ffffff\">
<!-- begin primary -->
<!-- begin any -->
<!-- end any -->
<!-- end primary -->
<div id="sidebar">
<!-- begin commandlinks -->
<!-- end commandlinks -->
</div>
</body>
</html>
EOQ

my $dir_template = <<'EOQ';
<html>
<head>
<!-- begin meta -->
<title><!-- begin title -->
<!-- end title --></title>
<!-- end meta -->
</head>
<body bgcolor=\"#ffffff\">
<!-- begin primary -->
<!-- begin dirdata -->
<h1><!-- begin title -->
<!-- end title --></h1>
<p><!-- begin body -->
<!-- end body --></p>
<div><!-- begin author -->
<!-- end author --></div>
<!-- end dirdata -->
<!-- end primary -->
<div id="sidebar">
<!-- begin parentlinks -->
<ul>
<!-- begin data -->
<!-- set url [[]] -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a></li>
<!-- end data -->
</ul>
<!-- end parentlinks -->
<!-- begin commandlinks -->
<ul>
<!-- begin data -->
<!-- set url [[]] -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a></li>
<!-- end data -->
</ul>
<!-- end commandlinks -->
</div>
</body>
</html>
EOQ

my $update_template = <<'EOQ';
<html>
<head>
</head>
<body bgcolor=\"#ffffff\">
<ul>
<!-- begin toplinks -->
<!-- begin data -->
<!-- set id [[]] -->
<!-- set url [[]] -->
<li><a href="{{url}}"><!--begin title -->
<!-- end title --></a></li>
<!-- end data -->
<!-- end toplinks -->
</ul>
</body>
</html>
EOQ

my $config = <<'EOQ';
# Maximum number of results to diplay on page
ITEMS = 20
# Maximum beginning result number
MAXSTART = 200
# Dump variables on error
DETAIL_ERRORS = 0
# Length of summary
SUMMARY_LENGTH = 300
# Group that owns files
GROUP = admin
EOQ

# Write dir as templates and pages

$wf->writer("$template_dir/$data_registry", $registry);

my $indexname = "$data_dir/index.html";
$indexname = $wf->validate_filename($indexname, 'w');
$wf->writer($indexname, $dir);

my $templatename = "$template_dir/create_page.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $create_dir);

$templatename = "$template_dir/dirdata.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $dir_template);

$templatename = "$template_dir/update_dir.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $update_template);

$config_file = $wf->validate_filename($config_file, 'w');
$wf->writer($config_file, $config);

my $data = CMS::Onsite::DirData->new(%$params);

#----------------------------------------------------------------------
# Create object

isa_ok($data, "CMS::Onsite::DirData"); # test 2
can_ok($data, qw(add_data browse_data edit_data read_data remove_data
                 search_data check_id)); # test 3

$wf->relocate($data_dir);

#----------------------------------------------------------------------
# Test id to filename

my $pagename = "$data_dir/a-test.html";
$pagename = $data->{wf}->rel2abs($pagename);

my $nestedname = "$data_dir/folder2/folder1/index.html";
$nestedname = $data->{wf}->rel2abs($nestedname);

my ($r, $extra) = $data->id_to_filename();
is($r, "$data_dir/index.html", "Id to filname with no id"); #test 4

($r, $extra) = $data->id_to_filename('');
is($r, "$data_dir/index.html", "Id to filname with blank id"); #test 5

my $folder1 = $data->{wf}->validate_filename("$data_dir/folder1", 'r');
mkdir($folder1);

my $folder2 = $data->{wf}->validate_filename("$data_dir/folder2" , 'r');
mkdir($folder2);

my $folder3 = $data->{wf}->validate_filename("$data_dir/folder2/folder1", 'r');
mkdir($folder3);

($r, $extra) = $data->id_to_filename('folder1');
is($r, "$folder1/index.html",
   "Id to filname with simple id of folder"); #test 6

($r, $extra) = $data->id_to_filename('folder2:folder1');
is($r, "$folder3/index.html",
   "Id to filname with complex id of folder"); #test 7

#----------------------------------------------------------------------
# Test filename to id

$r = $data->filename_to_id($data_dir);
is($r, '', "Filename to id for data_dir"); # test 8

$r = $data->filename_to_id($pagename);
is($r, 'a-test', "Filename to id for page"); # test 9

$r = $data->filename_to_id("$data_dir/index.html");
is($r, '', "Filename to id for index page"); # test 10

$r = $data->filename_to_id($nestedname);
is($r, 'folder2:folder1', "Filename to id for page"); # test 11

#----------------------------------------------------------------------
# Read data

my $dirname =$params->{data_dir};

$r = {title => "A title",
      body => "The Content",
      author => "An author",
      summary => "The Content",
      id => '',
      url => "$params->{base_url}/index.html",
     };

my $d = $data->read_data();
is_deeply($d, $r, "Read data"); # Test 12

#----------------------------------------------------------------------
# Add Data

my $dirname1 = 'a-title/index.html';

$r->{id} = 'a-title';
$r->{url} = join('/', $params->{base_url}, $dirname1);

$data->add_data('', $d);
$d = $data->read_data('a-title');
$r->{summary} = $d->{summary};

is_deeply($d, $r, "Add first directory"); # Test 13

my $e;
%$e = %$d;
$e->{id} = '';
$e->{title} =~ s/A/New/;
$e->{body} =~ s/The/New/;
$e->{author} =~ s/An/New/;
$e->{summary} =~ s/An/New/;

my $s;
%$s = %$e;
$s->{id} = 'new-title';
my $dirname2 = 'new-title/index.html';
$s->{url} = join('/', $params->{base_url}, $dirname2);

$data->add_data('', $e, 'dir');
$e = $data->read_data('new-title');
$s->{summary} = $e->{summary};

is_deeply($e, $s, "Add second directory"); # Test 14

#----------------------------------------------------------------------
# Browse data

my $i;
%$i = %$r;
$i->{id} = '';
$i->{url} = "$params->{base_url}/index.html";

my $c = {
      'detail_errors' => 0,
      'group' => 'admin',
      'id' => 'editor',
      'items' => 20,
      'maxstart' => 200,
      'summary_length' => 300,
      'title' => 'Editor Configuration',
      'summary' => 'Make changes to the editor configuration'
        };

my $results = $data->browse_data();
is_deeply($results, [$i], "Browse data"); # test 15

#----------------------------------------------------------------------
# Search data

$indexname = $data->{wf}->abs2rel($indexname);
$i->{url} = join('/', $params->{base_url}, $indexname);

my $list = $data->search_data({author => 'author'});
is_deeply($list, [$i, $r, $s], "Search data"); # test 16

$list = $data->search_data({author => 'author'}, '', 2);
is_deeply($list, [$i, $r], "Search data with limit"); # test 17

$list = $data->search_data({author => 'An'});
is_deeply($list, [$i, $r], "Search data single term"); # test 18

$list = $data->search_data({body =>'New', title => 'New'});
is_deeply($list, [$s], "Search data multiple terms"); # test 19

#----------------------------------------------------------------------
# Edit data

$d->{id} = 'a-title';
$d->{url} = join('/', $params->{base_url}, $dirname1);
%$s = %$d;

$data->edit_data('a-title', $d);
$d = $data->read_data('a-title');
$s->{summary} = $d->{summary};

is_deeply($d, $s, "Edit data"); # Test 20

#----------------------------------------------------------------------
# Remove data

$data->remove_data('new-title');
my $found = -e $dirname2 ? 1 : 0;
is($found, 0, "Remove data"); # Test 21
