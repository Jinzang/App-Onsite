#!/usr/bin/perl -wT

use strict;
use warnings;
use lib '../lib';
use CGI::Carp 'fatalsToBrowser';
use App::Onsite::Support::CgiHandler;

my $parameters;
$ENV{PATH} = '';
$parameters->{handler} = 'App::Onsite::Editor';

my $cgi = App::Onsite::Support::CgiHandler->new(%$parameters);
$cgi->run(@ARGV);
