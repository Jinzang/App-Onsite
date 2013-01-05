#!/usr/local/bin/perl
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 8;

use Cwd qw(abs_path);
use App::Onsite::Support::WebFile;

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

BEGIN {use_ok("App::Onsite::AddCommand");} # test 1

my $params = {
              base_url => 'http://wwww.onsite.org',
              script_url => 'http://www.onsite.org/test.cgi',
              data_dir => $data_dir,
              template_dir => "$template_dir",
              command_registry => $command_registry,
              data_registry => $data_registry,
              valid_write => [$data_dir, $template_dir],
              nonce => '01234567',
              data => 'App::Onsite::DirData',
             };

#----------------------------------------------------------------------
# Create templates

my $wf = App::Onsite::Support::WebFile->new(%$params);

my $command_registry_file = <<'EOQ';
        [every]
CLASS = App::Onsite:EveryCommand
        [add]
CLASS = App::Onsite:AddCommand
SUBTEMPLATE = add.htm
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
INDEX_NAME = index
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
        [dir]
CLASS = App::Onsite::DirData
SUPER = dir
HAS_SUBFOLDERS = 1
SUBTEMPLATE = dir.htm
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
<body>
<div id = "container">
<div  id="content">
<!-- begin primary type="dir" -->
<h1><!-- begin title valid="&" -->
A title
<!-- end title --></h1>
<p><!-- begin body valid="&" -->
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

my $page_template = <<'EOQ';
<html>
<head>
<!-- begin meta -->
<title><!-- begin title -->
<!-- end title --></title>
<!-- end meta -->
</head>
<body>
<!-- begin primary type="page" -->
<h1><!-- begin title valid="&" -->
<!-- end title --></h1>
<p><!-- begin body valid="&" -->
<!-- end body --></p>
<div><!-- begin author -->
<!-- end author --></div>
<!-- end primary -->
<div id="sidebar">
<ul>
<!-- begin pagelinks -->
<!-- begin data -->
<!-- set id [[]] -->
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
<body>
<!-- begin primary type="dir" -->
<h1><!-- begin title valid="&" -->
<!-- end title --></h1>
<p><!-- begin body valid="&" -->
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
<!-- begin pagelinks -->
<!-- begin data -->
<!-- set id [[]] -->
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

my $templatename = "$template_dir/page.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $page_template);

$templatename = "$template_dir/dir.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $dir_template);

#----------------------------------------------------------------------
# Create object

my $con = App::Onsite::AddCommand->new(%$params);

isa_ok($con, "App::Onsite::AddCommand"); # test 2
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
        type => 'page',
        url => "$params->{base_url}/$pagename",
        id => $id,
};

is_deeply($d, $r, "add"); # Test 8
