use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Create an object that handles file operations

package CMS::Onsite::Support::WebFile;

use Cwd;
use IO::Dir;
use IO::File;

use base qw(CMS::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
                    group => '',
					permissions => 0664,
                    valid_read => [],
                    valid_write => [],
		    cache => {DEFAULT => 'CMS::Onsite::Support::CachedFile'},
	);

    return %parameters;
}

#----------------------------------------------------------------------
# Convert absolute fileame to relative

sub abs2rel {
    my ($self, $filename, $base_dir) = @_;

    $base_dir = $self->base_dir($base_dir);
    $filename = $self->rel2abs($filename);

    my @base_path = split(/\//, $base_dir);
    my @file_path = split(/\//, $filename);

    while (@base_path && @file_path) {
        last if $base_path[0] ne $file_path[0];

        shift @base_path;
        shift @file_path;
    }

    my @new_path;
    while(@base_path) {
        push(@new_path, '..');
        shift @base_path;
    }

    push(@new_path, @file_path);
    $filename = join('/', @new_path) || '.';

    return $filename;
}

#----------------------------------------------------------------------
# Get the absolute path to the base directory

sub base_dir {
    my ($self, $base_dir) = @_;

    if (defined $base_dir) {
        $base_dir = $self->rel2abs($base_dir);
    } else {
        $base_dir = getcwd();
    }

    return $base_dir;
}

#----------------------------------------------------------------------
# Check path and create directories as necessary

sub create_dirs {
    my ($self, @dirs) = @_;

    my $path = '.';
    foreach my $dir (@dirs) {
        next if $dir eq '.';

        my ($part) = $dir =~ /^([\w-]*)$/;
        die "Illegal directory: $dir\n" unless $part;
        $path .= "/$part";

        if (! -d $path) {
            mkdir ($path) or die "Couldn't create $path: $!\n";
            $self->set_group($path);
			my $permissions = $self->{permissions} | 0111;
            chmod($permissions, $path);
        }
    }

    return;
}

#----------------------------------------------------------------------
# Get basname (last component) from filename

sub get_basename {
    my ($self, $filename) = @_;

    my ($root, $basename) = $self->split_filename($filename);
    return $basename;
}

#----------------------------------------------------------------------
# Get file modification time if file exists

sub get_modtime {
    my ($self, $filename) = @_;
    return unless -e $filename;

    my @stats = stat($filename);
    my $mtime = $stats[9];

    my ($modtime) = $mtime =~/^(\d+)$/; # untaint
    return $modtime;
}

#----------------------------------------------------------------------
# Check if filename is absolute

sub is_absolute {
    my ($self, $filename) = @_;

    my @path = split(/\//, $filename);
    return @path && $path[0] eq '';
}

#----------------------------------------------------------------------
# Read contents of file

sub reader {
    my ($self, $filename, $binmode) = @_;

    # Check filename and make absolute
    $filename = $self->validate_filename($filename, 'r');

    local $/;
    my $in = IO::File->new($filename, "r");
    die "Couldn't read $filename: $!\n" unless $in;
    $self->set_mode($in, $binmode);

    flock($in, 1);
    my $input = <$in>;
    close($in);

    return $input;
}

#----------------------------------------------------------------------
# Convert relative filename to absolute

sub rel2abs {
    my ($self, $filename, $base_dir) = @_;
    $base_dir = $self->base_dir($base_dir);

    my @path;
    @path = split(/\//, $base_dir) unless $self->is_absolute($filename);
    push(@path, split(/\//, $filename));

    my @newpath = ('');
    while (@path) {
        my $dir = shift @path;
        if ($dir eq '' or $dir eq '.') {
            ;
        } elsif ($dir eq '..') {
            pop(@newpath) if @newpath > 1;
        } else {
            push(@newpath, $dir);
        }
    }

    $filename = join('/', @newpath);
    return $filename;
}

#----------------------------------------------------------------------
# Move to the base directory

sub relocate {
    my ($self, $dir) = @_;

    $dir = $self->untaint_filename($dir);
    chdir($dir) or die "Couldn't move to $dir: $!\n";
    return;
}

#----------------------------------------------------------------------
# Remove a directory and its contents

sub remove_directory {
    my ($self, $directory) = @_;

    $directory = $self->validate_filename($directory, 'w');

    my $return_code = system("/bin/rm -rf $directory");
    die "Couldn't delete $directory: $!\n" if $return_code;

    return;
}

#----------------------------------------------------------------------
# Remove a file

sub remove_file {
    my ($self, $filename) = @_;

    $filename = $self->validate_filename($filename, 'w');
    my $count = unlink($filename);

    die "Couldn't delete $filename: $!\n" unless $count;
    return;
}

#----------------------------------------------------------------------
# Rename a file

sub rename_file {
    my ($self, $oldname, $newname) = @_;

    $oldname = $self->validate_filename($oldname, 'r');
    $newname = $self->validate_filename($newname, 'w');
    
    rename($oldname, $newname) or die "Couldn't rename $oldname: $!\n";

    return;
}

#----------------------------------------------------------------------
# Set the group of a file

sub set_group  {
    my ($self, $filename) = @_;

    return unless -e $filename;
    return unless $self->{group};

    my $group_id = getgrnam($self->{group});
    my ($gid) = $group_id =~ /^(\d+)$/; # untaint
    return unless $gid;

    chown(-1, $gid, $filename);
    return;
}

#----------------------------------------------------------------------
# Set the mode of the file i/o

sub set_mode {
    my ($self, $handle, $binmode) = @_;

    if (defined $binmode) {
        $binmode = ':raw' unless $binmode =~ /^:/;
        binmode($handle, $binmode);
    }

    return;
}

#----------------------------------------------------------------------
# Set the file modification time

sub set_modtime {
    my ($self, $filename, $modtime) = @_;

    utime($modtime, $modtime, $filename) if $modtime;
    return;
}

#----------------------------------------------------------------------
# Split off basename from rest of filename

sub split_filename {
    my ($self, $filename) = @_;

    my @dirs = split(/\//, $filename);
    my $basename = pop(@dirs);
    $filename = join('/', @dirs);

    return ($filename, $basename);
}

#----------------------------------------------------------------------
# Sort files by modification date or name

sub sorted_files {
    my ($self, $sort_field, @unsorted) = @_;

    $sort_field =~ s/^([+-])//;
    my $order = $1 || '+';

    my @sorted;
    my @augmented;
    
    if ($sort_field eq 'date') {
	my @augmented;
	foreach (@unsorted) {
	    push(@augmented, [-M, $_]);
	}
				
    } elsif ($sort_field eq 'id') {
	my @augmented;
	foreach (@unsorted) {
	    my $basename = $self->get_basename($_);
	    push(@augmented, [$basename, $_]);
	}

    } elsif ($sort_field eq 'ext') {
	my @augmented;
	foreach (@unsorted) {
	    my ($ext) = /\.([^\.]*)$/;
	    $ext = '' unless defined $ext;
	    push(@augmented, [$ext, $_]);
	}
    }

    if (@augmented) {
	@augmented = sort {$a->[0] <=> $b->[0]
			   || $b->[1] cmp $a->[1]} @augmented;
	
	@sorted =  map {$_->[1]} @augmented;

    } else {
	@sorted = sort @unsorted;
    }

    @sorted = reverse @sorted if $order eq '-';
    return @sorted;
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
# True if variable is tainted

sub taint_check {
    my ($self, $var) = @_;
    return ! eval { eval("#" . substr($var, 0, 0)); 1 };
}

#----------------------------------------------------------------------
# Check if the filename is under a valid directory

sub under_any_dir {
    my ($self, $filename, $mode) = @_;

    my $valid_dirs;
    if ($mode eq 'r') {
        $valid_dirs = $self->{valid_read};
    } else {
        $valid_dirs = $self->{valid_write};
    }

    if ($valid_dirs) {
        my $match = 0;
        my $path = $self->rel2abs($filename);

        foreach my $dir (@$valid_dirs) {
            return 1 if ($self->abs2rel($path, $dir) !~ /^\.\./);
        }
    }

    return;
}

#----------------------------------------------------------------------
# Make sure filename passes taint check

sub untaint_filename {
    my ($self, $filename) = @_;

    $filename = $self->rel2abs($filename);
    my ($newname) = $filename =~ m{^([-\w\./]+)$};

    die "Illegal filename: $filename\n" unless $newname;
    die "Tainted filename: $filename\n" if $self->taint_check($newname);

    return $newname;
}

#----------------------------------------------------------------------
# Check to make sure filename is under a valid directory

sub validate_filename {
    my ($self, $filename, $mode) = @_;

    my $valid;
    if ($mode eq 'r') {
        $valid = $self->under_any_dir($filename, 'r') ||
                 $self->under_any_dir($filename, 'w');
    } else {
        $valid = $self->under_any_dir($filename, 'w') &&
                 ! $self->under_any_dir($filename, 'r');
    }

    die "Invalid filename: $filename\n" unless $valid;
    return $self->untaint_filename($filename);
}

#----------------------------------------------------------------------
# Return a closure that visits files in a directory in reverse order

sub visitor {
    my ($self, $dir, $subfolders, $sort_field) = @_;

    my @dirlist;
    my @filelist;
    $dir = $self->validate_filename($dir, 'r');

    if (-e $dir) {
        push(@dirlist, $dir);
        push(@filelist, $dir) if $subfolders;
    }

    return sub {
        for (;;) {
            my $file = shift @filelist;
            return $file if defined $file;

            my $dir = shift @dirlist;
            return unless defined $dir;

            my $dd = IO::Dir->new($dir) or die "Couldn't open $dir: $!\n";

            # Find matching files and directories

            while (defined (my $file = $dd->read())) {
                next unless $file =~ /^([a-z][\-\w]*\.?\w*)$/;

                my $path = "$dir/$1";
                push(@filelist, $path);
				push(@dirlist, $path) if $subfolders && -d $path;
            }

            $dd->close;

	    # Sort files so that most recently modified are first

            @filelist = $self->sorted_files($sort_field, @filelist);
            @dirlist = $self->sorted_files($sort_field, @dirlist);
        }
    };
}

#----------------------------------------------------------------------
# Write file to disk

sub writer {
    my ($self, $filename, $output, $binmode) = @_;
    $filename = $self->abs2rel($filename);

    # Check path and create directories as necessary

    my @dirs = split(/\//, $filename);
    pop @dirs;
    $self->create_dirs(@dirs);

    # Check filename and make absolute
    $filename = $self->validate_filename($filename, 'w');

    # Invalidate cache, if any
    $self->{cache}->free($filename);
    
    # Write file

    my $modtime = $self->get_modtime($filename);

    my $out = IO::File->new($filename, "w");
    die "Couldn't write $filename: $!" unless $out;
    $self->set_mode($out, $binmode);

    flock($out, 2);
    print $out $output if defined $output;
    close($out);

    $self->set_modtime($modtime);
    $self->set_group($filename);
    chmod($self->{permissions}, $filename);

    return;
}

1;

__END__
=head1 NAME

CMS::Onsite::Support::WebFile encapsulates file i/o for CMS::Onsite

=head1 SYNOPSIS

    use CMS::Onsite::Support::WebFile;
    my $binmode = 0;
    my $subfolders = 1;
    my $sort_field = 'id';
    my $obj = CMS::Onsite::Support::WebFile->new(valid_write => [$dir]);
    my $visitor = $obj->visitor($dir, $subfolders, $sort_field);
    while (my $file = &$visitor()) {
        my $text = $obj->reader($file, $binmode);
        $obj->writer($file, $data, $binmode);
    }

=head1 DESCRIPTION

This class encapsulates the file i/o performed by Onsite::Editor. All file
access is checked against a list of directories to see if Stiki is allowed
to read or write to the directory. If the access is not in a valid directory,
an error is thrown.

=head1 AUTHOR

Bernie Simon, E<lt>bernie.simon@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bernie Simon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
