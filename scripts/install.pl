use strict;
use warnings;

use Cwd;
use IO::Dir;
use IO::File;
use Data::Dumper;

# Values for script parameters
# You can change the values or add new ones

my %parameters = (
                  group => '',
                  permissions => 0666,
                 );

# Set directory to one containing this script

my $dir = $0;
$dir =~ s{/?[^/]*$}{};
$dir ||= '.';

chdir $dir or die "Cannot cd to $dir";

# Get target directory from command line

my $target = shift(@ARGV) || rel2abs('../test');
$target =~ s/\/$//;

# Set reasonable defaults for parameters that aren't set above

my %defaults = (
                data_dir => rel2abs($target),
                config_file => "$target/editor.cfg",
                template_dir => rel2abs('../templates'),
                data_registry => 'data.reg',
                command_registry => 'command.reg',
               );

%parameters = (%defaults, %parameters);

# Install

my $source = rel2abs('../site');
my $library = rel2abs('../lib');

erase_target($target, %parameters);
copy_site($source, $target, $library, %parameters);

#----------------------------------------------------------------------
# Return a list of all the files in a directory

sub all_files {
    my ($dir) = @_;   
    my $dd = IO::Dir->new($dir) or die "Couldn't open $dir: $!";

    my @files;
    while (defined (my $file = $dd->read())) {
        next if -d $file;
        push(@files, $file);
    }

    $dd->close;
    return @files;
}

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
# Edit script and copy new version to output

sub copy_script {
    my ($input, $output, $library, %parameters) = @_;
    
    # Read input file
    my $in = IO::File->new($input, 'r') or die "Can't read $input";
    my $text = do {local $/; <$in>};
    close $in;
    
    # Change shebang line
    my $perl = `/usr/bin/which perl`;
    chomp $perl;
    $text =~ s/\#\!(\S+)/\#\!$perl/;

    # Change use lib line
    if ($text =~ /use lib/) {
        $text  =~ s/use lib \'(\S+)\'/use lib \'$library\'/;
    }
    
    # Set parameters
    if ($text =~ /my \$parameters/) {
        my $dumper = Data::Dumper->new([\%parameters], ['parameters']);
        my $parameters = $dumper->Dump();    
        $text =~ s/my \$parameters;/my $parameters/;
    }
    
    # Write output file  
    my $out = IO::File->new($output, 'w') or die "Can't write to $output";
    print $out $text;
    close $out;

    return;
}

#----------------------------------------------------------------------
# Copy initial version of website to target

sub copy_site {
    my ($source, $target, $library, %parameters) = @_;   

    foreach my $file (all_files($source)) {
        my $input = "$source/$file";
        my $output = "$target/$file";

        my $permissions;
        if ($input =~ /\.cgi$/) {
            copy_script($input, $output, $library, %parameters);
            $permissions = ($parameters{permissions} & 0775) | 0111;

        } else {
            copy_file($input, $output);
            $permissions = $parameters{permissions};
        }

        set_group($output, $parameters{group});
        chmod($permissions, $output);
    }

    return;
}

#----------------------------------------------------------------------
# Erase target directory

sub erase_target {
    my ($target, %parameters) = @_;
    
    my $return_code = system("/bin/rm -rf $target");
    die "Couldn't delete $target: $!" if $return_code;
    
    mkdir ($target) or die "Couldn't create $target: $!";

    set_group($target, $parameters{group});
    my $permissions = $parameters{permissions} | 0111;
    chmod($permissions, $target);
    
    return;
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
    my ($filename, $group) = @_;

    return unless -e $filename;
    return unless $group;

    my $gid = getgrnam($group);
    return unless $gid;

    my $status = chown(-1, $gid, $filename);
    return;
}
