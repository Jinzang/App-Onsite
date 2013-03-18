#!/usr/bin/env perl

use strict;
use warnings;

use CGI;
use Cwd;
use IO::Dir;
use IO::File;
use Data::Dumper;
use MIME::Base64 qw(decode_base64);

my $request;
our $modeline;

# Values for script parameters
# You can change the values or add new ones

my $parameters = {
                  group => '',
                  permissions => 0666,
                 };

eval {
    $request = get_request();
    if ($request->{error} = check_request($request)) {
        show_form($request);
    } else {
        run($parameters, $request);
    }
};

if ($@) {
    $request->{error} = $@;
    $request->{dump} = dump_state();
    show_form($request);
}

#----------------------------------------------------------------------
# Main routine

sub run {
    my ($parameters, $request) = @_;

    my $include = get_include();
    $parameters = set_parameters($include, $parameters);
    die "Could not compute base_url\n" unless $parameters->{base_url};

    copy_site($include, $parameters);
    protect_files($include, $parameters, $request);
    unlink($0);

    redirect($parameters->{base_url});
    return;
}

#----------------------------------------------------------------------
# Check request to see if it is complete and valid

sub check_request {
    my ($request) = @_;
    
    my $missing_user = "Please enter user name and password";
    my $missing_password = "Please enter password";
    my $nomatch = "Passwords don't match";
    
    return $missing_user unless exists $request->{user};
    return $missing_user unless $request->{user} =~ /\S/;
    
    return $missing_password unless exists $request->{pass1}
                             && exists $request->{pass2};
                             
    return $nomatch unless $request->{pass1} eq $request->{pass2};
    
    return;
}

#----------------------------------------------------------------------
# Create a copy of the input file

sub copy_file {
    my ($mode, $file, $text) = @_;
    
    my $out = IO::File->new($file, 'w') or die "Can't write $file";

    if ($mode eq 'b') {
        binmode($out) ;
        my @lines = split(/\n/, $text);
        foreach my $line (@lines) {
            print $out decode_base64($line);
        }

    } else {
        chomp $text;
        print $out $text;        
    }
    
    close($out);
    return;
}

#----------------------------------------------------------------------
# Copy initial version of website to target

sub copy_site {
    my ($include, $parameters) = @_;   

    while (my ($mode, $file, $text) = next_file()) {
        $file = map_filename($include, $file);
        create_dirs($file, $parameters);        
        my $modifiers;

        if ($file =~ /\.cgi$/) {
            $text = edit_script($file, $text, $include, $parameters);
            $modifiers = 'x';
        }
    
        copy_file($mode, $file, $text);
        set_permissions($file, $parameters, $modifiers);
   }

    return;
}

#----------------------------------------------------------------------
# Check path and create directories as necessary

sub create_dirs {
    my ($file, $parameters) = @_;

    my @dirs = split(/\//, $file);
    pop @dirs;
    
    my $path = '';
    foreach my $dir (@dirs) {
        $path .= "/$dir";

        if (! -d $path) {
            mkdir ($path) or die "Couldn't create $path: $!\n";
            set_permissions($path, $parameters, 'x')
        }
    }

    return;
}

#----------------------------------------------------------------------
# Dump the state of this script

sub dump_state {
    my ($msg) = @_; 

    my $dumper = Data::Dumper->new([\%ENV], ['ENV']);
    my $env = $dumper->Dump();

    return $env;
}

#----------------------------------------------------------------------
# Edit script to work on website

sub edit_script {
    my ($file, $text, $include, $parameters) = @_;
        
    # Change shebang line
    my $perl = `/usr/bin/which perl`;
    chomp $perl;
    $text =~ s/\#\!(\S+)/\#\!$perl/;

    # Change use lib line
    if ($text =~ /use lib/) {
        $text  =~ s/use lib \'(\S+)\'/use lib \'$include->{lib}\'/;
    }
    
    # Set parameters
    $parameters = update_parameters($file, $parameters);
    
    if ($text =~ /my \$parameters/) {
        my $dumper = Data::Dumper->new([$parameters], ['parameters']);
        my $parameters = $dumper->Dump();    
        $text =~ s/my \$parameters;/my $parameters/;
    }
    
    return $text;
}

#----------------------------------------------------------------------
# Encrypt password

sub encrypt {
	my ($plain) = @_;;

	my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
    return crypt($plain, $salt);
}

#----------------------------------------------------------------------
# Get the locations of the directories we need

sub get_include {
    # Set directory to one containing this script
    
    my $dir = $0;
    $dir =~ s{/?[^/]*$}{};
    $dir ||= '.';
    
    chdir $dir or die "Cannot cd to $dir";
    
    my $include = {};
    while (my ($source, $target) = next_dir()) {
        $include->{$source} = rel2abs($target);
    }
    
    return $include;    
}

#----------------------------------------------------------------------
# Get the request passed to the script

sub get_request {
    
    my $cgi = CGI->new;
    my %request = $cgi->Vars();

    # Split request parameters when they are arrays

    foreach my $field (keys %request) {
        next unless $request{$field} =~ /\000/;
        my @array = split(/\000/, $request{$field});
        $request{$field} = \@array;
    }
    
    return \%request;
}

#----------------------------------------------------------------------
# Map filename to name on uploaded system

sub map_filename {
    my ($include, $file) = @_;
    
    my @path = split(/\//, $file);
    my $dir = shift(@path);
    
    if (exists $include->{$dir}) {
        unshift(@path, $include->{$dir}) if $include->{$dir};
        $file = join('/', @path);
    }
        
    return $file;
}

#----------------------------------------------------------------------
# Get the name of the next directory

sub next_dir {
    $modeline = <DATA>;
    return unless $modeline =~ /^\#\+\+\%X\+\+\%X/;
    
    my ($comment, $source, $target) = split(' ', $modeline);
    die "Bad modeline: $modeline\n" unless defined $source;
    $target = '' unless defined $target;
    
    return ($source, $target)
}

#----------------------------------------------------------------------
# Get the name and contents of the next file

sub next_file {
    
    return unless $modeline;
    my ($comment, $mode, $file) = split(' ', $modeline);
    die "Bad modeline: $modeline\n" unless defined $file;
    
    my $text = '';
    $modeline = '';
    
    while (<DATA>) {
        if (/^\#--\%X--\%X/) {
            $modeline = $_;
            last;

        } else {
            $text .= $_;
        }
    }
    
    return ($mode, $file, $text);
}

#----------------------------------------------------------------------
# Protect the files with access and password files

sub protect_files {
    my ($include, $parameters, $request) = @_;

    while (my($source, $target) = each %$include) {
        if ($source eq 'site') {
            write_access_file($parameters, $target);
            write_password_file($parameters, $target, $request);

        } else {
            write_no_access_file($parameters, $target);
        }
    }
    
    return;
}

#----------------------------------------------------------------------
# Redirect browser to url

sub redirect {
    my ($url) = @_;
    
    print "Location: $url\n\n";
    return;
}

#----------------------------------------------------------------------
# Convert relative filename to absolute

sub rel2abs {
    my ($filename) = @_;

    my @path;
    my $base_dir = getcwd();
    @path = split(/\//, $base_dir) unless $filename =~ /^\//;
    push(@path, split(/\//, $filename));

    my @newpath = ('');
    while (@path) {
        my $dir = shift @path;
        if ($dir eq '' or $dir eq '.') {
            ;
        } elsif ($dir eq '..') {
            pop(@newpath) if @newpath > 1;
        } else {
            push(@newpath, $dir);
        }
    }

    $filename = join('/', @newpath);
    return $filename;
}

#----------------------------------------------------------------------
# Set the base url from values in environment variables

sub set_base_url {
    my $base_url = '';
    if (exists $ENV{SERVER_URI}) {
        $base_url = $ENV{SERVER_URI};
        
    } elsif (exists $ENV{SERVER_NAME}) {
        $base_url = "http://$ENV{SERVER_NAME}";
        $base_url .= ":$ENV{SERVER_PORT}" if $ENV{SERVER_PORT} != 80;
        $base_url .= $ENV{REQUEST_URI};
    }
    
    $base_url =~ s/[^\/]+$//;   
    return $base_url;
}

#----------------------------------------------------------------------
# Set the group of a file

sub set_group  {
    my ($filename, $group) = @_;

    return unless -e $filename;
    return unless $group;

    my $gid = getgrnam($group);
    return unless $gid;

    my $status = chown(-1, $gid, $filename);
    return;
}

#----------------------------------------------------------------------
# Set parameters for script

sub set_parameters {
    my ($include, $parameters) = @_;

    # Set reasonable defaults for parameters that aren't set above
    
    my %defaults = (
                    script_url => '*.cgi',
                    data_dir => $include->{site},
                    config_file => "$include->{site}/*.cfg",
                    template_dir => $include->{templates},
                    valid_read => [$include->{templates}],
                    valid_write => [$include->{site}],
                    data_registry => '*_data.reg',
                    command_registry => '*_commands.reg',
                   );
    
    $defaults{base_url} = set_base_url();
    %$parameters = (%defaults, %$parameters);
    return $parameters;
}

#----------------------------------------------------------------------
# Set permissions on a file

sub set_permissions {
    my ($file, $parameters, $modifiers) = @_;
    $modifiers = '' unless defined $modifiers;

    my $permissions = $parameters->{permissions} & 0775;
    $permissions |= 0111 if $modifiers =~ /x/;
    $permissions |= 0222 if $modifiers =~ /w/;
    $permissions |= 0444 if $modifiers =~ /r/;    
    
    set_group($file, $parameters->{group});
    chmod($permissions, $file);

    return;
}

#----------------------------------------------------------------------
# Show form to get user name and password

sub show_form {
    my ($request) = @_;    
    
    my $template = <<'EOS';
<head>
<title>Onsite Editor</title>
<style>
div#header {background: #5f9ea0;color: #fff;}
div#header h1{margin: 0; padding: 10px;}
div#footer {background: #fff; color: #666; border-top: 2px solid #5f9ea0;}
div#footer p{padding: 10px;}
</style>
</head>
<body>
<h1 id="banner">Onsite Editor</h1>
<p>{{error}}</p>

<!--
{{dump}}
-->

<form id="password_form" method="post" action="{{script_url}}">
<b>User Name<b><br />
<input name="user" value="{{user}}" size="20"><br />
<b>Password<b><br />
<input name="pass1" value="" size="20" type="password"><br />
<b>Repeat Password<b><br />
<input name="pass2" value="" size="20" type="password"><br /><br />
<input type="submit" name="cmd" value="Go">
</form>
<div id="footer"><p>The Onsite Editor is free software,
licensed on the same terms as Perl.</p></div>
</div>    
</body></html>
EOS

    $template =~ s/{{([^}]*)}}/$request->{$1} || ''/ge;
    print("Content-type: text/html\n\n$template");
    
    return;
}

#----------------------------------------------------------------------
# Update parameters by substituting for wild card

sub update_parameters {
    my ($file, $parameters) = @_;

    my ($basename) = $file =~ /(\w+)\.\w+$/;
    
    while (my ($name, $value) = each %$parameters) {
        $value =~ s/\*/$basename/;
        $parameters->{$name} = $value;        
    }

    return $parameters;
}

#----------------------------------------------------------------------
# Write access file for password protected site

sub write_access_file {
    my ($parameters, $directory) = @_;

    my $file = "$directory/.htaccess";
    my $fd = IO::File->new($file, 'w')
        or die "Can't open $file: $!\n";

    print $fd <<"EOS";
<Files "editor.cgi">
AuthName "Restricted Command" 
AuthType Basic 
AuthUserFile $directory/.htpasswd 
AuthGroupFile /dev/null 
require valid-user
</Files>
EOS

    close($fd);
    set_permissions($file, $parameters);  
    return;
}

#----------------------------------------------------------------------
# Write file that blocks access to site

sub write_no_access_file {
    my ($arameters, $directory) = @_;

    my $file = "$directory/.htaccess";
    my $fd = IO::File->new($file, 'w')
        or die "Can't open $file: $!\n";

    print $fd <<'EOS';
AuthUserFile /dev/null
AuthGroupFile /dev/null
AuthName "No Access"
AuthType Basic
<Limit GET>
order deny,allow
</Limit>
EOS

    close($fd);
    set_permissions($file, $parameters);  

    return;    
}

#----------------------------------------------------------------------
# Write password file

sub write_password_file {
    my ($permissions, $directory, $request) = @_;

    my $file = "$directory/.htpasswd";
    my $fd = IO::File->new($file, 'w')
        or die "Can't open $file: $!\n";
   
    print $fd $request->{user}, ':', encrypt($request->{pass1}), "\n";
    close($fd);
    set_permissions($file, $parameters);  

    return;
}

