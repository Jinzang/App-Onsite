use strict;
use warnings;
use integer;

package App::Onsite::ConfigurationData;

use base qw(App::Onsite::FileData);

#----------------------------------------------------------------------
# Get hardcoded default parameter values

sub parameters {
	my ($pkg) = @_;

	my %parameters = (
                        cf => {DEFAULT => 'ConfigFile'},
                     );

    my %base_params = $pkg->SUPER::parameters();
    %parameters = (%base_params, %parameters);
    
    return %parameters;
}

#----------------------------------------------------------------------
# Add extra data to the data read from file

sub extra_data {
    my ($self, $data) = @_;

    my $id = $data->{id};
    $data->{title} = ucfirst("$id Configuration");
    $data->{summary} = "Make changes to the $id configuration";

    return $data;
}

#----------------------------------------------------------------------
# Get field information (stub)

sub field_info {
    my ($self, $id) = @_;

	my ($filename, $extra) = $self->id_to_filename($id);
    die "No secondary data in configuration file: $id" if $extra;

	my @info;
	my $title = '';
 	my $lines = $self->{cf}->read_lines($filename);

	while (my ($value, $field) = $self->{cf}->read_field($lines)) {
		if (defined $field) {
            $title = $field unless $title;
			my $info = {NAME => $field, VALUE => $value, title => $title};
            push (@info, $info);
            $title = '';

		} elsif (defined $value) {
			$title = $value;
            $title =~ s/^\#\s*//;

		} else {
            last;
        }
	}

    return \@info;
}

#----------------------------------------------------------------------
# Get the type of a file given its id

sub id_to_type {
    my ($self, $id) = @_;

	my $type = $self->get_type();    
    return $type;
}

#----------------------------------------------------------------------
# Read records from configuration file

sub read_primary {
	my ($self, $filename) = @_;

	my %record = $self->{cf}->read_file($filename);
    $record{id} = $self->filename_to_id($filename);
  
	return \%record;
}

#----------------------------------------------------------------------
# Write records to configuration file

sub write_primary {
	my ($self, $filename, $record) = @_;

	$self->{cf}->write_file($record, $filename);
	return;
}

1;
