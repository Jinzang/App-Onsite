use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Simple website editor

package App::Onsite::CancelCommand;

use base qw(App::Onsite::EveryCommand);

# $self->{data} must support check_id

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
# Check request to see if we can perform it

sub check {
    my ($self, $request) = @_;

    return $self->set_response($request->{id}, 200);
}

#----------------------------------------------------------------------
# View a record

sub run {
    my ($self, $request) = @_;

    my $id = $request->{id};
    $id = $self->{data}->check_id($id, 'r') ? $id : '';

    return $self->set_response($id, 302);
}

1;
