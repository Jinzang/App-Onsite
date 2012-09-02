use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Simple website editor

package App::Onsite::RemoveCommand;

use base qw(App::Onsite::EveryCommand);

# $self->{data} must support check_id field_info read_data remove_data

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
# Check to see if file can be removed

sub check {
    my ($self, $request) = @_;

    # Check if id exists
    my $id = $request->{id};
    return $self->set_response($id, 404) unless $self->{data}->check_id($id, 'r');

    $request->{field_info} = $self->{data}->field_info($id);

    # Check for nonce

    my $response = $self->check_nonce($id, $request->{nonce});
    if ($response->{code} != 200) {
        my $data = $self->{data}->read_data($id);
        %$request = (%$request, %$data);
    }

    return $response;
}

#----------------------------------------------------------------------
# Remove a file

sub run {
    my ($self, $request) = @_;

    my $id = $request->{id};
    $self->{data}->remove_data($id, $request);
	return $self->set_response($id, 302);
}

1;
