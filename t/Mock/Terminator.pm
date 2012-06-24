use strict;
use warnings;

#----------------------------------------------------------------------
# Mock handler used for testing FileHandler

package Mock::Terminator;

use base qw(App::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Set default parameters

sub parameters {
  my ($pkg) = @_;

    my %parameters = (
		length => 20,
	);

    return %parameters;
}

#----------------------------------------------------------------------
# Truncate file content

sub run {
    my ($self, $file, $content) = @_;

    return substr($content, 0, $self->{length});
}

1;
