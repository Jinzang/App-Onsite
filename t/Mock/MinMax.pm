use strict;
use warnings;

#----------------------------------------------------------------------
# Mock handler used for testing CgiHandler

package Mock::MinMax;

use base qw(App::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
                    base_url => '',
                    script_url => '',
                    data_dir => '',
                    template_dir => '',
                    min => 1,
                    max => 10,
	);

    return %parameters;
}

#----------------------------------------------------------------------
# Execute command

sub batch {
    my ($self, $request) = @_;

    my $error = $self->check($request);

    my $msg;
    if (defined $error) {
        $msg = "ERROR $error";

    } else {
        $msg = "Value in bounds: $request->{value}";
    }

    return $msg;
}

#----------------------------------------------------------------------
# Check request

sub check {
    my ($self, $request) = @_;

    my $error;
    if (exists $request->{value}) {
        $error = "Value out of bounds: $request->{value}"
            if $request->{value} < $self->{min} ||
               $request->{value} > $self->{max};
    } else {
        die "Value not set\n";
    }

    return $error;
}

#----------------------------------------------------------------------
# Run the handler

sub run {
    my ($self, $request) = @_;

    my $response;
    my $msg = $self->batch($request);

    if ($msg =~ /^ERROR/) {
        $response = {code => 400, msg => $msg,
                     protocol => 'text/html', results => ''};

    } else {
        $response = {code => 200, msg => 'OK', 
                     protocol => 'text/html', results => $msg};
    }

}

1;
