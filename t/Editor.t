#!/usr/local/bin/perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 15;

use Cwd qw(abs_path getcwd);
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
my $cmd_registry = 'command.reg';

BEGIN {use_ok("App::Onsite::Editor");} # test 1

my $params = {
              items => 10,
              subfolders => 1,
              nonce => '01234567',
              data_dir => $data_dir,
              template_dir => "$template_dir",
              data_registry => $data_registry,
              command_registry => $cmd_registry,
              script_url => 'http://www.stsci.edu/test.cgi',
              base_url => 'http://www.stsci.edu/',
              valid_write => [$data_dir, $template_dir],
              data => 'App::Onsite::DirData',
              cmd => 'App::Onsite::ViewCommand',
             };

#----------------------------------------------------------------------
# Create templates

my $wf = App::Onsite::Support::WebFile->new(%$params);

my $type_registry = <<'EOQ';
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
CLASS = App::Onsite::DirData
SUPER = dir
HAS_SUBFOLDERS = 1
ADD_TEMPLATE = add_dir.htm
EDIT_TEMPLATE = edit_dir.htm
UPDATE_TEMPLATE = update_dir.htm
EOQ

my $command_registry = <<'EOQ';
        [every]
CLASS = App::Onsite::EveryCommand
TEMPLATE = show_form.htm
        [error]
CLASS = App::Onsite::EveryCommand
SUBTEMPLATE = error.htm
        [cancel]
CLASS = App::Onsite::CancelCommand
        [add]
CLASS = App::Onsite::AddCommand
SUBTEMPLATE = add.htm
        [browse]
CLASS = App::Onsite::BrowseCommand
SUBTEMPLATE = browse.htm
        [edit]
CLASS = App::Onsite::EditCommand
SUBTEMPLATE = edit.htm
        [remove]
CLASS = App::Onsite::RemoveCommand
SUBTEMPLATE = remove.htm
        [search]
CLASS = App::Onsite::SearchCommand
SUBTEMPLATE = search.htm
        [view]
CLASS = App::Onsite::ViewCommand
EOQ

$wf->writer("$template_dir/$data_registry", $type_registry);
$wf->writer("$template_dir/$cmd_registry", $command_registry);

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

my $show_form = <<'EOQ';
<!DOCTYPE html> 
<html lang="en">
<head>
<!-- begin meta -->
<!-- end meta -->
<link rel="stylesheet" type="text/css" href="style.css" title="style" />
<link rel="stylesheet" type="text/css" href="mobile.css" title="mobile" />
</head>
<body>
<div id="container">
<div id="primary">
<!-- begin primary -->
<!-- end primary -->
</div>
<div id="secondary">
<!-- begin secondary -->
<!-- end secondary -->
</div>
<div id="navigation">
<ul>
<!-- begin commandlinks -->
<!-- end commandlinks -->
</ul>
</div>
</div>
</body>
</html>
EOQ

my $edit_form = <<'EOQ';
<!DOCTYPE html> 
<html lang="en">
<head>
<!-- begin meta -->
<base href="{{base_url}}" />
<title>{{title}}</title>
<!-- end meta -->
<link rel="stylesheet" type="text/css" href="style.css" title="style" />
<link rel="stylesheet" type="text/css" href="mobile.css" title="mobile" />
</head>
<body>
<div id="container">
<div id="primary">
<!-- begin primary -->
<h1>{{title}}</h1>

<p class="error">{{error}}</p>

<!-- with form -->
<form id="edit_form" method="post" action="{{url}}" enctype="{{encoding}}">
<!-- with hidden -->
<!-- with field --><!-- end field -->
<!-- end hidden -->
<!-- with visible -->
<div class="title {{class}}">
<!-- with title --><!-- end title -->
</div>
<div class="formfield">
<!-- with field --><!-- end field -->
</div>
<!-- end visible -->
<div class="formfield"><!-- with buttons -->
<!-- with field --><!-- end field -->
<!-- end buttons --></div>
</form>
<!--end form -->
<!-- end primary -->
</div>
<div id="navigation">
<ul>
<!-- begin commandlinks -->
<!-- with data -->
<li><a href="{{url}}">
<!-- with title --><!-- end title -->
</a></li>
<!-- end data -->
<!-- end commandlinks -->
</ul>
</div>
</div>
</body>
</html>
EOQ

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

$templatename = "$template_dir/show_form.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $show_form);

$templatename = "$template_dir/edit.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $edit_form);

#----------------------------------------------------------------------
# Create object

my $con = App::Onsite::Editor->new(%$params);

isa_ok($con, "App::Onsite::Editor"); # test 2
can_ok($con, qw(batch execute run)); # test 3

#----------------------------------------------------------------------
# pick_command

my $cmd = $con->pick_command({id => '', cmd => "add"});
is($cmd, "add", "pick with command"); # test 4

$cmd = $con->pick_command({id => '', cmd => ""});
is($cmd, "edit", "pick with no command"); # test 5

$cmd = $con->pick_command({id => '', cmd => "cancel"});
is($cmd, "cancel", "pick with cancel"); # test 6

#----------------------------------------------------------------------
# Error response

my $error = 'Division by zero';
my $request = {cmd => 'edit', id => 'a-page'};
my $response = {code => 500, msg => $error,
                url => "$params->{base_url}a-page.html",
                protocol => 'text/html'};

$response = $con->error($request, $response);

my $d = {code => 200, msg => $error,
         protocol => 'text/html',
         url => $params->{base_url},
         results => {request => $request, results => undef,
                     title => 'Script Error', error => $error}};

is_deeply($response, $d, "error"); # test 7

#----------------------------------------------------------------------
# Top Page

my $filename = $con->top_page();
is($filename, "$params->{data_dir}/index.html", "top page"); # test 8

#----------------------------------------------------------------------
# Execute view command

##$wf->relocate($data_dir);

$request = {cmd => 'view', nonce => $params->{nonce}};
$response = $con->execute($request);

$d = {code => 302, msg => 'Found', url => $params->{base_url},
      protocol => 'text/html'};

is_deeply($response, $d, "execute view command"); # test 9

#----------------------------------------------------------------------
# Execute batch command

my $msg = $con->batch($request);
is($msg, undef, "batch"); # test 10

$request->{id} = "new-title";
$msg = $con->batch($request);
is($msg, "Invalid id: new-title", "batch error"); # test 11

#----------------------------------------------------------------------
# Run edit command

$request = {cmd => 'edit', id => 'a-title'};
$response = $con->run($request);

my $results = $response->{results};
delete $response->{results};

$d = {code => 200, msg => 'OK', url => "$params->{base_url}a-title.html",
      protocol => 'text/html'};

is_deeply($response, $d, "Run edit command"); # test 12
like($results, qr/x-www-form-urlencoded/, "Edit form"); # test 13

$request = {cmd => 'edit', id => 'new-title'};
$response = $con->run($request);
$results = $response->{results};

like($results, qr/Invalid id: new-title/, "Run with error msg"); # test 14
like($results, qr/RESULTS/, "Run with error results"); # test 15
