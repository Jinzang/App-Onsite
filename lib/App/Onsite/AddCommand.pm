use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Simple website editor

package App::Onsite::AddCommand;

use base qw(App::Onsite::EveryCommand);

# $self=>{data} must support add_data get_subtypes

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
                      data_registry => '',
                     );

    my %base_params = $pkg->SUPER::parameters();
    %parameters = (%base_params, %parameters);

    return %parameters;
}

#----------------------------------------------------------------------
# Check add request for validity

sub check {
    my ($self, $request) = @_;

    my $response = $self->check_subtype($request);

    if ($response->{code} == 400) {
        my $subtypes = $self->{data}->get_subtypes($request->{id});
        my $valid = '&|' . join('|', @$subtypes) . '|';
        
        $request->{field_info} = [{NAME => 'subtype',
                                   valid => $valid,
                                   style => 'type=radio',
                                   title => 'Choose type to add',
                                  }];

        return $response;
    }

    # Create child object to get its field information
    my $child = $self->{reg}->create_subobject($self->{data},
                                               $self->{data_registry},
                                               $request->{subtype});

    $request->{field_info} = $child->field_info();

    # Clean the request data
    $request = $self->clean_data($request);

    # Validate the data fields
    if ($self->any_data($request)) {
        my $error = $child->check_data($request);
        if ($error) {
            $response = $self->set_response($request->{id}, 400, $error);

        } else {
            $response = $self->check_nonce($request->{id}, $request->{nonce});
            $response = $self->check_fields($request)
                if $response->{code} == 200;
        }

    } else {
        $response = $self->set_response($request->{id}, 400, '');
    }

    return $response;
}

#----------------------------------------------------------------------
# Check type of child object to be added

sub check_subtype {
    my ($self, $request) = @_;

    if (! exists $request->{subtype}) {
        my $subtype = $self->{data}->has_one_subtype($request->{id});
        $request->{subtype} = $subtype if defined $subtype;
    }

    my $msg = '';
    my $code = 400;
    if (exists $request->{subtype}) {
        my $subtypes = $self->{data}->get_subtypes($request->{id});

        foreach my $subtype (@$subtypes) {
            if ($request->{subtype} eq $subtype) {
                $code = 200;
                $msg = 'OK';
                last;
            }
        }
    }

    return $self->set_response($request->{id}, $code, $msg);
}

#----------------------------------------------------------------------
# Add a file

sub run {
    my ($self, $request) = @_;

    my $subobject = $self->{reg}->create_subobject($self->{data},
                                                   $self->{data_registry},
                                                   $request->{subtype});

    my $id = $request->{id};
    $subobject->add_data($id, $request);

    my $data = $self->{data}->read_data($id);
    $self->{data}->write_data($id, $data);

    return $self->set_response($id, 302);
}

1;
