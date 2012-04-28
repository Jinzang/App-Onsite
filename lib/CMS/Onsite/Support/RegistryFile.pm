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
			registry_ext => 'reg',
            template_dir => '',
			cache => {DEFAULT => 'CMS::Onsite::Support::CachedFile'},
		   );
}

#----------------------------------------------------------------------
# Read the registry data for the specified type

sub read_data {
    my ($self, $name, $id) = @_;
    
    my $registry = $self->read_file($name);
    die "Did not find $name in registry: $id\n"
        unless exists $registry->{$id};
    
    return $registry->{$id};
}

#----------------------------------------------------------------------
# Read a registry file into a hash of parameters

sub read_file {
    my ($self, $name) = @_;

    my $filename = join('/', $self->{template_dir},
                        "$name.$self->{registry_ext}");

	my $cache = $self->{cache}->fetch($filename);

	unless ($cache) {
		my $in = IO::File->new($filename, 'r');
		die "Can't open $filename: $!\n" unless $in;

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
                die "Duplicate $name: $id\n" if exists $registry{$id};
                
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
		$self->{cache}->save($filename, $cache);
	}

    return $cache;
}

#----------------------------------------------------------------------
# Search the registry for parameters with a specified value of a field

sub search {
    my ($self, $name, %query) = @_;
    
    my @ids;
    my $registry = $self->read_file($name);
    
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
