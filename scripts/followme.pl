#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use App::Onsite::Support::FileHandler;

my %parameters = (handler => 'App::Onsite::Support::FollowMe',
                  extension => 'html',
                  valid_write => \@ARGV,
                  );

my $fh = App::Onsite::Support::FileHandler->new(%parameters);
$fh->run(@ARGV);
