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

    my $id = $request->{id};
    my $subtypes = $self->get_subtypes($id);

    my @commands = ($self->{default_command});
    push(@commands, 'add') if @$subtypes == 1;

    my $links =  $self->command_links($id, \@commands);
    return {data => $links};
}

#----------------------------------------------------------------------
# Build navigation links

sub build_links {
    my ($self, $blockname, $filename, $request) = @_;

    $filename = $self->{wf}->parent_file($filename) unless -e $filename;
    my $link = $self->single_navigation_link($request);

    my $links = $self->build_records($blockname, $filename, $link);
    return unless $links;
    
    $links =  $self->link_class($links, $link->{url});
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
# Set up data for primary block

sub build_primary {
    my ($self, $filename, $request) = @_;

    return $request;    
}

#----------------------------------------------------------------------
# Build a new set of records that includes request

sub build_records {
    my ($self, $blockname, $filename, $request) = @_;

    my $new_records;
    if (-e $filename) {
        my $current_records = $self->read_records($blockname, $filename);
        $new_records = $self->update_records($current_records, $request);
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
# Extract an array element from a hash with a single key

sub extract_from_data {
    my ($self, $records) = @_;

    if (ref $records eq 'HASH') {
        my @keys = keys %$records;

        if (@keys == 1 && $keys[0] eq 'data') {
            $records =  $records->{$keys[0]};
        }

    } elsif (ref $records eq 'ARRAY') {
        @$records = map {$self->extract_from_data($_)} @$records;       
    }

    return $records;
}

#----------------------------------------------------------------------
# Get field information by reading template file

sub field_info {
    my ($self, $id) = @_;

    my ($filename, $extra) = $self->id_to_filename($id);
    my $blockname = $extra ? 'secondary.data' : 'primary';
    
    my @templates = $self->get_templates($filename);
    my $template = pop(@templates);
    
    my $block = $self->{nt}->match($blockname, $template);

    die "Cannot get field info for $id\n" unless $block;
    my $info = $block->info();

    my @new_info = grep {$_->{NAME} ne 'id'} @$info;
    return \@new_info;
}

#----------------------------------------------------------------------
# Construct a url from a filename

sub filename_to_url {
    my ($self, $filename) = @_;

    my $path = $self->{wf}->abs2rel($filename);

    my $url;
    if ($path eq '.') {
        $url = $self->{base_url};

    } else {
        $url = $self->{base_url};
        $url .= '/' unless $url =~ /\/$/;
        $url .= $path;
    }

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
    my ($self, $filename) = @_;
    
    my @templates;
    if (-e $filename) {
        push(@templates, $filename);

    } else {
        my $id = $self->filename_to_id($filename);
        my ($parentid, $seq) = $self->{wf}->split_id($id);
        
        my ($template, $extra) = $self->id_to_filename($parentid);
        push(@templates, $template);
        
        my $subtemplate = "$self->{template_dir}/$self->{subtemplate}";
        push(@templates, $subtemplate);
    }
    
    return @templates;
}

#----------------------------------------------------------------------
# Return true if there is only one subtype

sub has_one_subtype {
    my ($self, $id) = @_;

    my $test;
    my ($filename, $extra) = $self->id_to_filename($id);

    if (! $extra && -e $filename) {
        my $item = $self->block_info('secondary', $filename);
        $test = exists $item->{type};
    }
    
    return $test;
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
        die "Cannot determine type for $id\n" unless exists $item->{type};
        $type = $item->{type};

    } else {
        $type = $self->get_type();
    }

    return $type;
}

#----------------------------------------------------------------------
# Convert id to url

sub id_to_url {
    my ($self, $id) = @_;
    
    my ($filename, $extra) = $self->id_to_filename($id);
    my $url = $self->filename_to_url($filename);
    $url .= "#$extra" if $extra;
    
    return $url;
}

#----------------------------------------------------------------------
# Set the class on a link to current or local

sub link_class {
    my ($self, $data, $url) = @_;

    my $ref = ref $data;
    if ($ref eq 'ARRAY') {
	foreach my $item (@$data) {
	    $item = $self->link_class($item, $url);
	}

    } elsif ($ref eq 'HASH') {
        if (exists $data->{url}) {
            if ($data->{url} eq $url) {
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
    $data->{pagelinks} = $self->build_pagelinks($filename, $request)
        unless $extra;

    $self->SUPER::remove_data($id, $request);
    $self->update_files($filename, $data) if $data->{pagelinks};

    return;    
}

#----------------------------------------------------------------------
# Build data fields used in links

sub single_navigation_link {
    my ($self, $data) = @_;

    my $id_field;
    if (exists $data->{id}) {
        $id_field = 'id'
    } elsif (exists $data->{oldid}) {
        $id_field = 'oldid'
    } else {
        die "id not defined"
    }
    
    my $link = {};
    $link->{$id_field} = $data->{$id_field};
    $link->{url} = $self->id_to_url($data->{$id_field});
    $link->{title} = $data->{title} if exists $data->{title};
    $link->{summary} = $data->{summary} if exists $data->{summary};

    return $link;
}

#----------------------------------------------------------------------
# Update navigation links after a file is changed

sub update_files {
    my ($self, $filename, $data, $skip) = @_;

    my $subfolders = 0;
    my ($repository, $basename) = $self->{wf}->split_filename($filename);    

    my $visitor = $self->{wf}->visitor($repository, $subfolders, 'any');

    while (my $file = &$visitor()) {
        next unless $self->valid_filename($file);
        next if $skip && $file eq $filename;

        my $url = $self->filename_to_url($file);
        $data =  $self->link_class($data, $url);
        $self->write_file($file, $data);
    }

    return;
}

#---------------------------------------------------------------------------
# Write a list of records to disk as a file

sub write_file {
    my ($self, $filename, $data) = @_;
    
   my @templates = $self->get_templates($filename);
    
    my $output = $self->{nt}->render($data, @templates); 
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
    $self->write_file($filename, $data);
 
    if ($data->{pagelinks}) {
        my $skip = 1;
        my $update_data = {};
        $update_data->{pagelinks} = $data->{pagelinks};
        $self->update_files( $filename, $update_data, $skip);
    }
    
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
    
    my $template = "$self->{template_dir}/rss.htm";
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

    my $data ={};
    $data->{secondary} = $self->build_secondary($filename, $request);
    $self->write_file($filename, $data);

    return;
}

1;
