use strict;
use warnings;
use integer;

#-----------------------------------------------------------------------
# Create an object that stores data in an html page

package App::Onsite::ListData;

use base qw(App::Onsite::PageData);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
	);

    my %base_params = $pkg->SUPER::parameters();
    %parameters = (%base_params, %parameters);

    return %parameters;
}

#----------------------------------------------------------------------
# Add a new file

sub add_data {
    my ($self, $parentid, $request) = @_;

    my $id = $self->next_id($parentid);
    $self->write_data($id, $request);

    return;
}

#----------------------------------------------------------------------
# Filter obsolete records before writing

sub build_secondary {
    my ($self, $filename, $request) = @_;

    my $records = $self->SUPER::build_secondary($filename, $request);
    $records = $self->cull_data($records);
    
    return $records;
}

#----------------------------------------------------------------------
# Remove obsolete records from list (stub)

sub cull_data {
    my ($self, $records) = @_;
    return $records;
}

1;
