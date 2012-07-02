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
# Construct command links for page

sub build_commandlinks {
    my ($self, $data) = @_;

    my $id = $data->{id};
    my $subtypes = $self->get_subtypes($id);

    my @commands = ($self->{default_command});
    push(@commands, 'add') if $self->has_one_subtype($id);

    my $links =  $self->command_links($id, \@commands);
    return {data => $links};
}

#----------------------------------------------------------------------
# Set up data for primary block

sub build_primary {
    my ($self, $data) = @_;
    
    my $type = $self->get_type();
    return {"${type}data" => $data};
}

#----------------------------------------------------------------------
# Set up data for secondary block

sub build_secondary {
    my ($self, $data) = @_;
    
    my $type = $self->get_type();
    return {"${type}data" => $data};
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
# Get field information by reading template file

sub field_info {
    my ($self, $id) = @_;

    my ($filename, $extra) = $self->id_to_filename($id);

    if (! defined $filename || ! -e $filename) {
        $filename = "$self->{template_dir}/$self->{add_template}";
    }

    my $block = $self->{nt}->match("primary.any", $filename);
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

    if (-e $filename) {
        my $block = $self->{nt}->match("secondary.any", $filename);
    
        if ($block) {
            my $type = $block->{NAME};
            $type =~ s/data$//;
            $subtypes = [$type];
    
        } else {
            $subtypes = $self->SUPER::get_subtypes($id);   
        }

    } else {
        $subtypes = [];
    }
    
    return $subtypes;
}

#---------------------------------------------------------------------------
# Construct the template used to render the data

sub get_templates {
    my ($self, $blockname, $filename, $subtemplate) = @_;
    
    my $template;

    if (-e $filename) {
        $template = $filename;

    } else {
        my $id = $self->filename_to_id($filename);
        my ($parentid, $seq) = $self->{wf}->split_id($id);

        my $extra;
        ($template, $extra) = $self->id_to_filename($parentid);
    }

    my $subsubtemplate;
    my $type = $self->get_type();

    if ($blockname) {
        if ($template eq $filename) {
            my $block = $self->{nt}->match($blockname, $template);
            if ($block && $block->{NAME} eq "${type}data") {
                $subsubtemplate = $template;
            }
        }
    }
    
    $subsubtemplate = "$self->{template_dir}/$self->{add_template}"
        unless $subsubtemplate;
        
    $template = $self->{nt}->parse($template, $subtemplate);
    $subtemplate = $self->{nt}->parse($subtemplate, $subsubtemplate);
    
    return ($template, $subtemplate);
}

#----------------------------------------------------------------------
# Return true if there is only one subtype

sub has_one_subtype {
    my ($self, $id) = @_;

    my $test;
    my ($filename, $extra) = $self->id_to_filename($id);

    if ($extra || ! -e $filename) {
        $test = 0;
    } else {
        $test = defined $self->{nt}->match('secondary.any', $filename);
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
        my $container_name = $extra ? 'secondary' : 'primary';

        my $block = $self->{nt}->match("$container_name.any", $filename);
        die "Cannot determine type for $id\n" unless $block;

        $type = $block->{NAME};
        $type =~ s/data$//;

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
# Build navigation links

sub navigation_links {
    my ($self, $subtemplate, $filename, $record) = @_;

    my $same = 1;
    my $data = {};
    my $blocks = $self->{nt}->info($subtemplate);

    foreach my $block (@$blocks) {
        my $blockname = $block->{NAME};	
        my $sort_field = $block->{sort} || $self->{sort_field};

        my $current_links = $self->read_records($filename, $blockname);

        my $new_links = $self->update_links($current_links, $record);
        $new_links = $self->{lo}->list_sort($new_links, $sort_field);
        $same  &&= $self->{lo}->list_same($current_links, $new_links);

        $data = {data => $new_links};
    }
    
    return $same ? undef : $data;   
}

#----------------------------------------------------------------------
# Read data from file

sub read_block {
    my ($self, $filename, $blockname) = @_;

    my $block = $self->{nt}->match($blockname, $filename);
    die "Can't read $blockname data from $filename\n" unless $block;
    return $block->data();

}

#----------------------------------------------------------------------
# Read data from file

sub read_primary {
    my ($self, $filename) = @_;

    return $self->read_block($filename, "primary.any");
}

#----------------------------------------------------------------------
# Read a list of records from a file

sub read_records {
    my ($self, $filename, $blockname) = @_;

    my $records = $self->read_block($filename, $blockname);
    
    if (ref $records eq 'HASH') {
    	my @keys = keys %$records;

        if (@keys == 1 && $keys[0] eq 'data') {
            $records = $records->{data};
        }
    }
    
    if (! ref $records) {
        $records = [];       
    } elsif (ref $records eq 'HASH') {
        $records = [$records];
    }

    return $records;
}

#----------------------------------------------------------------------
# Read data from file

sub read_secondary {
    my ($self, $filename) = @_;

    return $self->read_records($filename, "secondary.any");
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
# Build data fields used in links

sub single_navigation_link {
    my ($self, $data) = @_;

    my $id = $data->{id};
    my ($parentid, $seq) = $self->{wf}->split_id($id);
    
    my $link = {};
    $link->{id} = $seq ;
    $link->{url} = $self->id_to_url($id);
    $link->{title} = $data->{title} if exists $data->{title};
    $link->{summary} = $data->{summary} if exists $data->{summary};

    return $link;
}

#----------------------------------------------------------------------
# Sort data if marked to be sorted in template

sub sort_data {
    my ($self, $template, $blockname, $data) = @_;

    my $sort;
    my $block = $self->{nt}->match($blockname, $template);

    if ($block) {
        my $info = $block->info_item();
        $sort = $info->{sort};
    }

    $data = $self->sort_records($sort, $data) if defined $sort;   
    return $data;
}

#----------------------------------------------------------------------
# Sort arrays in a hash

sub sort_records {
    my ($self, $sort, $records) = @_;

    if (ref $records eq 'ARRAY') {
        $records = $self->{lo}->list_sort($records, $sort);

    } elsif (ref $records eq 'HASH') {
        foreach my $name (keys %$records) {
            $records->{$name} = $self->sort_records($sort, $records->{$name});
        }
    }

    return $records;
}

#----------------------------------------------------------------------
# Update navigation links after a file is changed

sub update_data {
    my ($self, $id, $record) = @_;

    my ($parentid, $seq) = $self->{wf}->split_id($id);
    my ($indexfile, $extra) = $self->id_to_filename($parentid);

    my $subtemplate = $self->{update_template};
    $subtemplate = "$self->{template_dir}/$subtemplate";

    my $data = $self->navigation_links($subtemplate, $indexfile, $record);
    return unless $data;
    
    my $url = $self->filename_to_url($indexfile);
    $data =  $self->link_class($data, $url);
    $self->write_file('', $indexfile, $subtemplate, $data);

    my $dir = $self->get_repository($parentid);
    my $subfolders = $self->{has_subfolders};
    my $visitor = $self->{wf}->visitor($dir, $subfolders, 'any');

    while (my $filename = &$visitor()) {
        next unless $self->valid_filename($filename);
        next if $filename eq $indexfile;

        $url = $self->filename_to_url($filename);
        $data =  $self->link_class($data, $url);
        $self->write_file('', $filename, $subtemplate, $data);
    }

    return;
}

#----------------------------------------------------------------------
# Build navigation links

sub update_links {
    my ($self, $current_links, $data) = @_;
    my $new_links;
    
    if (exists $data->{id}) {
        my $link = $self->single_navigation_link($data);
        $new_links = $self->{lo}->list_add($current_links, $link);
    }
    
    if (exists $data->{oldid}) {
        my ($parentid, $seq) = $self->{wf}->split_id($data->{oldid});
        $new_links = $self->{lo}->list_delete($current_links, $seq);
    }

    return $new_links;
}

#---------------------------------------------------------------------------
# Write a list of records to disk as a file

sub write_file {
    my ($self, $blockname, $filename, $subtemplate, $data) = @_;
    
    my $template;
    ($template, $subtemplate) =
        $self->get_templates($blockname, $filename, $subtemplate);

    $data = $self->sort_data($subtemplate,
                             $blockname,
                             $data);
    
    my $result = $self->{nt}->distribute_data($self,
                                              $data,
                                              $subtemplate); 

    my $output = $self->{nt}->render($result,
                                     $template,
                                     $subtemplate); 
                                     
    $self->{wf}->writer($filename, $output);

    return;
}

#---------------------------------------------------------------------------
# Write a list of records to disk as a file

sub write_primary {
    my ($self, $filename, $record) = @_;

    my $subtemplate = $self->{edit_template};
    $subtemplate = "$self->{template_dir}/$subtemplate";
   
    $record->{base_url} = $self->{base_url};
    
    $self->write_file('primary.any',
                      $filename,
                      $subtemplate,
                      $record);
    
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
    my ($self, $filename, $records) = @_;

    my $subtemplate = $self->{edit_template};
    $subtemplate = "$self->{template_dir}/$subtemplate";

    $self->write_file('secondary.any',
                      $filename,
                      $subtemplate,
                      {data => $records});
    return;
}

1;
