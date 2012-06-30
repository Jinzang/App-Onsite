use strict;
use warnings;

#----------------------------------------------------------------------
# Mock handler used for testing CgiHandler

package Mock::IO;

use base qw(CMS::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
        buffer => '',
	);

    return %parameters;
}

#----------------------------------------------------------------------
# Get contents of buffer and 

sub empty_buffer {
    my ($self) = @_;

    my $buffer = $self->{buffer};
    $self->{buffer} = '';

    return $buffer;
}

#----------------------------------------------------------------------
# Emulate print by sending text to buffer

sub print {
    my ($self, $str) = @_;

    $self->{buffer} .= $str;
}

1;
