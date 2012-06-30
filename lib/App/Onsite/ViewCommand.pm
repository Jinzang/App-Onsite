use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Simple website editor

package App::Onsite::ViewCommand;

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
# View a record

sub run {
    my ($self, $request) = @_;

    my $response = $self->set_response($request->{id}, 302);
    return $response;
}

1;
