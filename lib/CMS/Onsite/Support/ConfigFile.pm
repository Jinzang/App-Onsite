use strict;
use warnings;
use integer;

package CMS::Onsite::Support::ConfigFile;

use base qw(CMS::Onsite::Support::ConfiguredObject);
use IO::File;

#----------------------------------------------------------------------
# Get hardcoded default parameter values

sub parameters {
	my ($self) = @_;

	return (
			config_file => '',
			cache => {DEFAULT => 'CMS::Onsite::Support::CachedFile'},
		   );
}

#----------------------------------------------------------------------
# Read a field or comment from the configuration file

sub read_field {
	my ($self, $lines) = @_;

	my ($value, $field);
	my $line = shift @$lines;

	if (defined $line) {
		if ($line =~ /^[A-Z_]+\s*=/) {
			($field, $value) = split (/\s*=\s*/, $line, 2);
			$field = lc($field);

			while ($line = shift @$lines) {
				if ($line =~ /^[A-Z_]+\s*=/ || $line =~ /^\s*#/) {
					unshift(@$lines, $line);
					last;
				}

				$value .= $line;
			}

		} elsif ($line =~ /^\s*#/) {
			$value = $line;

			while ($line = shift @$lines) {
				if ($line !~ /^\s*#/) {
					unshift(@$lines, $line);
					last;
				}

				$value .= $line;
			}

		} else {
			$value = substr($line, 20);
			die "Data without any field: $value\n";
		}

		$value =~ s/\s+$//;
	}

	return ($value, $field);
}

#----------------------------------------------------------------------
# Read a configuration file into an array of parameters

sub read_file {
    my ($self) = @_;
	return unless $self->{config_file};

	my $cache = $self->{cache}->fetch($self->{config_file});

	unless ($cache) {
		my %record;
		my $lines = $self->read_lines();

		while (my ($value, $field) = $self->read_field($lines)) {
			last unless defined $value;
			next unless defined $field;

			if (exists $record{$field}) {
				if (ref $record{$field}) {
					push(@{$record{$field}}, $value);
				} else {
					$record{$field} = [$record{$field}, $value];
				}

			} else {
				$record{$field} = $value;
			}
		}

		$cache = \%record;
		$self->{cache}->save($self->{config_file}, $cache);
	}

    return %$cache;
}

#----------------------------------------------------------------------
# Read configuration file into an array of lines

sub read_lines {
    my ($self) = @_;

	my @lines;
	if (-e $self->{config_file}) {
		my $in = IO::File->new($self->{config_file}, 'r');
		die "Can't open $self->{config_file}: $!\n" unless $in;

		@lines = <$in>;
		close($in);
	}

	return \@lines;
}

#----------------------------------------------------------------------
# Read and parse a configuration file

sub write_file {
    my ($self, $parameters) = @_;

	my %skip;
	my $lines = $self->read_lines();

	my $out = IO::File->new($self->{config_file}, 'w');
	die "Couldn't open $self->{config_file}: $!\n" unless $out;

	while (my ($value, $field) = $self->read_field($lines)) {
		if (defined $field) {
			next if $skip{$field};
			$skip{$field} = 1;

			my $ufield = uc($field);
			if (exists $parameters->{$field}) {
				my $value = $parameters->{$field};
				my $ref = ref $value;

				if (! $ref) {
					print $out "$ufield = $value\n";

				} elsif ($ref =~ /ARRAY/) {
					$field = uc($field);
					foreach my $subvalue (@$value) {
						print $out "$ufield = $subvalue\n";
					}
				}

			} else {
				print $out "$ufield = $value\n";
			}

		} elsif (defined $value) {
			print $out "$value\n";

		} else {
			last;
		}
	}

	$self->{cache}->free($self->{config_file});
	close($out);

	return;
}

1;

__END__
=head1 NAME

CMS::Onsite::Support::ConfigFile reads and writes the object configuration

=head1 SYNOPSIS

	use CMS::Onsite::Support::ConfigFile;
    my $obj = CMS::Onsite::Support::ConfigFile->new(config_file => 'filename');
	my %parameters = $obj->read_file();
	$obj->write_file(\%parameters);

=head1 DESCRIPTION

This class implements a simple configuration file. It is the default class
used by CMS::Onsite::Support::ConfiguredObject and need not be separately
loaded. The file format is simple: each field starts on it own line and has
the form

    NAME = value

where NAME is the field name in all caps. Trailing whitespace, including the
newline, are deleted from the value. If a field name is used on several
lines, the field is converted to an array with values stored in the order they
appear in the file. Fields can continue over sevaral line. They are terminated
by the next field, a comment, or the end of file. Comments begin on a new line
and start with a # character

    # This is a comment
	# that runs for two lines

=head1 AUTHOR

Bernie Simon, E<lt>bernie.simon@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bernie Simon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
