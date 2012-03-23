#!/usr/bin/env perl

use strict;

use Cwd;
use CGI;
use CGI::Carp 'fatalsToBrowser';

use constant PARAMETER_NAME => 'module';

#----------------------------------------------------------------------
# Main procedure

# Build form

my $query = CGI->new ();
my $result = build_form ($query);

# Query computer for Perl module

$result->{status} = modulestatus ($query->param (PARAMETER_NAME));
$result->{environment} = build_environment();

# Generate output page and print it

my $source = join ('', <DATA>);
my $output = interpolate ($source, $result);

print "Content-type: text/html\n\n";
print $output;

#----------------------------------------------------------------------
# Cuild list of environment variables

sub build_environment {

    my $env = [];

    push (@$env, {name => '(Directory)', value => cwd()});
    push (@$env, {name => '(Perl Binary)', value => $^X});
    push (@$env, {name => '(Perl Version)', value => $]});    
    push (@$env, {name => '(OS Name)', value => $^O});

    foreach my $name (sort keys %ENV) {
	my $value = $ENV{$name};
	push (@$env, {name => $name, value => $value});
    }

    return $env;
}

#----------------------------------------------------------------------
# Generate form widgets

sub build_form {
    my ($query) = @_;

    my $result = {};
    $result->{script_url} = $query->script_name;
    $result->{parameter_widget} = $query->textfield (-name => PARAMETER_NAME);

    return $result;
}

#----------------------------------------------------------------------
# Yet another interpolator

sub interpolate {
    my ($template, $hash, $visible) = @_;

    if (! ref($template)) {
	my @tokens = grep (length($_), split (/^(\#[^\n]*)\n/m, $template));
	$template = {index => 0, tokens => \@tokens};
	$visible = 1;
    }

    my $output;
    my $saved_test;

    while ($template->{index} < @{$template->{tokens}}) {
	my $token = $template->{tokens}->[$template->{index}++];

	if ($token =~ /^\#(\w+)\s*(\S*)/) {
	    my $cmd = $1;
	    my $name = $2;

	    if ($cmd eq 'include') {
		if ($visible) {
		    my $fd = FileHandle->new("<$name");
		    if ($fd) {
			my $source = do {local $/; <$fd>};
			$output .= interpolate ($source, $hash);
		    }
		}
			
	    } elsif ($cmd eq 'for') {
		my $subarray = $hash->{$name};
		my $saved_index = $template->{index};

		if ($visible && $subarray && @$subarray) {
		    foreach my $subhash (@$subarray) {
			$template->{index} = $saved_index;
			my %hash = (%$hash, %$subhash);
			$output .= interpolate ($template, \%hash, $visible);
		    }

		} else {
		    $output .= interpolate ($template, {}, 0);
		}

	    } elsif ($cmd eq 'endfor') {
		return $output;

	    } elsif ($cmd eq 'if') {
		my $value = $hash->{$name};

		if (ref $value eq 'ARRAY') {
		    $saved_test = @$value ? 1 : 0;
		} elsif (ref $value eq 'HASH') {
		    $saved_test = %$value ? 1: 0;
		} else {
		    $saved_test = $value ? 1 : 0;
		}

		$output .= interpolate ($template, $hash, 
					$visible && $saved_test);

	    } elsif ($cmd eq 'else') {
		if (defined $saved_test) {
		    $saved_test = ! $saved_test;
		    $output .= interpolate ($template, $hash, 
					    $visible && $saved_test);
		} else {
		    $template->{index} --;
		    return $output;
		}

	    } elsif ($cmd eq 'endif') {
		if (defined $saved_test) {
		    undef $saved_test;
		} else {
		    $template->{index} --;
		    return $output;
		}

	    } elsif ($cmd eq 'switch') {
		$saved_test = $hash->{$name};

	    } elsif ($cmd eq 'case') {
		if (defined $saved_test) {
		    $output .= interpolate ($template, $hash, 
					    $visible && $saved_test eq $name);
		    $saved_test = '' if $saved_test eq $name;

		} else {
		    $template->{index} --;
		    return $output;
		}

	    } elsif ($cmd eq 'default') {
		if (defined $saved_test) {
		    $output .= interpolate ($template, $hash, 
					    $visible && $saved_test);
		    $saved_test = '';

		} else {
		    $template->{index} --;
		    return $output;
		}

	    } elsif ($cmd eq 'endswitch') {
		if (defined $saved_test) {
		    undef $saved_test;
		} else {
		    $template->{index} --;
		    return $output;
		}

	    } else {
		$output .= "$token\n";
	    }

	} elsif ($visible) {
	    $token =~ s/\$\(([^\)]*)\)/$hash->{$1}/ge;
	    $output .= $token;
	}
    }

    return $output;
}

#----------------------------------------------------------------------
# Search file system to see if a module is installed

sub modulesearch {
    my ($module) = @_;
    my $found = eval "require $module";

    return defined $found;
}

#----------------------------------------------------------------------
# Search file system to see if a module is installed

sub modulestatus {
    my ($name) = @_;

    my $msg;
    if (defined $name) {
	my $module = valid ($name);
	my $found = defined ($module) ? modulesearch ($module) : 0;

	$msg = "The Perl module $name was ";
	$msg .= $found ? 'found' : 'not found';

    } else {
	$msg = '';
    }

    return $msg;
}

#----------------------------------------------------------------------
# Read a file into a string

sub slurp {
    my ($input) = @_;

    local $/;

    my $in = FileHandle->new ($input);
    die "Couldn't read $input: $!\n" unless defined $in;

    my $text = <$in>;
    $in->close;

    return $text;
}

#----------------------------------------------------------------------
# Validate input

sub valid {
    my ($name) = @_;

    my ($module) = $name =~ /^\s*([\w:]+)\s*$/;
    return $module;
}

#----------------------------------------------------------------------
# Script templae

__DATA__
<html>
<head>
<!-- begin header -->
  <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
  <title>Perl Module Search</title>
<!-- end header -->
</head>
<body>
<!-- begin sidebar -->
<!-- end sidebar -->
<!-- begin content -->
  <h1>Perl Module Search</h1>

  <form method="post" action="$(script_url)">
    <p>Enter the name of the Perl module to search for <br />
    $(parameter_widget)
  </form>

  <p>$(status)</p>

  <h1>Environment Variables</h1>

  <table>
#for environment
  <tr><td><b>$(name)</b></td><td>$(value)</td></tr>
#endfor
  </table>
<!-- end content -->
</body>
</html>
