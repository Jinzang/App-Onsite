use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
package App::Onsite::NewsData;

use base qw(App::Onsite::ListData);

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
# Remove old records

sub cull_data {
    my ($self, $records) = @_;

    my $cutoff = time() - 86400 * $self->{max_news_age};

    $records = $self->extract_from_data($records);
    $records = [$records] unless ref $records eq 'ARRAY';

    my @new_records;
    foreach my $record (@$records) {
        my $delta = $record->{time} - $cutoff;
        next if $delta < 0;
        last if @new_records >= $self->{max_news_entries};

        push (@new_records, $record);
    }

    return  {data => \@new_records};
}

#----------------------------------------------------------------------
# Create rss file

sub update_files {
    my ($self, $record, $filename) = @_;

    my $id = $self->filename_to_id($filename);
    my ($parentid, $seq) = $self->{wf}->split_id($id);
    $self->write_rss($parentid);

    return;
}

1;
