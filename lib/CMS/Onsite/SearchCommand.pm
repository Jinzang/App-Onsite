use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Simple website editor

package CMS::Onsite::SearchCommand;

use base qw(CMS::Onsite::EveryCommand);

# $self->{data} must support field_info search_data

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
# Check for search query

sub check {
    my ($self, $request) = @_;

    $request->{field_info} = [{NAME => 'query', valid => '&'}];

    $request = $self->clean_data($request);
    my $response = $self->check_fields($request);
    $response->{msg} = '';

    return $response;
}

#----------------------------------------------------------------------
# Search data

sub run {
    my ($self, $request) = @_;

    my $query = {};
    my $q = $request->{query};
    my $id = $request->{id};

    my $field_info = $self->{data}->field_info($id);
    foreach my $info (@$field_info) {
        my $name = $info->{NAME};
        $query->{$name} = $q;
    }

    my $limit = $self->page_limit($request);
    my $results = $self->{data}->search_data($query, $id, $limit);
    $results = $self->missing_text($results);
    $results = $self->paginate($request, $results);
    $results->{title} = $self->form_title($request);
    $results->{base_url} = $self->{base_url};

    my $response = $self->set_response($id, 200);
    $response->{results} = $results;
    
    return $response;
}

1;
