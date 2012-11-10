use strict;
use warnings;
use integer;

package App::Onsite::Support::FollowMe;

use base qw(App::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Set package parameters

sub parameters {
    my ($pkg) = @_;

    my %parameters =  (
                  extension => '',
                  nt => {DEFAULT =>'App::Onsite::Support::NestedTemplate'},
		       );

    return %parameters;
}

#----------------------------------------------------------------------
# Determine which file is the template

sub prelude {
    my ($self, @args) = @_;

    push(@args, '.') unless @args;
    my $ext = $self->{extension};
    
    my $template;
    my $modtime = 0;

    for my $dir (@args) {
        my $dd = IO::Dir->new($dir) or die "Couldn't open $dir: $!\n";

        while (defined (my $file = $dd->read())) {
            next if $file =~ /^\./ || $file !~ /\.$ext$/;

            my $path = "$dir/$file";
            my @stats = stat($path);
            my $mtime = $stats[9];
            
            if ($mtime > $modtime) {
                $modtime = $mtime;
                $template = $path;
            }
        }
        
        $dd->close();
    }
    
    $self->{template} = $template;
    return;
}

#----------------------------------------------------------------------
# Update the web pages

sub run {
    my ($self, $filename, $content) = @_;
    
    if ($filename ne $self->{template}) {
        my $parsed = $self->{nt}->parse($self->{template}, $content);
        $content = $self->{nt}->unparse($parsed);
    }
    
    return $content;
}

1;