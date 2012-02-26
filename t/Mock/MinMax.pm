use strict;
use warnings;

#----------------------------------------------------------------------
# Mock handler used for testing CgiHandler

package Mock::MinMax;

use base qw(CMS::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
                    base_url => '',
                    script_url => '',
                    data_dir => '',
                    template_dir => '',
                    die => 0,
                    min => 1,
                    max => 10,
	);

    return %parameters;
}

#----------------------------------------------------------------------
# Batch check and run

sub batch {
    my ($self, $request) = @_;

    my $msg;
    my $error = $self->check($request);

    my $response;
    if (defined $error) {
        $response = {code => 400, msg => $error, results => ''};
    } else {
        $response = {code => 200, msg => 'OK', results => 'Value in bounds'};
    }

    die "$error\n" if $self->{die};
    return $response;
}

#----------------------------------------------------------------------
# Check request

sub check {
    my ($self, $request) = @_;

    my $error;
    if (exists $request->{value}) {
        $error = "Value out of bounds"
            if $request->{value} < $self->{min} ||
               $request->{value} > $self->{max};
    } else {
        $error = "Value not set";
    }

    return $error;
}

#----------------------------------------------------------------------
# Generate error message

sub error {
    my ($self, $error) = @_;
    die "Error while handling error\n" if $self->{die} == 2;

    my $response = {code => 200, msg => 'OK', results => $error};
    return ;
}

#----------------------------------------------------------------------
# Run the handler

sub run {
    my ($self, $request) = @_;

    my $response;
    eval {
        $response = $self->batch($request);
        $response = $self->error($response->{msg}) if $request->{code} == 400;
    };
    
    if ($@) {
        $response = $self->error($@);
    }

    return $response;
}

1;
