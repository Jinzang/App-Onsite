#!/usr/local/bin/perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 20;

use Cwd qw(abs_path getcwd);
use App::Onsite::Support::WebFile;
use App::Onsite::Support::RegistryFile;

#----------------------------------------------------------------------
# Initialize test directory

$ENV{PATH} = '/bin';
my $data_dir = 'test';
$data_dir = abs_path($data_dir);

my $blog_dir = "$data_dir/blog";
my $template_dir = "$data_dir/templates";
my $data_registry = 'data.reg';

my $params = {
              data_dir => $data_dir,
              template_dir => $template_dir,
              data_registry => $data_registry,
              script_url => 'test.cgi',
              base_url => 'http://www.onsite.org',
              valid_write => [$data_dir, $template_dir],
              file_sort => '-name',
              rss_title => 'Test Blog',
              rss_link => 'http://www.onsite.org/',
              rss_description => 'Testing this software',
              rss_file => "index.rss",
             };

my $wf = App::Onsite::Support::WebFile->new(%$params);
$data_dir = $wf->validate_filename($data_dir, 'w');

system("/bin/rm -rf $data_dir");
mkdir $data_dir;

$template_dir = $wf->validate_filename($template_dir, 'w');
mkdir $template_dir;

$blog_dir = $wf->validate_filename($blog_dir, 'w');
mkdir $blog_dir;

#----------------------------------------------------------------------
# Create test files

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
SUBTEMPLATE = add_page.htm
COMMANDS = browse
COMMANDS = add
COMMANDS = edit
COMMANDS = remove
COMMANDS = search
COMMANDS = view
        [dir]
CLASS = App::Onsite::DirData
SUPER = dir
HAS_SUBFOLDERS = 1
SUBTEMPLATE = add_dir.htm
       [blog]
CLASS = App::Onsite::BlogData
SUPER = dir
SORT_FIELD = -id
        [post]
CLASS = App::Onsite::PostData
SUPER = blog
INDEX_LENGTH = 2
HAS_SUBFOLDERS = 1
SUBTEMPLATE = add_post.htm
MONTHINDEX = add_monthindex.htm
YEARINDEX = add_yearindex.htm
BLOGINDEX = add_blogindex.htm
EOQ


$wf->writer("$template_dir/$data_registry", $registry);

my $blog_file = <<'EOQ';
<html>
<head>
<!-- begin meta -->
<title><!-- begin title -->My Very Fine Blog
<!-- end title --></title>
<!-- end meta -->
</head>
<body>
<div id = "container">
<div  id="content">
<!-- begin primary type="blog" -->
<h1><!-- begin title -->
My Very Fine Blog
<!-- end title --></h1>
<p><!-- begin body -->
A blog for testing.
<!-- end body --></p>
<div><!-- begin author -->
The Blogger.
<!-- end author --></div>
<!-- end primary -->
<!-- begin secondary type="post" -->
<!-- end secondary -->
</div>
<div id="sidebar">
<ul>
<!-- begin parentlinks -->
<!-- begin data -->
<!-- set id [[]] -->
<!-- set url [[http://www.stsci.edu/]] -->
<li><a href="http://www.stsci.edu/"><!--begin title -->
Home
<!-- end title --></a></li>
<!-- end data -->
<!-- end parentlinks -->
<!-- begin pagelinks -->
<!-- begin data -->
<!-- set id [[]] -->
<!-- set url [[http://www.stsci.edu/blog/index.html]] -->
<li><a href="http://www.stsci.edu/blog/index.html"><!--begin title -->
Blog
<!-- end title --></a></li>
<!-- end data -->
<!-- end pagelinks -->
</ul>
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

my $indexname = "$blog_dir/index.html";
$indexname = $wf->validate_filename($indexname, 'w');
$wf->writer($indexname, $blog_file);

my $posttemplate = <<'EOQ';
<html>
<head>
<!-- begin meta -->
<title>{{title}}</title>
<!-- end meta -->
</head>
<body>
<div id = "container">
<div  id="content">
<!-- begin primary type="post" -->
<h1><!-- begin title -->
<!-- end title --></h1>
<p><!-- begin body -->
<!-- end body --></p>
<div><!-- begin author -->
<!-- end author --></div>
<!-- end primary -->
<!-- begin secondary -->
<!-- end secondary -->
</div>
<div id="sidebar">
<ul>
<!-- begin parentlinks -->
<!-- begin data -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a><!-- set url [[]] --></li>
<!-- end data -->
<!-- end parentlinks -->
<!-- begin pagelinks -->
<!-- end pagelinks -->
</ul>
<ul>
<!-- begin commandlinks -->
<!-- begin data -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a><!-- set url [[]] --></li>
<!-- end data -->
<<!-- end commandlinks -->
</ul>
</div>
</div>
</body>
</html>
EOQ

my $monthtemplate = <<'EOQ';
<html>
<head>
<!-- begin meta -->
<title>{{title}}</title>
<!-- end meta -->
</head>
<body>
<div id = "container">
<div  id="content">
<!-- begin primary -->
<h1><!-- begin title -->
<!-- end title --></h1>
<!-- end primary -->
<!-- begin secondary -->
<!-- begin data -->
<h2><!-- begin title -->
<!-- end title --></h2>
<!-- set id [[]] -->
<p><!-- begin summary -->
<!-- end summary -->
<a href="{{url}}">More</a></p>
<!-- end data -->
<!-- end secondary -->
</div>
<div id="sidebar">
<ul>
<!-- begin parentlinks -->
<!-- begin data -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a><!-- set url [[]] --></li>
<!-- end data -->
<!-- end parentlinks -->
<!-- begin pagelinks -->
<!-- end pagelinks -->
</ul>
</div>
</div>
</body>
</html>
EOQ

my $yeartemplate = <<'EOQ';
<html>
<head>
<!-- begin meta -->
<title>{{title}}</title>
<!-- end meta -->
</head>
<body>
<div id = "container">
<div  id="content">
<!-- begin primary -->
<h1><!-- begin title -->
<!-- end title --></h1>
<!-- end primary -->
<!-- begin secondary -->
<ul>
<!-- begin data -->
<!-- set id [[]] -->
<li><a href="{{url}}">{{title}}</a></li>
<!-- end data -->
</ul>
<!-- end secondary -->
</div>
<div id="sidebar">
<ul>
<!-- begin parentlinks -->
<!-- begin data -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a><!-- set url [[]] --></li>
<!-- end data -->
<!-- end parentlinks -->
</ul>
</div>
</div>
</body>
</html>
EOQ

my $blogtemplate = <<'EOQ';
<html>
<head>
<!-- begin meta -->
<title>{{title}}</title>
<!-- end meta -->
</head>
<body>
<div id = "container">
<div  id="content">
<!-- begin primary -->
<!-- end primary -->
<!-- begin secondary sort="-id" -->
<!-- begin data -->
<h1><!-- begin title -->
<!-- end title --></h1>
<!-- set id [[]] -->
<p><!-- begin body -->
<!-- end body --></p>
<div><!-- begin author -->
<!-- end author --> <a href="{{url}}">Link</a></div>
<!-- end data -->
<!-- end secondary -->
</div>
<div id="sidebar">
<ul>
<!-- begin pagelinks -->
<!-- begin data -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a><!-- set url [[]] --></li>
<!-- end data -->
<!-- end pagelinks -->
</ul>
<ul>
<!-- begin commandlinks -->
<!-- begin data -->
<!-- begin data -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a><!-- set url [[]] --></li>
<!-- end data -->
<!-- end data -->
<!-- end commandlinks -->
</ul>
</div>
</div>
</body>
</html>
EOQ

my $rsstemplate = <<'EOQ';
<?xml version="1.0"?>
<!DOCTYPE rss PUBLIC  "-//Netscape Communications//DTD RSS 0.91//EN"
"http://my.netscape.com/publish/formats/rss-0.91.dtd">
<rss version="0.91">
<channel>
<!-- with channel -->
<title>{{title}}</title>
<link>{{link}}</link>
<description>{{description}}</description>
<!-- end channel -->
<!-- with rss_items --><item>
<title>{{title}}</title>
<link>{{url}}</link>
<description>{{body}}</description>
</item><!-- end rss_items -->
</channel>
</rss>
EOQ

# Write templates to script directory

my $templatename = "$params->{template_dir}/add_post.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $posttemplate);

$templatename = "$params->{template_dir}/add_monthindex.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $monthtemplate);

$templatename = "$params->{template_dir}/add_yearindex.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $yeartemplate);

$templatename = "$params->{template_dir}/add_blogindex.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $blogtemplate);

$templatename = "$params->{template_dir}/rss.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $rsstemplate);

#----------------------------------------------------------------------
# Create object

BEGIN {use_ok("App::Onsite::PostData");} # test 1

my $reg = App::Onsite::Support::RegistryFile->new(%$params);
my $blog = $reg->create_subobject($params, $data_registry, 'blog');
my $data = $reg->create_subobject($params, $data_registry, 'post');

isa_ok($data, "App::Onsite::PostData"); # test 2
can_ok($data, qw(add_data browse_data edit_data read_data remove_data
                 search_data check_id)); # test 3

$data->{wf}->relocate($data_dir);

#----------------------------------------------------------------------

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                                                localtime(time());
$year += 1900;
$mon = sprintf '%02d', $mon+1;

my $seq = "$year${mon}01";
my $postid = "blog:$seq";

$indexname = "$blog_dir/index.html";
my $postname = join('/', $blog_dir, "y$year", "m$mon", "post01.html");
my $relname = $wf->abs2rel($postname);

#----------------------------------------------------------------------
# create_date

my $required_time = time();
my $required_datestring = localtime($required_time);
my $date = $data->create_date($required_time);
my $datestring = sprintf("%s %s %2d %s:%s:%s %s", $date->{weekday},
                         $date->{month}, $date->{day}, $date->{hour24},
                         $date->{minute}, $date->{second}, $date->{year});
is($datestring, $required_datestring, "Build date"); # test 4

#----------------------------------------------------------------------
# Kind of index

my @kinds;
my @paths = ("$blog_dir/y$year/m$mon/index.html",
             "$blog_dir/y$year/index.html",
             "$blog_dir/index.html");

foreach my $path (@paths) {
    push(@kinds, $data->get_kind_file($path));
}

is_deeply(\@kinds, [qw(monthindex yearindex blogindex)],
          "Kind of archive"); # test 5

#----------------------------------------------------------------------
# Get info from sequence number

my $d = $data->info_from_seq($seq);
my $r = {year => $date->{year}, month => $date->{month},
         monthnum => $date->{monthnum}, post => '01', };

$d->{month} = substr($d->{month}, 0 , 3);
is_deeply($d, $r, "Info from seq"); # test 6

#----------------------------------------------------------------------
# Next id

my $id = $data->generate_id('blog', 'id');
is ($id, $postid, "Next id");  # test 7

#----------------------------------------------------------------------
# Id to filename

my ($test, $extra) = $data->id_to_filename($postid);
is($test, $postname, "Id to filename"); # Test 8

#----------------------------------------------------------------------
# Filename to id

$test = $data->filename_to_id($postname);
is($test, $postid, "Filename to id"); # Test 9

#----------------------------------------------------------------------
# Add Data

$d = {};
$d->{body} = 'The Content';
$d->{author} = 'An author';
$d->{title} = 'A title';

%$r = %$d;
$r->{id} = $postid;
$r->{url} = join('/', $params->{base_url}, $relname);

$data->add_data('blog', $d);
$d = $data->read_data($postid);
delete $d->{date}{second};

$r->{summary} = $d->{summary};
$r->{date} = $d->{date};

is_deeply($d, $r, "Add data"); # Test 10

#----------------------------------------------------------------------
# Check id

my $seq2 = ++ $seq;
my $postid2 = "blog:$seq2";

$test = $data->check_id($postid) ? 1 : 0;
is ($test, 1, "Does have id");  # test 11

$test = $data->check_id($postid2) ? 1 : 0;
is ($test, 0, "Doesn't have id");  # test 12

#----------------------------------------------------------------------
# Edit data

my $s;
$d->{id} = $postid;
$d->{url} = join('/', $params->{base_url}, $relname);
delete $d->{date}{second};
%$s = %$d;

$data->edit_data($postid, $d);
$d = $data->read_data($postid);
$s->{summary} = $d->{summary};
delete $d->{date}{second};

is_deeply($d, $s, "Edit data"); # Test 13

#----------------------------------------------------------------------
# Add Data

my $postname2 = $postname;
$postname2 =~ s/01\.html$/02\.html/;

$postid2 = $postid;
$postid2 =~ s/01$/02/;

$d->{id} = '';
$d->{author} =~ s/An/New/;
$d->{title} =~ s/A/New/;

%$s = %$d;
$s->{id} = $postid2;
my $relname2 = $wf->abs2rel($postname2);
$s->{url} = join('/', $params->{base_url}, $relname2);

$data->add_data('blog', $d);
$d = $data->read_data($postid2);
$s->{summary} = $d->{summary};
delete $d->{date}{second};
delete $s->{date}{second};

is_deeply($d, $s, "Add data"); # Test 14

#----------------------------------------------------------------------
# Browse data

my $results = $blog->browse_data('blog');
delete $_->{date}{second} foreach @$results;
is_deeply($results, [$s, $r], "Browse data"); # test 15

#----------------------------------------------------------------------
# Search data

my $list = $blog->search_data({author => 'author'}, 'blog');
delete $_->{date}{second} foreach @$list;
is_deeply($list, [$s, $r], "Search data"); # test 16

$list = $blog->search_data({author => 'author'}, 'blog', 1);
delete $_->{date}{second} foreach @$list;
is_deeply($list, [$s], "Search data with limit"); # test 17

$list = $blog->search_data({author => 'An'}, 'blog');
delete $_->{date}{second} foreach @$list;
is_deeply($list, [$r], "Search data single term"); # test 18

$list = $blog->search_data({body =>'New', title => 'New'}, 'blog');
delete $_->{date}{second} foreach @$list;
is_deeply($list, [$s], "Search data multiple terms"); # test 19

#----------------------------------------------------------------------
# Remove data

$data->remove_data($postid2, $s);
my $found = -e $postname2 ? 1 : 0;
is($found, 0, "Remove data"); # test 20
