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

# Set reasonable defaults for parameters that aren't set above

my %defaults = (
                data_dir => rel2abs('../test'),
                config_file => rel2abs('../test/editor.cfg'),
                template_dir => rel2abs('../templates'),
               );


%parameters = (%defaults, %parameters);

# Install

my $target = shift(@ARGV) || rel2abs('../test');
my @scripts = @ARGV || qw(editor.cgi);
my $source = rel2abs('../site');
my $library = rel2abs('../lib');

erase_target($target, %parameters);
copy_site($source, $target, %parameters);

foreach my $script (@scripts) {
    copy_script($script, '.', $target, $library, %parameters);
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
# Copy and edit script

sub copy_script {
    my ($script, $source, $target, $library, %parameters) = @_;
    
    my $input = "$source/$script";
    my $output = "$target/$script";
    
    # Read inout file
    
    my $in = IO::File->new($input, 'r')
             or die "Can't read $script";

    my $text = do {local $/; <$in>};

    close $in;
    
    # Change shebang line
    my $perl = `/usr/bin/which perl`;
    chomp $perl;
    $text =~ s/\#\!(\S+)/\#\!$perl/;

    # Set use lib line
    $text  =~ s/use lib \'(\S+)\'/use lib \'$library\'/;

    # Set parameters
    my $dumper = Data::Dumper->new([\%parameters], ['parameters']);
    my $parameters = $dumper->Dump();    
    $text =~ s/my \$parameters;/my $parameters/;
    
    # Write output file
    
    my $out = IO::File->new($output, 'w')
              or die "Can't write to $target";
    
    print $out $text;

    close $out;
    
    set_group($output, $parameters{group});
    my $permissions = $parameters{permissions} | 0111;
    chmod($permissions, $output);

    return;
}

#----------------------------------------------------------------------
# Copy initial version of website to target

sub copy_site {
    my ($source, $target, %parameters) = @_;   
    my $dd = IO::Dir->new($source) or die "Couldn't open $source: $!";

    while (defined (my $file = $dd->read())) {
        next unless $file =~ /^([\-\w]+\.?\w*)$/;
        
        my $input = "$source/$1";
        my $output = "$target/$1";

        copy_file($input, $output);
        set_group($output, $parameters{group});
        chmod($parameters{permissions}, $output);   
    }

    $dd->close;
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
    my ($self, $filename, $group) = @_;

    return unless -e $filename;
    return unless $group;

    my $gid = getgrnam($group);
    return unless $gid;

    chown(-1, $gid, $filename);
    return;
}
