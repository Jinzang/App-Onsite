use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Store data in a perl dump file

package CMS::Onsite::DumperData;

use Data::Dumper;
use base qw(CMS::Onsite::FileData);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    return $pkg->SUPER::parameters();
}

#----------------------------------------------------------------------
# Read data from a disk file

sub read_primary {
    my ($self, $filename) = @_;

    my $text = $self->{wf}->reader($filename);
    die "Couldn't read $filename\n" unless $text;

    # Untaint and evaluate
    my $hash;
    my ($expr) = $text =~ /^(.*)$/s;
    eval $expr;

    $hash->{id} = $self->filename_to_id($filename);
    return $hash;
}

#----------------------------------------------------------------------
# Write data to disk as a file

sub write_primary {
    my ($self, $filename, $hash) = @_;

    delete $hash->{id} if exists $hash->{id};
    delete $hash->{oldid} if exists $hash->{oldid};

    my $dumper = Data::Dumper->new([$hash], ['hash']);
    my $output = $dumper->Dump();

    $self->{wf}->writer($filename, $output);
    return;
}

1;
