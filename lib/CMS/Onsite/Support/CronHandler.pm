use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Run a package as a cron jon

package CMS::Onsite::Support::CronHandler;

use IO::File;
use File::Spec::Functions qw(rel2abs);

use base qw(CMS::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters =  (
		       handler => {},
		       data_dir => '',
		       mail_to => '',
		       mail_from => '',
		       mail_problem => '',
		       mail_subject => '[No Subject]',
		       mailcmd => '/usr/lib/sendmail',
		       mailargs => '-oi -t',
		       namecmd => '/usr/bin/uname',
		       nameargs => '-n',
		       send_ok => 1,
		       );

    return %parameters;
}

#----------------------------------------------------------------------
# Combine multiple values into a list, keep single values as scalars

sub aggregate {
    my ($self, @list) = @_;

    my @new_list = grep {length($_)} @list;
    return (@new_list > 1) ? \@new_list : shift @new_list;
}

#----------------------------------------------------------------------
# Convert array to hash

sub hashify {
    my ($self, @args) = @_;
    
    my %hash;
    foreach my $arg (@args) {
        if ($arg =~ /=/) {
            my ($name, $value) = split(/=/, $arg, 2);
            $hash{$name} = $value;
        } else {
            $hash{$arg} = 1;
        }
    }
    
    return \%hash;
}

#----------------------------------------------------------------------
# Return a string with the time, machine name, and script name

sub mail_header {
    my ($self) = @_;

    my $uname = `$self->{namecmd} $self->{nameargs}`;
    chomp $uname;
    $uname =~ s/\..*//;

    my $text = "This script is $0\n";
    $text .= "It was run at " .  localtime();
    $text .= " on $uname.\n";

    return $text;
}

#----------------------------------------------------------------------
# Send a mail message

sub mail_message {
    my ($self, $to, @message) = @_;

    # Open filehandle for mail

    my $mail =  IO::File->new( "| $self->{mailcmd} $self->{mailargs}");
    die "Could not send mail\n" unless $mail;

    my %fields = (To => $to,
		  From => $self->{mail_from},
		  Subject => $self->{mail_subject}
		 );

    while (my ($field, $value) = each %fields) {
	$value = join (',', @$value) if ref $value;
	print $mail "$field: $value\n";
    }

    print $mail "\n", join("\n", @message), "\n";
    close($mail);

    return;
}

#----------------------------------------------------------------------
# Run the script, send a mail message

sub run {
    my ($self, @args) = @_;

    if (length $self->{data_dir}) {
		my $dir = $self->untaint_filename($self->{data_dir});
		chdir($dir) or die "Couldn't move to $dir: $!\n";
    }

    my $to;
    my $request = $self->hashify(@args);
    my $message = eval {$self->{handler}->batch($request)};

    if ($@) {
		$message = $@;
		$to = $self->aggregate($self->{mail_to}, $self->{mail_problem});

    } elsif ($self->{send_ok}) {
		$message ||= "The script ran successfully";
		$to = $self->{mail_to};
    }

    my $header = $self->mail_header();
    $self->mail_message($to, $header, $message) if $to;

    return $message;
}

#----------------------------------------------------------------------
# Make sure filename passes taint check

sub untaint_filename {
    my ($self, $filename) = @_;

    $filename = rel2abs($filename);
    ($filename) = $filename =~ m{^([\w\./]+)$};

    return $filename;
}

1;

__END__
=head1 NAME

CMS::Onsite::Support::CronHandler runs an object as a cron job

=head1 SYNOPSIS

	use CMS::Onsite::Support::CronHandler;
    my $obj = CMS::Onsite::Support::CronHandler->new(handler => 'SomePackage');
	$obj->run(@args);

=head1 DESCRIPTION

This class calls the batch method of the object passed as the value of handler.
It sends a mail message at the conclusion of the job.

=head1 AUTHOR

Bernie Simon, E<lt>bernie.simon@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bernie Simon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
