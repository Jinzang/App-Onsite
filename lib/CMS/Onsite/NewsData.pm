use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
package CMS::Onsite::NewsData;

use base qw(CMS::Onsite::ListData);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
	    max_news_age => 7,
	    max_news_entries => 7,
	);

    my %base_params = $pkg->SUPER::parameters();
    %parameters = (%base_params, %parameters);

    return %parameters;
}

#----------------------------------------------------------------------
# Add a new file

sub add_data {
    my ($self, $parentid, $request) = @_;

    $request->{time} = time();
    $self->SUPER::add_data($parentid, $request);

    return;
}

#----------------------------------------------------------------------
# Add extra data to the data read from file

sub extra_data {
    my ($self, $hash, $filename) = @_;

    return $self->CMS::Onsite::FileData::extra_data($hash, $filename);
}

#---------------------------------------------------------------------------
# Get the value of a trait

sub get_trait {
    my ($self, $name) = @_;

    my %trait = (
                 index_length => 6,
                );

    return $trait{$name} || $self->SUPER::get_trait($name);
}
#----------------------------------------------------------------------
# Create rss file

sub update_data {
    my ($self, $id, $record) = @_;

    my ($parentid, $seq) = $self->split_id($id);
    $self->write_rss($parentid);

    return;
}

#----------------------------------------------------------------------
# Filter records before writing

sub write_secondary {
    my ($self, $filename, $records) = @_;

    my $cutoff = time() - 86400 * $self->{max_news_age};

    my @new_records;
    foreach my $record (@$records) {
        my $delta = $record->{time} - $cutoff;
        next if $delta < 0;
        last if @new_records >= $self->{max_news_entries};

        push (@new_records, $record);
    }

    $self->SUPER::write_secondary($filename, \@new_records);
    return;
}


1;
