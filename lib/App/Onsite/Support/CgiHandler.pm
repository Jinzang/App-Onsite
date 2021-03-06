use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# A wrapper for a class that handles a CGI request (Handler)
# Handler must have run method and should support the methods check
# and error

package App::Onsite::Support::CgiHandler;

use CGI qw(:cgi);
use Data::Dumper;
use File::Spec::Functions qw(rel2abs);
use base qw(App::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Configuration

use constant ERROR_TEMPLATE => <<'EOS';
<head><title>Script Error</title></head>
<body>
<h1>Script Error</h1>
<p>Please report this error to the developer.</p>
<pre>{{error}}</pre>
</body></html>
EOS

use constant ERROR_DETAIL_TEMPLATE => <<'EOS';
<html>
<head><title>Script Error</title></head>
<body>
<h1>Script Error</h1>
<p>Please report this error to the developer.</p>
<pre>{{error}}</pre>
<h2>REQUEST</h2>
{{request}}
<h2>RESPONSE</h2>
{{response}}
</body>
</html>
EOS

#----------------------------------------------------------------------
# Set default values

sub parameters {
  my ($pkg) = @_;

    my %parameters = (
                    data_dir => '',
					detail_errors => 0,
                    io => {DEFAULT => 'App::Onsite::Support::IO'},
                    handler => {},
	);

    return %parameters;
}

#----------------------------------------------------------------------
# Fallback error routine in case handler's is missing or doesn't work

sub error {
    my($self, $request, $response) = @_;

    my $template;
    my $data = {};
    $data->{error} = $response->{msg};

    if ($self->{detail_errors}) {
        $data->{request} = $request;
        $data->{response} = $response;
        $template = ERROR_DETAIL_TEMPLATE;

    } else {
        $template = ERROR_TEMPLATE;
    }

    return $self->render($data, $template);
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
# Set the field values in a new object

sub populate_object {
	my ($self, $configuration) = @_;

    $configuration = $self->update_config($configuration);
    return $self->SUPER::populate_object($configuration);
}

#----------------------------------------------------------------------
# Print extra header lines

sub print_extra_headers {
    my ($self, $response) = @_;
    
    my %normal_field = (code => 1,
                        url => 1,
                        protocol => 1,
                        msg => 1,
                        results => 1);

    foreach my $field (keys %$response) {
        next if $normal_field{$field};
        
        my $header = $field;
        $header =~ s/_/-/g;
        $header .= ": " . $response->{$field};
        $self->{io}->print("$header\n");
    }
    
    return;
}

#----------------------------------------------------------------------
# Default renderer

sub render {
    my ($self, $data, $template) = @_;

    my $result = $template;
    $result =~ s/{{(\w+)}}/$self->substitute($data, $1)/ge;

    my $response = {code => 200,
                    msg => 'OK',
                    protocol => 'text/html',
                    results => $result
                    };

    return $response;
}

#----------------------------------------------------------------------
# Get arguments used in handling cgi request

sub request {
    my ($self) = @_;

    my $cgi = CGI->new;
    my %request = $cgi->Vars();

    # Split request parameters when they are arrays

    foreach my $field (keys %request) {
        next unless $request{$field} =~ /\000/;
        my @array = split(/\000/, $request{$field});
        $request{$field} = \@array;
    }

    # Get file descriptor for filename    
 
    if ($request{filename}) {
        my $fd = $cgi->upload('filename');
        $request{filename} = $fd->handle;
    }
    
    return \%request;
}

#----------------------------------------------------------------------
# Run the cgi script, print the result

sub run {
    my ($self, @args) = @_;

    chdir($self->untaint_filename($self->{data_dir}));
    my $request = @args ? $self->hashify(@args) : $self->request();
       
    my $response;
    eval {            
        $response = $self->{handler}->run($request);
    };

    if ($@) {
        $response->{code} = 500;
        $response->{msg} = $@;
    }

    if ($response->{code} >= 400) {
        $response = $self->error($request, $response);
    }
    
    if ($response->{code} >= 300) {
        $self->{io}->print("Location: $response->{url}\n\n");

    } else {
        $self->{io}->print("Content-type: $response->{protocol}\n");
        $self->print_extra_headers($response);
        $self->{io}->print("\n");

        $self->{io}->print($response->{results});
    }

    return;
}

#----------------------------------------------------------------------
# Substitute for data for macro in template

sub substitute {
    my ($self, $data, $field) = @_;

    my $value = '';
    if (exists $data->{$field}) {
        if (ref $data->{$field}) {
            my $dumper = Data::Dumper->new([$data->{$field}], [$field]);

            $value = $dumper->Dump();
            $value = "<pre>\n$value</pre>\n";

        } else {
            $value = $data->{$field};
        }
    }

    return $value;
}

#----------------------------------------------------------------------
# Make sure urls are properly terminated with a slash

sub terminate_url {
    my ($self, $url) = @_;

    my ($file) = $url =~ m!([^/]*)$!;
    $url .= '/' if defined($file) && length($file) && $file !~ /\./;

    return $url;
}

#----------------------------------------------------------------------
# Make sure filename passes taint check

sub untaint_filename {
    my ($self, $filename) = @_;

    $filename = rel2abs($filename);
    ($filename) = $filename =~ m{^([\w\.\-/]+)$};

    return rel2abs($filename);
}

#----------------------------------------------------------------------
# Set missing values in configuration

sub update_config {
    my ($self, $configuration) = @_;

    unless ($configuration->{data_dir}) {
        $configuration->{data_dir} = rel2abs($0);
        $configuration->{data_dir}  =~ s!/[^/]*$!!;
    }
    
    $configuration->{data_dir} =
        $self->untaint_filename($configuration->{data_dir});
    
    unless ($configuration->{template_dir}) {
        $configuration->{template_dir} = "$configuration->{data_dir}/templates";
    }
    
    $configuration->{template_dir} =
        $self->untaint_filename($configuration->{template_dir});

    unless ($configuration->{script_url}) {
        my $script_url;
        if (exists $ENV{SCRIPT_URI}) {
            $script_url = $ENV{SCRIPT_URI};

        } elsif (exists $ENV{SERVER_NAME} && exists $ENV{REQUEST_URI}) {
            my $server = $ENV{SERVER_NAME};
            $server =~ s(/+$)();
            my $request = $ENV{REQUEST_URI};
            $request =~ s(^/+)();
            $script_url = "http://$server/$request";

        } else {
            my $file = rel2abs($0);
            $script_url = "file::/$file"
        }

        ($configuration->{script_url}) = split (/\?/, $script_url);
    }

    $configuration->{script_url} =
            $self->terminate_url($configuration->{script_url});

    unless ($configuration->{base_url}) {
        my $base_url = $configuration->{script_url};

        my @base_path = split(m{/}, $base_url);
        pop @base_path;

        $base_url = join("/", @base_path) . '/';
        $configuration->{base_url} = $base_url;
    }

    $configuration->{base_url} =
            $self->terminate_url($configuration->{base_url});

    $configuration->{valid_read} = [$configuration->{template_dir}];
    $configuration->{valid_write} = [$configuration->{data_dir}];
    
    return $configuration;
}

1;
