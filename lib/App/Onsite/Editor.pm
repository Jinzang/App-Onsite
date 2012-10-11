use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Simple website editor

package App::Onsite::Editor;

use App::Onsite::FieldValidator;
use base qw(App::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
                    base_url => '',
                    template_dir => '',
                    data_registry => '',
                    command_registry => '',
                    cmd => {},
                    data => {},
                    fm => {DEFAULT => 'App::Onsite::Form'},
                    wf => {DEFAULT => 'App::Onsite::Support::WebFile'},
					nt => {DEFAULT => 'App::Onsite::Support::NestedTemplate'},
					reg => {DEFAULT => 'App::Onsite::Support::RegistryFile'},
	);

    return %parameters;
}

#----------------------------------------------------------------------
# Add the temporary directory to list of valid directories to read from

sub add_valid_directory {
    my ($self, $request) = @_;

    if (exists $request->{filename}) {
        my ($directory, $basename) =
            $self->{wf}->split_filename($request->{filename});
        
        my @directories = @{$self->{configuration}{valid_read}};
        push(@directories, $directory);
        $self->{configuration}{valid_read} = \@directories;
    }

    return;
}

#----------------------------------------------------------------------
# Update a file as if it were edited with no changes

sub auto_update {
    my ($self, $id) = @_;
    
    my $type = $self->id_to_type($id);
    my $obj = $self->{reg}->create_subobject($self->{configuration},
                                             $self->{data_registry},
                                             $type);

    my $data = $obj->read_data($id);
    $obj->write_data($id, $data);
    
    return;
}

#----------------------------------------------------------------------
# Execute the application, return a message if it fails

sub batch {
    my ($self, $request) = @_;

    my $response = $self->execute($request);
    my $msg = $response->{msg};
    
    if ($response->{code} < 400) {
        undef $msg;

    } elsif (! $msg) {
        if ($self->{cmd}) {
            my $code = $response->{code};
            $response = $self->{cmd}->set_response($request->{id}, $code);
            $msg = $response->{msg};

        } else {
            $msg = "Invalid request\n";
        }
    }
    
    return $msg;
}

#----------------------------------------------------------------------
# Construct command links for form from request

sub build_commandlinks {
	my ($self, $request) = @_;

    my @commands;
    my $id = $request->{id};
    my $commands = $self->{data}->get_commands();
    
    foreach my $cmd (@$commands) {
        next if $cmd eq lc($request->{cmd});
        push(@commands, $cmd) if $self->{data}->check_command($id, $cmd);
    }

    my $links =  $self->{data}->command_links($id, \@commands);
    return {data => $links};
}

#----------------------------------------------------------------------
# Construct the data and command objects aprropriate for this command

sub construct_objects {
    my ($self, $request) = @_;
    $request->{id} = '' unless exists $request->{id};

    # Add temporary directory to list of valid directories
    
    $self->add_valid_directory($request);
    
    # Construct data object
    
    my $type = $self->id_to_type($request->{id});
    $self->{data} = $self->{reg}->create_subobject($self->{configuration},
                                                   $self->{data_registry},
                                                   $type);

    $self->{configuration}{data} = $self->{data};
    
    # Construct command object

    my $cmd = $self->pick_command($request);
    $request->{cmd} = $cmd;

    $self->{cmd} = $self->{reg}->create_subobject($self->{configuration},
                                                  $self->{command_registry},
                                                  $cmd);

    $self->{configuration}{cmd} = $self->{cmd};
    return;
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

    $results->{request} = $request;
    $results->{results} = $self->encode_hash($response->{results});

    $response->{code} = 200;
    $response->{results} = $results;
    $response->{url} = $self->{base_url};
     
    return $response;
}

#----------------------------------------------------------------------
# Check the request and execute the command if it passes

sub execute {
    my ($self, $request) = @_;
    my $response;

    eval {
        # Construct data object
        $self->construct_objects($request);

        # Check request
        $response = $self->{cmd}->check($request);
        
        # Run command if no problem
        if ($response->{code} == 200) {
            $response = $self->{cmd}->run($request);
        }
    };

    if ($@) {
        my $msg = $@;
        chomp($msg);

        # Check if $self->{cmd} is a blessed object
        # If not, define an error command to handle reporting

        unless (%{$self->{data}} && %{$self->{cmd}}) {
            delete $request->{id};
            delete $request->{cmd};
            $self->construct_objects($request);
        }

        $response = $self->{cmd}->set_response($request->{id}, 500, $msg);
    }

    return $response;
}

#----------------------------------------------------------------------
# Get the type of an existing file from its id

sub id_to_type {
	my ($self, $id) = @_;

    my $pkg;
    my $types = $self->{reg}->project($self->{data_registry}, 'extension');

    while (my ($type, $ext) = each %$types) {
        my ($filename, $extra) = $self->{wf}->id_to_filename_with_ext($id, $ext);

        if (-e $filename) {
            my $traits = $self->{reg}->read_data($self->{data_registry}, $type);
            ($pkg) = $traits->{class} =~ /^([A-Z][\w:]+Data)$/;
        }
    }
    
    die "Invalid id: $id\n" unless $pkg;
    eval "require $pkg" or die "$@\n";
	my $obj = $pkg->new(%$self);

	return $obj->id_to_type($id);
}

#----------------------------------------------------------------------
# Pick a command from a list and untaint at the same time

sub pick_command {
    my ($self, $request) = @_;

    my $cmd = $request->{cmd} || $self->{data}->get_default_command();
    my $commands = $self->{data}->get_commands();
    $cmd = lc($cmd);
    
    foreach my $command (@$commands) {
        $command = lc($command);
        if ($cmd eq $command &&
            $self->{data}->check_command($request->{id}, $cmd)) {
            return $command;
        }
    }
    
    return 'cancel';
}

#----------------------------------------------------------------------
# Set the field values in a new object

sub populate_object {
	my ($self, $configuration) = @_;
   
    $self = $self->SUPER::populate_object($configuration);
    $self->{configuration} = $configuration;
    
    return $self;
}

#----------------------------------------------------------------------
# Render page with templates stored in response

sub render {
    my ($self, $request, $response, $subtemplate) = @_;
    
    # Get and parse templates
    
    my $template = $self->top_page();
    $subtemplate = join('/', $self->{template_dir}, $subtemplate);
    
    # Assemble data to be rendered in template
    
    my $results = $response->{results} || {};
       
    my $data = {};
    $data->{primary} = $results;
    $data->{meta} = $results;
    $data->{meta}{base_url} = $self->{base_url};
    $data->{secondary} = '';
    $data->{pagelinks} = '';
    $data->{commandlinks} = $self->build_commandlinks($request);

    # Render data and return results

    return $self->{nt}->render($data, $template, $subtemplate);
}

#----------------------------------------------------------------------
# Execute the application build inout form if insufficient inputtest

sub run {
    my ($self, $request) = @_;

    my $response = $self->execute($request);

    if ($response->{code} == 400) {
        my $msg = $response->{msg} || '';
        $response = $self->{cmd}->set_response($request->{id}, 200);
        $response->{results} = $self->{fm}->create_form($request, $msg);
    }

    my $subtemplate;
    if ($response->{code} == 500 || $request->{debug}) {
        die $response->{msg} unless $self->{cmd};
        
        $response = $self->error($request, $response);
        $subtemplate = 'error.htm';

    } else {
        $subtemplate = $self->{cmd}->get_subtemplate();       
    }
   
    if ($response->{code} == 200) {
        $response->{results} = $self->render($request, $response, $subtemplate);
    }
    
    return $response;
}

#----------------------------------------------------------------------
# Return the filename of the top page

sub top_page {
	my ($self) = @_;
	
    my $types = $self->{reg}->project($self->{data_registry}, 'extension');

    foreach my $ext (values %$types) {
		my ($filename, $extra) = $self->{wf}->id_to_filename_with_ext('', $ext);
		return $filename if -e $filename;
	}
	
	die "No top page found\n";
}

1;

__END__
=head1 NAME

App::Onsite::Editor - Simple website creation and maintainance

=head1 SYNOPSIS

    use App::Onsite::Editor;
    my $ed =  App::Onsite::Editor->new();
    my $response = $ed->run({cmd => 'browse'});

=head1 DESCRIPTION

This is the top level class of App:: Onsite, though normally it is invoked
through App::Onsite::Support::CgiHandler. There are three public methods: new,
execute, and run. Batch and run take a hash reference as an argument. This hash
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

The url of the id invoked, used by redirects.

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
