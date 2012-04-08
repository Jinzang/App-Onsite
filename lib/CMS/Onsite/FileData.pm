use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Create an object that stores a data record in a single file

package CMS::Onsite::FileData;

use base qw(CMS::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
                    type => '',
                    data_dir => '',
                    script_url => '',
                    summary_length => 300,
                    lo => {DEFAULT => 'CMS::Onsite::Listops'},
                    wf => {DEFAULT => 'CMS::Onsite::Support::WebFile'},
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
    my $get_next = $self->get_next($parentid);

    while (defined(my $data = &$get_next)) {
        push(@list, $data);
        last unless -- $limit;
    }

    return $self->{lo}->list_sort(\@list);
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
        
    } elsif ($cmd eq 'browse' || $cmd eq 'search') {
        my $subtypes = $self->get_subtypes($id);
        return @$subtypes == 1;

    } elsif ($cmd eq 'edit' || $cmd eq 'remove') {
        my ($filename, $extra) = $self->id_to_filename($id);
        if ($extra) {
            return $self->can('write_secondary');
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
            my ($parentid, $seq) = $self->split_id($id);
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
    
    $commands ||= $self->get_trait('commands');
    
    my @links;
    my $type = $self->get_type();
    my $subtypes = $self->get_subtypes($id);
    my %parent_commands = map {$_ => 1} @{$self->get_trait('parent_commands')};

    foreach my $cmd (@$commands) {
        next unless $self->check_command($id, $cmd);
        
        my $query;
        if ($cmd eq 'add') {
            next if ! @$subtypes;
            $query = {cmd => $cmd, id => $id, type => $type};
            $query->{subtype} = $subtypes->[0] if @$subtypes == 1;
            
        } elsif ($parent_commands{$cmd}) {
            next if ! @$subtypes;
            $query = {cmd => $cmd, id => $id};
            $query->{type} = $subtypes->[0] if @$subtypes == 1;
 
        } else {
            $query = {cmd => $cmd, id => $id, type => $type};            
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

    my $title = ucfirst($args->{cmd});

    if ($args->{cmd} eq 'add') {
        $title .= ' ' . ucfirst($args->{subtype}) . ' Item' if $args->{subtype};

    } elsif (exists $args->{type}) {
        my $type = ucfirst ($args->{type});
    
        my %parentcmd = map {$_ => 1} @{$self->get_trait('parent_commands')};
        if ($parentcmd{$args->{cmd}} && $type !~ /s$/) {
            $type .= 's';
        }
    
        $title .= ' ' . $type;
    }
    
    return $title;
}

#----------------------------------------------------------------------
# Create a new data object of the specified type

sub create_subobject {
    my ($self, $type) = @_;

	my $subobject;
	if ($self->get_type() eq $type) {
		$subobject = $self;

	} else {
        # TODO: get the pkg from a type registry
		my $utype = ucfirst($type);
		my $pkg = "CMS::Onsite::${utype}Data";
        eval "require $pkg" or die "$@\n";

        my %parameters = (%$self, type => $type);        
		$subobject = $pkg->new(%parameters);
	}

    return $subobject;
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

    my $summary_field = $self->get_trait('summary_field');
    if (exists $data->{$summary_field} && ! exists $data->{summary}) {
    	$data->{summary} = $self->summarize($data->{$summary_field});
    }

    return $data;
}

#----------------------------------------------------------------------
# Get field information by reading file

sub field_info {
    my ($self, $id) = @_;

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
	$filename = $self->{wf}->abs2rel($filename, $self->{data_dir});

    my @path;
    if (length $filename) {
        @path = split(/\//, $filename);
        pop(@path) if $path[-1] eq $self->get_trait('index_name');
    }

    my $id;
    if (@path) {
        my $separator = $self->get_trait('separator');
        $id = join($separator, @path);
    } else {
        $id = '';
    }

	return $id;
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

    my $seq = substr($field, 0, $self->get_trait('id_length'));
    my $id = $parentid ? join($self->get_trait('separator'), $parentid, $seq) : $seq;
    
    return $id;
}

#----------------------------------------------------------------------
# Return list of commands, minus any passed in list

sub get_commands {
    my ($self) = @_;
       
    return $self->get_trait('commands');
}

#----------------------------------------------------------------------
# Return a closure that returns each record in the file

sub get_next {
    my ($self, $parentid) = @_;

    my ($filename, $extra) = $self->id_to_filename($parentid);

    my $separator = $self->get_trait('separator');
    my $records = $self->read_secondary($filename);

    return sub {
        my $record = pop @$records;
        return unless $record;

        my $seq = $record->{id};       
        my $id = $parentid ? join($separator, $parentid, $seq) : $seq;
        $record->{id} = $id;
        
        $record = $self->extra_data($record);
        
        return $record;
    };
}

#----------------------------------------------------------------------
# Get the enclosing object that records are stored in

sub get_repository {
    my ($self, $id) = @_;

    my $ext = $self->get_trait('extension');
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

#---------------------------------------------------------------------------
# Return type as subtype of parent

sub get_subtypes {
    my ($self, $parentid) = @_;

    my $subtypes;
    my $ext = $self->get_trait('extension');
    my ($filename, $extra) = $self->id_to_filename($parentid);

    if ($extra) {
        $subtypes = [];
    } else {
        $subtypes = $self->get_trait('subtypes');
    }

    return $subtypes;
}

#---------------------------------------------------------------------------
# Get the value of a trait

sub get_trait {
    my ($self, $name) = @_;

    my %trait = (
                 separator => ':',
                 index_name => 'index',
                 id_field => 'title',
                 sort_field => 'id',
                 summary_field => 'body',
                 id_length => 63,
                 index_length => 4,
                 has_subfolders => 0,
                 subtypes => [],
                 parent_commands => [qw(browse search)],
                 commands => [qw(browse add edit remove search)]
                );

    die "Unknown trait: $name\n" unless exists $trait{$name};
    return $trait{$name};
}

#----------------------------------------------------------------------
# Get the type of a file

sub get_type {
    my ($self) = @_;
    
    unless ($self->{type}) {
        my ($type) = $self =~ /CMS::Onsite::(\w+)Data/;
        $self->{type} = lc($type);
    }
    
    return $self->{type};
}

#----------------------------------------------------------------------
# Construct the filename

sub id_to_filename {
    my ($self, $id) = @_;

    my $ext = $self->get_trait('extension');
    return $self->id_to_filename_with_ext($id, $ext);
}

#----------------------------------------------------------------------
# Convert id to filename

sub id_to_filename_with_ext {
	my($self, $id, $ext) = @_;

	$id = '' unless defined $id;
	my $separator = $self->get_trait('separator');
	my @path = split(/$separator/, $id);

	# Numeric fields are the subfile id

	my @extra;
	while (@path) {
		my $seq = pop(@path);
		if ($seq =~ /^\d+$/) {
			unshift(@extra, $seq);
		} else {
			push(@path, $seq);
			last;
		}
	}

	# The non-numeric part gives the file basname

	my $basename = join('/', $self->{data_dir}, @path);
   
	my $filename;
    if (-d $basename) {
        my $index_name = $self->get_trait('index_name');
        $filename = "$basename/$index_name.$ext";
    } else {
        $filename = "$basename.$ext";
    }
    
	$filename = $self->{wf}->validate_filename($filename, 'w')
	    if defined $filename;
	    
	my $extra = join($separator, @extra);

	return ($filename, $extra);
}

#----------------------------------------------------------------------
# Get the type of a file given its id (stub)

sub id_to_type {
    my ($self, $id) = @_;

    return $self->get_type();
}

#----------------------------------------------------------------------
# Return the next available id

sub next_id {
    my ($self, $parentid) = @_;

    my ($filename, $extra) = $self->id_to_filename($parentid);

    my $records = $self->read_secondary($filename);
    my $record = $self->{lo}->list_max($records);

	my $index_length = $self->get_trait('index_length');
    my $seq = $record ?  $record->{id} : '0' x $index_length;
    $seq ++;

	my $separator = $self->get_trait('separator');
    my $id = $parentid ? join($separator, $parentid, $seq) : $seq;
    return $id;
}

#----------------------------------------------------------------------
# Set the field values in a new object

sub populate_object {
	my ($self, $configuration) = @_;

    unless (exists $configuration->{type}) {
        my $type;
        my $pkg = ref $self;
        ($type) = $pkg =~ /^CMS::Onsite::([\w-]+)Data$/;

        die "Cannot get type: $pkg\n" unless defined $type;
        $configuration->{type} = lc($type);
    }
    
    return $self->SUPER::populate_object($configuration);
}

#---------------------------------------------------------------------------
# Read record from file

sub read_data {
    my ($self, $id) = @_;

    my $ext = $self->get_trait('extension');
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

    my $title = ucfirst($self->get_type) . ' Data';
    return {title => $title, summary => $title};
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
    
    my ($filename, $extra) = $self->id_to_filename($id);
    my $cmd = $extra ? 'edit' : 'browse';

    my $args = {
		id => $id,
		cmd => $cmd,
		type => $self->get_type(),
	};

    my $link = $self->single_command_link($args);
    return $link->{url};
}

#----------------------------------------------------------------------
# Remove a file

sub remove_data {
    my ($self, $id, $request) = @_;

    my ($filename, $extra) = $self->id_to_filename($id);
	die "Invalid id: $id\n" unless -e $filename;

    if ($extra) {
        my $records = $self->read_secondary($filename);
        my $new_records = $self->{lo}->list_delete($records, $extra);
        $self->write_secondary($filename, $new_records);

    } elsif ($self->can('write_primary')) {
        $self->{wf}->remove_file($filename);
        $request->{oldid} = $request->{id};
        $self->update_data($id, $request);

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
    my $get_next = $self->get_next($parentid);

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

    return $self->{lo}->list_sort(\@list);

}

#---------------------------------------------------------------------------
# Generate the link for a single query

sub single_command_link {
    my ($self, $query) = @_;

    my $parameters = '';
    foreach my $field (sort keys %$query) {
        next if $field eq 'subtype' && $query->{cmd} ne 'add';
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

#---------------------------------------------------------------------------
# Split id string into parent and child

sub split_id {
    my ($self, $id) = @_;
    $id ||= '';

    my $separator = $self->get_trait('separator');
    my @ids = split(/$separator/, $id);
    my $seq = pop(@ids);
    my $parentid = join($separator, @ids);

    return ($parentid, $seq);
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
# Update navigation links after a file is changed (stub)

sub update_data {
    my ($self, $id, $record) = @_;

    return;
}

#----------------------------------------------------------------------
# Return boolean result indicating if this is a valid filename

sub valid_filename {
    my ($self, $filename) = @_;

    my ($ext) = $filename =~ /\.([^\.]*)$/;
    $ext ||= '';

    return $ext eq $self->get_trait('extension');
}

#---------------------------------------------------------------------------
# Write a record to a file

sub write_data {
    my ($self, $id, $request) = @_;

    my ($filename, $extra) = $self->id_to_filename($id);

    if ($extra) {
        my $records = $self->read_secondary($filename);
        
        $request->{id} = $extra;
        my $new_records = $self->{lo}->list_add($records, $request);
        $new_records = $self->{lo}->list_sort($new_records);

        $self->write_secondary($filename, $new_records);
        $request->{id} = $id;

    } elsif ($self->can('write_primary')) {
        $id = $self->change_filename($id, $filename, $request);

        if ($id ne $request->{id}) {
            ($filename, $extra) = $self->id_to_filename($id);
            $request->{oldid} = $request->{id};
            $request->{id} = $id;
        }

        $self->write_primary($filename, $request);
        $self->update_data($id, $request);

    } else {
        die "Write not permitted: $filename\n";
    }
    
    return;
}

#---------------------------------------------------------------------------
# Module documentation

=head1 NAME

FileData is the base class for file storage in CMS::Onsite

    $self->update_data($id, $request);
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
TODO: replaces next_id

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

=item update_data $id, $request

Update other files after change to recod

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
