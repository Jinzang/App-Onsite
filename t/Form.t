#!/usr/local/bin/perl -T
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 8;

#----------------------------------------------------------------------
# Create object

$ENV{PATH} = '/bin';
BEGIN {use_ok("App::Onsite::Form");} # test 1

my $params = {
              nonce => '01234567',
              script_url => 'http://www.stsci.edu/test.cgi',
             };

my $con = App::Onsite::Form->new(%$params);

isa_ok($con, "App::Onsite::Form"); # test 2
can_ok($con, qw(create_form)); # test 3

#----------------------------------------------------------------------
# Create test data

my $request = {title => "Test Title",
               body => "<p>Test body</p>\n",
               author => "Test Author",
              };

my $field_info = [{NAME => 'title', valid => '&'},
                  {NAME => 'body', valid => '&html'},
                  {NAME => 'author'},
                 ];
                 
$request->{field_info} = $field_info;

#----------------------------------------------------------------------
# Build form

$request = {cmd => 'edit',
            id => 'a-test',
            field_info => $field_info,
            nonce => $params->{nonce},
            script_url => $params->{script_url},
            title => "Test Title",
            body => "Test body",
            author => "Test Author",
           };

my $form = $con->get_command($request);
my $required_command = {
                        encoding => 'application/x-www-form-urlencoded',
                        url => $params->{script_url},
                       }; 

is_deeply($form, $required_command, "form command"); # test 4

$form->{visible} = $con->get_visible_fields($request, $field_info);
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

is_deeply($form->{visible}, $visible, "get_visible_fields"); # test 5

$form->{hidden} = $con->get_hidden_fields($request, $field_info);

my $nonce = $params->{nonce};
my $hidden = [
              {field => '<input type="hidden" name="id" value="a-test" id="id-field" />'},
              {field => "<input type=\"hidden\" name=\"nonce\" value=\"$nonce\" id=\"nonce-field\" />"},
            ];

is_deeply($form->{hidden}, $hidden, "get_hidden_fields"); # test 6

$form->{buttons} = $con->get_buttons($request);

my $buttons = [{field => '<input type="submit" name="cmd" value="Cancel" />'},
               {field => '<input type="submit" name="cmd" value="Edit" />'},
              ];

is_deeply($form->{buttons}, $buttons, "get_buttons"); # test 7

my $response = {code => 400, url=> $params->{base_url}, msg => 'Invalid type'};
$form->{error} = $response->{msg};

my $result_form = {};

%$result_form = (%$request, error => $form->{error}, title => 'Onsite Editor');
delete $form->{error};
$result_form->{form} = $form;

my $results = $con->create_form($request, $response->{msg});
is_deeply($results, $result_form, "create_form"); # test 8

