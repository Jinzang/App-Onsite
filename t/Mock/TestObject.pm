use strict;
use warnings;
use integer;

package Mock::TestObject;

use lib '../../lib';
use base qw(CMS::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Get hardcoded default parameter values

sub parameters {
	my ($self) = @_;

	return (one => 0, two => 0, list => []);
}

1;
