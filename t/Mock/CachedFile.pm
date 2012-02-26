use strict;
use warnings;
use integer;

package Mock::CachedFile;

#----------------------------------------------------------------------
# Create the initial, empty cache

sub new {
    my ($pkg) = @_;

    return bless ({}, $pkg);
}

#----------------------------------------------------------------------
# Fetch the parsed representation from the cache if available

sub fetch {
    my ($self, $filename) = @_;
    return;
}

#----------------------------------------------------------------------
# Free the cache item when no longer valid

sub free {
    my ($self, $filename) = @_;
    return;
}

#----------------------------------------------------------------------
# Fetch the parsed representation from the cache if available

sub save {
    my ($self, $filename, $data) = @_;
   return;
}

1;
