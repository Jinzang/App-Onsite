#!/usr/local/bin/perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 13;

use Cwd qw(abs_path getcwd);

#----------------------------------------------------------------------
# Initialize test directory

$ENV{PATH} = '/bin';
my $data_dir = 'test';
system("/bin/rm -rf $data_dir");

mkdir $data_dir;
$data_dir = abs_path($data_dir);
my $template_dir = "$data_dir/templates";

#----------------------------------------------------------------------
# Create object

BEGIN {use_ok("CMS::Onsite::NewsData");} # test 1

my $params = {
              base_dir => $data_dir,
              data_dir => $data_dir,
              template_dir => "$template_dir",
              script_url => 'test.cgi',
              base_url => 'http://www.stsci.edu',
              valid_write => [$data_dir, $template_dir],
             };

my $data = CMS::Onsite::NewsData->new(%$params);

isa_ok($data, "CMS::Onsite::NewsData"); # test 2
can_ok($data, qw(add_data browse_data edit_data read_data remove_data
                 search_data check_id)); # test 3

#----------------------------------------------------------------------
# Create test files

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
<!-- begin newsdata sort="-id" -->
<!-- begin data -->
<!-- set id [[0001]] -->
<!-- set time [[2265810786]] -->
<h3><!-- begin title -->
A title
<!-- end title --></h3>
<p><!-- begin body -->
The Content
<!-- end body --></p>
<div><!-- begin url -->
http://www.website.com/
<!-- end url --></div>
<!-- end data -->
<!-- end newsdata -->
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

my $create_template = <<'EOQ';
<html>
<head>
</head>
<body bgcolor=\"#ffffff\">
<div id = "container">
<div  id="content">
<!-- begin secondary -->
<!-- begin any -->
<!-- begin data -->
<!-- end data -->
<!-- end any -->
<!-- end secondary -->
</div>
<div id="sidebar">
</div>
</div>
</body>
</html>
EOQ

my $news_template = <<'EOQ';
<html>
<head>
</head>
<body bgcolor=\"#ffffff\">
<!-- begin secondary -->
<!-- begin newsdata sort="-id" -->
<!-- begin data -->
<!-- set id [[]] -->
<!-- set time [[]] -->
<h3><!-- begin title -->
<!-- end title --></h3>
<p><!-- begin body -->
<!-- end body --></p>
<div><!-- begin url -->
<!-- end url --></div>
<!-- end data -->
<!-- end newsdata -->
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
<link>{{url}}</link>
<description>{{body}}</description>
</item>
<!-- end rss_items -->
</channel>
</rss>
EOQ

# Write page as templates and pages

$data->{wf}->relocate($data_dir);

my $indexname = "$data_dir/index.html";
$indexname = $data->{wf}->validate_filename($indexname, 'w');
$data->{wf}->writer($indexname, $page);

my $pagename = "$data_dir/a-title.html";
$pagename = $data->{wf}->validate_filename($pagename, 'w');
$data->{wf}->writer($pagename, $page);

my $templatename = "$template_dir/newsdata.htm";
$templatename = $data->{wf}->validate_filename($templatename, 'w');
$data->{wf}->writer($templatename, $news_template);

$templatename = "$template_dir/create_subpage.htm";
$templatename = $data->{wf}->validate_filename($templatename, 'w');
$data->{wf}->writer($templatename, $create_template);

$templatename = "$template_dir/rss.htm";
$templatename = $data->{wf}->validate_filename($templatename, 'w');
$data->{wf}->writer($templatename, $rsstemplate);

#----------------------------------------------------------------------
# Read data

my $r = {
         id => 'a-title:0001',
         url => 'http://www.website.com/',
         title => "A title",
         body => "The Content",
         summary => "The Content",
        };

my $d = $data->read_data('a-title:0001');
delete $d->{time};

is_deeply($d, $r, "Read data"); # Test 4

#----------------------------------------------------------------------
# Add Data

delete $d->{id};
$d->{title} =~ s/A/New/;
$d->{body} =~ s/The/New/;
$d->{summary} = $d->{body};

my $s;
%$s = %$d;
$s->{id} = 'a-title:0002';

$data->add_data('a-title', $d);
$d = $data->read_data('a-title:0002');
delete $d->{time};

is_deeply($d, $s, "Add second entry"); # Test 5

#----------------------------------------------------------------------
# Browse data

my $results = $data->browse_data('a-title');
delete $_->{time} foreach @$results;
is_deeply($results, [$r, $s], "Browse data"); # test 6

#----------------------------------------------------------------------
# Search data

my $list = $data->search_data({title => 'title'}, 'a-title');
delete $_->{time} foreach @$list;
is_deeply($list, [$r, $s], "Search data"); # test 7

$list = $data->search_data({title => 'title'}, 'a-title', 1);
delete $_->{time} foreach @$list;
is_deeply($list, [$r], "Search data with limit"); # test 8

$list = $data->search_data({title => 'A'}, 'a-title');
delete $_->{time} foreach @$list;
is_deeply($list, [$r], "Search data single term"); # test 9

$list = $data->search_data({description =>'New', title => 'New'}, 'a-title');
delete $_->{time} foreach @$list;
is_deeply($list, [$s], "Search data multiple terms"); # test 10

#----------------------------------------------------------------------
# Edit data

$d->{id} = 'a-title:0001';
$d->{time} = 2265810786;
$d->{url} = 'http://www.website.net/';
%$s = %$d;

$data->edit_data('a-title:0001', $d);
$d = $data->read_data('a-title:0001');
is_deeply($d, $s, "Edit data"); # Test 11

#----------------------------------------------------------------------
# Remove data


$data->remove_data('a-title:0002');
$d = $data->read_data('a-title:0002');
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
<link>http://www.stsci.edu/a-title.html</link>
<description>The Content</description>
<item>
<title>New title</title>
<link>http://www.website.net/</link>
<description>New Content</description>
</item>
</channel>
</rss>
EOQ

$data->write_rss('a-title');
my $rss = $data->{wf}->reader("$data_dir/a-title.rss");
is($rss, $rssfile, "Rss file"); #test 13

