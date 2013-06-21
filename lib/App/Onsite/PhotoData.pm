use strict;
use warnings;

#----------------------------------------------------------------------
package App::Onsite::PhotoData;

use GD;
use base qw(App::Onsite::ListData);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
        thumb_width => 0,
        thumb_height => 0,
        photo_width => 0,
        photo_height => 0,
	);

    my %base_params = $pkg->SUPER::parameters();
    %parameters = (%base_params, %parameters);

    return %parameters;
}

#----------------------------------------------------------------------
# Add extra data to the data read from file

sub extra_data {
    my ($self, $hash) = @_;

    my $record = $self->SUPER::extra_data($hash);
    $record = $self->read_photo($record->{id}, $record);

    return $record;
}

#----------------------------------------------------------------------
# Get field information by reading template file

sub field_info {
    my ($self, $id) = @_;

    my $info = $self->SUPER::field_info($id);
    push(@$info, $self->photo_info($id));
    
    return $info;
}

#---------------------------------------------------------------------------
# Convert an id to a phto filename

sub id_to_photo_name {
    my ($self, $id, $field) = @_;
    
    my ($parentid, $seq) = $self->{wf}->split_id($id);
    my $dir = $self->get_repository($parentid);

    return "$dir/$field$seq.jpg";
}

#---------------------------------------------------------------------------
# Convert an id to a phto filename

sub id_to_photo_url {
    my ($self, $id, $field) = @_;
    
    my $filename = $self->id_to_photo_name($id, $field);
    return $self->filename_to_url($filename);
}

#----------------------------------------------------------------------
# Get field information for photo

sub photo_info {
    my ($self) = @_;

    my $item = {};
    $item->{NAME} = 'filename';
    $item->{title} = 'Choose photo';
    $item->{style} = 'type=file';
    $item->{valid} = '&';
    
    return $item;
}

#---------------------------------------------------------------------------
# Read record from file

sub read_data {
    my ($self, $id) = @_;

    my $record = $self->SUPER::read_data($id);
    $record = $self->read_photo($id, $record);
    
    return $record;
}

#---------------------------------------------------------------------------
# Read photo data into record

sub read_photo {
    my ($self, $id, $record) = @_;

    if (defined $record) {
        for my $field (qw(photo thumb)) {
            $record->{$field} = $self->id_to_photo_url($id, $field);
        }
    }

    return $record;
}

#----------------------------------------------------------------------
# Remove a photo

sub remove_data {
    my ($self, $id, $request) = @_;

    $self->SUPER::remove_data($id, $request);
    
    for my $field (qw(photo thumb)) {
        my $filename = $self->id_to_photo_name($id, $field);
        $self->{wf}->remove_file($filename);
    }
    
    return;
}

#---------------------------------------------------------------------------
# Resize a photo

sub resize {
    my ($self, $filename, $field) = @_;

    GD::Image->trueColor(1);
    my $old_photo = GD::Image->new($filename);
    die "Couldn't read $filename" unless $old_photo;

    my ($old_width, $old_height) = $old_photo->getBounds();

    my $width_field = "${field}_width";
    my $width = $self->{$width_field};
    
    my $height_field = "${field}_height";
    my $height = $self->{$height_field};

    my $height_factor = $height / $old_height;
    my $width_factor = $width / $old_width;
    my $factor = ($height_factor < $width_factor ? $height_factor : $width_factor);

    $height = int($factor * $old_height);
    $width  = int($factor * $old_width);

    my $photo = GD::Image->new($width, $height);
    $photo->copyResampled($old_photo,
                          0, 0, 0, 0,
                          $width, $height,
                          $old_width, $old_height);

    return $photo->jpeg();
}

#---------------------------------------------------------------------------
# Write a photo to the gallery

sub write_data {
    my ($self, $id, $request) = @_;

    $self->write_photo($id, $request);
    $self->SUPER::write_data($id, $request);
    
    return;
}

#---------------------------------------------------------------------------
# Write a photo to the gallery

sub write_photo {
    my ($self, $id, $request) = @_;
    
    my $binary = 1;
    for my $field (qw(photo thumb)) {
        my $photo = $self->resize($request->{filename}, $field);
        my $filename = $self->id_to_photo_name($id, $field);
        $self->{wf}->writer($filename, $photo, $binary);
    }

    return;
}

1;
