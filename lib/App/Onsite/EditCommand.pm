use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Simple website editor

package App::Onsite::EditCommand;

use base qw(App::Onsite::EveryCommand);

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
    return $self->set_response($id, 404) unless $self->{data}->check_id($id, 'r');

    # Read data into request where it is missing

    $request->{field_info} = $self->{data}->field_info($id);

    $request = $self->clean_data($request);
    $request = $self->supplement_data($request);
    
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

#----------------------------------------------------------------------
# Supplement data from record in file

sub supplement_data {
    my ($self, $request) = @_;
    
    my $data = $self->{data}->read_data($request->{id});
    
    if ($self->any_data($request)) {
        foreach my $item (@{$request->{field_info}}) {
            next unless exists $item->{style};

            my $field = $item->{NAME};
            $request->{$field} = $data->{$field} if $item->{hidden};
        }
        
    } else {
        %$request = (%$request, %$data);
    }
    
    return $request;
}

1;
