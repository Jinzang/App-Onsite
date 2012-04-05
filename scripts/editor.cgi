#!/usr/bin/perl -w

use strict;
use warnings;
use lib '../lib';
use CGI::Carp 'fatalsToBrowser';
use CMS::Onsite::Support::CgiHandler;

my $parameters;

$parameters->{handler} = 'CMS::Onsite::Editor';
$parameters->{valid_read} = [$parameters->{template_dir}];
$parameters->{valid_write} = [$parameters->{data_dir}];

my $cgi = CMS::Onsite::Support::CgiHandler->new(%$parameters);
$cgi->run(@ARGV);
