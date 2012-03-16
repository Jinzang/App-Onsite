#!/usr/bin/perl

use strict;
use warnings;

# All variables are configuration. Change them.

use FindBin qw($Bin);
use lib "$Bin/Lib";
use CMS::Onsite::Support::CgiHandler;

$ENV{PATH} = '';

my $cgi = CMS::Onsite::Support::CgiHandler->new(
                                        data_dir => $Bin,
                                        config_file => "$Bin/configuration.cfg",
                                        template_dir => "$Bin/Templates",
                                        script_url => 'http://www.test.org/editor.cgi',
                                        handler => 'CMS::Onsite::Editor',
                                        );

$cgi->run(@ARGV);
