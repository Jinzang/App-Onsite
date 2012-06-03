use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Simple website editor

package CMS::Onsite::AddCommand;

use base qw(CMS::Onsite::EveryCommand);

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
        delete $request->{subtype};
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


    my $subtypes = $self->{data}->get_subtypes($request->{id});
    if (! exists $request->{subtype} && @$subtypes == 1) {
        $request->{subtype} = $subtypes->[0];
    }

    my $msg = '';
    my $code = 400;
    if (exists $request->{subtype}) {
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

    $subobject->add_data($request->{id}, $request);

    return $self->set_response($request->{id}, 302);
}

1;
