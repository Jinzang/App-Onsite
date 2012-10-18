use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Export a file back to the user

package App::Onsite::ExportCommand;

use base qw(App::Onsite::EveryCommand);
use constant EXPORT_PROTOCOL => 'application/octet-stream';

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
# Check to see if file can be exported

sub check {
    my ($self, $request) = @_;

    # Check if id exists
    my $id = $request->{id};
    return $self->set_response($id, 404)
        unless $self->{data}->check_id($id, 'r');

    # Check that the id points to an entire file
    
    return $self->set_response($id, 403) unless $self->check_primary($id);

    # Check authorization
    
    my $response = $self->check_authorization($request);
    return $response if $response->{code} != 200;
    
    # Check for nonce

    $response = $self->check_nonce($id, $request->{nonce});

    if ($response->{code} != 200) {
        my $data = $self->{data}->read_data($id);
        %$request = (%$request, %$data);
    }

    return $response;
}

#----------------------------------------------------------------------
# Export a file

sub run {
    my ($self, $request) = @_;

	my $response = $self->set_response($request->{id}, 200);
    
    my ($filename, $extra) = $self->{data}->id_to_filename($request->{id});
    my @path = split(/\//, $filename);
    $filename = pop(@path);

    $response->{protocol} = EXPORT_PROTOCOL;
    $response->{Content_Disposition} = "attachment; filename=$filename";

    return $response;
}

1;
