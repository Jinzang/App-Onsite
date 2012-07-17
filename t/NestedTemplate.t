#!/usr/bin/env perl -T

use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 26;

#----------------------------------------------------------------------
# Remove internal entries from hash

sub filter_caps {
    my ($hash) = @_;

    my $newhash = {};
    while (my ($name, $value) = each %$hash) {
        next if $name ne "START" && $name =~ /[A-Z]/;
        $newhash->{$name} = $value;
    }

    return $newhash;
}

#----------------------------------------------------------------------
# Create objext

BEGIN {use_ok("App::Onsite::Support::NestedTemplate");} # test 1

my $n = App::Onsite::Support::NestedTemplate->new();
isa_ok($n, "App::Onsite::Support::NestedTemplate"); # test 2
can_ok($n, qw(data info parse render unparse)); # test 3

#----------------------------------------------------------------------
# Substitute for scalar

my $code = $n->parse('Hello {{name}}');
my $d = {name => 'Bernie'};
my $s = $n->render($d, $code);
is($s, "Hello Bernie", "Render simple template"); # test 4

#----------------------------------------------------------------------
# Substitute for list

my $t = <<'END';
<h1>{{name}}'s friends</h1>
<ul>
<!-- with friends -->
<li>{{friend}}</li>
<!-- end friends -->
</ul>
END

my  $r = <<'END';
<h1>Bernie's friends</h1>
<ul>
<li>Leigh</li>
<li>Greg</li>
<li>Craig</li>
<li>Mike</li>
</ul>
END

$code = $n->parse($t);
$d = {name =>'Bernie', friends => [qw(Leigh Greg Craig Mike)]};
$s = $n->render($d,  $code);
is($s, $r, "Render template with list"); # test 5

#----------------------------------------------------------------------
# Substitute for list of hashes

$t = <<'END';
<h1>{{name}}'s friends</h1>
<table>
<tr><th>Name</th><th>Phone</th></tr>
<!-- with friends -->
<tr><td>{{name}}</td><td>{{phone}}</td></tr>
<!-- end friends -->
</table>
END

$r = <<'END';
<h1>Bernie's friends</h1>
<table>
<tr><th>Name</th><th>Phone</th></tr>
<tr><td>Leigh</td><td>1242</td></tr>
<tr><td>Greg</td><td>1345</td></tr>
<tr><td>Craig</td><td>4849</td></tr>
<tr><td>Mike</td><td>4998</td></tr>
</table>
END

$code = $n->parse($t);
$d = {name =>'Bernie',
      friends => [
                  {name =>'Leigh', phone => 1242},
                  {name =>'Greg', phone => 1345},
                  {name =>'Craig', phone => 4849},
                  {name =>'Mike', phone => 4998}
                 ]
     };

$s = $n->render($d,  $code);
is($s, $r, "Render template with list of hashes"); # test 6

#----------------------------------------------------------------------
# Substitute for list of lists

$t = <<'END';
<h1>{{name}}'s friends</h1>
<table>
<tr><th>Name</th><th>Phone</th></tr>
<!-- with friends -->
<tr>
<!-- with friend -->
<td>{{field}}</td>
<!-- end friend -->
</tr>
<!-- end friends -->
</table>
END

$r = <<'END';
<h1>Bernie's friends</h1>
<table>
<tr><th>Name</th><th>Phone</th></tr>
<tr>
<td>Leigh</td>
<td>1242</td>
</tr>
<tr>
<td>Greg</td>
<td>1345</td>
</tr>
<tr>
<td>Craig</td>
<td>4849</td>
</tr>
<tr>
<td>Mike</td>
<td>4998</td>
</tr>
</table>
END

$code = $n->parse($t);
$d = {name =>'Bernie',
      friends => [
                  ['Leigh', 1242],
                  ['Greg', 1345],
                  ['Craig', 4849],
                  ['Mike', 4998]
                 ]
     };

$s = $n->render($d,  $code);
is_deeply($s, $r, "Render template with list of lists"); # test 7

#----------------------------------------------------------------------
# Render a data structure with no template

my  $r = <<'END';
<dl>
<dt>friends</dt>
<dd><ul>
<li><dl>
<dt>name</dt>
<dd>Leigh</dd>
<dt>phone</dt>
<dd>1242</dd>
</dl></li>
<li><dl>
<dt>name</dt>
<dd>Greg</dd>
<dt>phone</dt>
<dd>1345</dd>
</dl></li>
<li><dl>
<dt>name</dt>
<dd>Craig</dd>
<dt>phone</dt>
<dd>4849</dd>
</dl></li>
<li><dl>
<dt>name</dt>
<dd>Mike</dd>
<dt>phone</dt>
<dd>4998</dd>
</dl></li>
</ul></dd>
<dt>name</dt>
<dd>Bernie</dd>
</dl>
END
chomp $r;

$d = {d =>
          {
           name =>'Bernie',
           friends => [
                       {name =>'Leigh', phone => 1242},
                       {name =>'Greg', phone => 1345},
                       {name =>'Craig', phone => 4849},
                       {name =>'Mike', phone => 4998}
                      ]
           }
     };

$code = $n->parse('{{d}}');
$s = $n->render($d,  $code);
is($s, $r, "Render data structure with no templates"); # test 8

#----------------------------------------------------------------------
# Test if blocks

$d->{even} = sub {my $bin = shift; $bin->get('I') % 2 == 0;};

$t = <<'END';
<h1>{{name}}'s friends</h1>
<!-- if friends -->
<ul>
<!-- with friends -->
<li>{{friend}}</li>
<!-- end friends -->
</ul>
<!-- end friends --><!-- unless friends -->
<p>You have no friends</p>
<!-- end friends -->
END

$r = <<'END';
<h1>Bernie's friends</h1>
<ul>
<li>Leigh</li>
<li>Greg</li>
<li>Craig</li>
<li>Mike</li>
</ul>
END

$code = $n->parse($t);
$d = {name =>'Bernie', friends => [qw(Leigh Greg Craig Mike)]};
$s = $n->render($d,  $code);
is($s, $r, "If blocks"); # test 9

#----------------------------------------------------------------------
# Test scalar block

$t = <<'END';
Hello <!-- with name -->{{fool}}<!-- end name -->
END

$code = $n->parse($t);
$d = {name => 'Bernie'};

$s = $n->render($d,  $code);
is($s, "Hello Bernie\n", "Render scalar block"); # test 10

#----------------------------------------------------------------------
# Test scalar reference

my $name = 'Bernie';
$code = $n->parse('Hello {{name}}');
$d = {name => \$name};

$s = $n->render($d,  $code);
is($s, "Hello Bernie", "Render scalar reference"); # test 11

#----------------------------------------------------------------------
# Test block parse with missing blanks

$t = <<'END';
Hello <!-- with name -->{{fool}}<!--end name-->
END

$s = '';
$d = {name => 'Bernie'};
eval {
    $code = $n->parse($t);
    $s = $n->render($d,  $code);
};
is($s, "Hello Bernie\n", "Parse blocks with missing blanks"); # test 12

#----------------------------------------------------------------------
# Missing begin

$t = <<'END';
<h1>{{name}}'s friends</h1>
<ul>
<li>{{friend}}</li>
<!-- end friends -->
</ul>
END

$r = <<'END';
<h1>Bernie's friends</h1>
<ul>
<li>Leigh</li>
<li>Greg</li>
<li>Craig</li>
<li>Mike</li>
</ul>
END

eval {
    $code = $n->parse($t);
    $d = {name =>'Bernie', friends => [qw(Leigh Greg Craig Mike)]};
    my $s = $n->render($d,  $code);
};


like($@, qr(App::Onsite::Support::NestedTemplate: Mismatched begin/end),
	 "Missing begin"); # test 13

#----------------------------------------------------------------------
# Missing end

$t = <<'END';
<h1>${{name}}'s friends</h1>
<ul>
<!-- with friends -->
<li>{{friend}}</li>
</ul>
END

$r = <<'END';
<h1>Bernie's friends</h1>
<ul>
<li>Leigh</li>
<li>Greg</li>
<li>Craig</li>
<li>Mike</li>
</ul>
END

eval {
    $code = $n->parse($t);
    $d = {name =>'Bernie', friends => [qw(Leigh Greg Craig Mike)]};
    my $s = $n->render($d,  $code);
};


like($@, qr(App::Onsite::Support::NestedTemplate: Mismatched begin/end),
     "Missing end"); # test 14

#----------------------------------------------------------------------
# Test data retrieval

$t = <<'END';
<html>
<head>
<!-- begin header id="header" -->
<title>{{title}}</title>
<!-- end header -->
</head>
<body bgcolor=\"#ffffff\">
<div id = "container">
<div  id="content">
<!-- begin content id="content" -->
<p>Cogito ergo sum</p>
<!-- end content -->
</div>
<div id="sidebar">
<!-- begin sidebar id="sidebar" -->
<p>Side comment</p>
<!-- end sidebar -->
</div>
</div>
</body>
</html>
END

$r = {
    header =>'<title>{{title}}</title>',
    content => "<p>Cogito ergo sum</p>",
    sidebar => "<p>Side comment</p>",
};

$code = $n->parse($t);
$d = $n->data($code);

is_deeply($d, $r, "Data retrieval"); # test 15

$d = $n->info($code);

$r = [
    {NAME => 'header', id => 'header'},
    {NAME => 'content', id => 'content'},
    {NAME => 'sidebar', id => 'sidebar'},
];

is_deeply($d, $r, "Info retrieval"); # test 16

#----------------------------------------------------------------------
# Test begin block

$t = <<'END';
<h1>{{name}}'s friends</h1>
<table>
<tr><th>Name</th><th>Phone</th></tr>
<!-- begin friends -->
<tr><td>{{name}}</td><td>{{phone}}</td></tr>
<!-- end friends -->
</table>
END

$r = <<'END';
<h1>Bernie's friends</h1>
<table>
<tr><th>Name</th><th>Phone</th></tr>
<!-- begin friends -->
<tr><td>Leigh</td><td>1242</td></tr>
<!-- end friends -->
<!-- begin friends -->
<tr><td>Greg</td><td>1345</td></tr>
<!-- end friends -->
<!-- begin friends -->
<tr><td>Craig</td><td>4849</td></tr>
<!-- end friends -->
<!-- begin friends -->
<tr><td>Mike</td><td>4998</td></tr>
<!-- end friends -->
</table>
END

$code = $n->parse($t);
$d = {name =>'Bernie',
      friends => [
                  {name =>'Leigh', phone => 1242},
                  {name =>'Greg', phone => 1345},
                  {name =>'Craig', phone => 4849},
                  {name =>'Mike', phone => 4998}
                 ]
     };

$s = $n->render($d,  $code);
is_deeply($s, $r, "Begin block"); # test 17

#----------------------------------------------------------------------
# Test block arguments

$t = <<'END';
<!-- set query sql="phone is not null" distinct -->
<h1>{{name}}'s friends</h1>
<table>
<tr><th>Name</th><th>Phone</th></tr>
<!-- begin friends required title="My Friends" -->
<tr><td>{{name}}</td><td>{{phone}}</td></tr>
<!-- end friends -->
</table>
END

$r = <<'END';
<!-- set query sql="phone is not null" distinct [[]] -->
<h1>Bernie's friends</h1>
<table>
<tr><th>Name</th><th>Phone</th></tr>
<!-- begin friends required title="My Friends" -->
<tr><td>Leigh</td><td>1242</td></tr>
<!-- end friends -->
<!-- begin friends required title="My Friends" -->
<tr><td>Greg</td><td>1345</td></tr>
<!-- end friends -->
<!-- begin friends required title="My Friends" -->
<tr><td>Craig</td><td>4849</td></tr>
<!-- end friends -->
<!-- begin friends required title="My Friends" -->
<tr><td>Mike</td><td>4998</td></tr>
<!-- end friends -->
</table>
END

$code = $n->parse($t);
$d = {name =>'Bernie',
      friends => [
                  {name =>'Leigh', phone => 1242},
                  {name =>'Greg', phone => 1345},
                  {name =>'Craig', phone => 4849},
                  {name =>'Mike', phone => 4998}
                 ]
     };

$s = $n->render($d,  $code);
is_deeply($s, $r, "Block arguments"); # test 18

#----------------------------------------------------------------------
# Test multiple blocks with same name

$t = <<'END';
<table>
<!-- begin comments -->
<!-- begin comment id="0001" -->
<h2><!-- begin title -->Rocks!<!-- end title --></h2>
<!-- begin body -->
<p>This rocks!</p>
<!-- end body -->
<!-- end comment --><!-- begin comment id="0002" -->
<h2><!-- begin title -->Sucks!<!-- end title --></h2>
<!-- begin body -->
<p>This sucks!</p>
<!-- end body -->
<!-- end comment --><!-- begin comment id="0003" -->
<h2><!-- begin title -->Blows!<!-- end title --></h2>
<!-- begin body -->
<p>This blows!</p>
<!-- end body -->
<!-- end comment -->
<!-- end comments -->
</table>
END

$r = {comments => {comment => [
    {title => 'Rocks!', body => '<p>This rocks!</p>'},
    {title => 'Sucks!', body => '<p>This sucks!</p>'},
    {title => 'Blows!', body => '<p>This blows!</p>'},
]}};

$s = $n->data($t);
is_deeply($s, $r, "Data from multiple blocks"); # Test 19

#----------------------------------------------------------------------
# Test set with value

$t = <<'END';
<ul>
<!-- begin urls -->
<li><!-- set url required id="001" [[http://www.stsci.edu/resources/]] -->
<a href="http://www.stsci.edu/resources">Resources</a></li>
<li><!-- set url required id="002" [[http://www.stsci.edu/hst/]] -->
<a href="http://www.stsci.edu/hst">HST</a></li>
<li><!-- set url required id="003" [[http://www.stsci.edu/jwst/]] -->
<a href="http://www.stsci.edu/jwst">JWST</a></li>
<li><!-- set url required id="004" [[http://www.stsci.edu/outreach/]] -->
<a href="http://www.stsci.edu/outreach">Outreach</a></li>
<!-- end urls -->
</ul>
END

$s = $n->data($t);

$r = {urls =>
       {url =>
	[qw(http://www.stsci.edu/resources/ http://www.stsci.edu/hst/
        http://www.stsci.edu/jwst/ http://www.stsci.edu/outreach/)]
       }
     };

is_deeply($s, $r, "Set with value"); # Test 20

#----------------------------------------------------------------------
# Test render set

$t = <<'END';
<ul>
<!-- begin urls -->
<li><!-- set url required [[http://www.stsci.edu/resources/]] -->
<a href="{{url}}">{{url}}</a></li>
<!-- end urls -->
</ul>
END

$r = <<'END';
<ul>
<!-- begin urls -->
<li><!-- set url required [[http://www.stsci.edu/resources/]] -->
<a href="http://www.stsci.edu/resources/">http://www.stsci.edu/resources/</a></li>
<!-- end urls -->
<!-- begin urls -->
<li><!-- set url required [[http://www.stsci.edu/hst/]] -->
<a href="http://www.stsci.edu/hst/">http://www.stsci.edu/hst/</a></li>
<!-- end urls -->
<!-- begin urls -->
<li><!-- set url required [[http://www.stsci.edu/jwst/]] -->
<a href="http://www.stsci.edu/jwst/">http://www.stsci.edu/jwst/</a></li>
<!-- end urls -->
<!-- begin urls -->
<li><!-- set url required [[http://www.stsci.edu/outreach/]] -->
<a href="http://www.stsci.edu/outreach/">http://www.stsci.edu/outreach/</a></li>
<!-- end urls -->
</ul>
END

$d = {urls => $s->{urls}{url}};
$code = $n->parse($t);
my $list = $n->render($d,  $code);
is_deeply($list, $r, "Render set"); # Test 21

#----------------------------------------------------------------------
# Match block

$t = <<'END';
<table>
<!-- begin comments -->
<!-- begin comment id="0001" -->
<h2><!-- begin title -->Rocks!<!-- end title --></h2>
<!-- begin body -->
<p>This rocks!</p>
<!-- end body -->
<!-- end comment --><!-- begin comment id="0002" -->
<h2><!-- begin title -->Sucks!<!-- end title --></h2>
<!-- begin body -->
<p>This sucks!</p>
<!-- end body -->
<!-- end comment --><!-- begin comment id="0003" -->
<h2><!-- begin title -->Blows!<!-- end title --></h2>
<!-- begin body -->
<p>This blows!</p>
<!-- end body -->
<!-- end comment -->
<!-- end comments -->
</table>
END

$code = $n->parse($t);
$d = $code->match("comments.comment")->data();
$r = {title => 'Rocks!', body => '<p>This rocks!</p>'};

is_deeply($d, $r, "Match block"); # Test 22

#----------------------------------------------------------------------
# Render template and subtemplate

my $t1 = <<'END';
<h1>{{name}}'s friends</h1>
<table>
<tr><th>Name</th><th>Phone</th></tr>
<!-- begin subtemplate type="one" -->
<!-- end subtemplate -->
</table>
END

my $t2 = <<'END';

<!-- begin subtemplate type="two" -->
<!-- with friends -->
<tr><td>{{name}}</td><td>{{phone}}</td></tr>
<!-- end friends -->
<!-- end subtemplate -->

END

$r = <<'END';
<h1>Bernie's friends</h1>
<table>
<tr><th>Name</th><th>Phone</th></tr>
<!-- begin subtemplate type="two" -->
<tr><td>Leigh</td><td>1242</td></tr>
<tr><td>Greg</td><td>1345</td></tr>
<tr><td>Craig</td><td>4849</td></tr>
<tr><td>Mike</td><td>4998</td></tr>
<!-- end subtemplate -->
</table>
END

$code = $n->parse($t1, $t2);

$d = {name =>'Bernie',
	  subtemplate => {
		friends => [
					{name =>'Leigh', phone => 1242},
					{name =>'Greg', phone => 1345},
					{name =>'Craig', phone => 4849},
					{name =>'Mike', phone => 4998}
				   ]
	 },
     };

$s = $n->render($d,  $code);
is($s, $r, "Render template and subtemplate"); # test 23

#----------------------------------------------------------------------
# Test subtemplate

$t1 = <<'END';
<h1>{{name}}'s friends</h1>
<ul>
<!-- begin subtemplate -->
<!-- with friends -->
<!-- if even -->
<li class="even">{{friend}}</li>
<!-- end even --><!-- unless even -->
<li class="odd">{{friend}}</li>
<!-- end even -->
<!-- end friends -->
<!-- end subtemplate -->
</ul>
END

$t2  = <<'END';
<h1>Bernie's friends</h1>
<ol>
<!-- begin subtemplate -->
<!-- end subtemplate -->
</ol>
END

$r = <<'END';
<h1>Bernie's friends</h1>
<ol>
<!-- begin subtemplate -->
<!-- with friends -->
<!-- if even -->
<li class="even">{{friend}}</li>
<!-- end even --><!-- unless even -->
<li class="odd">{{friend}}</li>
<!-- end even -->
<!-- end friends -->
<!-- end subtemplate -->
</ol>
END

$code = $n->parse($t2, $t1);
$s = $n->unparse($code);
is($s, $r, "Replace with subtemplate"); # test 24

#----------------------------------------------------------------------
# Test multi-level replace

$t1 = <<'END';
<h1>{{name}}'s friends</h1>
<ul>
<!-- begin subtemplate -->
<!-- begin friends -->
<!-- if even -->
<li class="even">{{friend}}</li>
<!-- end even --><!-- unless even -->
<li class="odd">{{friend}}</li>
<!-- end even -->
<!-- end friends -->
<!-- end subtemplate -->
</ul>
END

$t2  = <<'END';
<h1>Bernie's friends</h1>
<ol>
<!-- begin subtemplate -->
<!-- begin friends -->
<!-- end friends -->
<!-- end subtemplate -->
</ol>
END

$r = <<'END';
<h1>Bernie's friends</h1>
<ol>
<!-- begin subtemplate -->
<!-- begin friends -->
<!-- if even -->
<li class="even">{{friend}}</li>
<!-- end even --><!-- unless even -->
<li class="odd">{{friend}}</li>
<!-- end even -->
<!-- end friends -->
<!-- end subtemplate -->
</ol>
END

$code = $n->parse($t2, $t1);
$s = $n->unparse($code);
is($s, $r, "Multi-level replace with subtemplate"); # test 25

#----------------------------------------------------------------------
# Partial update

$t = <<'END';
<!-- begin caption -->
<h1><!-- begin name -->Bernie<!-- end name -->'s friends</h1>
<!-- end caption -->
<table>
<!-- begin table -->
<tr><th>Name</th><th>Phone</th></tr>
<!-- begin friends -->
<tr><td><!-- begin name -->Leigh<!-- end name --></td>
<td><!-- begin phone -->1242<!-- end phone --></td></tr>
<!-- end friends -->
<!-- begin friends -->
<tr><td><!-- begin name -->Greg<!-- end name --></td>
<td><!-- begin phone -->1345<!-- end phone --></td></tr>
<!-- end friends -->
<!-- begin friends -->
<tr><td><!-- begin name -->Craig<!-- end name --></td>
<td><!-- begin phone -->4849<!-- end phone --></td></tr>
<!-- end friends -->
<!-- begin friends -->
<tr><td><!-- begin name -->Mike<!-- end name --></td>
<td><!-- begin phone -->4998<!-- end phone --></td></tr>
<!-- end friends -->
<!-- end table -->
</table>
END

my $caption = {caption => {name => 'Anne'}};
                   
$code = $n->parse($t);
$r = $n->render($caption,  $code);
$s = $n->data($r);

$d = {
      caption => {name =>'Anne'},
      table => {friends => [
                  {name =>'Leigh', phone => '1242'},
                  {name =>'Greg', phone => '1345'},
                  {name =>'Craig', phone => '4849'},
                  {name =>'Mike', phone => '4998'}
                 ]
              }
     };

is_deeply($s, $d, "Partial data render"); # test 26

