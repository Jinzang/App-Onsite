use strict;
use warnings;
use integer;

package App::Onsite::Support::CachedFile;

use base qw(App::Onsite::Support::ConfiguredObject);
use Digest::MD5 qw(md5_hex);

# Singleton, for obvious reasons
my $singleton;

#----------------------------------------------------------------------
# Default parameter values

sub parameters {
	my ($pkg) = @_;

	return (
			expires => 60,
		   );
}

#----------------------------------------------------------------------
# Create the initial, empty cache

sub create_object {
    my ($pkg) = @_;

    $singleton ||= bless ({cache => {}}, $pkg);
    return $singleton;
}

#----------------------------------------------------------------------
# Fetch the parsed representation from the cache if available

sub fetch {
    my ($self, $key) = @_;

    my $data;
    my $hash = md5_hex($key);
    
    if (exists $self->{cache}{$hash}) {
        if (time() < $self->{cache}{$hash}{TIME} + $self->{expires}) {
            $data = $self->{cache}{$hash}{DATA};
        } else {
            delete $self->{cache}{$hash};
        }
    }

    return $data;
}

#----------------------------------------------------------------------
# Remove the cache

sub flush {
    my ($self) = @_;

    $self->{cache} = {};
    return;
}

#----------------------------------------------------------------------
# Free the cache item when no longer valid

sub free {
    my ($self, $key) = @_;

    my $hash = md5_hex($key);
    delete $self->{cache}{$hash};

    return;
}

#----------------------------------------------------------------------
# Save the parsed version of the file to the cache

sub save {
    my ($self, $key, $data) = @_;

    my $hash = md5_hex($key);
    $self->{cache}{$hash} = {DATA => $data, TIME => time()};

    return;
}

1;

__END__
=head1 NAME

App::Onsite::Support::CachedFile saves the parsed representation of a file

=head1 SYNOPSIS

	use App::Onsite::Support::CachedFile;
    my $obj = App::Onsite::Support::CachedFile->new();
	$obj->save('filename', $data);
	my $data = $obj->fetch('filename');
	$obj->free('filename');

=head1 DESCRIPTION

This class implements a simple cache that is indexed by filename. After a
file is parsed, it may be saved to the cache and re-used. This saves the time
used to read and parse the file. Cache entries expire after $obj->{expires}
seconds.

This is the default class used for caching App::Onsite::Support::ConfigFile
and need not be separately loaded.

=head1 AUTHOR

Bernie Simon, E<lt>bernie.simon@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bernie Simon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
