use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# A directory that contains a blog

package App::Onsite::BlogData;

use base qw(App::Onsite::DirData);

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
# Retrieve all records

sub browse_data {
    my ($self, $parentid, $limit) = @_;

    return $self->App::Onsite::FileData::browse_data($parentid, $limit);
}

#----------------------------------------------------------------------
# Return the names of the subdata objects contained in the file

sub get_subtypes {
    my ($self, $id) = @_;

    $self->App::Onsite::PageData::get_subtypes($id);
}

#----------------------------------------------------------------------
# Return true if there is only one subtype

sub has_one_subtype {
    my ($self, $id) = @_;

    return  $self->App::Onsite::PageData::has_one_subtype($id);
}

1;
