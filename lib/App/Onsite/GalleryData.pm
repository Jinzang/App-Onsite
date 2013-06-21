use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# A directory that contains a photo gallery

package App::Onsite::GalleryData;

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
# Return a closure for browse_data

sub get_browsable {
    my ($self, $parentid) = @_;
    return $self->App::Onsite::FileData::get_next($parentid);    
}

#----------------------------------------------------------------------
# Return a closure for search_data

sub get_searchable {
    my ($self, $parentid) = @_;
    return $self->App::Onsite::FileData::get_next($parentid);    
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

    return $self->App::Onsite::PageData::has_one_subtype($id);
}

#----------------------------------------------------------------------
# Get records whose contents match the hash

sub search_data {
    my ($self, $query, $parentid, $limit) = @_;

    return $self->App::Onsite::FileData::search_data($query, $parentid, $limit);
}

1;
