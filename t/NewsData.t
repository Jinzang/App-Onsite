#!/usr/local/bin/perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 13;

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
my $data_registry = 'data.reg';

#----------------------------------------------------------------------
# Create object

BEGIN {use_ok("App::Onsite::NewsData");} # test 1

my $params = {
              base_dir => $data_dir,
              data_dir => $data_dir,
              template_dir => "$template_dir",
              script_url => 'test.cgi',
              base_url => 'http://www.onsite.org',
              valid_write => [$data_dir, $template_dir],
              data_registry => $data_registry,
              max_news_age => 7,
              max_news_entries => 10,
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
COMMANDS = browse
COMMANDS = add
COMMANDS = edit
COMMANDS = remove
COMMANDS = search
COMMANDS = view
        [list]
CLASS = App::Onsite::ListData
SUBTEMPLATE = add_subpage.htm
COMMANDS = edit
COMMANDS = remove
COMMANDS = view
        [news]
CLASS = App::Onsite::NewsData
SUBTEMPLATE = news.htm
SUPER = page
PLURAL = news
INDEX_LENGTH = 6
EOQ

$wf->writer("$template_dir/$data_registry", $registry);

my $pagefile = <<'EOQ';
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
<!-- begin primary type="page" -->
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
<!-- begin secondary type="news" sort="-id" -->
<!-- begin data -->
<!-- set id [[0001]] -->
<!-- set time [[2265810786]] -->
<h3><!-- begin title -->
A title
<!-- end title --></h3>
<p><!-- begin body -->
The Content
<!-- end body --></p>
<div><!-- begin link -->
http://www.website.com/
<!-- end link --></div>
<!-- end data -->
<!-- end secondary -->
</div>
<div id="sidebar">
<ul>
<!-- begin parentlinks -->
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

my $news_template = <<'EOQ';
<html>
<head>
</head>
<body>
<!-- begin secondary type="news" sort="-id" -->
<!-- begin data -->
<!-- set id [[]] -->
<!-- set time [[]] -->
<h3><!-- begin title -->
<!-- end title --></h3>
<p><!-- begin body -->
<!-- end body --></p>
<div><!-- begin link -->
<!-- end link --></div>
<!-- end data -->
<!-- end secondary -->
<div id="sidebar">
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
<link>{{url}}</link>
<description>{{body}}</description>
<!-- end channel -->
<!-- with rss_items -->
<item>
<title>{{title}}</title>
<link>{{link}}</link>
<description>{{body}}</description>
</item>
<!-- end rss_items -->
</channel>
</rss>
EOQ

# Write page as templates and pages

my $indexname = "$data_dir/index.html";
$indexname = $wf->validate_filename($indexname, 'w');
$wf->writer($indexname, $pagefile);

my $pagename = "$data_dir/a-title.html";
$pagename = $wf->validate_filename($pagename, 'w');
$wf->writer($pagename, $pagefile);

my $templatename = "$template_dir/news.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $news_template);

$templatename = "$template_dir/rss.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $rsstemplate);

#----------------------------------------------------------------------
# Create object

my $reg = App::Onsite::Support::RegistryFile->new(%$params);
my $page = $reg->create_subobject($params, $data_registry, 'page');
my $news = $reg->create_subobject($params, $data_registry, 'news');

isa_ok($news, "App::Onsite::NewsData"); # test 2
can_ok($news, qw(add_data browse_data edit_data read_data remove_data
                 search_data check_id)); # test 3

#----------------------------------------------------------------------
# Read data

$page->{wf}->relocate($data_dir);

my $r = {
         id => 'a-title:0001',
         link => 'http://www.website.com/',
         title => "A title",
         body => "The Content",
         summary => "The Content",
        };

my $d = $news->read_data('a-title:0001');
delete $d->{time};

is_deeply($d, $r, "Read data"); # Test 4

#----------------------------------------------------------------------
# Add Data

$d->{id} = 'a-title';
$d->{title} =~ s/A/New/;
$d->{body} =~ s/The/New/;
$d->{summary} = $d->{body};

my $s;
%$s = %$d;
$d->{subtype} = 'news';
$s->{id} = 'a-title:0002';

$news->add_data('a-title', $d);
$d = $news->read_data('a-title:0002');
delete $d->{time};

is_deeply($d, $s, "Add second entry"); # Test 5

#----------------------------------------------------------------------
# Browse data

$r->{url} = 'http://www.onsite.org/a-title.html#0001';
$s->{url} = 'http://www.onsite.org/a-title.html#0002';

my $results = $page->browse_data('a-title');
delete $_->{time} foreach @$results;
is_deeply($results, [$r, $s], "Browse data"); # test 6

#----------------------------------------------------------------------
# Search data

my $list = $page->search_data({title => 'title'}, 'a-title');
delete $_->{time} foreach @$list;
is_deeply($list, [$r, $s], "Search data"); # test 7

$list = $page->search_data({title => 'title'}, 'a-title', 1);
delete $_->{time} foreach @$list;
is_deeply($list, [$r], "Search data with limit"); # test 8

$list = $page->search_data({title => 'A'}, 'a-title');
delete $_->{time} foreach @$list;
is_deeply($list, [$r], "Search data single term"); # test 9

$list = $page->search_data({description =>'New', title => 'New'}, 'a-title');
delete $_->{time} foreach @$list;
is_deeply($list, [$s], "Search data multiple terms"); # test 10

#----------------------------------------------------------------------
# Edit data

$d->{id} = 'a-title:0001';
$d->{time} = 2265810786;
$d->{link} = 'http://www.website.net/';
%$s = %$d;

$news->edit_data('a-title:0001', $d);
$d = $news->read_data('a-title:0001');
is_deeply($d, $s, "Edit data"); # Test 11

#----------------------------------------------------------------------
# Remove data

$d->{id} = 'a-title:0002';
$news->remove_data('a-title:0002', $d);
$d = $news->read_data('a-title:0002');
is($d, undef, "Remove data"); # Test 12

#----------------------------------------------------------------------
# Rss file

my $rssfile = <<'EOQ';
<?xml version="1.0"?>
<!DOCTYPE rss PUBLIC  "-//Netscape Communications//DTD RSS 0.91//EN"
"http://my.netscape.com/publish/formats/rss-0.91.dtd">
<rss version="0.91">
<channel>
<title>A title</title>
<link>http://www.onsite.org/a-title.html</link>
<description>The Content</description>
<item>
<title>New title</title>
<link>http://www.website.net/</link>
<description>New Content</description>
</item>
</channel>
</rss>
EOQ

$page->write_rss('a-title');
my $rss = $news->{wf}->reader("$data_dir/a-title.rss");
is($rss, $rssfile, "Rss file"); #test 13

