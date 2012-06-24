#!/usr/bin/env perl -T
use strict;

use lib 't';
use lib 'lib';

use Test::More tests => 50;

#----------------------------------------------------------------------
# Create object

BEGIN {use_ok("App::Onsite::FieldValidator");} # test 1

do {
	my $fv = App::Onsite::FieldValidator->new(valid => '');
	my $r = {};
	is_deeply($fv, $r, "Empty validator"); # Test 2
};

do {
	my $fv = App::Onsite::FieldValidator->new(valid => 'string');
	my $r = {};
	is_deeply($fv, $r, "String validator"); # Test 3
	my $b = $fv->validate('');
	is($b, 1, "Validate empty string");  # Test 4
	$b = $fv->validate('foo');
	is($b, 1, "Validate string"); # Test 5
};

do {
	my $fv = App::Onsite::FieldValidator->new(valid => 'number');
	my $r = {};
	is_deeply($fv, $r, "Number validator"); # Test 6
	my $b = $fv->validate('');
	is($b, 1, "Validate empty number"); # Test 7
	$b = $fv->validate('23');
	is($b, 1, "Validate naumber"); # Test 8
	$b = $fv->validate('a23');
	is($b, undef, "Validate non-naumber"); # Test 9
};

do {
	my $fv = App::Onsite::FieldValidator->new(valid => '&string');
	my $r = {required => 1};
	is_deeply($fv, $r, "Required string validator"); # Test 10
	my $b = $fv->validate('');
	is($b, undef, "Validate empty required string"); # Test 11
	$b = $fv->validate('foo');
	is($b, 1, "Validate required string"); # Test 12
};

do {
	my $fv = App::Onsite::FieldValidator->new(valid => '&number');
	my $r = {required => 1};
	$r->{required} = 1;
	is_deeply($fv, $r, "Required number validator"); # Test 13
	my $b = $fv->validate('');
	is($b, undef, "Validate empty required number"); # Test 14
	$b = $fv->validate('23');
	is($b, 1, "Validate required naumber"); # Test 15
};

do {
	my $valid = '/\$\d+\.\d\d/';
	my $fv = App::Onsite::FieldValidator->new(valid => $valid);
	my $r = {regexp => '\$\d+\.\d\d'};
	is_deeply($fv, $r, "String regexp"); # Test 16
	my $b = $fv->validate('$317.43');
	is($b, 1, "Validate valid regexp string"); # Test 17
	$b = $fv->validate('$24');
	is($b, undef, "Validate invalid regexp string"); # Test 18
};


do {
	my $valid = '|joe|jack|jim|';
	my $fv = App::Onsite::FieldValidator->new(valid => $valid);
	my $r = {selection => 'joe|jack|jim'};
	is_deeply($fv, $r, "String selector"); # Test 19
	my $b = $fv->validate('jack');
	is($b, 1, "Validate valid selector string"); # Test 20
	$b = $fv->validate('jason');
	is($b, undef, "Validate invalid selector string"); # Test 21
};

do {
	my $valid = 'number|10|20|30|';
	my $fv = App::Onsite::FieldValidator->new(valid => $valid);
	my $r = {selection => '10|20|30'};
	is_deeply($fv, $r, "Number selector"); # Test 22
	my $b = $fv->validate('10.0');
	is($b, 1, "Validate valid number selector string"); # Test 23
	$b = $fv->validate('15');
	is($b, undef, "Validate invalid number selector string"); # Test 24
};

do {
	my $valid = 'number[10,30]';
	my $fv = App::Onsite::FieldValidator->new(valid => $valid);
	my $r = {limits => '[10,30]'};
	is_deeply($fv, $r, "Numeric limits"); # Test 25
	my $b = $fv->validate('10.0');
	is($b, 1, "Validate lower numeric limit string"); # Test 26
	$b = $fv->validate('15.0');
	is($b, 1, "Validate intermediate numeric limit string"); # Test 27
	$b = $fv->validate('20.0');
	is($b, 1, "Validate upper numeric limit string"); # Test 28
	$b = $fv->validate('5');
	is($b, undef, "Validate outside numeric limit string"); # Test 29
};

do {
	my $valid = 'number(10,30)';
	my $fv = App::Onsite::FieldValidator->new(valid => $valid);
	my $r = {limits => '(10,30)'};
	is_deeply($fv, $r, "Open numeric limits"); # Test 30
	my $b = $fv->validate('10.0');
	is($b, undef, "Validate lower open numeric limit string"); # Test 31
	$b = $fv->validate('15.0');
	is($b, 1, "Validate intermediate open numeric limit string"); # Test 32
	$b = $fv->validate('20.0');
	is($b, 1, "Validate upper open numeric limit string"); # Test 33
	$b = $fv->validate('5');
	is($b, undef, "Validate outside numeric limit string"); # Test 34
};

do {
	my $valid = 'number(0,)';
	my $fv = App::Onsite::FieldValidator->new(valid => $valid);
	my $r = {limits => '(0,)'};
	is_deeply($fv, $r, "Open numeric one sided limits"); # Test 35
	my $b = $fv->validate('0.0');
	is($b, undef, "Validate lower open one sided numeric limit string"); # Test 36
	$b = $fv->validate('5.0');
	is($b, 1, "Validate intermediate open one sided numeric limit string"); # Test 37
	$b = $fv->validate('-10');
	is($b, undef, "Validate outside numeric limit string"); # Test 38
};

do {
	my $valid = 'number[,9]';
	my $fv = App::Onsite::FieldValidator->new(valid => $valid);
	my $r = {limits => '[,9]'};
	is_deeply($fv, $r, "Closed numeric limits"); # Test 39
	my $b = $fv->validate('5.0');
	is($b, 1, "Validate intermediate closed one sided numeric limit string"); # Test 40
	$b = $fv->validate('9.0');
	is($b, 1, "Validate upper closed one sided numeric limit string"); # Test 41
	$b = $fv->validate('10');
	is($b, undef, "Validate outside closed numeric limit string"); # Test 42
};

do {
	my $valid = 'string[5,]';
	my $fv = App::Onsite::FieldValidator->new(valid => $valid);
	my $r = {limits => '[5,]'};
	is_deeply($fv, $r, "String limits"); # Test 43
	my $str = $fv->canonize(' <b> </b>');
	is($str, '&#60;b&#62; &#60;&#47;b&#62;', "Convert html"); # Test 44
	my $b = $fv->validate('12345');
	is($b, 1, "Validate valid string length"); # Test 45
	$b = $fv->validate('1234');
	is($b, undef, "Validate invalid string length"); # Test 46
};

do {
	my $fv = App::Onsite::FieldValidator->new(valid => 'string');
	my $field = $fv->build_field('foo', 'bar');
	is($field, '<input type="text" name="foo" value="bar" id="foo-field" />',
	   "Form text field"); # Test 47

	$fv = App::Onsite::FieldValidator->new(valid => 'html');
	$field = $fv->build_field('foo', 'bar');
	is($field, '<textarea name="foo" id="foo-field">bar</textarea>',
	   "Form textarea"); # Test 48

	$field = $fv->build_field('foo', 'bar', 'rows=20;cols=64');
	is($field,
	   '<textarea name="foo" rows="20" cols="64" id="foo-field">bar</textarea>',
	   "Form textarea with style"); # Test 49

	$fv = App::Onsite::FieldValidator->new(valid => 'string|bar|biz|baz|');
	$field = $fv->build_field('foo', 'bar');
	my $r = <<EOQ;
<select name="foo" id="foo-field">
<option selected="selected" value="bar">bar</option>
<option value="biz">biz</option>
<option value="baz">baz</option>
</select>
EOQ
	chomp $r;
	is($field, $r, "Form selection"); # Test 50
};
