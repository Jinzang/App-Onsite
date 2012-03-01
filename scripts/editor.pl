#!/usr/bin/env perl -T

use strict;
use warnings;

# Configuration. Change me.

use FindBin qw($Bin);
use lib "$Bin/../lib";

use constant PARAMETERS => {
                            data_dir => "$Bin/../test",
                            template_dir => "$Bin/../templates",
                            script_url => 'http://www.test.org/editor.pl',
                            handler => 'CMS::Onsite::Editor',
                            };

# Create object and run it

my $cgi = CMS::Onsite::Support::CgiHandler->new(PARAMETERS);
$ENV{PATH} = '';
$cgi->run();
