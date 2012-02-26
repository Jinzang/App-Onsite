use strict;
use warnings;
use integer;

use IO::Dir;
use IO::File;

#----------------------------------------------------------------------
# Run a function that edits files

package CMS::Onsite::Support::FileHandler;

use Getopt::Std;
use base qw(CMS::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters =  (
		       handler => {},
		       extension => '',
		       );

    return %parameters;
}

#----------------------------------------------------------------------
# Make previous version of files the current version

sub revert {
    my ($self, $file) = @_;

    return unless -f "$file~";

    rename($file, "$file~~") or return;
	rename("$file~", $file) or return;
	rename("$file~~", "$file~");

    return;
}

#----------------------------------------------------------------------
# Run the script once on each file

sub run {
    my ($self, @args) = @_;

    my $opt = {};
    getopts("dnrx:", $opt);

	@args = $self->sanitize(@args);
    my $visitor = $self->visitor($opt->{x}, @args);

	$self->{handler}->prelude(@args) if $self->{handler}->can('prelude');

    while (my $file = &$visitor) {
        if ($opt->{n}) {
            print "$file\n";

        } elsif ($opt->{r}) {
            $self->revert($file);

        } elsif ($opt->{d}) {
            unlink("$file~");

        } else {
            my $content = $self->slurp($file);

            $content = $self->save("$file~", $content)
                if defined $content;

            $content = $self->{handler}->run($file, $content)
                if defined $content;

            $self->save($file, $content)
                if defined $content;
        }
    }

	$self->{handler}->postlude(@args) if $self->{handler}->can('postlude');
    return;
}

#----------------------------------------------------------------------
# Remove arguments starting with a dash

sub sanitize {
	my ($self, @args) = @_;

	my @new_args;
	my $finished;
	foreach my $arg (@args) {
		if ($arg eq '--') {
			$finished = 1;
		} elsif ($finished || $arg !~ /^-/) {
			push(@new_args, $arg);
		}
	}

	return @new_args;
}

#----------------------------------------------------------------------
# Save a file

sub save {
    my ($self, $file, $content) = @_;

    my $out = IO::File->new($file, "w");

    if ($out) {
        print $out $content;
        close($out);

    } else {
        warn "Skipping $file, couldn't save: $!\n";
        undef $content;
    }

    return $content;
}

#----------------------------------------------------------------------
# Get text from file

sub slurp {
    my ($self, $file) = @_;

    local $/;
    my $in = IO::File->new($file, "r");

    my $content;
    if ($in) {
        $content = <$in>;
        close($in);

    } else {
        warn "Skipping $file, couldn't read: $!\n";
    }

    return $content;
}

#----------------------------------------------------------------------
# Return a closure that visits files in a directory with extension

sub visitor {
    my ($self, $ext, @arglist) = @_;

    push(@arglist, '.') unless @arglist;
    $ext = $self->{extension} unless $ext;

    my (@dirlist, @filelist);
    foreach my $arg (@arglist) {
        if (-d $arg) {
            push(@dirlist, $arg);
        } else {
            push(@filelist, $arg);
        }
    }

    return sub {
        for (;;) {
            my $file = shift @filelist;
            return $file if defined $file;

            my $dir = shift @dirlist;
            return unless defined $dir;

            my $dd = IO::Dir->new($dir) or die "Couldn't open $dir: $!\n";

            # Find matching files and directories

            while (defined (my $file = $dd->read())) {
                next if $file =~ /^\./;

                my $path = "$dir/$file";
                push(@filelist, $path) if $file =~ /\.$ext$/;
                push(@dirlist, $path) if -d $path;
            }

            @filelist = sort(@filelist);
            @dirlist = sort(@dirlist);
            $dd->close;
        }
    };
}

1;
__END__
=head1 NAME

CMS::Onsite::Support::FileHandler runs an object method on each file

=head1 SYNOPSIS

	use CMS::Onsite::Support::FileHandler;
    my $obj = CMS::Onsite::Support::CronHandler->new(handler => 'SomePackage');
	$obj->run(@args);

=head1 DESCRIPTION

This class calls the run method of the object passed as the value of handler
once on each file.

=head1 AUTHOR

Bernie Simon, E<lt>bernie.simon@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bernie Simon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
