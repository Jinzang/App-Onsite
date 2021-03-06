#!/usr/local/bin/perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 24;

use Cwd qw(abs_path getcwd);
use App::Onsite::Support::WebFile;
use App::Onsite::Support::RegistryFile;

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

BEGIN {use_ok("App::Onsite::DirData");} # test 1

my $params = {
              data_dir => $data_dir,
              template_dir => $template_dir,
              config_file => $config_file,
              script_url => 'test.cgi',
              base_url => 'http://www.onsite.org',
              valid_write => [$data_dir, $template_dir],
              data_registry => $data_registry,
             };

#----------------------------------------------------------------------
# Create test files

my $wf = App::Onsite::Support::WebFile->new(%$params);

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
DEFAULT_COMMAND = edit
PARENT_COMMANDS = browse
PARENT_COMMANDS = search
COMMANDS = browse
COMMANDS = add
COMMANDS = edit
COMMANDS = remove
COMMANDS = search
		[page]
EXTENSION = html
CLASS = App::Onsite::PageData
SUPER = dir
SORT_FIELD = id
SUBTEMPLATE = page.htm
OMMANDS = browse
COMMANDS = add
COMMANDS = edit
COMMANDS = remove
COMMANDS = search
COMMANDS = view
        [dir]
CLASS = App::Onsite::DirData
SUPER = dir
HAS_SUBFOLDERS = 1
SUBTEMPLATE = dir.htm
EOQ

my $dir = <<'EOQ';
<html>
<head>
<!-- begin meta -->
<title><!-- begin title -->A title
<!-- end title --></title>
<!-- end meta -->
</head>
<body>
<div id = "container">
<div  id="content">
<!-- begin primary type="dir" -->
<h1><!-- begin title -->
A title
<!-- end title --></h1>
<p><!-- begin body -->
The Content
<!-- end body --></p>
<div><!-- begin author -->
An author
<!-- end author --></div>
<!-- end primary -->
<!-- begin secondary -->
<!-- end secondary -->
</div>
<div id="sidebar">
<ul>
<!-- begin parentlinks -->
<!-- begin data -->
<!-- set id [[]] -->
<!-- set url [[http://www.onsite.org/index.html]] -->
<li><a href="http://www.onsite.org/index.html"><!--begin title -->
A title
<!-- end title --></a></li>
<!-- end data -->
<!-- end parentlinks -->
<!-- begin dirlinks -->
<!-- begin data -->
<!-- end data -->
<!-- end dirlinks -->
<!-- begin pagelinks -->
<!-- begin data -->
<!-- end data -->
<!-- end pagelinks -->
</ul>
<ul>
<!-- begin commandlinks -->
<!-- begin data -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a><!-- set url [[]] --></li>
<!-- end data -->
<!-- end commandlinks -->
</ul>
</div>
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
<!-- begin primary type="dir" -->
<h1><!-- begin title -->
<!-- end title --></h1>
<p><!-- begin body -->
<!-- end body --></p>
<div><!-- begin author -->
<!-- end author --></div>
<!-- end primary -->
<div id="sidebar">
<ul>
<!-- begin parentlinks -->
<!-- begin data -->
<!-- set id [[]] -->
<!-- set url [[]] -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a></li>
<!-- end data -->
<!-- end parentlinks -->
<!-- begin dirlinks -->
<!-- begin data -->
<!-- set id [[]] -->
<!-- set url [[]] -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a></li>
<!-- end data -->
<!-- end dirlinks -->
<!-- begin pagelinks -->
<!-- begin data -->
<!-- set id [[]] -->
<!-- set url [[]] -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a></li>
<!-- end data -->
<!-- end pagelinks -->
</ul>

<ul>
<!-- begin commandlinks -->
<!-- begin data -->
<!-- set url [[]] -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a></li>
<!-- end data -->
<!-- end commandlinks -->
</ul>
</div>
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
GROUP = adm
EOQ

# Write dir as templates and pages

$wf->writer("$template_dir/$data_registry", $registry);

my $indexname = "$data_dir/index.html";
$indexname = $wf->validate_filename($indexname, 'w');
$wf->writer($indexname, $dir);

my $templatename = "$template_dir/dir.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $dir_template);

$config_file = $wf->validate_filename($config_file, 'w');
$wf->writer($config_file, $config);

my $reg = App::Onsite::Support::RegistryFile->new(%$params);
my $data = $reg->create_subobject($params, $data_registry, 'dir');

#----------------------------------------------------------------------
# Create object

isa_ok($data, "App::Onsite::DirData"); # test 2
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
      type => 'dir',
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

my $f = {};
%$f = %$d;
$f->{title} = 'Lower';
$f->{body} =~ s/The/Lower/;
$f->{author} =~ s/An/Lower/;

my $t = {};
%$t = %$f;
$t->{id} = 'a-title:lower';

$dirname2 = 'a-title/lower/index.html';
$t->{url} = join('/', $params->{base_url}, $dirname2);

$data->add_data('a-title', $f, 'dir');
$f = $data->read_data('a-title:lower');
$t->{summary} = $f->{summary};

is_deeply($f, $t, "Add subdirectory"); # Test 15

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
is_deeply($results, [$i], "Browse data"); # test 16

#----------------------------------------------------------------------
# Search data

$indexname = $data->{wf}->abs2rel($indexname);
$i->{url} = join('/', $params->{base_url}, $indexname);

my $list = $data->search_data({author => 'author'});
is_deeply($list, [$i, $r, $t, $s], "Search data"); # test 17

$list = $data->search_data({author => 'author'}, '', 2);
is_deeply($list, [$i, $r], "Search data with limit"); # test 18

$list = $data->search_data({author => 'An'});
is_deeply($list, [$i, $r], "Search data single term"); # test 19

$list = $data->search_data({body =>'New', title => 'New'});
is_deeply($list, [$s], "Search data multiple terms"); # test 20

#----------------------------------------------------------------------
# Edit data

$d->{id} = 'a-title';
$d->{url} = join('/', $params->{base_url}, $dirname1);
%$s = %$d;

$data->edit_data('a-title', $d);
$d = $data->read_data('a-title');
$s->{summary} = $d->{summary};

is_deeply($d, $s, "Edit data"); # Test 21

#----------------------------------------------------------------------
# Rename directory

$d->{title} = 'The Title';
%$s = %$d;

$data->edit_data('a-title', $d);
$d = $data->read_data('the-title');
$s->{id} = 'the-title';
$s->{summary} = $d->{summary};
$s->{url} = $d->{url};

is_deeply($d, $s, "Rename data"); # Test 22

my $file;
($file, $extra) = $data->id_to_filename('the-title:lower');

$t = $data->read_primary($file);
$t = $data->extra_data($t);
$d = $data->read_records('parentlinks', $file);

my $l = [{id => $i->{id}, title => $i->{title}, url => $i->{url}},
         {id => $s->{id}, title => $s->{title}, url => $s->{url}},
         {id => $t->{id}, title => $t->{title}, url => $t->{url}},
        ];
         
is_deeply($d, $l, "Renamed directory links"); # Test 23

#----------------------------------------------------------------------
# Remove data

$data->remove_data('new-title', $e);
my $found = -e $dirname2 ? 1 : 0;
is($found, 0, "Remove data"); # Test 24
