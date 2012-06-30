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
                    base_url => '',
                    template_dir => '',
                    lo => {DEFAULT => 'App::Onsite::Listops'},
                    nt => {DEFAULT => 'App::Onsite::Support::NestedTemplate'},
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
# Remove obsolete records from list (stub)

sub cull_data {
    my ($self, $records) = @_;
    return $records;
}

#----------------------------------------------------------------------
# Get field information by reading template file

sub field_info {
    my ($self, $id) = @_;

    my ($filename, $extra) = $self->id_to_filename($id);
    my $block = $self->{nt}->match("secondary.any.data", $filename);

    if (! $block) {
        my $type = $self->get_type();
        $filename = "$self->{template_dir}/${type}data.htm";
        $block = $self->{nt}->match("secondary.$type.data", $filename);
    }

    die "Cannot get field info for $id\n" unless $block;
    my $info = $block->info();

    my @new_info = grep {$_->{NAME} ne 'id'} @$info;
    return \@new_info;
}

#----------------------------------------------------------------------
# Return the names of the subdata objects contained in the file

sub get_subtypes {
    my ($self, $id) = @_;

    return [];
}

#----------------------------------------------------------------------
# Update navigation links after a file is changed

sub update_data {
    my ($self, $id, $record) = @_;

    return;
}

#----------------------------------------------------------------------
# Filter obsolete records before writing

sub write_secondary {
    my ($self, $filename, $records) = @_;

    my $new_records = $self->cull_data($records);
    $self->SUPER::write_secondary($filename, $new_records);

    return;
}


1;
