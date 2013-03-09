use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Partial implementation of Blosxom data, used fro blog conversion

package App::Onsite::BlosxomData;

use base qw(App::Onsite::FileData);

use constant MONTHS => [qw(January February March April May June July
			   August September October November December)];

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
	    extension => 'txt',
        wf => {DEFAULT => 'App::Onsite::Support::WebFile'},
	);
}

#-----------------------------------------------------------------------
# Create a date string

sub create_date {
    my ($self, $time) = @_;
    $time = time() unless defined $time;

    # Based on Blosxom 3

    my $num = '01';
    my $months = MONTHS;
    my %month2num = map {substr($_, 0, 3) => $num ++} @$months;

    my $ctime = localtime($time);
    my @names = qw(weekday month day hour24 minute second year);
    my @values = split(/\W+/, $ctime);

    my $date = {};
    while (@names) {
        my $name = shift @names;
        my $value = shift @values;
        $date->{$name} = $value;
    }

    $date->{day} = sprintf("%02d", $date->{day});
    $date->{monthnum} = $month2num{$date->{month}};

    my $hr = $date->{hour24};
    if ($hr < 12) {
        $date->{ampm} = 'am';
    } else {
        $date->{ampm} = 'pm';
        $hr -= 12;
    }

    $hr = 12 if $hr == 0;
    $date->{hour} = sprintf("%02d", $hr);

    return $date;
}

#----------------------------------------------------------------------
# Add date to extra data read from file

sub extra_data {
    my ($self, $data, $filename) = @_;

    $data = $self->SUPER::extra_data($data);
    my $modtime = $self->{wf}->get_modtime($filename);
    $data->{date} = $self->create_date($modtime);

    return $data;
}

#----------------------------------------------------------------------
# Convert filename to id

sub filename_to_id {
	my ($self, $filename) = @_;

    $filename =~ s/\.[^\.]*$//;
    $self->abs2rel($filename, $self->{top_dir});
    return $self->{wf}->basename_to_id($filename);
}

#----------------------------------------------------------------------
# Return a closure that returns a record for each file

sub get_next {
    my ($self, $directory) = @_;

    my $maxlevel = 100;
    my $sort_order = 'date';
    my $visitor = $self->{wf}->($directory, $maxlevel, $sort_order);
    
    return sub {
        my $ext;
    	my $filename;

    	for (;;) {
    	    $filename = &$visitor();
            return unless defined $filename;
            last if $self->valid_filename($filename);
        }

        my $data = $self->read_primary($filename);
        $data = $self->extra_data($data, $filename);
        
        return $data;
   };
}

#----------------------------------------------------------------------
# Read data from file

sub read_primary {
    my ($self, $filename) = @_;

    my $input = $self->{wf}->reader($filename);
    my @input = split(/\n/, $input);

    my %data;
    $data{id} = $self->filename_to_id($filename);
    $data{title} = shift(@input);
    # TODO: read header comments
    $data{body} = join("\n", @input);

    return \%data;
}

1;