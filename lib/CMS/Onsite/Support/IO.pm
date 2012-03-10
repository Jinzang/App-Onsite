use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# A wrapper for file i/o

package CMS::Onsite::Support::IO;

use IO::File;
use base qw(CMS::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Set default values

sub parameters {
  my ($pkg) = @_;

    my %parameters = ();
    return %parameters;    
}

#----------------------------------------------------------------------
# Print to output file

sub print {
    my ($self, $str) = @_;
    
    return print $str;
}

1;