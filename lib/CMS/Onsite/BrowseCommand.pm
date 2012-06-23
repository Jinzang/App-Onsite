use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Simple website editor

package CMS::Onsite::BrowseCommand;

use base qw(CMS::Onsite::EveryCommand);

# $self->{data} must support browse_data single_command_link

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
                      base_url => '',
                     );

    my %base_params = $pkg->SUPER::parameters();
    %parameters = (%base_params, %parameters);

    return %parameters;
}

#----------------------------------------------------------------------
# Get data from all files

sub run {
    my ($self, $request) = @_;

    my $id = $request->{id};
    my $limit = $self->page_limit($request);

    my $results = $self->{data}->browse_data($id, $limit);    
    $results = $self->create_links($results, 'edit');
    $results = $self->missing_text($results);
    $results = $self->paginate($request, $results);
    $results->{title} = $self->form_title($request);
    $results->{base_url} = $self->{base_url};

    my $response = $self->set_response($id, 200);
    $response->{results} = $results;
    
    return $response;
}

1;
