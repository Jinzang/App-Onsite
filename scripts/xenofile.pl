#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use App::Onsite::Support::XenoFile;

my $output_dir = pop(@ARGV);
my @input_dirs = @ARGV;
die "Usage: input_dir output_dir" unless @input_dirs && $output_dir;

my %parameters = (
                  valid_read => \@input_dirs,
                  valid_write => [$output_dir],
                  );

my $xf = App::Onsite::Support::XenoFile->new(%parameters);
$xf->run($output_dir, @input_dirs);
