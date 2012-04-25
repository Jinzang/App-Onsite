use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Simple website editor

package CMS::Onsite::Editor;

use Digest::MD5 qw(md5_hex);
use CMS::Onsite::FieldValidator;

use base qw(CMS::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Configuration

use constant DEFAULT_TITLE => 'Onsite Editor';
use constant MISSING_TEXT => '[No *]';
use constant BEFORE_TITLE => 'Previous';
use constant AFTER_TITLE => 'Next';

use constant RESPONSE_PROTOCOL => 'text/html';
use constant SUBTEMPLATE => 'show_form.htm';

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
                    base_url => '',
                    script_url => '',
                    template_dir => '',
                    nonce => 0,
                    items => 20,
                    maxstart => 200,
                    data => {DEFAULT => 'CMS::Onsite::DirData'},
					nt => {DEFAULT => 'CMS::Onsite::Support::NestedTemplate'},
	);

    return %parameters;
}

#----------------------------------------------------------------------
# Add a file

sub add {
    my ($self, $request) = @_;

    my $parentid = $request->{id};
    my $subobject = $self->{data}->create_subobject($request->{subtype});
    $subobject->add_data($parentid, $request);

	return $self->set_response($request->{id}, 302);
}

#----------------------------------------------------------------------
# Check add request for validity

sub add_check {
    my ($self, $request) = @_;

    # Check type of child object to be added
    if (! exists $request->{subtype}) {
        my $subtypes = $self->{data}->get_subtypes($request->{id});
    
        if (@$subtypes == 0) {
            $request->{subtype} = '';
        } elsif (@$subtypes == 1) {
            $request->{subtype} = $subtypes->[0];
        }
    }

    my $response = $self->check_type($request->{id}, $request->{subtype});

    if ($response->{code} == 400) {
        delete $request->{subtype};

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
    my $child = $self->{data}->create_subobject($request->{subtype});
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
# Return true if all data fields are missing or empty

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
# Check the request and run the command if it passes

sub batch {
    my ($self, $request) = @_;
    my $response;

    eval {
        # Overwrite proxy data object with real object
        $request->{id} = '' unless exists $request->{id};
        $request->{type} ||= $self->{data}->id_to_type($request->{id});
        $self->{data} = $self->{data}->create_subobject($request->{type});
    
        # Set command if not found or not valid
        my $cmd = $self->pick_command($request);
        $request->{cmd} = $cmd;
    
        # Check request
        $response = $self->check($request);
        
        # Run command if no problem
        if ($response->{code} == 200) {
            $response = $self->$cmd($request);
        }
    };

    $response = $self->set_response($request->{id}, 500, $@) if $@;  
    return $response;
}

#----------------------------------------------------------------------
# Get data from all files

sub browse {
    my ($self, $request) = @_;

    my $id = $request->{id};
    my $limit = $self->page_limit($request);

    my $results = $self->{data}->browse_data($id, $limit);    
    $results = $self->browse_links($results);
    $results = $self->missing_text($results);
    $results = $self->paginate($request, $results);

    my $response = $self->set_response($id, 200);
    $response->{results} = $results;
    
    return $response;
}

#---------------------------------------------------------------------------
# Create edit link for browsed objects

sub browse_links {
    my($self, $results) = @_;

    my $cmd = 'edit';
    foreach my $result (@$results) {
        my $query = {cmd => $cmd, id => $result->{id}};
		$result->{browselink} = $self->{data}->single_command_link($query);
    }

    return $results;
}

#----------------------------------------------------------------------
# Construct command links for form from request

sub build_commandlinks {
	my ($self, $request) = @_;

    my @commands;
    my $id = $request->{id};
    my $commands = $self->{data}->get_commands();
    
    foreach my $cmd (@$commands) {
        next if $cmd eq $request->{cmd};
        push(@commands, $cmd) if $self->{data}->check_command($id, $cmd);
    }

    my $links =  $self->{data}->command_links($id, \@commands);
    return {data => $links};
}

#----------------------------------------------------------------------
# Build an empty data set for thr secondary block

sub build_secondary {
	my ($self, $request) = @_;
    return '';
}

#----------------------------------------------------------------------
# Redirect to previous page

sub cancel {
    my ($self, $request) = @_;
    return $self->view($request);
}

#----------------------------------------------------------------------
# Check request to see if we can perform it

sub check {
    my ($self, $request) = @_;

    my $cmd = $request->{cmd};
    my $check = "${cmd}_check";
    my $response = $self->check_authorization($request);
    return $response unless $response->{code} == 200;

    if ($self->can($check)) {
        $response = $self->$check($request);
    } else {
        $response = $self->set_response($request->{id}, 200);
    }

    return $response;
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
        my $validator = CMS::Onsite::FieldValidator->new(valid => $valid);

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
    } elsif ($nonce ne $self->get_nonce()) {
        my $msg = 'Bad form submission, try again';
        $response = $self->set_response($id, 400, $msg);
    } else {
        $response = $self->set_response($id, 200);
    }

    return $response;
}

#----------------------------------------------------------------------
# Check for a valid type

sub check_type {
    my ($self, $parentid, $type) = @_;

    $type ||= '';
    my $msg = '';
    my $code = 400;
    my $subtypes = $self->{data}->get_subtypes($parentid);
    foreach my $subtype (@$subtypes) {
        if ($type eq $subtype) {
            $code = 200;
            $msg = 'OK';
            last;
        }
    }

    return $self->set_response($parentid, $code, $msg);
}

#----------------------------------------------------------------------
# Put input in canonical form and delete empty fields

sub clean_data {
    my ($self, $request) = @_;

    foreach my $info (@{$request->{field_info}}) {
	my $name = $info->{NAME};

        if (exists $request->{$name}) {
            my $validator = CMS::Onsite::FieldValidator->new(%$info);
            $request->{$name} = $validator->canonize($request->{$name});

            delete $request->{$name} unless length($request->{$name});
        }
    }

    return $request;
}

#----------------------------------------------------------------------
# Edit a file

sub edit {
    my ($self, $request) = @_;

    $self->{data}->edit_data($request->{id}, $request);
	return $self->set_response($request->{id}, 302);
}

#----------------------------------------------------------------------
# Check edit data

sub edit_check {
    my ($self, $request) = @_;

    # Check if id exists
    my $id = $request->{id};
    return $self->set_response($id, 404) unless $self->{data}->check_id($id, 'w');

    # Check for data and read if no data in request

    $request->{field_info} = $self->{data}->field_info($id);
    $request = $self->clean_data($request);

    if (! $self->any_data($request)) {
        my $data = $self->{data}->read_data($id);
        %$request = (%$request, %$data);
    }

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
# Create a new hash with html elements encoded

sub encode_hash {
    my ($self, $value) = @_;
    return unless defined $value;

    my $new_value;
	if (ref $value eq 'HASH') {
        $new_value = {};
        while (my ($name, $subvalue) = each %$value) {
            $new_value->{$name} = $self->encode_hash($subvalue);
        }

	} elsif (ref $value eq 'ARRAY') {
	    $new_value = [];
	    foreach my $subvalue (@$value) {
            push(@$new_value, $self->encode_hash($subvalue));
	    }

	} else {
        $new_value = $value;
	    $new_value =~ s/&/&amp;/g;
	    $new_value =~ s/</&lt;/g;
	    $new_value =~ s/>/&gt;/g;
    }

    return $new_value;
}

#----------------------------------------------------------------------
# Report error back to user

sub error {
    my ($self, $request, $response) = @_;

    my $results = {};
    $results->{title} = 'Script Error';
    $results->{error} = $response->{msg};

    $results->{env} = \%ENV;
    $results->{request} = $request;
    $results->{results} = $self->encode_hash($response->{results});

    $response = $self->set_response($request->{id}, 200);
    $response->{results} = $results;
     
    return $response;
}

#---------------------------------------------------------------------------
# Build the hidden fields on the form

sub form_buttons {
    my ($self, $request) = @_;

    my @fields;
    for my $button (('cancel', $request->{cmd})) {
        my $field = $self->form_field('cmd', ucfirst($button), 'submit');
        push(@fields, {field => $field});
    }

   return \@fields;
}

#----------------------------------------------------------------------
# Create form to send request

sub form_command {
    my ($self, $request) = @_;

    my %command;
    my $field_info = $request->{field_info};

    $command{url} = $request->{script_url};
    $command{encoding} = 'application/x-www-form-urlencoded';

    foreach my $info (@{$field_info}) {
        my $validator = CMS::Onsite::FieldValidator->new(%$info);
        $command{encoding} = 'multipart/form-data'
            if $validator->field_type($info->{style}) eq 'file';
    }

    return \%command;
}

#---------------------------------------------------------------------------
# Build a form field

sub form_field {
    my ($self, $name, $value, $info) = @_;

    my ($style, $valid);
    if (ref $info) {
        $style = exists $info->{style} ? $info->{style} : '';
        $valid = exists $info->{valid} ? $info->{valid} : '';
    } else {
        $valid = '';
        $style = "type=$info";
    }

    my $validator = CMS::Onsite::FieldValidator->new(valid => $valid);
    return $validator->build_field($name, $value, $style);
}

#---------------------------------------------------------------------------
# Build the hidden fields on the form

sub form_hidden_fields {
    my ($self, $request) = @_;

    my @fields;
    my $field_info = $request->{field_info};
    my @hidden_fields = ('type', 'subtype', 'id');

 
    foreach my $info (@$field_info) {
        my $validator = CMS::Onsite::FieldValidator->new(%$info);

        push(@hidden_fields, $info->{NAME})
            if $validator->field_type($info->{style}) eq 'hidden';
    }

    foreach my $name (@hidden_fields) {
        next unless exists $request->{$name};
        my $value = $request->{$name};

        my $field = $self->form_field($name, $value, 'hidden');
        push(@fields, {field => $field});
    }

    my $field = $self->form_field('nonce', $self->get_nonce(), 'hidden');
    push(@fields, {field => $field});

    return \@fields;
}

#----------------------------------------------------------------------
# Build the command title for a form

sub form_title {
	my ($self, $request) = @_;

    my $links = $self->{data}->command_links($request->{id}, [$request->{cmd}]);
    return @$links ? $links->[0]{title} : DEFAULT_TITLE;
}

#---------------------------------------------------------------------------
# Build the visible fields on the form

sub form_visible_fields {
    my ($self, $request) = @_;

    my @fields;
    my $field_info = $request->{field_info};

    foreach my $info (@$field_info) {
        my $validator = CMS::Onsite::FieldValidator->new(%$info);
        next if $validator->field_type($info->{style}) eq 'hidden';

    	my %field;
    	my $name = $info->{NAME};
        my $value = exists $request->{$name} ? $request->{$name} : '';

        $field{title} = $info->{title} || ucfirst($name);
        $field{class} = $validator->{required} ? 'required' : 'optional';
        $field{field} = $self->form_field($name, $value, $info);
        push(@fields, \%field);
    }

    return \@fields;
}

#----------------------------------------------------------------------
# Create the nonce for validated form input

sub get_nonce {
    my ($self) = @_;
    return $self->{nonce} if $self->{nonce};

    my $nonce = time() / 24000;
    return md5_hex($(, $nonce, $>);
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
# Pick a command from a list and untaint at the same time

sub pick_command {
    my ($self, $request) = @_;

    my @candidates = qw (browse edit view);
    unshift(@candidates, lc($request->{cmd})) if exists $request->{cmd};

    my @commands = (@{$self->{data}->get_commands()}, 'cancel');
    
    foreach my $candidate (@candidates) {
        my $cmd;
        foreach my $command (@commands) {
            if ($candidate eq $command) {
                $cmd = $command;
                last;
            }
        }
        
        return $cmd if $cmd &&
            $self->{data}->check_command($request->{id}, $cmd);        
    }
    
    return 'cancel';
}

#----------------------------------------------------------------------
# Check request to see if we can perform it

sub query {
    my ($self, $request, $response) = @_;

    my $results = {};
    $results->{error} = $response->{msg};
    $results->{title} = $self->form_title($request);

    my $form = $self->form_command($request);
    $form->{hidden} = $self->form_hidden_fields($request);
    $form->{visible} = $self->form_visible_fields($request);
    $form->{buttons} = $self->form_buttons($request);
    $results->{form} = $form;
   
    $response = $self->set_response($request->{id}, 200);
    $response->{results} = $results;
    
    return $response;
}

#----------------------------------------------------------------------
# Remove a file

sub remove {
    my ($self, $request) = @_;

    $self->{data}->remove_data($request->{id}, $request);
    my ($parentid, $seq) = $self->{data}->split_id($request->{id});

	return $self->set_response($parentid, 302);
}

#----------------------------------------------------------------------
# Check to see if file can be removed

sub remove_check {
    my ($self, $request) = @_;

    # Check if id exists
    my $id = $request->{id};
    return $self->set_response($id, 404) unless $self->{data}->check_id($id, 'w');

    $request->{field_info} = $self->{data}->field_info($id);

    # Check for nonce

    my $response = $self->check_nonce($id, $request->{nonce});
    if ($response->{code} != 200) {
        my $data = $self->{data}->read_data($id);
        %$request = (%$request, %$data);
    }

    return $response;
}

#----------------------------------------------------------------------
# Render page with templates stored in response

sub render {
    my ($self, $request, $response, $template, $subsubtemplate) = @_;
    
    $subsubtemplate = "$self->{template_dir}/$subsubtemplate";
    my $subtemplate = join('/', $self->{template_dir}, SUBTEMPLATE);
    
    $template = $self->{nt}->parse($template, $subtemplate);
    $subtemplate = $self->{nt}->parse($subtemplate, $subsubtemplate);

    my $results = $response->{results};
    %$results = (%$request, %$results);
    $results->{base_url} = $self->{base_url};
    
    $results = $self->{nt}->distribute_data($self, $results, $subtemplate);
    
    return $self->{nt}->render($results, $template, $subtemplate);
}

#----------------------------------------------------------------------
# Run the application after request passes test

sub run {
    my ($self, $request) = @_;

    my ($template, $extra) = $self->{data}->id_to_filename('');
    my $response = $self->batch($request);

    $response = $self->query($request, $response)
        if $response->{code} == 400;

    my $subtemplate;
    if ($response->{code} == 500 || $request->{debug}) {
        $response = $self->error($request, $response);
        $subtemplate = 'error.htm';
    }
   
    if ($response->{code} == 200) {
        $subtemplate ||= "$request->{cmd}.htm";
        $response->{results} = $self->render($request, $response,
                                             $template, $subtemplate);
    }
    
    return $response;
}

#----------------------------------------------------------------------
# Search data

sub search {
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

    my $response = $self->set_response($id, 200);
    $response->{results} = $results;
    
    return $response;
}

#----------------------------------------------------------------------
# Check for search query

sub search_check {
    my ($self, $request) = @_;

    $request->{field_info} = [{NAME => 'query', valid => '&'}];

    $request = $self->clean_data($request);
    my $response = $self->check_fields($request);
    $response->{msg} = '';

    return $response;
}

#----------------------------------------------------------------------
# Create the response structure

sub set_response {
    my ($self, $id, $code, $msg) = @_;
    
    my %response;
    $response{code} = $code;
    $response{msg} = defined $msg ? $msg : RESPONSE_MSG->{$code};
    $response{url} = $self->{data}->redirect_url($id);
    $response{protocol} = RESPONSE_PROTOCOL;
    
    return \%response;
}

#----------------------------------------------------------------------
# View a record

sub view {
    my ($self, $request) = @_;

    my $response = $self->set_response($request->{id}, 302);
    return $response;
}

#----------------------------------------------------------------------
# Check for valid id to view

sub view_check {
    my ($self, $request) = @_;

    # Check if id exists
    my $id = $request->{id};
    my $code = $self->{data}->check_id($id, 'r') ? 200 : 404;

    return $self->set_response($id, $code);
}

1;

__END__
=head1 NAME

CMS::Onsite::Editor - Simple website creation and maintainance

=head1 SYNOPSIS

    use CMS::Onsite::Editor;
    my $ed =  CMS::Onsite::Editor->new();
    my $response = $ed->run({cmd => 'browse'});

=head1 DESCRIPTION

This is the top level class of CMS:: Onsite, though normally it is invoked
through CMS::Onsite::Support::CgiHandler. There are three public methods: new,
batch, and run. Batch and run take a hash reference as an argument. This hash
contains the parameters passed by an http request. Batch and run return a hash
with several fields corresponding to an http response

=over 4

=item code

A numeric code, corresponding to the http response code.

=item msg

A string, which may contain an error message.

=item results

The results, if any, of the call. Batch returns a hash, run a web page.

=item url

The url of the file invoked, used by redirects.

=back

Data sources must support the following methods

    data->add->data($parentid, $response);
    Create a new object using values in hash

    $loh = $data->browse_data($parentid, $limit);
    Return data from all objects under parent as a list of hashes

    $error = $data->check_data($request);
    Check if data fields are consistent with each other

    $flag = $data->check_id($id, $mode);
    Return a flag indicating if id is valid. Modes are r and w

    $data->edit_data($id, $response);
    Update an existing object from a hash

    $loh = $data->field_info($id);
    Return a list of hashes describing fields in object

    $str = $data->get_type();
    Get the type of an object

    $list= $data->get_subtypes($parentid);
    Get the list of valid subtypes to add to a parent

    $hash = $data->read_data($id);
    Read data from an object

    $data->redirect_url($id);
    Redirect after a successful command

    $data->remove_data($id);
    Remove an object

    $loh = $data->search_data($query, $parentid, $limit);
    Return data from all objects that match query

Templates must support the following method

    $text = $tf->render($response, $template, $subtemplate);
    Render a data structure using the template and optional subtemplate

=head1 AUTHOR

Bernie Simon, E<lt>bernie.simon@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bernie Simon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
