use strict;
use warnings;
use integer;

package Mock::ConfigFile;

use lib '../../lib';
use base qw(App::Onsite::Support::ConfiguredObject);

my $cache = {};

#----------------------------------------------------------------------
# Get hardcoded default parameter values

sub parameters {
	my ($self) = @_;

	return ();
}

#----------------------------------------------------------------------
# Read a configuration file into an array of parameters

sub read_file {
    my ($self) = @_;

	return %$cache;
}

#----------------------------------------------------------------------
# Read and parse a configuration file

sub write_file {
    my ($self, $parameters) = @_;

    %$cache = %$parameters;
    return;
}

1;
