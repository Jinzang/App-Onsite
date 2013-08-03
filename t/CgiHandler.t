#!/usr/local/bin/perl
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 12;

use Cwd qw(abs_path getcwd);
use App::Onsite::Support::WebFile;

#----------------------------------------------------------------------
# Create object

BEGIN {use_ok("App::Onsite::Support::CgiHandler");} # test 1

my $params = {
              min => 10,
              max => 20,
              detail_errors => 0,
              script_url => 'http://www.test.org/test.cgi',
              io => 'Mock::IO',
              handler => 'Mock::MinMax',
             };

my $o = App::Onsite::Support::CgiHandler->new(%$params);

isa_ok($o, "App::Onsite::Support::CgiHandler"); # test 2
can_ok($o, qw(run)); # test 3

#----------------------------------------------------------------------
# Update config

my $h = $o->{handler};
is($h->{script_url}, $params->{script_url}, "Script url configuration"); # test 4
is($h->{base_url}, 'http://www.test.org/', "Base url configuration"); # test 5

my $cwd = getcwd();
is($h->{data_dir}, "$cwd/t", "Data dir configuration"); # test 6
is($h->{template_dir}, "$cwd/t/templates", "Templates dir configuration"); # test 7

#----------------------------------------------------------------------
# Hashify
my $hash = $o->hashify('one=1', 'two=2', 'flag');
is_deeply($hash, {one => 1, two => 2, flag => 1}, "Hashify"); # test 8

#----------------------------------------------------------------------
# error

my $request = {expr => '1/0'};
my $response = {code => 500, msg => 'Division by zero', results => 'NaN'};

my $html = <<'EOS';
<head><title>Script Error</title></head>
<body>
<h1>Script Error</h1>
<p>Please report this error to the developer.</p>
<pre>Division by zero</pre>
</body></html>
EOS

$response  = $o->error($request, $response);

my $ok_response = {code => 200,
                    msg => 'OK',
                    protocol => 'text/html',
                    results => $html
                    };

is_deeply($response, $ok_response, "Error with short template"); # test 9

#----------------------------------------------------------------------
# Run

$response = $o->run('value=15');
my $buffer = $o->{io}->empty_buffer();

is($buffer, "Content-type: text/html\n\nValue in bounds: 15",
   "Run valid request"); # test 10

$response = $o->run('value=25');
$buffer = $o->{io}->empty_buffer();

$html = <<'EOS';
<head><title>Script Error</title></head>
<body>
<h1>Script Error</h1>
<p>Please report this error to the developer.</p>
<pre>ERROR Value out of bounds: 25</pre>
</body></html>
EOS

is($buffer, "Content-type: text/html\n\n$html",
   "Run invalid request"); # test 11

$response = $o->run('foo=bar');
$buffer = $o->{io}->empty_buffer();

$html = <<'EOS';
<head><title>Script Error</title></head>
<body>
<h1>Script Error</h1>
<p>Please report this error to the developer.</p>
<pre>Value not set
</pre>
</body></html>
EOS

is($buffer, "Content-type: text/html\n\n$html",
   "Run invalid request"); # test 12
