#!/usr/local/bin/perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 8;

use Cwd qw(abs_path);
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

BEGIN {use_ok("CMS::Onsite::AddCommand");} # test 1

my $params = {
              base_url => 'http://wwww.onsite.org',
              script_url => 'http://www.onsite.org/test.cgi',
              data_dir => $data_dir,
              template_dir => "$template_dir",
              command_registry => $command_registry,
              data_registry => $data_registry,
              valid_write => [$data_dir, $template_dir],
              nonce => '01234567',
              data => 'CMS::Onsite::DirData',
             };

#----------------------------------------------------------------------
# Create templates

my $wf = CMS::Onsite::Support::WebFile->new(%$params);

my $command_registry_file = <<'EOQ';
        [every]
CLASS = CMS::Onsite:EveryCommand
        [add]
CLASS = CMS::Onsite:AddCommand
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

my $templatename = "$template_dir/edit_page.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $edit_page);

$templatename = "$template_dir/add_page.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $page_template);

$templatename = "$template_dir/update_page.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $update_page_template);

#----------------------------------------------------------------------
# Create object

my $con = CMS::Onsite::AddCommand->new(%$params);

isa_ok($con, "CMS::Onsite::AddCommand"); # test 2
can_ok($con, qw(check run)); # test 3

$wf->relocate($data_dir);

#----------------------------------------------------------------------
# check_subtype

my $data = {
    id => '',
    cmd => 'add',
    title => 'Test Title',
    body => 'Test text.',
    nonce => $params->{nonce},
    script_url => $params->{script_url},
};

my $test = $con->check_subtype($data);
my $response = {code => 400, msg => '', protocol => 'text/html',
                url => $params->{base_url}};

is_deeply($test, $response, "check_subtype bad data"); # test 4

$data->{subtype} = 'page';
$test = $con->check_subtype($data);
$response = {code => 200, msg => 'OK', protocol => 'text/html',
             url => $params->{base_url}};

is_deeply($test, $response, "check_subtype good data"); # test 5

#----------------------------------------------------------------------
# Check

$test = $con->check($data);
$response = {code => 200, msg => 'OK', protocol => 'text/html',
                url => $params->{base_url}};

is_deeply($test, $response, "check"); # test 6

$data->{subtype} = 'page';
delete $data->{title};

$test = $con->check($data);
$response->{code} = 400;
$response->{msg} = "Invalid or missing fields: title";
is_deeply($test, $response, "Check with missing data"); # test 7

#----------------------------------------------------------------------
# Add

$data = {
    id => '',
    cmd => 'add',
    subtype => 'page',
    title => 'Test Title',
    body => 'Test text.',
    nonce => $params->{nonce},
    script_url => $params->{script_url},
};

$con->run($data);

my $id = 'test-title';
my ($pagename, $extra) = $con->{data}->id_to_filename($id);
$pagename = $wf->abs2rel($pagename);
my $d = $con->{data}->read_data($id);

my $r = {
        author => '',
        body => $data->{body},
        summary => $data->{body},
        title => $data->{title},
        url => "$params->{base_url}/$pagename",
        id => $id,
};

is_deeply($d, $r, "add"); # Test 8
