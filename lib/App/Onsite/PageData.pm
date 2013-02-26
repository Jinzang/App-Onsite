use strict;
use warnings;
use integer;

#-----------------------------------------------------------------------
# Create an object that stores data in an html page

package App::Onsite::PageData;

use base qw(App::Onsite::FileData);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
                    base_url => '',
                    template_dir => '',
                    lo => {DEFAULT => 'App::Onsite::Listops'},
                    nt => {DEFAULT => 'App::Onsite::Support::NestedTemplate'},
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
    
    $self->write_data($id, $request);
    return;
}

#----------------------------------------------------------------------
# Return a specific item from the info for a file

sub block_info {
    my ($self, $blockname, $filename) = @_;
    
    my $info = $self->{nt}->info($filename);
    foreach my $item (@$info) {
        return $item if $item->{NAME} eq $blockname;
    }

    die "Couldn't find $blockname in $filename\n";
    return;
}

#----------------------------------------------------------------------
# Construct command links for page

sub build_commandlinks {
    my ($self, $filename, $request) = @_;

    my @commands = ($self->{default_command});
    if (-e $filename) {
        my $item = $self->block_info('secondary', $filename);
        push(@commands, 'add') if exists $item->{type};
    }

    my $id = $self->filename_to_id($filename);
    my $links =  $self->command_links($id, \@commands);
    return {data => $links};
}

#----------------------------------------------------------------------
# Build navigation links

sub build_links {
    my ($self, $blockname, $filename, $request) = @_;

    my $links = $self->build_records($blockname, $filename, $request);
    $links =  $self->link_class($links, $request->{url});

    return $links;
}

#----------------------------------------------------------------------
# Set up data for meta block

sub build_meta {
    my ($self, $filename, $request) = @_;

    my %data = %$request;    
    $data{base_url} = $self->{base_url};
    
    return \%data;
}

#----------------------------------------------------------------------
# Set up data for pagelinks block

sub build_pagelinks {
    my ($self, $filename, $request) = @_;

    return $self->build_links('pagelinks', $filename, $request);    
}

#----------------------------------------------------------------------
# Set up data for pagelinks block

sub build_parentlinks {
    my ($self, $filename, $request) = @_;

    my ($parent_id, $seq) = $self->{wf}->split_id($request->{id});
    my ($parent_file, $extra) = $self->id_to_filename($parent_id);

    return $self->build_links('parentlinks', $parent_file, $request);    
}

#----------------------------------------------------------------------
# Set up data for primary block

sub build_primary {
    my ($self, $filename, $request) = @_;

    return $request;    
}

#----------------------------------------------------------------------
# Build a new set of records that includes request

sub build_records {
    my ($self, $blockname, $filename, $request) = @_;
   
    $filename = $self->{wf}->parent_file($filename) unless -e $filename;

    my $new_records;
    if (-e $filename) {
        my $current_records = $self->read_records($blockname, $filename);
        $new_records = $self->{lo}->list_change($current_records, $request);
        return if $self->{lo}->list_same($current_records, $new_records);
    
        my $item = $self->block_info($blockname, $filename);
        my $sort_field = $item->{sort} || 'id';        
        $new_records = $self->{lo}->list_sort($new_records, $sort_field);

    } else {
        $new_records = [$request];        
    }

    return {data => $new_records};       
}

#----------------------------------------------------------------------
# Set up data for secondary block

sub build_secondary {
    my ($self, $filename, $request) = @_;
    
    return $self->build_records('secondary', $filename, $request);
}

#----------------------------------------------------------------------
# Build the links used in updating the page

sub build_update_links {
    my ($self, $parent_file, $request) = @_;
    
    my $data = {};
    $data->{pagelinks} = $self->build_pagelinks($parent_file, $request);
    return unless $data->{pagelinks};
    
    return $data;
}

#----------------------------------------------------------------------
# Change the filename to match request

sub change_filename {
    my ($self, $id, $filename, $request) = @_;
 
    my ($parentid, $seq) = $self->{wf}->split_id($id);
    my $id_field = $self->{id_field};
    $id = $self->generate_id($parentid, $request->{$id_field});

    my ($newname, $extra) = $self->id_to_filename($id);
    $self->{wf}->rename_file($filename, $newname) if $filename ne $newname;

    return $id;
}

#----------------------------------------------------------------------
# Copy a new version of a file

sub copy_data {
    my ($self, $id, $request) = @_;
    
    my ($output_filename, $extra) = $self->id_to_filename($id);
    die "Con't copy into subobject" if $extra;

    $self->copy_file($request->{filename}, $output_filename);
    return;
}

#----------------------------------------------------------------------
# Copy a new version of a file

sub copy_file {
    my ($self, $input_filename, $output_filename) = @_;
    
    my $template = $self->{nt}->parse($input_filename,
                                      $output_filename);
    
    my $output = $self->{nt}->unparse($template);
    $self->{wf}->writer($output_filename, $output);

    return;
}

#----------------------------------------------------------------------
# Dump variables to file, for debugging

sub dump {
    my ($self, $filename, @args) = @_;

    my $output = Dumper(@args);
    my $logfile = $filename;
    $logfile =~ s/[^\/]+$/onsite.log/;
     $self->{wf}->writer($logfile, $output);   
    return;
}

#----------------------------------------------------------------------
# Convert fields in records to their escaped form

sub escape_data {
    my ($self, $data, $strip) = @_;
    
    my $new_data;
    my $ref = ref $data;
    if (! $ref) {
        $new_data = $data;
        if ($strip) {
            $new_data =~ s/<!--.*?-->/ /gs;
            $new_data =~ s/<[^>]*>/ /gs;
            $new_data =~ s/&nbsp;/ /g;
            $new_data =~ tr/\t\r\n / /s;
	    
        } else {
            $new_data =~ s/&/&amp;/g;
            $new_data =~ s/</&lt;/g;
            $new_data =~ s/>/&gt;/g;
        }
	
    } elsif ($ref eq 'ARRAY') {
        $new_data = [];
        foreach my $item (@$data) {
            push(@$new_data, $self->escape_data($item, $strip));
        }
	
    } elsif ($ref eq 'HASH') {
        $new_data = {};
        my $summary_field = $self->{summary_field};
	
        while (my ($name, $value) = each %$data) {
            $strip = $name ne $summary_field;
            $new_data->{$name} = $self->escape_data($value, $strip);
        }

    } else {
        $new_data = $data;
    }

    return $new_data;
}

#----------------------------------------------------------------------
# Add extra data to the data read from file

sub extra_data {
    my ($self, $data) = @_;

    $data = $self->SUPER::extra_data($data);
    $data->{url} = $self->id_to_url($data->{id});

    return $data;
}

#----------------------------------------------------------------------
# Add extra info to info read from file

sub extra_info {
    my ($self, $info) = @_;

    $info->{hidden} = exists $info->{style} &&
                      $info->{style} =~ /type=hidden/;

    return $info;
}

#----------------------------------------------------------------------
# Extract an array element from a hash with a single key

sub extract_from_data {
    my ($self, $records) = @_;

    # TODO: fix
    if (ref $records eq 'HASH') {
        my @keys = keys %$records;

        if (@keys == 1 && $keys[0] eq 'data') {
            $records =  $records->{$keys[0]};
            $records = [] unless ref $records;
        }

    } elsif (ref $records eq 'ARRAY') {
        @$records = map {$self->extract_from_data($_)} @$records;       

    } else {
        $records = {};
    }

    return $records;
}

#----------------------------------------------------------------------
# Get field information by reading template file

sub field_info {
    my ($self, $id) = @_;

    my $info = $self->template_info();

    my @new_info;
    foreach  my $item (@$info) {
        next if $item->{NAME} eq 'id';
        push(@new_info, $item);
    }

    return \@new_info;
}

#----------------------------------------------------------------------
# Construct a url from a filename

sub filename_to_url {
    my ($self, $filename, $extra) = @_;

    my $path = $self->{wf}->abs2rel($filename);

    my $url;
    if ($path eq '.') {
        $url = $self->{base_url};

    } else {
        $url = $self->{base_url};
        $url .= '/' if $url && $url !~ /\/$/;
        $url .= $path;
    }

    $url .= "#$extra" if $extra;
    return $url;
}

#----------------------------------------------------------------------
# Return the names of the subdata objects contained in the file

sub get_subtypes {
    my ($self, $id) = @_;

    my $subtypes;
    my ($filename, $extra) = $self->id_to_filename($id);

    if ($extra || ! -e $filename) {
        $subtypes = [];

    } else {
        my $item = $self->block_info('secondary', $filename);
        $subtypes = exists $item->{type} ? [$item->{type}]
                                         : $self->SUPER::get_subtypes($id);
    }
    
    return $subtypes;
}

#---------------------------------------------------------------------------
# Get the names of the templates used to render the data

sub get_templates {
    my ($self, $filename, $data) = @_;
    
    my $subtemplate = "$self->{template_dir}/$self->{subtemplate}";
    $subtemplate = $self->{nt}->mask_template($data, $subtemplate);
    
    my $template;
    if (-e $filename) {
        $template = $filename;
    } else {
        $template = $self->{wf}->parent_file($filename);
    }

    $template = $self->{nt}->parse($template, $subtemplate);
    return $template;
}

#----------------------------------------------------------------------
# Return true if there is only one subtype

sub has_one_subtype {
    my ($self, $id) = @_;

    my $subtype;
    my ($filename, $extra) = $self->id_to_filename($id);

    if (! $extra && -e $filename) {
        my $item = $self->block_info('secondary', $filename);
        $subtype = $item->{type} if exists $item->{type};
    }
    
    return $subtype;
}

#----------------------------------------------------------------------
#  Get the type of a file given its id

sub id_to_type {
    my ($self, $id) = @_;

    my $type;
    my ($filename, $extra) = $self->id_to_filename($id);

    if (-e $filename) {
        my $blockname = $extra ? 'secondary' : 'primary';
        my $item = $self->block_info($blockname, $filename);

        if (exists $item->{type}) {
            $type = $item->{type};
        } else {
            die "Can't determine type of $id\n" if $blockname eq 'secondary';
        }
    }

    $type ||= $self->SUPER::id_to_type($id);
    return $type;
}

#----------------------------------------------------------------------
# Convert id to url

sub id_to_url {
    my ($self, $id) = @_;
    
    my ($filename, $extra) = $self->id_to_filename($id);
    my $url = $self->filename_to_url($filename, $extra);
    
    return $url;
}

#----------------------------------------------------------------------
# Set the class on a link to current or local

sub link_class {
    my ($self, $data, $url) = @_;

    my $ref = defined $data ? ref $data : '';
    
    if ($ref eq 'ARRAY') {
        foreach my $item (@$data) {
            $item = $self->link_class($item, $url);
        }

    } elsif ($ref eq 'HASH') {
        if (exists $data->{url}) {
            if (defined $url && $url eq $data->{url}) {
                $data->{class} = 'current';
            } else {
                $data->{class} = 'local';
            }	    
    
        } else {
            foreach my $item (values %$data) {
                $item = $self->link_class($item, $url);
            }
        }
    }

    return $data;
}

#----------------------------------------------------------------------
# Read data from file

sub read_block {
    my ($self, $blockname, $filename) = @_;


    my $block = $self->{nt}->match($blockname, $filename);
    die "Can't read $blockname data from $filename\n" unless $block;

    return $block->data();
}

#----------------------------------------------------------------------
# Read data from file

sub read_primary {
    my ($self, $filename) = @_;

    my $record = $self->read_block('primary', $filename);
    $record->{id} = $self->filename_to_id($filename);
   
    return $record;
}

#----------------------------------------------------------------------
# Read a list of records from a file

sub read_records {
    my ($self, $blockname, $filename) = @_;

    my $records = $self->read_block($blockname, $filename);
        
    if (ref $records) {
        $records = $self->extract_from_data($records);
        $records = [$records] unless ref $records eq 'ARRAY';
        
    } else {
        $records = [];               
    }

    return $records;
}

#----------------------------------------------------------------------
# Read data from file

sub read_secondary {
    my ($self, $filename) = @_;

    return $self->read_records('secondary', $filename);
}

#----------------------------------------------------------------------
# The url to redirect to after a command is successfully executed

sub redirect_url {
    my ($self, $id) = @_;

    my ($filename, $extra, $seq);
    while ($id) {
        ($filename, $extra) =  $self->id_to_filename($id);
        return $self->filename_to_url($filename) if -e $filename;
        
        ($id, $seq) = $self->{wf}->split_id($id);
    }

    return $self->{base_url};
}

#----------------------------------------------------------------------
# Remove a file

sub remove_data {
    my ($self, $id, $request) = @_;

    my ($filename, $extra) = $self->id_to_filename($id);

    my $data = {};
    delete $request->{id};
    $request->{oldid} = $id;

    $self->SUPER::remove_data($id, $request);
    $self->update_directory_links($id, $request);

    return;    
}

#----------------------------------------------------------------------
# Get field information by reading template file

sub template_info {
    my ($self) = @_;

    my $template = "$self->{template_dir}/$self->{subtemplate}";    
    my $block = $self->{nt}->match('primary', $template);

    die "Cannot get field info from subtemplate\n" unless $block;

    my $info = $block->info();
    foreach my $item (@$info) {
        $item = $self->extra_info($item);
    }
    
    return $info;
}

#----------------------------------------------------------------------
# Update navigation links after a file is changed

sub update_directory_links {
    my ($self, $id, $request) = @_;

    my ($filename, $extra) = $self->id_to_filename($id);
    return if $extra;

    my $parent_file;
    my ($parent_id, $seq) = $self->{wf}->split_id($id);
    ($parent_file, $extra) = $self->id_to_filename($parent_id);

    my $maxlevel = 0;
    my ($repository, $basename) = $self->{wf}->split_filename($parent_file);
    my $visitor = $self->{wf}->visitor($repository, $maxlevel, 'any');

    my $data = $self->build_update_links($parent_file, $request);
    return unless $data;
    
    while (my $file = &$visitor()) {
        next unless $self->valid_filename($file);
        next if $file eq $filename;
        
        $self->update_file_links($file, $data);
    }

    return;
}

#---------------------------------------------------------------------------
# Update the links

sub update_file_links {
    my ($self, $filename, $data) = @_;
    return unless -e $filename;
    
    foreach my $key (keys %$data) {
        delete $data->{$key} unless defined $data->{$key};
    }
    
    my $url = $self->filename_to_url($filename);
    $data =  $self->link_class($data, $url);
    $self->write_file($filename, $data);

    return;
}

#----------------------------------------------------------------------
# Validate uploaded file

sub validate_file {
    my ($self, $request) = @_;
    
    my $new_filename = $request->{filename};
    my ($old_filename, $extra) = $self->id_to_filename($request->{id});
    
    my $new_blocks = $self->{nt}->data($new_filename);
    my $old_blocks = $self->{nt}->data($old_filename);
    
    my @missing;
    for my $field (sort keys %$old_blocks) {
        push(@missing, $field) if ! exists $new_blocks->{$field};
    }

    return @missing;
}

#---------------------------------------------------------------------------
# Write a list of records to disk as a file

sub write_file {
    my ($self, $filename, $data) = @_;
  
    my $template = $self->get_templates($filename, $data);
    my $output = $self->{nt}->render($data, $template); 
    $self->{wf}->writer($filename, $output);

    return;
}

#---------------------------------------------------------------------------
# Write a record to disk as a file

sub write_primary {
    my ($self, $filename, $request) = @_;

    my $data = {};
    $data->{meta} = $self->build_meta($filename, $request);
    $data->{primary} = $self->build_primary($filename, $request);
    $data->{pagelinks} = $self->build_pagelinks($filename, $request);
    $data->{commandlinks} = $self->build_commandlinks($filename, $request);

    if (exists $request->{cmd} && $request->{cmd} eq 'add') {
        $data->{secondary} = {data => []};
    }
    
    $self->write_file($filename, $data);
    $self->update_directory_links($request->{id}, $request);
        
    return;
}

#----------------------------------------------------------------------
# Write rss file 

sub write_rss {
    my ($self, $id) = @_;

    my ($filename, $extra) = $self->id_to_filename($id);
    my $channel = $self->read_primary($filename);
    $channel = $self->escape_data($channel);
    $channel->{url} = $self->filename_to_url ($filename);
    
    my $records = $self->read_secondary($filename);
    $records = $self->escape_data($records);
    
    my $template = join('/', $self->{template_dir}, $self->{rsstemplate});
    $filename =~ s/\.[^\.]*$/\.rss/;

    my $data = {channel => $channel, rss_items => $records};
    my $output = $self->{nt}->render($data, $template);
    $self->{wf}->writer($filename, $output);

    return;
}

#---------------------------------------------------------------------------
# Write a list of records to disk as a file

sub write_secondary {
    my ($self, $filename, $request) = @_;

    my $data = {};
    $data->{secondary} = $self->build_secondary($filename, $request);
    $data->{commandlinks} = $self->build_commandlinks($filename, $request);

    $self->write_file($filename, $data);

    return;
}

1;
