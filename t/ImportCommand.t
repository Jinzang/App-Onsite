#!/usr/local/bin/perl
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 7;

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

BEGIN {use_ok("App::Onsite::ImportCommand");} # test 1

my $params = {
              base_url => 'http://wwww.onsite.org',
              script_url => 'http://www.onsite.org/test.cgi',
              data_dir => $data_dir,
              template_dir => "$template_dir",
              command_registry => $command_registry,
              data_registry => $data_registry,
              valid_write => [$data_dir, $template_dir],
              nonce => '01234567',
              data => 'App::Onsite::PageData',
             };

#----------------------------------------------------------------------
# Create templates

my $wf = App::Onsite::Support::WebFile->new(%$params);

my $command_registry_file = <<'EOQ';
        [every]
CLASS = App::Onsite:EveryCommand
        [import]
CLASS = App::Onsite:ImportCommand
SUBTEMPLATE = import.htm
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
DEFAULT_COMMAND = import
PARENT_COMMANDS = browse
PARENT_COMMANDS = search
COMMANDS = browse
COMMANDS = add
COMMANDS = import
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
COMMANDS = import
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
<!-- begin primary  type="page" -->
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
<!-- begin secondary type="list" -->
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
<!-- end secondary -->
</div>
<div id="sidebar">
<ul>
<!-- begin parentlinks -->
<!-- end parentlinks -->
<!-- begin pagelinks -->
<!-- begin data -->
<!-- set id [[a-title]] -->
<!-- set url [[http://www.onsite.org/a-title.html]] -->
<li><a href="http://www.onsite.org/a-title.html"><!--begin title -->
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

my $pagename = "$data_dir/a-title.html";
$pagename = $wf->validate_filename($pagename, 'w');
$wf->writer($pagename, $page);

my $replacement = $page;
$replacement =~ s/\#ffffff/\#eeeeee/;
my $replacement_name = "$data_dir/replacement.html";
$replacement_name = $wf->validate_filename($replacement_name, 'w');
$wf->writer($replacement_name, $replacement);

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
<!-- begin pagelinks -->
<ul>
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

#----------------------------------------------------------------------
# Create object

my $con = App::Onsite::ImportCommand->new(%$params);

isa_ok($con, "App::Onsite::ImportCommand"); # test 2
can_ok($con, qw(check run)); # test 3

$wf->relocate($data_dir);

#----------------------------------------------------------------------
# Check

my $data = {
    id => 'a-title',
    cmd => 'import',
    filename => $replacement_name,
    nonce => $params->{nonce},
    script_url => $params->{script_url},
};

my $test = $con->check($data);
my $response = {code => 200, msg => 'OK', protocol => 'text/html',
                url => "$params->{base_url}/a-title.html"};

is_deeply($test, $response, "check"); # test 4

delete $data->{filename};

$test = $con->check($data);
$response->{code} = 400;
$response->{msg} = "Invalid or missing fields: filename";
is_deeply($test, $response, "Check with missing data"); # test 5

#----------------------------------------------------------------------
# Import

my $id = 'a-title';
my ($filename, $extra) = $con->{data}->id_to_filename($id);
$filename = $wf->abs2rel($filename);

$data = {
    cmd => 'import',
    filename => $replacement_name,
    nonce => $params->{nonce},
    id => $id,
};

$con->run($data);
$page = $con->{wf}->reader($pagename);
is($page =~/\#eeeeee/, 1, "Inport body"); # Test 6

my $d = $con->{data}->read_data('a-title');

my $r = {
          author => 'An author',
          body => 'The Content',
          summary => 'The Content',
          title => 'A title',
          url => "$params->{base_url}/a-title.html",
          type => 'page',
          id => 'a-title',
};

is_deeply($d, $r, "Import data"); # Test 7
