use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# A directory that contains a blog

package App::Onsite::BlogData;

use base qw(App::Onsite::DirData App::Onsite::PostData);

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
    return $self->get_next($parentid);    
}

#----------------------------------------------------------------------
# Return a closure that returns each record in the file

sub get_next {
    my ($self, $parentid) = @_;

    my ($filename, $extra) = $self->id_to_filename($parentid); 
    my $item = $self->block_info('secondary', $filename);
    
    my $sort = $item->{sort} || '-id';
    my $subtype = $item->{type} if exists $item->{type};
    die "Cannot determine subtype of $parentid\n" unless $subtype;
    
    my $obj = $self->{reg}->create_subobject($self,
                                             $self->{data_registry},
                                             $subtype);

    my $maxlevel = 3;
    my $dir = $self->get_repository($parentid);
    my $visitor = $self->{wf}->visitor($dir, $maxlevel, $sort);
    
    return sub {
        my $ext;
    	my $filename;

    	for (;;) {
    	    $filename = &$visitor();
            return unless defined $filename;

            last if $obj->valid_filename($filename);
        }

        my $data = $obj->read_primary($filename);
        $data = $obj->extra_data($data);
        
        return $data;
    };
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

1;
