use strict;
use warnings;
use integer;

package Mock::TestObject2;

use lib '../../lib';
use base qw(App::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Get hardcoded default parameter values

sub parameters {
	my ($self) = @_;

	return (mo => {DEFAULT => 'Mock::TestObject'},
			mu => {DEFAULT => 'Mock::TestObject2'});
}

1;
