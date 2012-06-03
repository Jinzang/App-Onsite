use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Simple website editor

package CMS::Onsite::EditCommand;

use base qw(CMS::Onsite::EveryCommand);

# $self->{data} must support check_data check_id edit_data field_info read_data

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
# Check edit data

sub check {
    my ($self, $request) = @_;

    # Check if id exists
    my $id = $request->{id};
    return $self->set_response($id, 404) unless $self->{data}->check_id($id, 'w');

    # Check for data and read if no data in request

    $request->{field_info} = $self->{data}->field_info($id);
    $request = $self->clean_data($request);

    if (! $self->any_data($request)) {
        my $data = $self->{data}->read_data($id);
        %$request = (%$request, %$data);
    }

    # Validate data

    my $response;
    my $error = $self->{data}->check_data($request);
    if ($error) {
        $response = $self->set_response($request->{id}, 400, $error);

    } else {
        $response = $self->check_nonce($id, $request->{nonce});
        $response = $self->check_fields($request) if $response->{code} == 200;
    }
    
    return $response;
}

#----------------------------------------------------------------------
# Edit a file

sub run {
    my ($self, $request) = @_;

    $self->{data}->edit_data($request->{id}, $request);
	return $self->set_response($request->{id}, 302);
}

1;
