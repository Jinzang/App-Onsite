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
# Change the filename to match request TODO: rewrite

sub change_filename {
    my ($self, $id, $filename, $request) = @_;

    # Don't rename topmost index
    return $id unless $id;
        
    my ($parentid, $seq) = $self->{wf}->split_id($id);
    my $id_field = $self->{id_field};
    
    $id = $self->generate_id($parentid, $request->{$id_field});
    my ($newname, $extra) = $self->id_to_filename($id);
    
    if ($filename ne $newname) {
        die "Renaming directories is not supported yet\n";
        
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
# Return a closure that returns a browsable file with each call

sub get_browsable {
    my ($self, $parentid) = @_;

    my $subfolders = 0;
    my $sort_field = 'ext';
    my $dir = $self->get_repository($parentid);
    my $types = $self->{reg}->project($self->{data_registry}, 'extension');

    my %extensions = reverse %$types;
    my $visitor = $self->{wf}->visitor($dir, $subfolders, $sort_field);

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
        $data->{id} = $self->filename_to_id($filename);
        $data = $obj->extra_data($data);        

        return $data;
   };
}

#----------------------------------------------------------------------
# Return a closure that returns a filename with each call

sub get_next {
    my ($self, $parentid, $subfolders) = @_;

    my $dir = $self->get_repository($parentid);
    my $extension = $self->{extension};    

    my $visitor = $self->{wf}->visitor($dir,
                                       $self->{has_subfolders},
                                       $self->{sort_field});

    return sub {
        my $ext;
    	my $filename;

    	for (;;) {
    	    $filename = &$visitor();
            return unless defined $filename;

            ($ext) = $filename =~ /\.([^\.]*)$/;
    	    last if defined $ext && $extension eq $ext;
        }

        my $data = $self->read_primary($filename);
        $data->{id} = $self->filename_to_id($filename);
        $data = $self->extra_data($data);        

        return $data;
   };
}

#---------------------------------------------------------------------------
# Get subtypes to be added to file (stub)

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
# Remove a directory

sub remove_data {
    my ($self, $id, $request) = @_;

    if ($id) {
        my ($parentid, $seq) = $self->{wf}->split_id($id);
        my ($repository, $extra) = $self->id_to_filename($parentid);

        my $data = {};
        $request->{oldid} = $id;
        $data->{pagetlinks} = $self->build_pagelinks($repository, $request);

        my $directory = $self->get_repository($id);
        $self->{wf}->remove_directory($directory);

        $self->update_files($repository, $data);

    } else {
        my $filename = $self->id_to_filename('');
    	die "Can't remove $filename\n";
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
    $self->write_file($filename, $data);
 
    if ($data->{parentlinks}) {
        my $parent_file = $self->{wf}->parent_file($filename);
        
        if ($filename ne $parent_file) {
            my $update_data = {};
            $update_data->{pagelinks} = $self->build_pagelinks($parent_file,
                                                               $request);
            $self->update_files($parent_file, $update_data);
        }
    }
    
    return;
}

1;
