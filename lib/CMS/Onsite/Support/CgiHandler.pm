use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# A wrapper for a class that handles a CGI request (Handler)
# Handler must have run method and should support the methods check
# and error

package CMS::Onsite::Support::CgiHandler;

use Data::Dumper;
use File::Spec::Functions qw(rel2abs);
use base qw(CMS::Onsite::Support::ConfiguredObject);

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
                    io => {DEFAULT => 'CMS::Onsite::Support::IO'},
                    cgi => {DEFAULT => 'CGI'},
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

    # @args is an optional hash containg request parameters
    # that is used for debugging
    my %request = $self->{cgi}->Vars();

    # Split request parameters when they are arrays

    foreach my $field (keys %request) {
        next unless $request{$field} =~ /\000/;
        my @array = split(/\000/, $request{$field});
        $request{$field} = \@array;
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
        $self->{cgi}->redirect(-status => $response->{code}.
                               -url => $response->{url});
    } else {
        $self->{io}->print("Content-type: $response->{protocol}\n\n");
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
    ($filename) = $filename =~ m{^([\w\./]+)$};

    return rel2abs($filename);
}

#----------------------------------------------------------------------
# Set missing values in configuration

sub update_config {
    my ($self, $configuration) = @_;

    unless ($configuration->{data_dir}) {
        $configuration->{data_dir} = $0;
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
        my ($script_url) = split (/\?/, $ENV{SCRIPT_URI});
        $configuration->{script_url} = $script_url;
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
