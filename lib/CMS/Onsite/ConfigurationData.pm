use strict;
use warnings;
use integer;

package CMS::Onsite::ConfigurationData;

use base qw(CMS::Onsite::FileData);

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
# Get field information (stub)

sub field_info {
    my ($self) = @_;

	my @info;
	my $title = '';
	my $lines = $self->{cf}->read_lines();

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

#---------------------------------------------------------------------------
# Set the traits of this data class

sub get_trait {
    my ($self, $name) = @_;

	my %trait = (
                 extension => 'cfg',
                 summary_field => 'data',
                 subtypes => [],
                 commands => [qw(edit)]
                );

    return $trait{$name} || $self->SUPER::get_trait($name);
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

	my %record = $self->{cf}->read_file();
	return \%record;
}

#----------------------------------------------------------------------
# Write records to configuration file

sub write_primary {
	my ($self, $filename, $record) = @_;

	$self->{cf}->write_file($record);
	return;
}

#----------------------------------------------------------------------
# Update after configuration file change (no-op)

sub update_data {
	my ($self, $id, $records) = @_;

	return;
}

1;
