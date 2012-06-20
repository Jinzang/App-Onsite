#!/usr/local/bin/perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 27;

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
my $template_dir = "$data_dir/templates";
my $data_registry = 'data.reg';

my $params = {
              data_dir => $data_dir,
              template_dir => "$template_dir",
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
ADD_TEMPLATE = add_page.htm
EDIT_TEMPLATE = edit_page.htm
UPDATE_TEMPLATE = update_page.htm
COMMANDS = browse
COMMANDS = add
COMMANDS = edit
COMMANDS = remove
COMMANDS = search
COMMANDS = view
EOQ

$wf->writer("$template_dir/$data_registry", $registry);

my $page = <<'EOQ';
<html>
<head>
<!-- begin meta -->
<title><!-- begin title -->A title
<!-- end title --></title>
<!-- end meta -->
</head>
<body bgcolor=\"#ffffff\">
<div id = "container">
<div  id="content">
<!-- begin primary -->
<!-- begin pagedata -->
<h1><!-- begin title -->
A title
<!-- end title --></h1>
<p><!-- begin body -->
The Content
<!-- end body --></p>
<div><!-- begin author -->
An author
<!-- end author --></div>
<!-- end pagedata -->
<!-- end primary -->
<!-- begin secondary -->
<!-- begin listdata -->
<!-- begin data -->
<!-- set id [[0001]] -->
<h3><!-- begin title -->
A title
<!-- end title --></h3>
<p><!-- begin body -->
The Content
<!-- end body --></p>
<div><!-- begin author -->
An author
<!-- end author --></div>
<!-- end data -->
<!-- end listdata -->
<!-- end secondary -->
</div>
<div id="sidebar">
<ul>
<!-- begin parentlinks -->
<!-- end parentlinks -->
<!-- begin pagelinks -->
<!-- begin data -->
<!-- set id [[a-title]] -->
<!-- set url [[http://www.stsci.edu/a-title.html]] -->
<li><a href="http://www.stsci.edu/a-title.html"><!--begin title -->
A Title
<!-- end title --></a></li>
<!-- end data -->
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

my $edit_page = <<'EOQ';
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

my $edit_subpage = <<'EOQ';
<html>
<head>
</head>
<body bgcolor=\"#ffffff\">
<!-- begin secondary -->
<!-- begin any -->
<!-- begin data -->
<!-- end data -->
<!-- end any -->
<!-- end secondary -->
<div id="sidebar">
</div>
</body>
</html>
EOQ

my $page_template = <<'EOQ';
<html>
<head>
<!-- begin meta -->
<title><!-- begin title -->
<!-- end title --></title>
<!-- end meta -->
</head>
<body bgcolor=\"#ffffff\">
<!-- begin primary -->
<!-- begin pagedata -->
<h1><!-- begin title -->
<!-- end title --></h1>
<p><!-- begin body -->
<!-- end body --></p>
<div><!-- begin author -->
<!-- end author --></div>
<!-- end pagedata -->
<!-- end primary -->
<div id="sidebar">
<!-- begin pagelinks -->
<ul>
<!-- begin data -->
<!-- set url [[]] -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a></li>
<!-- end data -->
</ul>
<!-- end pagelinks -->
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

my $subpage_template = <<'EOQ';
<html>
<head>
</head>
<body bgcolor=\"#ffffff\">
<!-- begin secondary -->
<!-- begin listdata -->
<!-- begin data -->
<!-- set id [[]] -->
<h3><!-- begin title -->
<!-- end title --></h3>
<p><!-- begin body -->
<!-- end body --></p>
<div><!-- begin author -->
<!-- end author --></div>
<!-- end data -->
<!-- end listdata -->
<!-- end secondary -->
<div id="sidebar">
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
<!-- begin pagelinks -->
<!-- begin data -->
<!-- set id [[]] -->
<!-- set url [[]] -->
<li><a href="{{url}}"><!--begin title -->
<!-- end title --></a></li>
<!-- end data -->
<!-- end pagelinks -->
</ul>
</body>
</html>
EOQ

# Write page as templates and pages

my $indexname = "$data_dir/index.html";
$indexname = $wf->validate_filename($indexname, 'w');
$wf->writer($indexname, $page);

my $pagename = "$data_dir/a-title.html";
$pagename = $wf->validate_filename($pagename, 'w');
$wf->writer($pagename, $page);

my $templatename = "$template_dir/edit_page.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $edit_page);

$templatename = "$template_dir/edit_subpage.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $edit_subpage);

$templatename = "$template_dir/add_page.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $page_template);

$templatename = "$template_dir/add_subpage.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $subpage_template);

$templatename = "$template_dir/update_page.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $update_template);

#----------------------------------------------------------------------
# Create object

BEGIN {use_ok("CMS::Onsite::PageData");} # test 1


my $data = CMS::Onsite::PageData->new(%$params);

isa_ok($data, "CMS::Onsite::PageData"); # test 2
can_ok($data, qw(add_data browse_data edit_data read_data remove_data
                 search_data check_id)); # test 3

$data->{wf}->relocate($data_dir);

#----------------------------------------------------------------------
# command links

my $elink = [{
             title => 'Edit',
             url => "test.cgi?cmd=edit&id=a-title&type=page",
            },
            {
             title => 'Add List',
             url => "test.cgi?cmd=add&id=a-title&subtype=list&type=page",
            }];

my $links = $data->build_commandlinks({id =>'a-title'});
is_deeply($links, {data => $elink}, "Page command links"); # test 4

#----------------------------------------------------------------------
# Update data

my $r = {title => "A title",
      body => "The Content",
      author => 'An author',
      id => 'a-title',
     };

$r->{summary} = $r->{body};
$r->{url} = join('/', $params->{base_url}, "a-title.html");
my $d = $data->read_data('a-title');

is_deeply($d, $r, "Read data"); # Test 5

$d->{cmd} = 'edit';
my $q = {id => $r->{id}, title => $r->{title}, url => $r->{url}};

$data->update_data('a-title', $d);

my $u = $data->read_records($pagename, 'pagelinks');
is_deeply($u, [$q], "Update page siblings"); # Test 6

$r = $data->read_data('a-title');
$r->{cmd} = $d->{cmd};
is_deeply($r, $d, "Update page contents"); # Test 7

#----------------------------------------------------------------------
# summarize

my $text = "<p>" . "abcd <b>efgh</b>" x 300 . "</p>";
my $summary = $data->summarize($text);
my $required_summary = "abcd efgh " x 29 . "abcd ...";

is($summary, $required_summary, "Summarize page"); # test 8

#----------------------------------------------------------------------
# extra_data

my $hash = {body => $text};
$hash = $data->extra_data($hash, '0001');

is_deeply([sort keys %$hash],
          [qw(body summary url)],
          "Page extra data"); # test 9

#----------------------------------------------------------------------
# File Visitor

my $get_next = $data->get_next('a-title');
$hash = &$get_next();
my @keys = sort keys %$hash;

is_deeply(\@keys, [qw(author body id
                   summary title url)], "File visitor"); # test 10

#----------------------------------------------------------------------
# Check id

my $test = $data->check_id('a-title') ? 1 : 0;
is ($test, 1, "Page has id");  # test 11

$test = $data->check_id('new-title') ? 1 : 0;
is ($test, 0, "Page doesn't have id");  # test 12

#----------------------------------------------------------------------
# Generate id

my $id2 = $data->generate_id('', 'New Title');
is ($id2, 'new-title', "Generate page id");  # test 13

#----------------------------------------------------------------------
# Read data

$pagename = $data->id_to_filename('a-title');
$pagename = $data->{wf}->abs2rel($pagename);

$r = {title => "A title",
      body => "The Content",
      author => "An author",
      summary => "The Content",
      id => 'a-title',
      url => "$params->{base_url}/a-title.html",
     };

$d = $data->read_data('a-title');
is_deeply($d, $r, "Read page"); # Test 14

#----------------------------------------------------------------------
# Edit data

my $s;
%$s = %$d;
$d->{cmd} = 'edit';

$data->edit_data('a-title', $d);
$d = $data->read_data('a-title');
$s->{summary} = $d->{summary};

is_deeply($d, $s, "Edit"); # Test 15

my $pagedata = $data->{nt}->data("$data_dir/a-title.html");

my $meta = $pagedata->{meta};
is_deeply($meta, {title => $d->{title}}, "Page meta"); # Test 16

$links = $pagedata->{commandlinks}{data};
is_deeply($links, $elink, "Page command Links"); # Test 17

#----------------------------------------------------------------------
# Read data

$r = {title => "A title",
      body => "The Content",
      summary => "The Content",
      author => "An author",
      id => 'a-title:0001',
      url => 'http://www.stsci.edu/a-title.html#0001',
     };

$d = $data->read_data('a-title:0001');
is_deeply($d, $r, "Read subpage"); # Test 18

#----------------------------------------------------------------------
# Add Second Page

$d->{id} = '';
$d->{title} =~ s/A/New/;
$d->{body} =~ s/The/New/;
$d->{summary} =~ s/The/New/;
$d->{author} =~ s/An/New/;

%$s = %$d;
$s->{id} = 'new-title';
$s->{url}= 'http://www.stsci.edu/new-title.html';

$data->add_data('', $d);
$d = $data->read_data('new-title');
is_deeply($d, $s, "Add second page"); # Test 19

#----------------------------------------------------------------------
# Redirect url

my $url = $data->redirect_url('a-title');
is($url, "$params->{base_url}/a-title.html",
         "Redirect page url"); # test 20
   
#----------------------------------------------------------------------
# Rename page

$d = $data->read_data('new-title');
$d->{title} = 'Strange Title';
$d->{url} =~ s/new-/strange-/;
$d->{cmd} = 'edit';

$data->write_data('new-title', $d);
$s = $data->read_data('strange-title');
$d->{id} = 'strange-title';
delete $d->{base_url};
delete $d->{oldid};
delete $d->{cmd};

is_deeply($s, $d, "Rename page"); # Test 21

#----------------------------------------------------------------------
# Remove page

$d->{cmd} = 'remove';
$data->remove_data('strange-title', $d);
my $file = $data->id_to_filename('strange-title');
ok(! -e $file, "Remove page"); # Test 22

#----------------------------------------------------------------------
# Browse subpage

my $results = $data->browse_data('a-title');
is_deeply($results, [$r], "Browse subpage"); # test 23

#----------------------------------------------------------------------
# Search subpage

my $list = $data->search_data({author => 'author'}, 'a-title');
is_deeply($list, [$r], "Search subpage"); # test 24

$list = $data->search_data({author => 'author'}, 'a-title', 1);
is_deeply($list, [$r], "Search subpage with limit"); # test 25

$list = $data->search_data({author => 'An'}, 'a-title');
is_deeply($list, [$r], "Search subpage single term"); # test 26

$list = $data->search_data({body =>'The', title => 'A'}, 'a-title');
is_deeply($list, [$r], "Search subpage multiple terms"); # test 27

