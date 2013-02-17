use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Maintain directory hierarchy through operations on data

package App::Onsite::DirData;

use base qw(App::Onsite::PageData);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
        sort_field => 'ext',
	);

    my %base_params = $pkg->SUPER::parameters();
    %parameters = (%base_params, %parameters);

    return %parameters;
}

#----------------------------------------------------------------------
# Add a new file

sub add_data {
    my ($self, $parentid, $request) = @_;
    
    my $id_field = $self->{id_field};
    my $id = $self->generate_id($parentid, $request->{$id_field});
    $request->{id} = $id;

    my @dirs = $self->{wf}->id_to_path($id);
    $self->{wf}->create_dirs(@dirs);

    $self->write_data($id, $request);
    return;
}

#----------------------------------------------------------------------
# Retrieve all records

sub browse_data {
    my ($self, $parentid, $limit) = @_;

    $limit = 1.0e9 unless $limit;
    die "Invalid search limit: $limit\n" if $limit <= 0;

    my @list;
    my $subfolders = 0;

    my $get_next = $self->get_browsable($parentid);

    while (defined(my $data = &$get_next)) {
        push(@list, $data);
        last unless -- $limit;
    }

    return $self->{lo}->list_sort(\@list);
}

#----------------------------------------------------------------------
# Rebuild data in dirlinks block

sub build_all_dirlinks {
    my ($self, $filename) = @_;

    # Need to completely rebuild the directory links, all urls are changed
    
    my @dirlinks;
    my $maxlevel = 1;
    my ($repository, $basename) = $self->{wf}->split_filename($filename);
    my $visitor = $self->{wf}->visitor($repository, $maxlevel, 'id');

    while (my $file = &$visitor()) {
        next unless $self->{wf}->is_directory($file);
        next if $filename eq $self->{wf}->parent_file($file);
        
        my $record = $self->read_primary($file);
        $record = $self->extra_data($record);
        push(@dirlinks, $record);
    }
    
    return  {data => \@dirlinks};
}

#----------------------------------------------------------------------
# Reubuild data in pagelinks block

sub build_all_pagelinks {
    my ($self, $filename) = @_;

    # Need to completely rebuild the page links, all urls are changed
    
    my @pagelinks;
    my $maxlevel = 0;
    my ($repository, $basename) = $self->{wf}->split_filename($filename);
    my $visitor = $self->{wf}->visitor($repository, $maxlevel, 'id');

    while (my $file = &$visitor()) {
        next unless $self->valid_filename($file);
        next if $file eq $filename;
        
        my $record = $self->read_primary($file);
        $record = $self->extra_data($record);
        push(@pagelinks, $record);
    }
    
    return  {data => \@pagelinks};
}

#----------------------------------------------------------------------
# Rebuild data in parentlinks block

sub build_all_parentlinks {
    my ($self, $filename) = @_;

    my $request = $self->read_primary($filename);
    $request = $self->extra_data($request);
    my $links = $self->build_parentlinks($filename, $request);

    return $links;
}

#----------------------------------------------------------------------
# Set up data for pagelinks block

sub build_dirlinks {
    my ($self, $filename, $request) = @_;

    return $self->build_links('dirlinks', $filename, $request);    
}

#----------------------------------------------------------------------
# Build the links used in updating the page

sub build_update_links {
    my ($self, $parent_file, $request) = @_;
    
    my $data = {};
    $data->{dirlinks} = $self->build_dirlinks($parent_file, $request);
    return unless $data->{dirlinks};
    
    return $data;
}

#----------------------------------------------------------------------
# Change the filename to match request 

sub change_filename {
    my ($self, $id, $filename, $request) = @_;

    # Don't rename topmost index
    return $id unless $id;
        
    my ($parentid, $seq) = $self->{wf}->split_id($id);
    my $id_field = $self->{id_field};
    
    $id = $self->generate_id($parentid, $request->{$id_field});
    my ($newname, $extra) = $self->id_to_filename($id);
    
    if ($filename ne $newname) {
        my $index;
        ($filename, $index) = $self->{wf}->split_filename($filename);
        ($newname, $index) = $self->{wf}->split_filename($newname);
        $self->{wf}->rename_file($filename, $newname);
    }
    
    return $id;
}

#----------------------------------------------------------------------
# Check if command is legal

sub check_command {
    my ($self, $id, $cmd) = @_;

    my $test;
    if ($self->is_parent_command($cmd)) {
        $test = 1;

    } elsif ( $cmd eq 'remove') {
        $test = $id && $self->SUPER::check_command($id, $cmd);

    } else {
        $test = $self->SUPER::check_command($id, $cmd);
    }

    return $test;
}

#----------------------------------------------------------------------
# Copy a new version of a file

sub copy_data {
    my ($self, $id, $request) = @_;

    my $maxlevel = 100;
    my $input_filename = $request->{filename};
    my ($repository, $basename) = $self->{wf}->split_filename($input_filename);    

    my $visitor = $self->{wf}->visitor($repository, $maxlevel, 'any');

    while (my $file = &$visitor()) {
        next unless $self->valid_filename($file);
        $self->copy_file($input_filename, $file);
    }

    return;
}

#----------------------------------------------------------------------
# Return a closure that returns a browsable file with each call

sub get_browsable {
    my ($self, $parentid) = @_;

    my $maxlevel = 0;
    my $sort_field = 'ext';
    my $dir = $self->get_repository($parentid);
    my $types = $self->{reg}->project($self->{data_registry}, 'extension');

    my %extensions = reverse %$types;
    my $visitor = $self->{wf}->visitor($dir, $maxlevel, $sort_field);

    return sub {
        my $ext;
    	my $filename;

    	for (;;) {
    	    $filename = &$visitor();
            return unless defined $filename;

            ($ext) = $filename =~ /\.([^\.]*)$/;
    	    last if defined $ext && $extensions{$ext};
        }

        my $obj;
        my $type = $extensions{$ext};

        if (ref $type) {
            $obj = $type;
        } else {
            $obj = $self->{reg}->create_subobject($self,
                                                 $self->{data_registry},
                                                 $type);
            $extensions{$ext} = $obj;
        }
        
        # NB this is not quite correct, we are assuming that
        # the methods here are not overloaded from the base type
        # at least as far as browse_data is concerned

        my $data = $obj->read_primary($filename);
        $data = $obj->extra_data($data);        

        return $data;
   };
}

#----------------------------------------------------------------------
# Return a closure that returns a filename with each call

sub get_next {
    my ($self, $parentid, $subfolders) = @_;
   
    my $obj;
    if ($self->has_one_subtype($parentid)) {
        my $subtypes = $self->get_subtypes($parentid);
        
        $obj = $self->{reg}->create_subobject($self,
                                              $self->{data_registry},
                                              $subtypes->[0]);
    } else {
        $obj = $self;
    }

    my $dir = $self->get_repository($parentid);
    my $maxlevel = $self->{has_subfolders} ? 100 : 0;
    my $visitor = $self->{wf}->visitor($dir, $maxlevel, $self->{sort_field});

    return sub {
        my $ext;
    	my $filename;

    	for (;;) {
    	    $filename = &$visitor();
            return unless defined $filename;

            last if $obj->valid_filename($filename);
        }

        my $data = $obj->read_primary($filename);
        $data = $obj->extra_data($data);
        
        return $data;
   };
}

#---------------------------------------------------------------------------
# Get subtypes to be added to file

sub get_subtypes {
    my ($self, $parentid) = @_;
    
    my @subtypes = $self->{reg}->search($self->{data_registry},
                                        super => $self->get_type());
    my %subtypes = map {$_ => 1} @subtypes;
    
    my $subtypes = $self->SUPER::get_subtypes($parentid);
    %subtypes = (%subtypes, (map {$_ => 1} @$subtypes));

    @subtypes = sort keys %subtypes;
    return \@subtypes;
}

#----------------------------------------------------------------------
# Return true if there is only one subtype

sub has_one_subtype {
    my ($self, $id) = @_;

    return;
}

#----------------------------------------------------------------------
# Convert directory id to filemane

sub id_to_filename {
    my ($self, $id) = @_;
    
    my ($filename, $extra) = $self->SUPER::id_to_filename($id);
    return ($filename, $extra) if -e $filename;
    
    $filename = join('.', $self->{index_name}, $self->{extension});

    if ($id) {
        my @path = $self->{wf}->id_to_path($id);
        $filename = join('/', @path, $filename);
    }
    
    $filename = $self->{wf}->rel2abs($filename);
    return ($filename);
}

#----------------------------------------------------------------------
# Remove a directory

sub remove_data {
    my ($self, $id, $request) = @_;

    if ($id) {
        my ($parentid, $seq) = $self->{wf}->split_id($id);
        my ($repository, $extra) = $self->id_to_filename($parentid);

        my $data = {};
        delete $request->{id};
        $request->{oldid} = $id;
        $data->{pagelinks} = $self->build_pagelinks($repository, $request);

        my $directory = $self->get_repository($id);
        $self->{wf}->remove_directory($directory);

        $self->update_directory_links($id, $request);

    } else {
        my $filename = $self->id_to_filename('');
    	die "Can't remove $filename\n";
    }

    return;
}

#----------------------------------------------------------------------
# Update navigation links after a directory name is changed

sub update_all_links {
    my ($self, $filename) = @_;

    my $data = {};
    $data->{parentlinks} = $self->build_all_parentlinks($filename);
    $data->{dirlinks} = $self->build_all_dirlinks($filename);
    $data->{pagelinks} = $self->build_all_pagelinks($filename);
        
    # Rewrite the links of all the pages
    
    my $maxlevel = 0;
    my ($repository, $basename) = $self->{wf}->split_filename($filename);
    my $visitor = $self->{wf}->visitor($repository, $maxlevel, 'any');

    while (my $file = &$visitor()) {
        next unless $self->valid_filename($file);

        my $id = $self->filename_to_id($file);
        my $record = {id => $id};
        
        $data->{commandlinks} = $self->build_commandlinks($file, $record);
        $self->update_file_links($file, $data);
    }

    # Do this recursively for all subdirectories
    
    $visitor = $self->{wf}->visitor($repository, $maxlevel, 'any');
    while (my $file = &$visitor()) {
        next if $file eq $filename;
        next unless -d $file;

        $file .= "/$self->{index_name}.$self->{extension}";
        $self->update_all_links($file);
    }

    return;
}

#---------------------------------------------------------------------------
# Write a record to disk as a file

sub write_primary {
    my ($self, $filename, $request) = @_;

    my $data = {};
    $data->{meta} = $self->build_meta($filename, $request);
    $data->{primary} = $self->build_primary($filename, $request);
    $data->{parentlinks} = $self->build_parentlinks($filename, $request);
    $data->{commandlinks} = $self->build_commandlinks($filename, $request);

    if (exists $request->{cmd} && $request->{cmd} eq 'add') {
        my $empty_list = {data => []};
        $data->{secondary} = $empty_list;
        $data->{pagelinks} = $empty_list;
    }

    $self->write_file($filename, $data);
    
    $self->update_directory_links($request->{id}, $request);
    $self->update_all_links($filename) if $request->{id} && $request->{oldid};

    return;
}

1;
