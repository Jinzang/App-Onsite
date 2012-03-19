#!/usr/bin/perl

use strict;
use warnings;

BEGIN {unshift @INC, '' . '/lib'}; # SOURCE
use CMS::Onsite::Support::CgiHandler;

$ENV{PATH} = '';

my $cgi = CMS::Onsite::Support::CgiHandler->new(
                                        group => '', # GROUP
                                        data_dir => '', # TARGET
                                        config_file => '' . '/editor.cfg', # TARGET
                                        template_dir => '', # TEMPLATES
                                        handler => 'CMS::Onsite::Editor',
                                        );

$cgi->run(@ARGV);
