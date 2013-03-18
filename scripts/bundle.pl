#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use IO::File;
use IO::Dir;
use MIME::Base64  qw(encode_base64);

#----------------------------------------------------------------------
# Configuration

my $output = 'scripts/unbundle.cgi';
my $script = 'scripts/unbundle.pl';

my $include = {
               'site' => '',
               'templates' => 'templates',
               'lib' => 'Lib',
               };

#----------------------------------------------------------------------
# Main routine

chdir("$Bin/..") or die "Couldn't cd to $Bin directory\n";

my $out = IO::File->new($output, 'w');
copy_script($out, $script);
include_dirs($out, $include);

my $visitor = get_visitor($include);

while (my $file = &$visitor) {
    bundle_file($include, $out, $file);
}

close($out);
chmod(0775, $output);

#----------------------------------------------------------------------
# Append a text file to the bundle

sub append_binary_file {
    my ($out, $file) = @_;
    
    my $in = IO::File->new($file, 'r') or
        die "Couldn't read $file: $!\n";

    binmode $in;
    my $buf;
        
    while (read($in, $buf, 60*57)) {
        print $out encode_base64($buf);
    }

    close($in);
    return;
}

#----------------------------------------------------------------------
# Append a text file to the bundle

sub append_text_file {
    my ($out, $file) = @_;
    
    my $in = IO::File->new($file, 'r') or
        die "Couldn't read $file: $!\n";

    while (defined (my $line = <$in>)) {
        print $out $line;
    }
    
    print $out "\n";
    close($in);
    return;
}

#----------------------------------------------------------------------
# Add a file, prefaced with a comment indicating its name and type

sub bundle_file {
    my ($mapping, $out, $file) = @_;
    
    my $bin = -B $file ? 'b' : 't';
    print $out "#--%X--%X $bin $file\n";

    if ($bin eq 'b') {
        append_binary_file($out, $file);
    } else {
        append_text_file($out, $file)
    }
}

#----------------------------------------------------------------------
# Copy the script to start

sub copy_script {
    my ($out, $script) = @_;
    
    append_text_file($out, $script);
    print $out "__DATA__\n";
    return;
}

#----------------------------------------------------------------------
# Return a closure that visits files in a directory in reverse order

sub get_visitor {
    my ($include) = @_;
    
    my @dirlist = keys %$include;
    my @filelist;

    return sub {
        for (;;) {
            my $file = shift @filelist;
            return $file if defined $file;

            my $dir = shift @dirlist;
            return unless defined $dir;

            my $dd = IO::Dir->new($dir) or die "Couldn't open $dir: $!\n";

            while (defined (my $file = $dd->read())) {
                next if $file eq '.' || $file eq '..';
                $file = "$dir/$file" if $dir;

                if (-d $file) {
                    push(@dirlist, $file);
                } else {
                    push(@filelist, $file);                    
                }
            }

            $dd->close;
        }
    };
}

#----------------------------------------------------------------------
# Save names of directories to output file

sub include_dirs {
    my ($out, $include) = @_;
    
    while (my ($source, $target) = each %$include) {
        print $out "#++%X++%X $source $target\n";
    }
    
    return;
}
