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
               'lib' => 'lib',
               'site' => '',
               'templates' => 'templates',
               };

#----------------------------------------------------------------------
# Main routine

chdir("$Bin/..") or die "Couldn't cd to $Bin directory\n";

my $out = IO::File->new($output, 'a');
copy_script($out, $script);

my $visitor = get_visitor($include);

while (my $file = &$visitor) {
    bundle_file($include, $out, $file);
}

close($out);
chmod(0775, $script);

#----------------------------------------------------------------------
# Append a text file to the bundle

sub append_bin_file {
    my ($out, $file) = @_;
    
    my $in = IO::File->new($file, 'r') or
        die "Couldn't read $file: $!\n";

    binmode $in;
    my $buf;
        
    while (read($in, $buf, 60*57)) {
        print $out, encode_base64($buf);
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
    
    close($in);
    return;
}

#----------------------------------------------------------------------
# Add a file, prefaced with a comment indicating its name and type

sub bundle_file {
    my ($mapping, $out, $file) = @_;
    
    my $bin = -B $file ? 'b' : 't';
    my $new_name = map_filename($mapping, $file);
    print $out "#--%X--%X $bin $new_name\n";

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
    print $out "__DATA__";
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
# Map filename to name on new system

sub map_filename {
    my ($mapping, $file) = @_;
    
    my @path = split(/\//, $file);
    my $dir = shift(@path);
    
    if (exists $mapping->{$dir}) {
        unshift(@path, $mapping->{$dir}) if $mapping->{$dir};
        $file = join('/', @path);
    }
        
    return $file;
}