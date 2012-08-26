use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
package App::Onsite::PostData;

use base qw(App::Onsite::PageData);

use constant MONTHS => [qw(January February March April May June July
			   August September October November December)];

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
	    max_entries => 10,
	);

    my %base_params = $pkg->SUPER::parameters();
    %parameters = (%base_params, %parameters);

    return %parameters;
}

#----------------------------------------------------------------------
# Construct parent links for page

sub build_parentlinks {
    my ($self, $index_name, $index_data) = @_;
   
    my ($parentid, $seq) = $self->{wf}->split_id($index_data->{id});
    my ($blog_index_file, $extra) = $self->id_to_filename($parentid);

    my @links;
    my $current_links = $self->read_records('parentlinks', $blog_index_file);
    push(@links, @$current_links);

    my $uplinks = $self->build_uplinks($index_name);
    push(@links, @$uplinks);
       
    my $url = $self->filename_to_url($index_name);
    my $links = $self->link_class(\@links, $url);
   
    return {data => $links};
}

#----------------------------------------------------------------------
# Build a  list of links for breadcrumb trail

sub build_uplinks {
    my ($self, $filename, $request) = @_;

    my @links;
    foreach my $index_file ($self->get_index_files($filename)) {
        my $data = {};
        $data->{title} = $self->title_from_filename($index_file);
        $data->{url} = $self->filename_to_url($index_file);

        push(@links, $data);
    }

    @links = reverse @links;
    return \@links;
}

#----------------------------------------------------------------------
# Change the filename to match request (actually, don't)

sub change_filename {
    my ($self, $id, $filename, $request) = @_;
    return $id;
}

#-----------------------------------------------------------------------
# Create a date string

sub create_date {
    my ($self, $time) = @_;
    $time = time() unless defined $time;

    # Based on Blosxom 3

    my $num = '01';
    my $months = MONTHS;
    my %month2num = map {substr($_, 0, 3) => $num ++} @$months;

    my $ctime = localtime($time);
    my @names = qw(weekday month day hour24 minute second year);
    my @values = split(/\W+/, $ctime);

    my $date = {};
    while (@names) {
        my $name = shift @names;
        my $value = shift @values;
        $date->{$name} = $value;
    }

    $date->{day} = sprintf("%02d", $date->{day});
    $date->{monthnum} = $month2num{$date->{month}};

    my $hr = $date->{hour24};
    if ($hr < 12) {
        $date->{ampm} = 'am';
    } else {
        $date->{ampm} = 'pm';
        $hr -= 12;
    }

    $hr = 12 if $hr == 0;
    $date->{hour} = sprintf("%02d", $hr);

    return $date;
}

#----------------------------------------------------------------------
# Add date to extra data read from file

sub extra_data {
    my ($self, $data) = @_;

    $data = $self->SUPER::extra_data($data);

    unless (exists $self->{date}) {
        my ($filename, $extra) = $self->id_to_filename($data->{id});
        my $modtime = $self->{wf}->get_modtime($filename);
        $data->{date} = $self->create_date($modtime);
    }
    
    return $data;
}

#----------------------------------------------------------------------
# Extract id from a filename

sub filename_to_id {
    my ($self, $filename) = @_;

    my @ids;
    my $info = $self->info_from_filename($filename);

    push(@ids, $self->{wf}->basename_to_id($info->{dir}));
    push(@ids, $info->{year} . $info->{monthnum} . $info->{post})
        if $info->{year} !~ /^0+$/;

    return $self->{wf}->path_to_id(@ids);
}

#----------------------------------------------------------------------
# Get the id for a new post

sub generate_id {
    my ($self, $parentid, $field) = @_;

    my $subfolders = 0;
    my $sort_field = '-id';

    my $seq = '0' x $self->{index_length};
    my $pattern = "[0-9]" x $self->{index_length};

    my $date = $self->create_date();
    my $dir = $self->get_repository($parentid);
    $dir = join('/', $dir, "y$date->{year}", "m$date->{monthnum}");

    my $visitor = $self->{wf}->visitor($dir, $subfolders, $sort_field);

    while (defined (my $file = &$visitor)) {
        next unless $self->valid_filename($file);

        my $id = $self->filename_to_id($file);
        my ($parentval, $val) = $self->{wf}->split_id($id);
    	$seq = $val if $val gt $seq;
    }

    $seq = "$date->{year}$date->{monthnum}$seq" if $seq < 1;
    $seq ++;

    return $self->{wf}->path_to_id($parentid, $seq);
}

#----------------------------------------------------------------------
# Construct the names of the index files above a particular file

sub get_index_files {
    my ($self, $filename) = @_;

    my @dirs = split('/', $filename);
    pop(@dirs); # Lose filename

    my @index_files;
    while (@dirs) {
        my $index_file = "$self->{index_name}.$self->{extension}";
        $index_file = join('/', @dirs, $index_file);
        push(@index_files, $index_file) if $index_file ne $filename;

        my $basename = pop(@dirs);
        last if $basename !~ /^[my]\d+$/;
    }

    return @index_files;
}

#----------------------------------------------------------------------
# Construct data fields for index

sub get_index_data {
    my ($self, $index_file) = @_;

    my $data = {};
    $data->{id} = $self->filename_to_id($index_file);
    $data->{url} = $self->filename_to_url($index_file);
    $data->{title} = $self->title_from_filename($index_file);
    $data->{body} = '';
    
    return $data;
}

#----------------------------------------------------------------------
# Get the index file name

sub get_index_name {
    my ($self, $filename, $levels) = @_;

    my @dirs = split('/', $filename);
    pop(@dirs) while $levels -- > 0;

    my $index_file = "$self->{index_name}.$self->{extension}";
    $index_file = join('/', @dirs, $index_file);

    return $index_file;
}

#----------------------------------------------------------------------
# What kind of file is this? Used to select template.

sub get_kind_file {
    my ($self, $filename) = @_;

    my @dirs = split('/', $filename);
    my $basename = pop(@dirs);

    my $kind;
    my $type = $self->get_type();
    if ($basename =~ /^$type/) {
        $kind = 'post';

    } else {
        my $basedir = pop(@dirs);
    
        if ($basedir =~ /^m\d+/) {
            $kind = 'monthindex';
        } elsif ($basedir =~ /^y\d+/) {
            $kind = 'yearindex';
        } else {
            $kind = 'blogindex';
        }
    }

    return $kind;
}

#---------------------------------------------------------------------------
# Get the names of the templates used to render the data

sub get_templates {
    my ($self, $filename, $data) = @_;
           
    my $kind_template = $self->get_kind_file($filename);
    $kind_template = 'subtemplate' if $kind_template eq 'post';
        
    my $subtemplate = "$self->{template_dir}/$self->{$kind_template}";
    $subtemplate = $self->{nt}->mask_template($data, $subtemplate);
    
    my $template;
    if (-e $filename) {
        $template = $filename;
    } else {
        my @index_files = $self->get_index_files($filename);
        $template = pop(@index_files);
    }

    $template = $self->{nt}->parse($template, $subtemplate);
    return $template;
}

#----------------------------------------------------------------------
# Return 1 if this datatype has subfolders

sub has_subfolders {
    my ($self) = @_;
    return 1;
}

#----------------------------------------------------------------------
# Extract id from a filename

sub id_to_filename {
    my ($self, $id) = @_;

    my ($filename, $extra) = $self->SUPER::id_to_filename($id);

    if ($extra) {
        my @extra = $self->{wf}->id_to_path($extra);
        my $seq = shift(@extra);
        $extra = $self->{wf}->path_to_id(@extra);

        my ($repository, $basename) = $self->{wf}->split_filename($filename);
        my $info = $self->info_from_seq($seq);

        my @path = ($repository);
        push(@path, "y$info->{year}") unless $info->{year} =~ /^0+$/;
        push(@path, "m$info->{monthnum}") unless $info->{monthnum} =~ /^0+$/;

        my $path = $info->{post} =~ /^0+$/ ? $self->{index_name}
                                           : "post$info->{post}";
        $path .= ".$self->{extension}";

        $filename = join('/', @path, $path);
    }

    return ($filename, $extra);
}

#----------------------------------------------------------------------
# Infer what we can about a file from its name alone

sub info_from_filename {
    my ($self, $filename) = @_;

    my $info = {year => '0000', monthnum => '00'};
    $info->{post} = '0' x $self->{index_length};
    
    my @dirs = split(/\//, $filename);
    my $basename = pop(@dirs);
    $info->{post} = $1 if $basename =~ /^post(\d+)/;

    while (defined($_ = pop(@dirs))) {
        if (/^y(\d+)/) {
            $info->{year} = $1;
        } elsif (/^m(\d+)/) {
            my $months = MONTHS;
            $info->{monthnum} = $1;
            $info->{month} = $months->[$info->{monthnum}-1];
        } else {
            push(@dirs, $_);
            last;
        }
    }

    $info->{dir} = join('/', @dirs);
    return $info;
}

#----------------------------------------------------------------------
# Extract info from sequence number

sub info_from_seq {
    my ($self, $seq) = @_;
    return unless $seq;

    die "Invalid sequence number: $seq\n"
	unless length($seq) == $self->{index_length} + 6;

    my $info = {};

    my $months = MONTHS;
    $info->{year} = substr($seq, 0, 4);
    $info->{monthnum} = substr($seq, 4, 2);
    $info->{month} = $months->[$info->{monthnum}-1];
    $info->{post} = substr($seq, 6);

    return $info;
}

#----------------------------------------------------------------------
# Construct a title from an archive directory name

sub title_from_filename {
    my ($self, $filename) = @_;

    my $title;
    my $info = $self->info_from_filename($filename);

    if ($info->{post} !~ /^0+$/) {
    	$title = "Archived post";
    } elsif ($info->{monthnum}  !~ /^0+$/) {
    	$title = "Archive for $info->{month}";
    } elsif ($info->{year} !~ /^0+$/) {
    	$title = "Archive for $info->{year}";
    } else {
    	$title = "Recent posts";
    }

    return $title;
}

#----------------------------------------------------------------------
# Create the blog index

sub update_blogindex {
    my ($self, $filename, $request, $record) = @_;

    my $data = {};
    my $index_file = $self->get_index_name($filename, 3);
    $data->{secondary} = $self->build_secondary($index_file, $request);

    if ($data->{secondary}) {
        if (@{$data->{secondary}{data}} > $self->{max_entries}) {
            pop(@{$data->{secondary}{data}});
        }
    
        $data->{pagelinks} = $self->build_pagelinks($index_file, $record);
        $self->write_file($index_file, $data);
    }
    
    return;
}

#----------------------------------------------------------------------
# Update indexes after a post has been changed

sub update_files {
    my ($self, $filename, $request, $skip) = @_;

    my $record = $self->update_postindex($filename, $request, 1);
    $record = $self->update_postindex($filename, $record, 2);
    
    $self->update_blogindex($filename, $request, $record);

    my $id = $self->filename_to_id($filename);
    my ($parentid, $seq) = $self->{wf}->split_id($id);
    $self->write_rss($parentid);

    return;
}

#----------------------------------------------------------------------
# Update the two levels of indexes of posts

sub update_postindex {
    my ($self, $filename, $record, $level) = @_;
   
    my $index_file = $self->get_index_name($filename, $level);
    my $index_data = $self->get_index_data($index_file);

    my $data = {};
    $data->{meta} = $self->build_meta($index_file, $index_data);
    $data->{primary} = $self->build_primary($index_file, $index_data);
    $data->{secondary} = $self->build_secondary($index_file, $record);

    $data->{pagelinks} = '';
    $data->{commandlinks} = '';
    $data->{parentlinks} = $self->build_parentlinks($index_file, $index_data);

    if ($data->{secondary}) {  
        if (@{$data->{secondary}{data}} == 0) {
            $self->{wf}->remove_file($index_file);
            
            $index_data->{oldid} = $index_data->{id};
            delete $index_data->{id};

        } else {
            $self->write_file($index_file, $data);            
        }
    }
    
    return $index_data;
}

#----------------------------------------------------------------------
# Return boolean result indicating if this is a valid filename

sub valid_filename {
    my ($self, $filename) = @_;

    my ($repository, $basename) = $self->{wf}->split_filename($filename);
    return $basename =~ /^post\d+\.$self->{extension}$/;
}

#---------------------------------------------------------------------------
# Write a record to disk as a file

sub write_primary {
    my ($self, $filename, $request) = @_;

    my $data = {};
    $data->{meta} = $self->build_meta($filename, $request);
    $data->{primary} = $self->build_primary($filename, $request);
    $data->{pagelinks} = '';
    $data->{parentlinks} = $self->build_parentlinks($filename, $request);
    $data->{commandlinks} = $self->build_commandlinks($filename, $request);
 
    my $skip = 0;
    $self->write_file($filename, $data);
    $self->update_files($filename, $request, $skip);
  
    return;
}

1;
