#!/usr/bin/perl -w

use strict;
use warnings;
use lib '../lib';
use CGI::Carp 'fatalsToBrowser';
use CMS::Onsite::Support::CgiHandler;

my $parameters;
$parameters->{handler} = 'CMS::Onsite::Editor';

my $cgi = CMS::Onsite::Support::CgiHandler->new(%$parameters);
$cgi->run(@ARGV);
