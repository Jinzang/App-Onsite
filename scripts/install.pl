use strict;
use warnings;

use Cwd;
use IO::Dir;
use IO::File;

# Set directory to one containing this script

my $dir = $0;
$dir =~ s{/?[^/]*$}{};
$dir ||= '.';

chdir $dir or die "Cannot cd to $dir";

# Default values for arguments

my %defaults = (
                script => 'editor.cgi',
                SOURCE => rel2abs('../site'),
                TARGET => rel2abs('../test'),
                TEMPLATES => rel2abs('../template'),
                GROUP => 'adm',
               );

# Install

my %arg = read_arguments(%defaults);
erase_target($arg{TARGET}, $arg{GROUP});
copy_site($arg{SOURCE}, $arg{TARGET}, $arg{GROUP});
copy_script(%arg);

#----------------------------------------------------------------------
# Create a copy of the input file

sub copy_file {
    my ($input, $output) = @_;
    
    my $in = IO::File->new($input, 'r') or die "Can't read $input";
    my $out = IO::File->new($output, 'w') or die "Can't write $output";
    
    my $text = do {local $/; <$in>};
    print $out $text;
    
    return;
}

#----------------------------------------------------------------------
# Copy and edit script

sub copy_script {
    my (%arg) = @_;
    
    my $input = $arg{script};
    my $output = "$arg{TARGET}/$arg{script}";
    
    my $in = IO::File->new($input, 'r')
             or die "Can't read $arg{script}";
             
    my $out = IO::File->new($output, 'w')
              or die "Can't write to $arg{TARGET}";
    
    delete $arg{script};
    my $pattern = join('|', keys %arg);
    
    # TODO: shebang line from /usr/bin/which
    while (<$in>) {
        if (/\#\s*($pattern)/) {
            my $name = $1;
            s/\'\'/\'$arg{$name}\'/;
        }
        
        print $out $_;
    }

    close $in;
    close $out;
    
    set_group($output, $arg{GROUP});
    chmod(0775, $output);   
    return;
}

#----------------------------------------------------------------------
# Copy initial version of website to target

sub copy_site {
    my ($source, $target, $group) = @_;   
    my $dd = IO::Dir->new($source) or die "Couldn't open $source: $!";

    while (defined (my $file = $dd->read())) {
        next unless $file =~ /^([\-\w]+\.?\w*)$/;
        
        my $input = "$source/$1";
        my $output = "$target/$1";

        copy_file($input, $output);
        set_group($output, $arg{GROUP});
        chmod(0664, $output);   
    }

    $dd->close;
    return;
}

#----------------------------------------------------------------------
# Erase target directory

sub erase_target {
    my ($target, $group) = @_;
    
    my $return_code = system("/bin/rm -rf $target");
    die "Couldn't delete $target: $!" if $return_code;
    
    mkdir ($target) or die "Couldn't create $target: $!";
    set_group($target, $group);
    chmod(0775, $target);
    
    return;
}

#----------------------------------------------------------------------
# Read command line arguments

sub read_arguments {
    my (%arg) = @_;
    
    foreach my $arg (@ARGV) {
        if ($arg =~ /=/) {
            my ($name, $value) = split(/=/, $arg);
            $arg{uc($name)} = $value;
        } else {
            $arg{script} = $arg;
        }
    
    }
    
    return %arg;
}

#----------------------------------------------------------------------
# Convert relative filename to absolute

sub rel2abs {
    my ($filename) = @_;

    my @path;
    my $base_dir = getcwd();;
    @path = split(/\//, $base_dir) unless $filename =~ /^\//;
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
# Set the group of a file

sub set_group  {
    my ($self, $filename, $group) = @_;

    return unless -e $filename;
    return unless $group;

    my $gid = getgrnam($group);
    return unless $gid;

    chown(-1, $gid, $filename);
    return;
}
