use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Simple website editor

package App::Onsite::EveryCommand;

use base qw(App::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Configuration

use constant MISSING_TEXT => '[No *]';
use constant BEFORE_TITLE => 'Previous';
use constant AFTER_TITLE => 'Next';

use constant RESPONSE_PROTOCOL => 'text/html';

use constant RESPONSE_MSG => {
    200 => 'OK',
    302 => 'Found',
    400 => 'Invalid Request',
    401 => 'Unauthorized',
    404 => 'File Not Found',
    500 => 'Script Error',
};

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
                      items => 20,
                      maxstart => 200,
                      form_title => 'Onsite Editor',
                      command_registry => 'command.reg',
                      data => {},
                      fm => {DEFAULT => 'App::Onsite::Form'},                      
                      wf => {DEFAULT => 'App::Onsite::Support::WebFile'},
					  reg => {DEFAULT => 'App::Onsite::Support::RegistryFile'},
                   	);

    return %parameters;
}

#----------------------------------------------------------------------
# Return true if not all the data fields are missing or empty

sub any_data {
    my ($self, $request) = @_;

    foreach my $info (@{$request->{field_info}}) {
    	my $name = $info->{NAME};
        if (exists $request->{$name}) {
    	    return 1 if length($request->{$name});
        }
    }

    return;
}

#----------------------------------------------------------------------
# Check for valid id to viewm

sub check {
    my ($self, $request) = @_;

    # Check if id exists
    my $id = $request->{id};
    my $code = $self->{data}->check_id($id, 'r') ? 200 : 404;

    return $self->set_response($id, $code);
}

#----------------------------------------------------------------------
# Check user authorization to execute the command

sub check_authorization {
	my($self, $request) = @_;

    my $code = $self->{data}->authorize($request->{cmd}, $request) ? 200 : 401;
    my $response = $self->set_response($request->{id}, $code);

    return $response;
}

#----------------------------------------------------------------------
# Fill fields from request

sub check_fields {
    my ($self, $request) = @_;

    my @bad;
    foreach my $field (@{$request->{field_info}}) {
        next unless exists $field->{valid};

        my $valid = $field->{valid};
        my $validator = App::Onsite::FieldValidator->new(valid => $valid);

        my $name = $field->{NAME};
        my $value = $request->{$name} || '';
        push (@bad, $name) unless $validator->validate($value);
    }

    my $bad;
    $bad = "Invalid or missing fields: " . join(',', @bad) if @bad;

    my $response;
    if ($bad) {
        $response = $self->set_response($request->{id}, 400, $bad);
    } else {
        $response = $self->set_response($request->{id}, 200);
    }

    return $response;
}

#----------------------------------------------------------------------
# Check the value of the nonce, push it on the bad list if no match

sub check_nonce {
    my ($self, $id, $nonce) = @_;

    my $response;
    if (! defined $nonce) {
        $response = $self->set_response($id, 400, '');
    } elsif ($nonce ne $self->{wf}->get_nonce()) {
        my $msg = 'Bad form submission, try again';
        $response = $self->set_response($id, 400, $msg);
    } else {
        $response = $self->set_response($id, 200);
    }

    return $response;
}

#----------------------------------------------------------------------
# Put input in canonical form and delete empty fields

sub clean_data {
    my ($self, $request) = @_;

    foreach my $info (@{$request->{field_info}}) {
    	my $name = $info->{NAME};

        if (exists $request->{$name}) {
            my $validator = App::Onsite::FieldValidator->new(%$info);
            $request->{$name} = $validator->canonize($request->{$name});

            delete $request->{$name} unless length($request->{$name});
        }
    }

    return $request;
}

#---------------------------------------------------------------------------
# Create link for found objects

sub create_links {
    my($self, $results, $cmd) = @_;

    foreach my $result (@$results) {
        my $query = {id => $result->{id}};
        $query->{cmd} = $cmd if defined $cmd;

		$result->{itemlink} = $self->{data}->single_command_link($query);
    }

    return $results;
}

#----------------------------------------------------------------------
# Build the command title for a form

sub form_title {
	my ($self, $request) = @_;

    my $links = $self->{data}->command_links($request->{id}, [$request->{cmd}]);
    return @$links ? $links->[0]{title} : $self->{form_title};
}

#---------------------------------------------------------------------------
# Get the subtemplate for building the form

sub get_subtemplate {
    my ($self) = @_;
    return $self->{subtemplate};
}

#---------------------------------------------------------------------------
# Get the template for building the form

sub get_template {
    my ($self) = @_;
    return $self->{template};
}

#---------------------------------------------------------------------------
# Supply text for missing fields in hash

sub missing_text {
    my($self, $results) = @_;

    foreach my $hash (@$results) {
        foreach my $key (keys %$hash) {
           next if defined($hash->{$key}) && length($hash->{$key});
            next if $key eq 'id';
            
           $hash->{$key} = MISSING_TEXT;
           $hash->{$key} =~ s/\*/$key/;
       }
    }

    return $results;
}

#---------------------------------------------------------------------------
# Compute the number of items to return from a browse or search

sub page_limit {
    my ($self, $request) = @_;

    my $limit = $self->{items} + 1;
    $limit += $request->{start} if $request->{start};

    return $limit;
}

#---------------------------------------------------------------------------
# Restrict enties to a subset of results and construct navigation links

sub paginate {
    my ($self, $request, $list) = @_;

	my @paging_links;

    my $start = $request->{start} || 0;
    my $end = $start + $self->{items};
    $end =  @$list if $end >=  @$list;

    if ($start) {
        my $start = $start - $self->{items};
		$start = 0 if $start < 0;
        my $links = $self->{data}->command_links($request->{id},
                                                 [$request->{cmd}]);
		push(@paging_links, pagination_links(BEFORE_TITLE, $start, $links));
    }

    if ($end < @$list && $end <= $self->{maxstart}) {
        my $links = $self->{data}->command_links($request->{id},
                                                 [$request->{cmd}]);
		push(@paging_links, pagination_links(AFTER_TITLE, $end, $links));
    }

    my $results;
    if (@paging_links) {
        my @entries = @$list;
        @entries = @entries[$start .. $end-1];

        $results->{data} = \@entries;
		$results->{paginglinks} = {data => \@paging_links};

    } else {
        $results->{data} = $list;
    }

    return $results;
}

#----------------------------------------------------------------------
# Modify url and title for pagination links

sub pagination_links {
	my ($new_title, $start, $links) = @_;

	foreach my $link (@$links) {
        $link->{url} .= "&start=$start";
		$link->{title} = $new_title;
	}

	return @$links;
}

#----------------------------------------------------------------------
# Set the field values in a new object

sub populate_object {
	my ($self, $configuration) = @_;
   
    $self = $self->SUPER::populate_object($configuration);

    my $package = ref $self;
    my %traits = $self->{reg}->add_traits($package);

    while (my ($field, $value) = each %traits) {
        $self->{$field} = $value;
    }
    
    return $self;
}

#----------------------------------------------------------------------
# Stubbed out run command

sub run {
    my ($self, $request) = @_;

	return $self->set_response($request->{id}, 500, "Unimplemented command");
}

#----------------------------------------------------------------------
# Create the response structure

sub set_response {
    my ($self, $id, $code, $msg) = @_;
    
    my %response;
    $response{code} = $code;
    $response{protocol} = RESPONSE_PROTOCOL;
    $response{url} = $self->{data}->redirect_url($id);
    $response{msg} = defined $msg ? $msg : RESPONSE_MSG->{$code};
   
    return \%response;
}

1;
