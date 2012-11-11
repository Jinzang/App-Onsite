use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Convert posts from another blogging system to native html pages

package App::Onsite::Support::FileHandler;

use IO::File;
use base qw(App::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters =  (
                        xeno => {DEFAULT => 'App::Onsite::Blosxom'},
                        data => {DEFAULT => 'App::Onsite::BlogData'},
		       );

    return %parameters;
}

#----------------------------------------------------------------------
# Read foreign data and create a new blog post from it

sub run {
    my ($self, $output_dir, @input_dirs) = @_;
    
    my $blog = $self->{data}->filename_to_id($output_dir);

    foreach my $input_dir (@input_dirs) {
        $self->{xeno}{top_dir} = $input_dir;
        my $get_next = $self->{xeno}->get_next($input_dir);

        while (my $data = &$get_next()) {
            $self->{data}->add_data($blog, $data);
        }
    }
    
    return;
}

1;