#!/usr/local/bin/perl
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 26;

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

BEGIN {use_ok("CMS::Onsite::Editor");} # test 1

my $params = {
              items => 10,
              subfolders => 1,
              nonce => '01234567',
              data_dir => $data_dir,
              template_dir => "$template_dir",
              data_registry => $data_registry,
              script_url => 'http://www.stsci.edu/test.cgi',
              base_url => 'http://www.stsci.edu/',
              valid_write => [$data_dir, $template_dir],
              data => 'CMS::Onsite::DirData',
             };

#----------------------------------------------------------------------
# Create templates

my $wf = CMS::Onsite::Support::WebFile->new(%$params);

my $registry = <<'EOQ';
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

$wf->writer("$template_dir/$data_registry", $registry);

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
<h1><!-- begin title valid="&" -->
A title
<!-- end title --></h1>
<p><!-- begin body valid="&" -->
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

# Write templates and pages

my $indexname = "$data_dir/index.html";
$indexname = $wf->validate_filename($indexname, 'w');
$wf->writer($indexname, $dir);

my $pagename = "$data_dir/a-title.html";
$pagename = $wf->validate_filename($pagename, 'w');
$wf->writer($pagename, $page);

my $templatename = "$template_dir/edit_page.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $edit_page);

$templatename = "$template_dir/edit_dir.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $edit_dir);

$templatename = "$template_dir/add_page.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $page_template);

$templatename = "$template_dir/add_dir.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $dir_template);

$templatename = "$template_dir/update_page.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $update_page_template);

$templatename = "$template_dir/update_dir.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $update_dir_template);

$templatename = "$template_dir/error.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $error_template);

#----------------------------------------------------------------------
# Create object

my $con = CMS::Onsite::Editor->new(%$params);

isa_ok($con, "CMS::Onsite::Editor"); # test 2
can_ok($con, qw(check batch run render error)); # test 3

$wf->relocate($data_dir);

#----------------------------------------------------------------------
# Clean data

my $request = {title => "Test Title",
               body => "<p>Test body</p>\n",
               author => "Test Author",
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
# Response and error response

my $error = 'Division by zero';
my $response = $con->set_response('a-page', 500, $error);
my $d = {code => 500, msg => $error, protocol => 'text/html',
         url => $params->{base_url}}; 

is_deeply($response, $d, "set response"); # test 5

$response = $con->error($request, $response);
$d ={code => 200, msg => 'OK',
     protocol => 'text/html',
     url => $params->{base_url},
     results => {request => $request, results => undef, env => \%ENV,
                 title => 'Script Error', error => $error}};

is_deeply($response, $d, "error"); # test 6

#----------------------------------------------------------------------
# check_fields

$d = $con->check_fields($request);
$response = {code => 200, msg => 'OK', protocol => 'text/html',
             url => $params->{base_url}};

is_deeply($d, $response, "check_fields with all data"); # test 7

$request->{title} = '';
$d = $con->check_fields($request);

$response->{code} = 400;
$response->{msg} = "Invalid or missing fields: title";
is_deeply($d, $response, "check_fields with missing data"); # test 8

#----------------------------------------------------------------------
# page_limit

my $limit = $con->page_limit();
is($limit, $con->{items}+1, "page_limit no args"); #test 9

$limit = $con->page_limit({start => 100});
is($limit, $con->{items} + 101, "page limit with start"); # test 10

#----------------------------------------------------------------------
# pick_command

my $cmd = $con->pick_command({id => '', cmd => "add"});
is($cmd, "add", "pick with command"); # test 11

$cmd = $con->pick_command({id => '', cmd => ""});
is($cmd, "browse", "pick with no command"); # test 12

$cmd = $con->pick_command({id => '', cmd => "cancel"});
is($cmd, "cancel", "pick with cancel"); # test 13

#----------------------------------------------------------------------
# add_check

my $data = {
    id => '',
    cmd => 'add',
    subtype => 'page',
    title => 'Test Title',
    body => 'Test text.',
    nonce => $params->{nonce},
    script_url => $params->{script_url},
};

my $test = $con->add_check($data);
$response = {code => 200, msg => 'OK', protocol => 'text/html',
             url => $params->{base_url}};

is_deeply($test, $response, "add_check"); # test 14

delete $data->{title};
$test = $con->add_check($data);
$response->{code} = 400;
$response->{msg} = "Invalid or missing fields: title";
is_deeply($test, $response, "add_check with missing data"); # test 15

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

$con->batch($data);

my $extra;
my $id = 'test-title';
($pagename, $extra) = $con->{data}->id_to_filename($id);
$pagename = $wf->abs2rel($pagename);
$d = $con->{data}->read_data($id);

my $r = {
        author => '',
        body => $data->{body},
        summary => $data->{body},
        title => $data->{title},
        url => "$params->{base_url}/$pagename",
        id => $id,
};

is_deeply($d, $r, "add"); # Test 16

#----------------------------------------------------------------------
# Edit

my $filename;
$id = 'a-title';
($filename, $extra) = $con->{data}->id_to_filename($id);
$filename = $wf->abs2rel($filename);

$data = {
    cmd => 'edit',
    title => 'New Title',
    body => 'New text.',
    author => '',
    nonce => $params->{nonce},
    id => $id,
};

$con->batch($data);
$d = $con->{data}->read_data('new-title');

$r = {
      author => 'An author',
      body => $data->{body},
      summary => $data->{body},
      title => $data->{title},
      url => "$params->{base_url}/new-title.html",
      id => 'new-title',
};

is_deeply($d, $r, "Edit"); # Test 17

#----------------------------------------------------------------------
# View

$request = {cmd => 'view', id => 'new-title', };
$d = $con->view_check($request);
$response = {code => 200, msg => 'OK', protocol => 'text/html',
             url => $r->{url}};
is_deeply($d, $response, "View check"); # Test 18

$d = $con->batch($request);
$response = {code => 302, msg => 'Found', protocol => 'text/html',
             url => $r->{url}};
is_deeply($d, $response, "View"); # Test 19

#----------------------------------------------------------------------
# Remove

foreach $id (('new-title', 'test-title')) {
    $con->batch({cmd => 'remove', id => $id, nonce => $params->{nonce}});
    my $found = -e "$data_dir/$id.html" ? 1 : 0;
    is($found, 0, "Remove $id"); # Test 20-21
}

#----------------------------------------------------------------------
# Browse

my @data;
my %template = (title => "%% file", body => "%% text.", author => "%% author");

for my $count (qw(First Second Third)) {
    my %data = %template;
    foreach my $key (keys %data) {
        $data{$key} =~ s/%%/$count/g;
    }

    $id = $con->{data}->generate_id('', $data{title});
    my %request = (%data, id => '', nonce => $params->{nonce},
                   subtype => 'page', cmd => 'add');

    $con->batch(\%request);

    $data = $con->{data}->read_data($id);
    $data->{browselink} = {title => 'Edit', 
    url => "$params->{script_url}?cmd=edit&id=$data->{id}"};

    push (@data, $data);
}

$request = {nonce => $params->{nonce}, cmd => 'browse'};
$response = $con->batch($request);
my $results = $response->{results}{data};
shift(@$results);

is_deeply($results, \@data, "Browse all"); # Test 22

my @subset = @data[0..1];
my $max = $con->{items};
$con->{items} = 3;

$response = $con->browse($request);
$results = $response->{results}{data};
shift(@$results);

is_deeply($results, \@subset, "Browse with limit"); # Test 23
$con->{items} = $max;

#----------------------------------------------------------------------
# Search

delete $_->{browselink} foreach @data;
@subset = @data[0..1];

$request = {query => 'file', cmd => 'search'};

$response = $con->search($request);
$results = $response->{results}{data};
is_deeply($results, \@data, "Search"); # Test 24

$max = $con->{items};
$con->{items} = 3;
$response = $con->search($request);
$results = $response->{results}{data};
pop(@$results);

is_deeply($results, \@subset, "Search with limit"); # Test 25
$con->{items} = $max;

$request->{query} = 'First author';
$response = $con->search($request);
$results = $response->{results}{data};
is_deeply($results, [$data[0]], "Search with multiple terms"); # Test 26
