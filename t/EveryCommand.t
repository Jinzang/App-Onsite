#!/usr/local/bin/perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 12;

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
my $data_registry = 'data.reg';
my $command_registry = 'command.reg';

BEGIN {use_ok("CMS::Onsite::EveryCommand");} # test 1

my $params = {
              items => 10,
              nonce => '01234567',
              base_url => 'http://wwww.onsite.org',
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
CLASS = CMS::Onsite:EveryCommand
TEMPLATE = show_form.htm
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

#----------------------------------------------------------------------
# Create object

my $con = CMS::Onsite::EveryCommand->new(%$params);

isa_ok($con, "CMS::Onsite::EveryCommand"); # test 2
can_ok($con, qw(check run)); # test 3

$wf->relocate($data_dir);

#----------------------------------------------------------------------
# Clean data

my $request = {title => "Test Title",
               body => "<p>Test body</p>\n",
               author => "Test Author",
               cmd => 'Edit',
              };

my $field_info = [{NAME => 'title', valid => '&'},
                  {NAME => 'body', valid => '&html'},
                  {NAME => 'author'},
                 ];
$request->{field_info} = $field_info;

my $cleaned = {};
%$cleaned = %$request;
$cleaned->{title} = "Test Title";
$cleaned->{body} = "<p>Test body</p>";
$cleaned->{author} = "Test Author",

$request = $con->clean_data($request);
is_deeply($request, $cleaned, "clean_data"); # test 4

#----------------------------------------------------------------------
# Form title

my $title = $con->form_title($request);
is($title, "Edit", "Form title"); # test 5

#----------------------------------------------------------------------
# Set Response

my $error = 'Division by zero';
my $response = $con->set_response('a-page', 500, $error);
my $d = {code => 500, msg => $error, protocol => 'text/html',
         url => $params->{base_url}}; 

is_deeply($response, $d, "set response"); # test 6

#----------------------------------------------------------------------
# Any data

my $flag = $con->any_data($request);
is($flag, 1, "any request"); # test 7

#----------------------------------------------------------------------
# Check nonce

my $d = $con->check_nonce($request->{id}, $params->{nonce});

$response = {code => 200, msg => 'OK', protocol => 'text/html',
             url => $params->{base_url}};

is_deeply($d, $response, "check nonce"); # test 8

#----------------------------------------------------------------------
# check_fields

$d = $con->check_fields($request);
is_deeply($d, $response, "check_fields with all data"); # test 9

$request->{title} = '';
$d = $con->check_fields($request);

$response->{code} = 400;
$response->{msg} = "Invalid or missing fields: title";
is_deeply($d, $response, "check_fields with missing data"); # test 10

#----------------------------------------------------------------------
# page_limit

my $limit = $con->page_limit();
is($limit, $con->{items}+1, "page_limit no args"); #test 11

$limit = $con->page_limit({start => 100});
is($limit, $con->{items} + 101, "page limit with start"); # test 12
