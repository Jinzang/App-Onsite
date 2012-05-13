use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Maintain directory hierarchy through operations on data

package CMS::Onsite::DirData;

use base qw(CMS::Onsite::PageData);

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
# Add a new file

sub add_data {
    my ($self, $parentid, $request) = @_;
    
    my $id_field = $self->{id_field};
    my $id = $self->generate_id($parentid, $request->{$id_field});
    $request->{id} = $id;

    my $separator = $self->{separator};
    my @dirs = split($separator, $id);
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

    my $types = $self->{reg}->project($self->{data_registry}, 'extension');
    my @extensions = values %$types;

    my $get_next = $self->get_next($parentid, $subfolders, @extensions);

    while (defined(my $data = &$get_next)) {
        push(@list, $data);
        last unless -- $limit;
    }

    return $self->{lo}->list_sort(\@list);
}

#----------------------------------------------------------------------
# Construct command links for page

sub build_parentlinks {
    my ($self, $data, $sort) = @_;

    my ($parentid, $seq) = $self->split_id($data->{id});
    my $filename = $self->id_to_filename($parentid);
    
    my $links = $self->read_block($filename, 'parentlinks');
    my $link = $self->single_navigation_link($data);

    $links = $self->{lo}->list_add($links, $link);
    $links = $self->link_class($links, $data->{url});
    
    return {data => $links};
}

#----------------------------------------------------------------------
# Change the filename to match request TODO: rewrite

sub change_filename {
    my ($self, $id, $filename, $request) = @_;

    # Don't rename topmost index
    return $id unless $id;
        
    my ($parentid, $seq) = $self->split_id($id);
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
    if ($cmd eq 'browse' || $cmd eq 'search') {
        $test = 1;
    } else {
        $test = $self->SUPER::check_command($id, $cmd);
    }

    return $test;
}

#----------------------------------------------------------------------
# Return a closure that returns a page with each call

sub get_next {
    my ($self, $parentid, $subfolders, @extensions) = @_;

    $subfolders = $self->{has_subfolders} unless defined $subfolders;

    my $extension = $self->{extension};    
    push(@extensions, $extension) unless @extensions;

    my $sort_field = $self->{sort_field};

    my $dir = $self->get_repository($parentid);
    my %extensions = map {$_ => 1} @extensions;
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
        my $id = $self->filename_to_id($filename);

        if ($ext eq $extension) {
            $obj = $self;

        } else {
            my $type = $self->id_to_type($id);
            $obj = $self->create_subobject($type);
        }
        
        my $data = $obj->read_primary($filename);
        $data->{id} = $id;
        $data = $obj->extra_data($data);        

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
# Get the type of an existing file from its id

sub id_to_type {
	my ($self, $id) = @_;


    my $pkg;
    my $types = $self->{reg}->project($self->{data_registry}, 'extension');

    while (my ($type, $ext) = each %$types) {
        my ($filename, $extra) = $self->id_to_filename_with_ext($id, $ext);

        if (-e $filename) {
            my $traits = $self->{reg}->read_data($self->{data_registry}, $type);
            ($pkg) = $traits->{class} =~ /^([A-Z][\w:]+Data)$/;
            last;
        }
    }
    
    die "Invalid id: $id\n" unless $pkg;

    eval "require $pkg" or die "$@\n";
	my $obj = $pkg->new(%$self);

	return $obj->id_to_type($id);
}

#----------------------------------------------------------------------
# Return the next available id
# TODO: move to PostData or remove
sub next_id {
    my ($self, $parentid) = @_;

    my $seq = '0' x $self->{index_length};
    my $pattern = "[0-9]" x $self->{index_length};

    my $sort_field = $self->{sort_field};
    my $subfolders = $self->{has_subfolders};

    my $dir = $self->{wf}->get_repository($parentid);
    my $visitor = $self->{wf}->visitor($dir, $subfolders, $sort_field);

    while (defined (my $file = &$visitor)) {
    	next unless $self->valid_filename($file);

        my $val = $self->filename_to_id($file);
    	$seq = $val if $val gt $seq;
    }

    $seq ++;
    my $separator = $self->{separator};
    my $id = $parentid ? join($separator, $parentid, $seq) : $seq;
    return $id;
}

#----------------------------------------------------------------------
# Remove a directory

sub remove_data {
    my ($self, $id, $request) = @_;

    if ($id) {
        my $directory = $self->get_repository($id);
        $self->{wf}->remove_directory($directory);

        $request->{oldid} = $id;
        $self->update_data($id, $request);

    } else {
    	die "Can't remove $self->{data_dir}\n";
    }

    return;
}

#----------------------------------------------------------------------
# Build navigation links

sub update_links {
    my ($self, $current_links, $data) = @_;

    # Only update links if parent is top level

    my $new_links;
    my ($parentid, $seq) = $self->split_id($data->{id});

    if ($parentid) {
        $new_links = $current_links;
    } else {
        $new_links = $self->SUPER::update_links($current_links, $data);       
    }

   return $new_links;
}

1;
