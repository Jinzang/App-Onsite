#!/usr/local/bin/perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 6;

use Cwd qw(abs_path getcwd);
use App::Onsite::AddCommand;
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

BEGIN {use_ok("App::Onsite::SearchCommand");} # test 1

my $params = {
              items => 10,
              nonce => '01234567',
              base_url => '',
              data_dir => $data_dir,
              template_dir => "$template_dir",
              command_registry => $command_registry,
              data_registry => $data_registry,
              valid_write => [$data_dir, $template_dir],
              data => 'App::Onsite::DirData',
             };

#----------------------------------------------------------------------
# Create templates

my $wf = App::Onsite::Support::WebFile->new(%$params);

my $command_registry_file = <<'EOQ';
        [every]
CLASS = App::Onsite::EveryCommand

        [add]
CLASS = App::Onsite::AddCommand
SUBTEMPLATE = add.htm
        [search]
CLASS = App::Onsite::SearchCommand
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
<!-- begin data -->
<!-- set id [[]] -->
<!-- set url [[]] -->
<li><a href={{url}}"><!--begin title -->
<!-- end title --></a></li>
<!-- end data -->
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

$templatename = "$template_dir/dir.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $dir_template);

#----------------------------------------------------------------------
# Create object

my $con = App::Onsite::SearchCommand->new(%$params);

isa_ok($con, "App::Onsite::SearchCommand"); # test 2
can_ok($con, qw(check run)); # test 3

$wf->relocate($data_dir);

#----------------------------------------------------------------------
# Search

my @data;
my $add = App::Onsite::AddCommand->new(%$params);
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
   $data->{itemlink} = {title => 'View', 
    url => "$params->{script_url}?cmd=view&id=$data->{id}"};

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
