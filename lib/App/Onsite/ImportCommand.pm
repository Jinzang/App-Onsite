use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Import a webplace to replace a current page

package App::Onsite::ImportCommand;

use base qw(App::Onsite::EveryCommand);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
                      nt => {DEFAULT => 'App::Onsite::Support::NestedTemplate'},
                    );

    my %base_params = $pkg->SUPER::parameters();
    %parameters = (%base_params, %parameters);

    return %parameters;
}

#----------------------------------------------------------------------
# Check edit data TODO rewrite

sub check {
    my ($self, $request) = @_;

    # Check if id exists
    my $id = $request->{id};
    return $self->set_response($id, 404) unless $self->{data}->check_id($id, 'r');

    # Check if this is a complete file
    return $self->set_response($id, 403) unless $self->check_primary($id);
    
    # Info needed to build form
    $request->{field_info} = $self->filename_info();

    # Validate request

    my $response = $self->check_authorization($request);
        
    $response = $self->check_fields($request)
        if $response->{code} == 200;
   
    $response = $self->check_nonce($id, $request->{nonce})
        if $response->{code} == 200;
 
    # Validate uploaded file
    
    $response = $self->validate_data($request)
        if $response->{code} == 200;

    $response = $self->{data}->validate_file($request)
        if $response->{code} == 200;

    return $response;
}

#----------------------------------------------------------------------
# Get field information for user file

sub filename_info {
    my ($self) = @_;

    my $item = {};
    $item->{NAME} = 'filename';
    $item->{title} = 'Choose file';
    $item->{style} = 'type=file';
    
    return [$item];
}

#----------------------------------------------------------------------
# Import a file 

sub run {
    my ($self, $request) = @_;

    $self->{data}->copy_file($request->{id}, $request);
	return $self->set_response($request->{id}, 302);
}

#----------------------------------------------------------------------
# Validate the imported file data

sub validate_data {
    my ($self, $request) = @_;

    my @missing;
    my $filename = $request->{'filename'};
    # TODO bypass validate_filename
    my $data = $self->{data}->read_primary($filename);
    my $info = $self->read_info($request->{id});

    foreach my $item (@$info) {
        my $name = $item->{NAME};
        push(@missing, $name) unless exists $data->{$name};
    }
    
    my $response;
    if (@missing) {
        my $msg = "Missing: " . join(',', @missing);   
        $response = $self->set_response($request->{id}, 400, $msg);

    } else {        
        $self->set_response($request->{id}, 200);
    }

    return $response;
}

1;