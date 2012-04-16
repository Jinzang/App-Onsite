#!/usr/local/bin/perl
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 38;

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

#----------------------------------------------------------------------
# Create object

BEGIN {use_ok("CMS::Onsite::Editor");} # test 1

my $params = {
              items => 10,
              subfolders => 1,
              nonce => '01234567',
              data_dir => $data_dir,
              template_dir => "$template_dir",
              script_url => 'http://www.stsci.edu/test.cgi',
              base_url => 'http://www.stsci.edu/',
              valid_write => [$data_dir, $template_dir],
             };

my $con = CMS::Onsite::Editor->new(%$params);
my $wf = CMS::Onsite::Support::WebFile->new(%$params);

isa_ok($con, "CMS::Onsite::Editor"); # test 2
can_ok($con, qw(check query run render error)); # test 3

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
# Build form

my $bad = [];
$request = {cmd => 'edit',
            id => 'a-test',
            field_info => $field_info,
            nonce => $params->{nonce},
            script_url => $params->{script_url},
            title => "Test Title",
            body => "Test body",
            author => "Test Author",
           };

my $form = $con->form_command($request);
my $required_command = {
                        encoding => 'application/x-www-form-urlencoded',
                        url => $params->{script_url},
                       }; 

is_deeply($form, $required_command, "form command"); # test 5

$form->{title} = $con->form_title($request);
is($form->{title}, 'Edit Dir', "Form title"); # test 6

$form->{visible} = $con->form_visible_fields($request, $field_info);
my $visible = [{title => 'Title',
                class => 'required',
                field => '<input type="text" name="title" value="Test Title" id="title-field" />',
               },
               {title => 'Body',
                class => 'required',
                field => '<textarea name="body" id="body-field">Test body</textarea>',
               },
               {title => 'Author',
                class => 'optional',
                field => '<input type="text" name="author" value="Test Author" id="author-field" />',
               },
              ];

is_deeply($form->{visible}, $visible, "form_visible_fields"); # test 7

$form->{hidden} = $con->form_hidden_fields($request, $field_info);

my $nonce = $params->{nonce};
my $hidden = [
              {field => '<input type="hidden" name="id" value="a-test" id="id-field" />'},
              {field => "<input type=\"hidden\" name=\"nonce\" value=\"$nonce\" id=\"nonce-field\" />"},
            ];

is_deeply($form->{hidden}, $hidden, "form_hidden_fields"); # test 8

$form->{buttons} = $con->form_buttons($request);

my $buttons = [{field => '<input type="submit" name="cmd" value="Cancel" />'},
               {field => '<input type="submit" name="cmd" value="Edit" />'},
              ];

is_deeply($form->{buttons}, $buttons, "form_buttons"); # test 9

my $response = {code => 400, url=> $params->{base_url}, msg => 'Invalid type'};
$form->{error} = $response->{msg};

my $result_form = {error => $form->{error}, title => $form->{title},
                   form => {visible => $form->{visible}, hidden => $form->{hidden},
                             buttons => $form->{buttons}, url => $form->{url},
                              encoding => $form->{encoding}
                            }
                  };
               
$response = $con->query($request, $response);
is_deeply($response->{results}, $result_form, "query"); # test 10

#----------------------------------------------------------------------
# Response and error response

my $error = 'Division by zero';
$response = $con->set_response('a-page', 500, $error);
my $d = {code => 500, msg => $error, protocol => 'text/html',
         url => $params->{base_url}}; 

is_deeply($response, $d, "set response"); # test 11

$response = $con->error($request, $response);
$d ={code => 200, msg => 'OK',
     protocol => 'text/html',
     url => $params->{base_url},
     results => {request => $request, results => undef, env => \%ENV,
                 title => 'Script Error', error => $error}};

is_deeply($response, $d, "error"); # test 12

#----------------------------------------------------------------------
# Encode hash

my $encoded_form = $con->encode_hash($form);

my %new_form = %$form;
foreach my $section (%new_form) {
    if (ref $new_form{$section}) {
        my @section;
        foreach my $hash (@{$new_form{$section}}) {
            my %new_hash = %$hash;
            $new_hash{field} =~ s/</&lt;/g;
            $new_hash{field} =~ s/>/&gt;/g;
            push(@section, \%new_hash);
        }
        $new_form{$section} = \@section;
    }
}

is_deeply($encoded_form, \%new_form, "encode_hash"); # test 13

#----------------------------------------------------------------------
# check_fields

$d = $con->check_fields($request);
$response = {code => 200, msg => 'OK', protocol => 'text/html',
             url => $params->{base_url}};

is_deeply($d, $response, "check_fields with all data"); # test 14

$request->{title} = '';
$d = $con->check_fields($request);

$response->{code} = 400;
$response->{msg} = "Invalid or missing fields: title";
is_deeply($d, $response, "check_fields with missing data"); # test 15

#----------------------------------------------------------------------
# page_limit

my $limit = $con->page_limit();
is($limit, $con->{items}+1, "page_limit no args"); #test 16

$limit = $con->page_limit({start => 100});
is($limit, $con->{items} + 101, "page limit with start"); # test 17

#----------------------------------------------------------------------
# pick_command

my $cmd = $con->pick_command({id => '', cmd => "add"});
is($cmd, "add", "pick with command"); # test 18

$cmd = $con->pick_command({id => '', cmd => ""});
is($cmd, "browse", "pick with no command"); # test 19

$cmd = $con->pick_command({id => '', cmd => "cancel"});
is($cmd, "cancel", "pick with cancel"); # test 20

#----------------------------------------------------------------------
# Create template

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

my $create_dir = <<'EOQ';
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

my $create_page = <<'EOQ';
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

my $edit_form = <<'EOQ';
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
<h1>{{title}}</h1>

<p class="error">{{error}}</p>

<!-- begin form -->
<form id="edit_form" method="post" action="{{url}}" enctype="{{encoding}}">
<!-- begin hidden -->
<!-- begin field --><!-- end field -->
<!-- end hidden -->
<!-- begin visible -->
<div class="title {{class}}">
<!-- begin title --><!-- end title -->
</div>
<div class="formfield">
<!-- begin field --><!-- end field -->
</div>
<!-- end visible -->
<div><!-- begin buttons -->
<!-- begin field --><!-- end field -->
<!-- end buttons --></div>
</form>
<!--end form -->
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
<html>
<head>
<!-- begin meta -->
<!-- end meta -->
</head>
<body bgcolor=\"#ffffff\">
<!-- begin primary -->
<!-- end primary -->
<!-- begin secondary -->
<!-- end secondary -->
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
</body>
</html>
EOQ

# Write templates and pages

$wf->relocate($data_dir);

my $indexname = "$data_dir/index.html";
$indexname = $wf->validate_filename($indexname, 'w');
$wf->writer($indexname, $dir);

my $pagename = "$data_dir/a-title.html";
$pagename = $wf->validate_filename($pagename, 'w');
$wf->writer($pagename, $page);

my $templatename = "$template_dir/create_page.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $create_page);

$templatename = "$template_dir/create_dir.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $create_dir);

$templatename = "$template_dir/pagedata.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $page_template);

$templatename = "$template_dir/dirdata.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $dir_template);

$templatename = "$template_dir/update_page.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $update_page_template);

$templatename = "$template_dir/update_dir.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $update_dir_template);

$templatename = "$template_dir/edit.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $edit_form);

$templatename = "$template_dir/error.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $error_template);

$templatename = "$template_dir/show_form.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $show_form);

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

is_deeply($test, $response, "add_check"); # test 21

delete $data->{title};
$test = $con->add_check($data);
$response->{code} = 400;
$response->{msg} = "Invalid or missing fields: title";
is_deeply($test, $response, "add_check with missing data"); # test 22

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

is_deeply($d, $r, "add"); # Test 23

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

is_deeply($d, $r, "Edit"); # Test 24

#----------------------------------------------------------------------
# View

$request = {cmd => 'view', id => 'new-title', };
$d = $con->view_check($request);
$response = {code => 200, msg => 'OK', protocol => 'text/html',
             url => $r->{url}};
is_deeply($d, $response, "View check"); # Test 25

$d = $con->batch($request);
$response = {code => 302, msg => 'Found', protocol => 'text/html',
             url => $r->{url}};
is_deeply($d, $response, "View"); # Test 26

#----------------------------------------------------------------------
# Remove

foreach $id (('new-title', 'test-title')) {
    $con->batch({cmd => 'remove', id => $id, nonce => $params->{nonce}});
    my $found = -e "$data_dir/$id.html" ? 1 : 0;
    is($found, 0, "Remove $id"); # Test 27-28
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

is_deeply($results, \@data, "Browse all"); # Test 29

my @subset = @data[0..1];
my $max = $con->{items};
$con->{items} = 3;

$response = $con->browse($request);
$results = $response->{results}{data};
shift(@$results);

is_deeply($results, \@subset, "Browse with limit"); # Test 30
$con->{items} = $max;

#----------------------------------------------------------------------
# Search

delete $_->{browselink} foreach @data;
@subset = @data[0..1];

$request = {query => 'file', cmd => 'search'};

$response = $con->search($request);
$results = $response->{results}{data};
is_deeply($results, \@data, "Search"); # Test 31

$max = $con->{items};
$con->{items} = 3;
$response = $con->search($request);
$results = $response->{results}{data};
pop(@$results);

is_deeply($results, \@subset, "Search with limit"); # Test 32
$con->{items} = $max;

$request->{query} = 'First author';
$response = $con->search($request);
$results = $response->{results}{data};
is_deeply($results, [$data[0]], "Search with multiple terms"); # Test 33

#----------------------------------------------------------------------
# Render form

$response = $con->set_response('', 200);
$response->{results} = $result_form;

$request = {cmd => 'edit', id => ''};
my $rendered_form = $con->render($request, $response,
                                 "$data_dir/index.html", 'edit.htm');
my $rendered_data = $con->{nt}->data($rendered_form);

is($rendered_data->{meta}{title}, 'Edit Dir', "render form title"); # test 34
my @rendered_form_fields = sort keys %{$rendered_data->{primary}{form}};
is_deeply(\@rendered_form_fields, [qw(buttons hidden visible)],
          "render form fields"); #test 35
my $commandlinks = @{$rendered_data->{commandlinks}{data}};
is($commandlinks, 5, "render form commands"); # test 36

#----------------------------------------------------------------------
# Error page

$response = $con->set_response('', 500, "Debug Dump");
$response->{results} = $result_form;

my $subtemplate = 'error.htm';
$request = {cmd => 'edit', id => ''};
$response = $con->error($request, $response);
$response->{results} = $con->render($request, $response,
                                    "$data_dir/index.html", $subtemplate);

$rendered_data = $con->{nt}->data($response->{results});
is($rendered_data->{primary}{error}, 'Debug Dump', "Error page error"); # test 37

my $rendered_request = <<EOS;
<dl>
<dt>cmd</dt>
<dd>edit</dd>
<dt>id</dt>
<dd></dd>
</dl>
EOS
chomp $rendered_request;

is($rendered_data->{primary}{request}, $rendered_request,
   "Error page request"); # test 38
