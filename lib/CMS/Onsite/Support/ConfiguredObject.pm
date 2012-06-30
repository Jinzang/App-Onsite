use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Create an object whose parameters are read from args and from a file

package CMS::Onsite::Support::ConfiguredObject;

#----------------------------------------------------------------------
# Create new object, configure fields, and create subobjects recursively

sub new {
	my ($pkg, %configuration) = @_;

	my $self = CMS::Onsite::Support::ConfiguredObject->create_object();
	$self = $self->populate_object(\%configuration);

	%configuration = ($self->{cf}->read_file(), %configuration);

	my $obj = $self->load_object($pkg);
	$obj = $obj->populate_object(\%configuration)
		   if $obj->isa('CMS::Onsite::Support::ConfiguredObject');

	return $obj;
}

#----------------------------------------------------------------------
# Get default parameter values

sub parameters {
	my ($self) = @_;
	return (cf => {DEFAULT => 'CMS::Onsite::Support::ConfigFile'});
}

#----------------------------------------------------------------------
# Create an empty object

sub create_object {
	my ($pkg) = @_;

	return bless({}, $pkg);
}

#----------------------------------------------------------------------
# Load a module and create a new object

sub load_object {
	my ($self, $pkg) = @_;

	# Untaint class name
	my ($class) = $pkg =~ /^(\w+(?:\:\:\w+)*)$/;
	die "Invalid class name: $pkg\n" unless $class;

    eval "require $class" or die "$@\n";

	if ($class->isa('CMS::Onsite::Support::ConfiguredObject')) {
		 return $class->create_object();
	} else {
		return $class->new();
	}
}

#----------------------------------------------------------------------
# Set the field values in a new object

sub populate_object {
	my ($self, $configuration) = @_;

	my %parameters = $self->parameters();

	foreach my $field (keys %parameters) {
		if (exists $configuration->{$field}) {
			if (! ref $parameters{$field}) {
				if (! ref $configuration->{$field}) {
					$self->{$field} = $configuration->{$field}
				}

			} elsif (ref $parameters{$field} eq 'ARRAY') {
				if (! ref $configuration->{$field}) {
					$self->{$field} = [$configuration->{$field}];
				} elsif (ref $configuration->{$field} eq 'ARRAY') {
					$self->{$field} = $configuration->{$field};
				}

			} elsif (ref $parameters{$field} eq 'HASH') {
				if (! ref $configuration->{$field}) {
					$self->{$field} = {DEFAULT => $configuration->{$field}};
				} elsif (ref $configuration->{$field} ne 'ARRAY') {
					$self->{$field} = $configuration->{$field};
				}

			}

		} else {
			$self->{$field} = $parameters{$field};
		}

		unless (exists $self->{$field}) {
			my $ref = ref $self;
			die "Field type mismatch for $field in $ref\n";
		}
	}

	foreach my $field (keys %$self) {
		next unless ref $self->{$field} eq 'HASH';

		if (exists $self->{$field}{DEFAULT}) {
			my $subpackage = $self->{$field}{DEFAULT};
			my $subobject = $self->load_object($subpackage);

			$configuration->{$field} = $subobject;
			$self->{$field} = $subobject;

			$self->{$field} = $subobject->populate_object($configuration)
				if $subobject->isa('CMS::Onsite::Support::ConfiguredObject');
		}
	}

	return $self;
}

1;

__END__
=head1 NAME

CMS::Onsite::Support::ConfiguredObject is the base class for configured objects

=head1 SYNOPSIS

	use CMS::Onsite::Support::ConfiguredObject;
    $obj = $pkg->new(par1 => 'val1', par2 => 'val2', );

=head1 DESCRIPTION

The class implements a dependency injection framework. It combines values
passed as parameters with values read from a configuration file. Any subclass
must implement the parameters method, which returns a hash containing the
fields of the class and their default values. If the value of a field is a hash
reference, it indicates that the field is a subobject. If the hash reference
has a field named DEFAULT, that is taken as the default class for the subobject
and will be used if no class name is read from the configuration.

=head1 AUTHOR

Bernie Simon, E<lt>bernie.simon@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bernie Simon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
