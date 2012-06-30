use strict;
use warnings;
use integer;

package CMS::Onsite::Support::RegistryFile;

use base qw(CMS::Onsite::Support::ConfiguredObject);
use IO::File;

#----------------------------------------------------------------------
# Get hardcoded default parameter values

sub parameters {
	my ($self) = @_;

	return (
            template_dir => '',
            data_registry => '',
            command_registry => '',
			cache => {DEFAULT => 'CMS::Onsite::Support::CachedFile'},
		   );
}

#----------------------------------------------------------------------
# Add traits from registry file to object

sub add_traits {
    my ($self, $package) = @_;

    no strict;
    my %traits;

    foreach my $pkg (@{"${package}::ISA"}) {
        %traits = (%traits, $self->add_traits($pkg));
    }

    my @pkg = split(/::/, $package);
    my ($id, $family) = $pkg[-1] =~ /^([A-Z][a-z]*)([A-Z][a-z]*)$/;
    return %traits unless defined $id;

    my $param = lc("${family}_registry");   
    my $filename = $self->{$param};
    return %traits unless defined $filename;

    my $traits = $self->read_data($filename, lc($id));
    return %traits unless defined $traits;
    
    return (%traits, %$traits);
}

#----------------------------------------------------------------------
# Create a new data object of the specified type

sub create_subobject {
    my ($self, $configuration, $filename, $type) = @_;

    my $traits = $self->read_data($filename, $type);

    my ($pkg) = $traits->{class} =~ /^([A-Z][\w:]+)$/;
    eval "require $pkg" or die "$@\n";

    my $subobject = $pkg->new(%$configuration);
    my %traits = $self->add_traits($type);
    
    while (my ($field, $value) = each %traits) {
        $subobject->{$field} = $value;
    }

    return $subobject;
}

#----------------------------------------------------------------------
# Select one field out of the registry

sub project {
    my ($self, $filename, $field) = @_;
    
    my %hash;
    my $registry = $self->read_file($filename);
    
    foreach my $id (keys %$registry) {
        next unless exists $registry->{$id}{$field};
        $hash{$id} = $registry->{$id}{$field};
    }
    
    return \%hash;
}

#----------------------------------------------------------------------
# Read the registry data for the specified type

sub read_data {
    my ($self, $filename, $id) = @_;
    
    my $registry = $self->read_file($filename);
    die "Did not find $id in registry: $filename\n"
        unless exists $registry->{$id};
    
    return $registry->{$id};
}

#----------------------------------------------------------------------
# Read a registry file into a hash of parameters

sub read_file {
    my ($self, $filename) = @_;

    my $pathname = $self->{template_dir};
    $pathname .= '/' unless $pathname =~ m(/$);
    $pathname .= $filename;
    
 	my $cache = $self->{cache}->fetch($pathname);

	unless ($cache) {
		my $in = IO::File->new($pathname, 'r');
		die "Can't open $pathname: $!\n" unless $in;

        my $id;
        my $field;
        my %registry;
        while (<$in>) {
            if (/^\s*#/) {
                # Comment line
                undef $field;
                
            } elsif (/^\s*\[([^\]]*)\]/) {
                # new id
                $id = lc($1);
                die "Duplicate ids: $id\n" if exists $registry{$id};
                
            } elsif (/^[A-Z_]+\s*=/) {
                # new field definition
                my $value;
                ($field, $value) = split (/\s*=\s*/, $_, 2);
                $field = lc($field);
                $value =~ s/\s+$//;
                
                if (exists $registry{$id}{$field}) {
                    if (ref $registry{$id}{$field}) {
                        push(@{$registry{$id}{$field}}, $value);
                    } else {
                        $registry{$id}{$field} = [$registry{$id}{$field}, $value];
                    }
    
                } else {
                    $registry{$id}{$field} = $value;
                }

            } else {
                # continuation of registry field
                die "Undefined field\n" . substr($_, 20) . "\n"
                    unless defined $field;

                s/\s+$//;    
                $registry{$id}{$field} .= "\n$_";
            }
        }

		close($in);
		$cache = \%registry;
		$self->{cache}->save($pathname, $cache);
	}

    return $cache;
}

#----------------------------------------------------------------------
# Search the registry for parameters with a specified value of a field

sub search {
    my ($self, $filename, %query) = @_;
    
    my @ids;
    my $registry = $self->read_file($filename);
    
    foreach my $id (sort keys %$registry) {
        my $match;
        foreach my $field (keys %query) {
            last unless exists $registry->{$id}{$field};
            
            my $value = $query{$field};
            my $entry = $registry->{$id}{$field};
            
            if (ref $entry) {
                $match = 0;
                foreach my $item (@$entry) {
                    if ($item eq $value) {
                        $match = 1;
                        last;
                    }
                }

            } else {
                $match = $entry eq $value;
            }
            
            last unless $match;
        }

        push(@ids, $id) if $match;        
    }
    
    return @ids;
}

1;

__END__
=head1 NAME

TODO: rewite
CMS::Onsite::Support::RegistryFile reads and searches the type registry file

=head1 SYNOPSIS

	use CMS::Onsite::Support::RegistryFile;
    my $obj = CMS::Onsite::Support::RegistryFile->new();
    my $traits = $obj->read_data('type', 'blog');
    my @types = $obj->search('type', extension => 'html');

=head1 DESCRIPTION

This class reads and searches the type registry file. The file format is simple:
each field starts on it own line and has the form

    NAME = value

where NAME is the field name in all caps. Trailing whitespace, including the
newline, are deleted from the value. If a field name is used on several
lines, the field is converted to an array with values stored in the order they
appear in the file. Fields can continue over sevaral line.s They are terminated
by the next field, a comment, or the end of file. If a field name is repeated,
it is treated  as an array of the values.

Comments begin on a new line and start with a # character

    # This is a comment
	# that runs for two lines

The registry file is divided into sections preceded by a type name in brackets:

    [TYPENAME]

The type name may be in either case and is converted to lower case. All following
field names and valurs are traits of that type until the next type name. The type
name may be preceded by blanks on the line.

=head1 AUTHOR

Bernie Simon, E<lt>bernie.simon@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bernie Simon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
