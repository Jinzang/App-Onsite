#!/usr/local/bin/perl
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 6;

use Cwd qw(abs_path getcwd);
use CMS::Onsite::AddCommand;
use CMS::Onsite::Support::WebFile;

#----------------------------------------------------------------------
# Initialize test directory

$ENV{PATH} = '/bin';
my $data_dir = 'test';
system("/bin/rm -rf $data_dir");

mkdir $data_dir;
$data_dir = abs_path($data_dir);
my $template_dir = "$data_dir/templates";
my $data_registry = 'data.reg';
my $command_registry = 'command.reg';

BEGIN {use_ok("CMS::Onsite::SearchCommand");} # test 1

my $params = {
              items => 10,
              nonce => '01234567',
              base_url => '',
              data_dir => $data_dir,
              template_dir => "$template_dir",
              command_registry => $command_registry,
              data_registry => $data_registry,
              valid_write => [$data_dir, $template_dir],
              data => 'CMS::Onsite::DirData',
             };

#----------------------------------------------------------------------
# Create templates

my $wf = CMS::Onsite::Support::WebFile->new(%$params);

my $command_registry_file = <<'EOQ';
        [every]
CLASS = CMS::Onsite::EveryCommand
TEMPLATE = show_form.htm
        [add]
CLASS = CMS::Onsite::AddCommand
SUBTEMPLATE = add.htm
        [search]
CLASS = CMS::Onsite::SearchCommand
SUBTEMPLATE = search.htm
EOQ

$wf->writer("$template_dir/$command_registry", $command_registry_file);

my $data_registry_file = <<'EOQ';
        [file]
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
        [dir]
CLASS = CMS::Onsite::DirData
SUPER = dir
HAS_SUBFOLDERS = 1
ADD_TEMPLATE = add_dir.htm
EDIT_TEMPLATE = edit_dir.htm
UPDATE_TEMPLATE = update_dir.htm
EOQ

$wf->writer("$template_dir/$data_registry", $data_registry_file);

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
<h1><!-- begin title valid="&" -->
A title
<!-- end title --></h1>
<p><!-- begin body valid="&" -->
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

my $indexname = "$data_dir/index.html";
$indexname = $wf->validate_filename($indexname, 'w');
$wf->writer($indexname, $dir);

my $edit_page = <<'EOQ';
<html>
<head>
<!-- begin meta -->
<title><!-- begin title -->
<!-- end title --></title>
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
<h1><!-- begin title valid="&" -->
<!-- end title --></h1>
<p><!-- begin body valid="&" -->
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

my $update_page_template = <<'EOQ';
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

my $add_dir = <<'EOQ';
<!DOCTYPE html> 
<html lang="en">
<meta charset=utf-8" />
<!-- begin meta -->
<!-- set title [[]] -->
<!-- set base_url [[]] -->
<base href="{{base_url}}" />
<title>{{title}}</title>
<meta name="robots" content="index, follow" />
<!-- end meta -->
<link rel="stylesheet" type="text/css" href="style.css" title="style" />
</head>
<body bgcolor=\"#ffffff\">
<div id ="container">
<div id="header">
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
</div>
<div id="primary">
<!-- begin primary -->
<!-- begin dirdata -->
<h1><!-- begin title valid="&" -->
<!-- end title --></h1>
<!-- begin body required valid="&html" style="rows=20;cols=80" -->
<!-- end body -->
<!-- end dirdata -->
<!-- end primary -->
</div>
<div id="navigation">
<ul>
<!-- begin parentlinks -->
<!-- begin data -->
<!-- set id [[]] -->
<!-- set url [[]] -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a></li>
<!-- end data -->
<!-- end parentlinks -->
</ul>
<ul>
<!-- begin commandlinks -->
<!-- begin data -->
<!-- set id [[]] -->
<!-- set url [[]] -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a></li>
<!-- end data -->
<!-- end commandlinks -->
</ul>
</div>
</div>
</body>
</html>
EOQ

my $edit_dir = <<'EOQ';
<html>
<head>
<!-- begin meta -->
<title><!-- begin title -->
<!-- end title --></title>
<!-- end meta -->
</head>
<body bgcolor=\"#ffffff\">
<!-- begin primary -->
<!-- begin any -->
<!-- end any -->
<!-- end primary -->
<div id="sidebar">
<!-- begin parentlinks -->
<!-- end parentlinks -->
</div>
</body>
</html>
EOQ

my $edit_page = <<'EOQ';
<html>
<head>
<!-- begin meta -->
<title><!-- begin title -->
<!-- end title --></title>
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
<h1><!-- begin title valid="&" -->
<!-- end title --></h1>
<p><!-- begin body valid="&" -->
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
<h1><!-- begin title valid="&" -->
<!-- end title --></h1>
<p><!-- begin body valid="&" -->
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

my $update_page_template = <<'EOQ';
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

my $update_dir_template = <<'EOQ';
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

my $error_template = <<'EOS';
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<!-- begin meta -->
<base href="{{base_url}}" />
<title>
<!-- begin title --><!-- end title -->
</title>
<!-- end meta -->
</head>
<body>
<!-- begin primary -->
<h2><!-- begin title -->
<!-- end title --></h2>

<p class="error"><!-- begin error -->
<!-- end error --></p>

<h2>REQUEST</h2>
<!-- begin request -->
<!-- end request -->

<h2>RESULTS</h2>
<!-- begin results -->
<!-- end results -->

<!-- end primary -->

<div id="sidebar">
<h2>Commands</h2>

<!-- begin commandlinks -->
<!-- begin data -->
<a href="{{url}}">
<!-- begin title --><!-- end title -->
</a>
<!-- end data -->
<!-- end commandlinks -->
</div>
</body></html>
EOS

my $templatename = "$template_dir/edit_page.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $edit_page);

$templatename = "$template_dir/add_page.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $page_template);

$templatename = "$template_dir/update_page.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $update_page_template);

$templatename = "$template_dir/add_dir.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $edit_page);

$templatename = "$template_dir/edit_dir.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $edit_page);

$templatename = "$template_dir/update_dir.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $update_dir_template);

#----------------------------------------------------------------------
# Create object

my $con = CMS::Onsite::SearchCommand->new(%$params);

isa_ok($con, "CMS::Onsite::SearchCommand"); # test 2
can_ok($con, qw(check run)); # test 3

$wf->relocate($data_dir);

#----------------------------------------------------------------------
# Search

my @data;
my $add = CMS::Onsite::AddCommand->new(%$params);
my %template = (title => "%% file", body => "%% text.", author => "%% author");

for my $count (qw(First Second Third)) {
    my %data = %template;
    foreach my $key (keys %data) {
        $data{$key} =~ s/%%/$count/g;
    }

    my $request = {%data, id => '', nonce => $params->{nonce},
                   subtype => 'page', cmd => 'add'};

    my $id = lc($request->{title});
    $id =~ s/ /-/g;
    
    $add->run($request);
    my $data = $con->{data}->read_data($id);
    push (@data, $data);
}

my @subset = @data[0..1];

my $request = {query => 'file', cmd => 'search'};

my $response = $con->run($request);
my $results = $response->{results}{data};
is_deeply($results, \@data, "Search"); # Test 4

my $max = $con->{items};
$con->{items} = 3;
$response = $con->run($request);
$results = $response->{results}{data};
pop(@$results);

is_deeply($results, \@subset, "Search with limit"); # Test 5
$con->{items} = $max;

$request->{query} = 'First author';
$response = $con->run($request);
$results = $response->{results}{data};
is_deeply($results, [$data[0]], "Search with multiple terms"); # Test 6
