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
# Construct pageinks

sub build_pagelinks {
    my ($self, $data) = @_;

    my $id = $data->{id} || '';
    my ($filename, $extra) = $self->id_to_filename($id);
    my $uplinks = $self->get_downlinks($filename);
    
    my $url = $self->id_to_url($id);
    my $links = $self->link_class($uplinks, $url);
   
    return {data => $links};
}


#----------------------------------------------------------------------
# Construct parent links for page

sub build_parentlinks {
    my ($self, $data) = @_;

    my $id = $data->{id} || '';
    my ($filename, $extra) = $self->id_to_filename($id);
    my $uplinks = $self->get_uplinks($filename);
    
    my $url = $self->id_to_url($id);
    my $links = $self->link_class($uplinks, $url);
   
    return {data => $links};
}

#----------------------------------------------------------------------
# Build an empty data set for thr secondary block

sub build_primary {
	my ($self, $request) = @_;

    my %primary;
    while (my ($name, $value) = each %$request) {
        next if $name eq 'data';
        $primary{$name} = $value;
    }
    
    my $type = $self->get_type();
    return {"${type}data" =>  \%primary};
}

#----------------------------------------------------------------------
# Build an empty data set for thr secondary block

sub build_secondary {
	my ($self, $request) = @_;

    return '' unless exists $request->{data};

    my $type = $self->get_type();
    return {"${type}data" => {data => $request->{data}}};
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

    my ($filename, $extra) = $self->id_to_filename($data->{id});
    my $modtime = $self->{wf}->get_modtime($filename);

    $data->{date} = $self->create_date($modtime);
    $data->{count} = 0 unless defined $data->{count};

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
# Get links to dirs in folder containing filename

sub get_downlinks {
    my ($self, $filename) = @_;

    my @dirs = split('/', $filename);
    pop(@dirs);
    my $index_dir = join('/', @dirs);

    my $subfolders = 0;
    my $sort_field = 'date';
    my $visitor = $self->{wf}->visitor($index_dir, $subfolders, $sort_field);

    my @list;
    while (defined(my $path = &$visitor)) {
        my $basename = $self->{wf}->get_basename($path);
        next if $basename !~ /^[my]\d+$/;

        my $index_file = "$self->{index_name}.$self->{extension}";
        my $file = join('/', $path, $index_file);

        my $data = {};
        $data->{title} = $self->title_from_filename($file);
        $data->{url} = $self->filename_to_url($file);

        push(@list, $data);
    }

    return \@list;
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
            $kind = 'postindex';
        } elsif ($basedir =~ /^y\d+/) {
            $kind = 'monthindex';
        } else {
            $kind = 'blogindex';
        }
    }

    return $kind;
}

#---------------------------------------------------------------------------
# Construct the template used to render the data

sub get_templates {
    my ($self, $blockname, $filename, $subtemplate) = @_;
            
    my $id = $self->filename_to_id($filename);
    my ($parentid, $seq) = $self->{wf}->split_id($id);
    
    my $template;
    if ($seq =~ /^\d+$/) {
        my $extra;
        ($template, $extra) = $self->id_to_filename($parentid);
    } else {
        $template = $filename;
    }

    my $subsubtemplate;
    my $kind = $self->get_kind_file($filename);

    if ($kind eq 'post') {
        $subsubtemplate = $self->{add_template};
    } else {
        $subsubtemplate = $self->{"${kind}_template"};
    }

    $subsubtemplate = join('/', $self->{template_dir}, $subsubtemplate);
        
    $template = $self->{nt}->parse($template, $subtemplate);
    $subtemplate = $self->{nt}->parse($subtemplate, $subsubtemplate);
    
    return ($template, $subtemplate);
}

#----------------------------------------------------------------------
# Get list of links for breadcrumb trail

sub get_uplinks {
    my ($self, $filename) = @_;

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

        # TODO: need to generate indexes from id
        $filename = join('/',
                         $repository,
                         "y$info->{year}",
                         "m$info->{monthnum}",
                         "post$info->{post}.html"
                        );
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
    my ($self, $filename, $record) = @_;

    my $sort_field = '-id';
    my $index_file = $self->update_indexfile($filename, 3);

    $self->update_records($index_file, $record, $sort_field, 
                          $self->{max_entries});

    return;
}

#----------------------------------------------------------------------
# Update indexes after a post has been changed

sub update_data {
    my ($self, $id, $data) = @_;

    my ($filename, $extra) = $self->id_to_filename($id);

    my $change = $self->update_postindex($filename, $data);
    $self->update_monthindex($filename) if $change;
    $self->update_blogindex($filename, $data);

    # TODO: fix later
    ##my ($parentid, $seq) = $self->{wf}->split_id($id);
    ##$self->write_rss($parentid);

    return;
}

#----------------------------------------------------------------------
# Create the index file name

sub update_indexfile {
    my ($self, $filename, $levels) = @_;

    my @dirs = split('/', $filename);
    pop(@dirs) while $levels -- > 0;

    my $index_file = "$self->{index_name}.$self->{extension}";
    $index_file = join('/', @dirs, $index_file);

    return $index_file;
}

#----------------------------------------------------------------------
# Update the yearly index of months

sub update_monthindex {
    my ($self, $filename) = @_;

    my $index_file = $self->update_indexfile($filename, 1);

    my $record = {};
    $record->{title} = $self->title_from_filename($index_file);
    $record->{url} = $self->filename_to_url($index_file);
    $record->{id} = $self->filename_to_id($index_file);

    my $sort_field = 'id';
    $index_file = $self->update_indexfile($filename, 2);
    $self->update_records($index_file, $record, $sort_field);

    return;
}

#----------------------------------------------------------------------
# Update the monthly index of posts

sub update_postindex {
    my ($self, $filename, $record) = @_;

    my $index_file = $self->update_indexfile($filename, 1);
    my $change = ! -e $index_file;

    my $sort_field = 'id';
    $self->update_records($index_file, $record, $sort_field);

    return $change;
}

#----------------------------------------------------------------------
# Write blog index

sub update_records {
    my ($self, $index_file, $record, $sort, $limit) = @_;

    my $records = -e $index_file ? $self->read_secondary($index_file) : [];        

    my ($parentid, $seq) = $self->{wf}->split_id($record->{id});
    $record->{id} = $seq;

    $records = $self->{lo}->list_add($records, $record);
    $records = $self->{lo}->list_sort($records, $sort);

    if ($limit && $limit < @$records) {
        my @records = @$records;
        @records = @records[0 .. $limit-1];
        $records = \@records;
    }

    my $data = {};
    $data->{data} = $records;
    $data->{base_url} = $self->{base_url};
    $data->{id} = $self->filename_to_id($index_file);
    $data->{title} = $self->title_from_filename($index_file);

    my $subtemplate = $self->{edit_template};
    $subtemplate = "$self->{template_dir}/$subtemplate";

    $self->write_file('secondary.any',
                      $index_file,
                      $subtemplate,
                      $data);

   return;
}

1;
