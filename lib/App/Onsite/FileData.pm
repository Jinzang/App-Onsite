use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Create an object that stores a data record in a single file

package App::Onsite::FileData;

use base qw(App::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
                    base_url => '',
                    script_url => '',
                    data_registry => '',
                    summary_length => 300,
                    default_title => 'Editor',
                    lo => {DEFAULT => 'App::Onsite::Listops'},
                    wf => {DEFAULT => 'App::Onsite::Support::WebFile'},
                    reg => {DEFAULT => 'App::Onsite::Support::RegistryFile'},
	);

    return %parameters;
}

#----------------------------------------------------------------------
# Add a new file

sub add_data {
    my ($self, $parentid, $request) = @_;

    my $id;
    if ($self->can('write_primary')) {
        my $id_field = $self->get_trait('id_field');
        $id = $self->generate_id($parentid, $request->{$id_field});

    } elsif ($self->can('write_secondary')) {
        $id = $self->next_id($parentid);

    } else {
        die "Can't add $request->{subtype}\n";
    }

    $self->write_data($id, $request);
    return;
}

#----------------------------------------------------------------------
# Check user authorization to execute the command (stub)

sub authorize {
	my($self, $cmd, $request) = @_;
	return 1;
}

#----------------------------------------------------------------------
# Retrieve all records

sub browse_data {
    my ($self, $parentid, $limit) = @_;

    $limit = 1.0e9 unless $limit;
    die "Invalid search limit: $limit\n" if $limit <= 0;

    my @list;
    my $get_next = $self->get_browsable($parentid);

    while (defined(my $data = &$get_next)) {
        push(@list, $data);
        last unless -- $limit;
    }

    return \@list;
}

#----------------------------------------------------------------------
# Change the filename to match request (stub)

sub change_filename {
    my ($self, $id, $filename, $request) = @_;

    return $id;
}

#----------------------------------------------------------------------
# Check if command is legal

sub check_command {
    my ($self, $id, $cmd) = @_;

    if ($cmd eq 'add') {
        my $subtypes = $self->get_subtypes($id);
       return $self->can('write_secondary') && @$subtypes > 0;
        
    } elsif ($self->is_parent_command($cmd)) {
        return $self->has_one_subtype($id) ? 1 : undef;

    } elsif ($cmd eq 'edit' || $cmd eq 'remove') {
        my ($filename, $extra) = $self->id_to_filename($id);
        if ($extra) {
            return $self->can('write_secondary');
        } else {
            return $self->can('write_primary');
        }

    } elsif ($cmd eq 'import' || $cmd eq 'export') {
        my ($filename, $extra) = $self->id_to_filename($id);
        if ($extra) {
            return;
        } else {
            return $self->can('write_primary');
        }       
    }

    return 1;
}

#----------------------------------------------------------------------
# Check data for consistency (stub)

sub check_data {
    my ($self, $data) = @_;
    return; # no error
}

#----------------------------------------------------------------------
# Check for a valid id

sub check_id {
    my ($self, $id, $mode) = @_;
    $mode = 'r' unless defined $mode;

    my $test;
    my ($filename, $extra) = $self->id_to_filename($id);

    if ($extra) {
        if ($mode eq 'w') {
            my ($parentid, $seq) = $self->{wf}->split_id($id);
            $test = $self->can('write_secondary') &&
                    $self->check_id($parentid, 'r');
        } else {
            my $record = $self->read_data($id);
            $test = defined $record;
        }
 
    } else {
        if ($mode eq 'w') {
            $test = $self->can('write_primary') &&
                    $self->{wf}->under_any_dir($filename, 'w');
        } else {
            $test = -e $filename;
        }
    }
    
    return $test;
}

#----------------------------------------------------------------------
# Construct command links for page from page id

sub command_links {
	my ($self, $id, $commands) = @_;
    
    my @links;
    $commands ||= $self->{commands};

    foreach my $cmd (@$commands) {
        next unless $self->check_command($id, $cmd);
        
        my $query = {cmd => $cmd, id => $id};  

        if ($cmd eq 'add') {
            my $type =$self->has_one_subtype($id);
            if ($type) {
                $query->{type} = $type;
                $query->{subtype} = $type;
            }
            
        } elsif ($self->is_parent_command($cmd)) {
            my $type =$self->has_one_subtype($id);
            if ($type) {
                $query->{type} = $type;
            } else {
                $query->{type} = $self->get_type();                
            }

        } else {
            $query->{type} = $self->get_type();
        }
        
        my $link = $self->single_command_link($query);
        push (@links, $link);
    }
 
    return \@links;
}

#----------------------------------------------------------------------
# Create a title for a command

sub command_title {
    my ($self, $args) = @_;

    my @words;
    if ($args->{cmd}) {
        push(@words, ucfirst($args->{cmd}));

        if ($args->{type}) {
            my $type = $args->{type};

            my $object = $self;
            if ($type eq $self->get_type()) {
                $object = $self;

            } else {
                eval {
                $object =
                    $self->{reg}->create_subobject($self,
                                                   $self->{data_registry},
                                                   $type);
                };

                $object = $self if $@;
            }
 
            if ($self->is_parent_command($args->{cmd})) {
                if ($object->{plural}) {
                    $type = $object->{plural};
                } else {
                    $type = $object->{singular} if $object->{singular};
                    $type .= 's';
                }

            } else {
                if ($object->{singular}) {
                    $type = $object->{singular};
                }
            }
       
            push(@words, ucfirst($type));
        }

    } else {
        push(@words, ucfirst($self->{default_title}));
    }
    
    return join(' ', @words);
}

#----------------------------------------------------------------------
# Copy a new version of a file

sub copy_data {
    my ($self, $id, $request) = @_;
    
    my ($output_filename, $extra) = $self->id_to_filename($id);
    die "Con't copy into subobject" if $extra;
    
    $self->{wf}->copy_data($request->{filename}, $output_filename);
    return;
}

#----------------------------------------------------------------------
# Edit a file

sub edit_data {
    my ($self, $id, $request) = @_;

    $self->write_data($id, $request);
    return;
}

#----------------------------------------------------------------------
# Add extra data to the data read from file

sub extra_data {
    my ($self, $data) = @_;

    my $summary_field = $self->{summary_field};
    if (exists $data->{$summary_field} && ! exists $data->{summary}) {
    	$data->{summary} = $self->summarize($data->{$summary_field});
    }

    $data->{type} = $self->id_to_type($data->{id});
    return $data;
}

#----------------------------------------------------------------------
# Get field information by reading file

sub field_info {
    my ($self, $id) = @_;
    die "Can't get field info without id\n" unless defined $id;
    
	my @field_info;
    my $hash;

	my ($filename, $extra) = $self->id_to_filename($id);
    if ($extra) {
        my $records = $self->read_secondary($filename);
        $hash = $records->[0] if @$records; 
    } else {
        $hash = $self->read_primary($filename);
    }
    
    if ($hash) {
    	foreach my $field (sort keys %$hash) {
            next if $field eq 'id';
        	push(@field_info, {NAME => $field});
        }
    }
    
    return \@field_info;
}

#----------------------------------------------------------------------
# Convert filename to id

sub filename_to_id {
	my ($self, $filename) = @_;

    $filename =~ s/\.[^\.]*$//;
    return $self->{wf}->basename_to_id($filename);
}

#----------------------------------------------------------------------
# Convert title string to id

sub generate_id {
    my ($self, $parentid, $field) = @_;

    $field = lc($field);
    $field =~ s/[\W_]/ /g;
    $field =~ s/^\s+//;
    $field =~ s/\s+$//;
    $field =~ s/\s+/-/g;

    my $seq = substr($field, 0, $self->{id_length});
    return $self->{wf}->path_to_id($parentid, $seq);
}

#----------------------------------------------------------------------
# Return list of commands

sub get_commands {
    my ($self) = @_;
    
    my $commands = $self->{commands};;
    $commands = [$commands] unless ref $commands;
    
    return $commands;
}

#----------------------------------------------------------------------
# Return default command

sub get_default_command {
    my ($self) = @_;
    return $self->{default_command};
}

#----------------------------------------------------------------------
# Return a closure for browse_data

sub get_browsable {
    my ($self, $parentid) = @_;
    return $self->get_next($parentid);    
}

#----------------------------------------------------------------------
# Return a closure that returns each record in the file

sub get_next {
    my ($self, $parentid) = @_;

    my ($filename, $extra) = $self->id_to_filename($parentid);
    my $obj = $self->get_subobject($parentid) || $self;
    my $records = $self->read_secondary($filename);

    return sub {
        my $record = pop @$records;
        return unless $record;

        my $seq = $record->{id};       
        my $id = $self->{wf}->path_to_id($parentid, $seq);
        $record->{id} = $id;
        
        $record = $obj->extra_data($record);
        
        return $record;
    };
}

#----------------------------------------------------------------------
# Get the enclosing object that records are stored in

sub get_repository {
    my ($self, $id) = @_;

    my ($filename, $extra) = $self->id_to_filename($id);

    my $repository;
    if ($extra) {
        $repository = $filename;

    } else {
        my $basename;
        ($repository, $basename) = $self->{wf}->split_filename($filename);
    }

    die "Invalid id: $id\n" unless -e $repository;
    return $repository;
}

#----------------------------------------------------------------------
# Return a closure for search_data

sub get_searchable {
    my ($self, $parentid) = @_;
    return $self->get_next($parentid);    
}

#---------------------------------------------------------------------------
# Return type as subtype of parent

sub get_subobject {
    my ($self, $parentid) = @_;
    
    my $obj;
    if ($self->has_one_subtype($parentid)) {
        my $subtypes = $self->get_subtypes($parentid);
        
        $obj = $self->{reg}->create_subobject($self,
                                              $self->{data_registry},
                                              $subtypes->[0]);
    }

    return $obj;
}

#---------------------------------------------------------------------------
# Return type as subtype of parent

sub get_subtypes {
    my ($self, $parentid) = @_;

    my @subtypes;
    my ($filename, $extra) = $self->id_to_filename($parentid);
    
    if ($extra) {
        @subtypes = ();
    } else {
        @subtypes = $self->{reg}->search($self->{data_registry},
                                         super => $self->get_type());
    }
    
    return \@subtypes;
}

#----------------------------------------------------------------------
# Get the type of a file

sub get_type {
    my ($self) = @_;
    
    unless ($self->{type}) {
        my @pkg = split(/::/, ref $self);
        my ($type) = $pkg[-1] =~ /(\w+)Data/;
        $self->{type} = lc($type);
    }
    
    return $self->{type};
}

#----------------------------------------------------------------------
# Return true if there is only one subtype

sub has_one_subtype {
    my ($self, $id) = @_;

    my $subtype;
    my $subtypes = $self->get_subtypes($id);
    
    $subtype = $subtypes->[0] if @$subtypes == 1;
    return $subtype;
}

#----------------------------------------------------------------------
# Construct the filename

sub id_to_filename {
    my ($self, $id) = @_;

    my $ext = $self->{extension};
    return $self->{wf}->id_to_filename_with_ext($id, $ext);
}

#----------------------------------------------------------------------
# Get the type of a file given its id (stub)

sub id_to_type {
    my ($self, $id) = @_;

    return $self->get_type();
}

#----------------------------------------------------------------------
# Is the command a parent command?

sub is_parent_command {
    my ($self, $cmd) = @_;
    
    my $test;
    if ($self->{parent_commands}) {
        if (ref $self->{parent_commands}) {
            foreach my $parent_cmd (@{$self->{parent_commands}}) {
                if ($cmd eq $parent_cmd) {
                    $test = 1;
                    last;
                }
            }

        } else {
            $test = $cmd eq $self->{parent_commands};
        }
    }

    return $test;
}

#----------------------------------------------------------------------
# Return the next available id

sub next_id {
    my ($self, $parentid) = @_;

    my ($filename, $extra) = $self->id_to_filename($parentid);

    my $records = $self->read_secondary($filename);
    my $record = $self->{lo}->list_max($records);

	my $index_length = $self->{index_length};
    my $seq = $record ?  $record->{id} : '0' x $index_length;
    $seq ++;

    return $self->{wf}->path_to_id($parentid, $seq);
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

#---------------------------------------------------------------------------
# Read record from file

sub read_data {
    my ($self, $id) = @_;

    my ($filename, $extra) = $self->id_to_filename($id);
	die "Invalid id: $id\n" unless -e $filename;

    my $record;
    if ($extra) {
        my $records = $self->read_secondary($filename);
        $record = $self->{lo}->list_find($records, $extra);

    } else {
        $record = $self->read_primary($filename);
    }

    if ($record) {    
        $record->{id} = $id || '';
        $record = $self->extra_data($record);
    }

    return $record;
}

#----------------------------------------------------------------------
# Read data from file (stub)

sub read_primary {
    my ($self, $filename) = @_;

    my $id = $self->filename_to_id($filename);
    my $title = ucfirst($self->get_type) . ' Data';
    return {title => $title, summary => $title, id => $id};
}

#----------------------------------------------------------------------
# Read data from file (stub)

sub read_secondary {
    my ($self, $filename) = @_;

    return [];
}

#----------------------------------------------------------------------
# Get the url to redirect to

sub redirect_url {
    my ($self, $id) = @_;
    
    return $self->{base_url};
}

#----------------------------------------------------------------------
# Remove a file

sub remove_data {
    my ($self, $id, $request) = @_;

    my ($filename, $extra) = $self->id_to_filename($id);
	die "Invalid id: $id\n" unless -e $filename;

    if ($extra) {
        my ($parentid, $seq) = $self->{wf}->split_id($id);
        $request->{oldid} = $seq;
        delete $request->{id};
        
        $self->write_secondary($filename, $request);
        $request->{id} = $id;

    } elsif ($self->can('write_primary')) {
        $self->{wf}->remove_file($filename);

    } else {
        die "Delete not permitted: $filename\n";
    }
   
    return;
}

#----------------------------------------------------------------------
# Get files whose contents match the hash

sub search_data {
    my ($self, $query, $parentid, $limit) = @_;

    $limit = 1.0e9 unless defined $limit;
    die "Invalid search limit: $limit\n" if $limit <= 0;

    my $expanded_query = {};
    while (my ($field, $value) = each %$query) {
        my @values = map('\b' . $_ . '\b', split(' ', $value));
        $expanded_query->{$field} = \@values;
    }

    my @list;
    my $get_next = $self->get_searchable($parentid);

    while (defined(my $data = &$get_next)) {
        my $match;
        foreach my $field (keys %$expanded_query) {
            next unless exists $data->{$field};

            $match = 1;
            foreach my $term (@{$expanded_query->{$field}}) {
                if ($data->{$field} !~ /$term/i) {
                    $match = 0;
                    last;
                }
            }

            last if $match;
        }

        if ($match) {
            push(@list, $data);
            last unless -- $limit;
        }
    }

    return \@list;

}

#---------------------------------------------------------------------------
# Generate the link for a single query

sub single_command_link {
    my ($self, $query) = @_;

    my $parameters = '';
    foreach my $field (sort keys %$query) {
        next if $field eq 'subtype' && $query->{cmd} ne 'add';
        next if $field eq 'type';
        
        my $value = $query->{$field};
		next if ! defined $value || length($value) == 0;

        $value =~ s/([^-:., \w\/])/sprintf ('%%%02x', ord($1))/ge;
        $value =~ tr/ /+/;

        if ($parameters) {
            $parameters .= "&$field=$value";
        } else {
            $parameters = "$field=$value";
        }
    }

    $parameters = "?$parameters" if $parameters;

    my $link = {};
	$link->{url} = $self->{script_url} . $parameters;
	$link->{title}  = $self->command_title($query);
    
    return $link;
}

#----------------------------------------------------------------------
# Summarize the body of an article

sub summarize {
    my ($self, $text) = @_;

    $text =~ s/<!--.*?-->/ /gs;
    $text =~ s/<[^>]*>/ /gs;
    $text =~ s/&nbsp;/ /g;
    $text =~ tr/\t\r\n / /s;

    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;

    my $summary;
    if (length($text) <= $self->{summary_length})  {
        $text =~ s/^\s+//;
        $text =~ s/\s+$//;
        $summary = $text;

    } else {
        $summary = substr ($text, 0, $self->{summary_length});
        $summary =~ s/^\S*\s+//g;
        $summary =~ s/\s+\S*$//g;
        $summary =~ s/([^\?\!\.])$/$1 .../;
    }

    return $summary;
}

#----------------------------------------------------------------------
# Update links after add (no-op)

sub update_links {
    my ($self, $id, $request) = @_;
    
    return;
}

#----------------------------------------------------------------------
# Validate uploaded file (stub)

sub validate_file {
    my ($self, $request) = @_;
    
    return;
}

#----------------------------------------------------------------------
# Return boolean result indicating if this is a valid filename

sub valid_filename {
    my ($self, $filename) = @_;

    my ($ext) = $filename =~ /\.([^\.]*)$/;
    $ext ||= '';

    return $ext eq $self->{extension};
}

#---------------------------------------------------------------------------
# Write a record to a file

sub write_data {
    my ($self, $id, $request) = @_;

    my ($filename, $extra) = $self->id_to_filename($id);

    if ($extra) {
        my ($parentid, $seq) = $self->{wf}->split_id($id);
        $request = $self->extra_data($request);
        $request->{id} = $seq;
        
        $self->write_secondary($filename, $request);
        $request->{id} = $id;

    } elsif ($self->can('write_primary')) {
        $id = $self->change_filename($id, $filename, $request);

        if ($id ne $request->{id}) {
            ($filename, $extra) = $self->id_to_filename($id);
            $request->{oldid} = $request->{id};
            $request->{id} = $id;
        }

        $request = $self->extra_data($request);
        $self->write_primary($filename, $request);

    } else {
        die "Write not permitted: $filename\n";
    }
    
    return;
}

#---------------------------------------------------------------------------
# Module documentation

=head1 NAME

FileData is the base class for file storage in App::Onsite

=head1 DESCRIPTION

This class serves as the base class for all file storage. It has two interfaces:
an outward facing interface, which is invoked by ContentManager, and an inward
facing iterface, which is implemented by its subclasses, which perform the
various kinds of file storage. The inner interface is not implemented in this
class.

The outer interface is:

=over 4

=item add_data  $parentid, $request

Add a new record

=item authorize $request

Check user authorization to execute command

=item browse_data $parentid, $limit

Return all records to build browse form

=item check_data $data

Check data for consistency between fields

=item check_id $id, $mode

Check if this is a valid id. Mode is 'r' or 'w'.

=item edit_data $id, $request

Update file from values in response

=item filename_to_id $filename

Return id corresponding to filename

=item generate_id $parentid

Return id one greater than largest id

==item get_subtypes

Return list of types that can be added to this object

==item get_type

Return type of object

=item id_to_filename $id

Return filename corresponding to id.

=item redirect_url $request

Construct the url to redirect to after successful command

=item remove_data $id

Remove record with given id.

=item search_data $query, $parentid, $limit

Retrieve records matching query.

=back

The inner interface is:

=over 4

=item field_info

Get info for each data field

=item read_primary $filename

Read a single record from a file.

=item read_secondary $filename

Read a list of records from a file.

=item write_primary $filename $record

Write a single record to a file

=item write_secondary $filename, $records

Write a list of records to a file.

=back

=head1 AUTHOR

Bernie Simon, E<lt>bernie.simon@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bernie Simon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

1;
