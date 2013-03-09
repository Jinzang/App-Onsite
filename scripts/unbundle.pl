use strict;
use warnings;

use Cwd;
use IO::Dir;
use IO::File;
use Data::Dumper;
use MIME::Base64 qw(decode_base64);

our $modeline;

# Values for script parameters
# You can change the values or add new ones

my $parameters = {
                  group => '',
                  permissions => 0666,
                 };

# Install

my $where = get_where();
$parameters = set_parameters($where. $parameters);
copy_site($where, $parameters);

#----------------------------------------------------------------------
# Create a copy of the .htaccess file

sub copy_access {
    my ($file, $text) = @_;
    
    my $out = IO::File->new($file, 'w') or die "Can't write $file";
    
    my $password = $file;
    $password =~ s/htaccess$/htpasswd/;
    
    $text =~ s/AuthUserFile\s+(\S+)/AuthUserFile $password/;
    print $out $text;
    
    return;
}

#----------------------------------------------------------------------
# Create a copy of the input file

sub copy_file {
    my ($mode, $file, $text) = @_;
    
    my $out = IO::File->new($file, 'w') or die "Can't write $file";

    if ($mode eq 'b') {
        binmode($out) ;
        my @lines = split(/\n/, $text);
        foreach my $line (@lines) {
            print $out decode_base64($line);
        }

    } else {
        print $out $text;        
    }
    
    close($out);
    return;
}

#----------------------------------------------------------------------
# Edit script and copy new version to output

sub copy_script {
    my ($file, $text, $where, $parameters) = @_;
        
    # Change shebang line
    my $perl = `/usr/bin/which perl`;
    chomp $perl;
    $text =~ s/\#\!(\S+)/\#\!$perl/;

    # Change use lib line
    if ($text =~ /use lib/) {
        $text  =~ s/use lib \'(\S+)\'/use lib \'$where->{library}\'/;
    }
    
    # Set parameters

    $parameters = update_parameters($file, $parameters);
    
    if ($text =~ /my \$parameters/) {
        my $dumper = Data::Dumper->new([$parameters], ['parameters']);
        my $parameters = $dumper->Dump();    
        $text =~ s/my \$parameters;/my $parameters/;
    }
    
    # Write output file  
    my $out = IO::File->new($file, 'w') or die "Can't write to $file";
    print $out $text;
    close $out;

    return;
}

#----------------------------------------------------------------------
# Copy initial version of website to target

sub copy_site {
    my ($where, $parameters) = @_;   

    while (my ($mode, $file, $text) = next_file()) {
        create_dirs($file, $parameters);
        
        my $permissions;
        if ($file =~ /\.cgi$/) {
            copy_script($file, $text, $where, $parameters);
            $permissions = ($parameters->{permissions} & 0775) | 0111;

        } elsif ($file =~/\.htaccess$/) {
            copy_access($file, $text);
            $permissions = $parameters->{permissions} & 0775;
            
        } else {
            copy_file($mode, $file, $text);
            $permissions = $parameters->{permissions};
        }
    
        set_group($file, $parameters->{group});
        chmod($permissions, $file);
    }

    return;
}

#----------------------------------------------------------------------
# Check path and create directories as necessary

sub create_dirs {
    my ($file, $parameters) = @_;

    my @dirs = split(/\//, $file);
    pop @dirs;
    
    my $path = getcwd();  
    foreach my $dir (@dirs) {
        next if $dir eq '.';

        $path .= "/$dir";

        if (! -d $path) {
            mkdir ($path) or die "Couldn't create $path: $!\n";
            set_group($path, $parameters->{group});
			my $permissions = $parameters->{permissions} | 0111;
            chmod($permissions, $path);
        }
    }

    return;
}

#----------------------------------------------------------------------
# Get the locations of the directories we need

sub get_where {
    # Set directory to one containing this script
    
    my $dir = $0;
    $dir =~ s{/?[^/]*$}{};
    $dir ||= '.';
    
    chdir $dir or die "Cannot cd to $dir";
    
    my $where = {};
    $where->{target} = getcwd();
    $where->{library} = rel2abs('lib');
    $where->{templates} = rel2abs('templates');
    
    return $where;    
}

#----------------------------------------------------------------------
# Get the name and contents of the next file

sub next_file {

    $modeline ||= <DATA>;
    my ($comment, $mode, $file) = split(' ', $modeline);
    
    my $text = '';
    while (<DATA>) {
        if (/^\#--\%X--\%X/) {
            $modeline = $_;
            last;

        } else {
            $text .= $_;
        }
    }
    
    return ($mode, $file, $text);
}

#----------------------------------------------------------------------
# Convert relative filename to absolute

sub rel2abs {
    my ($filename) = @_;

    my @path;
    my $base_dir = getcwd();
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

#----------------------------------------------------------------------
# Set parameters for script

sub set_parameters {
    my ($where, $parameters) = @_;

    # Set reasonable defaults for parameters that aren't set above
    # TODO: set base_url from script url
    
    my %defaults = (
                    script_url => '*.cgi',
                    data_dir => $where->{target},
                    config_file => "$where->{target}/*.cfg",
                    template_dir => $where->{templates},
                    valid_read => [$where->{templates}],
                    valid_write => [$where->{target}],
                    data_registry => '*_data.reg',
                    command_registry => '*_commands.reg',
                   );
    
    %$parameters = (%defaults, %$parameters);
    return $parameters;
}

#----------------------------------------------------------------------
# Update parameters by substituting for wild card

sub update_parameters {
    my ($file, %parameters) = @_;

    my ($basename) = $file =~ /(\w+)\.\w+$/;
    
    while (my ($name, $value) = each %parameters) {
        $value =~ s/\*/$basename/;
        $parameters{$name} = $value;        
    }

    return %parameters;
}