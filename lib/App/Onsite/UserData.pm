use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# USERDATA -- A module to read and write from Apache password files

package App::Onsite::UserData;

use base qw(App::Onsite::TextdbData);
use constant PASSWORD_FILE => '.htpasswd';

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = ();
    my %base_params = $pkg->SUPER::parameters();
    %parameters = (%base_params, %parameters);

    return %parameters;
}

#----------------------------------------------------------------------
# Check user authorization to modify the data

sub authorize {
	my($self, $cmd, $request) = @_;

    $request->{remote_user} = $ENV{REMOTE_USER};
	return exists $request->{remote_user};
}

#----------------------------------------------------------------------
# Check passwords for consistency

sub check_data {
    my ($self, $data) = @_;

    my $error;
    $error = "Passwords do not match"
        if $data->{password} ne $data->{password2};

    # Check for duplicate user names

    unless ($error) {
        my $id = $data->{id};
        my ($parentid, $seq) = $self->{wf}->split_id($id);
        $data->{id} = $seq;
        
        my ($filename, $extra) = $self->id_to_filename($id);
        my $records = $self->read_secondary($filename);
        $records = $self->{lo}->list_add($data);
        
        my $count = 0;
        my $user = $data->{user};
        foreach my $record (@$records) {
            $count ++ if $record->{user} eq $user;
        }
        
        $error = "Duplicate user name" if $count > 1;
        $data->{id} = $id;
    }
    
    return $error;
}

#----------------------------------------------------------------------
# Encrypt password

sub encrypt {
	my ($self, $plain, $salt) = @_;
    return unless defined $plain;

	$salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64]
		unless defined $salt;

	return crypt($plain, $salt);
}

#----------------------------------------------------------------------
# Add extra data to the data read from file

sub extra_data {
    my ($self, $data) = @_;

    $data->{summary} = "Change name or password of $data->{user}"; 
	$data->{password2} = $data->{password};
    $data = $self->SUPER::extra_data($data);
    
    return $data;
}

#----------------------------------------------------------------------
# Get field information for user file

sub field_info {
    my ($self, $id) = @_;

    my $info = $self->SUPER::field_info($id);

    my $item2 = {};
    foreach my $item (@$info) {
        if ($item->{NAME} eq 'password') {
            %$item2 = %$item;
            last;
        }
    }
    
    $item2->{NAME} = 'password2';
    $item2->{title} = 'Repeat Password';

    push (@$info, $item2);
    return $info;
}

#----------------------------------------------------------------------
# Remove a user 

sub remove_data {
    my ($self, $id, $request) = @_;

    die "Cannot remove self\n" if $request->{user} eq $request->{remote_user};
    $self->SUPER::remove_data($id, $request);

    return;
}

#---------------------------------------------------------------------------
# Get the record for the top user

sub top_user {
    my ($self, $id) = @_;

    my ($filename, $extra) = $self->id_to_filename($id);
    my $users = $self->read_secondary($filename);
    $users = $self->{lo}->list_sort($users);

    return $users->[0];
}

#---------------------------------------------------------------------------
# Write a text database with fields separated by a colon

sub update_password_file {
    my ($self, $filename) = @_;

    my $records = $self->read_secondary($filename);

    my $output = '';    
    foreach my $record (@$records) {        
		$output .= "$record->{user}:$record->{password}\n";
    }

    $self->{wf}->write_wo_validation(PASSWORD_FILE, $output);
    return;
}

#---------------------------------------------------------------------------
# Write a text database with records separated by double bars

sub write_secondary {
    my ($self, $filename, $request) = @_;

    $request->{password} = $self->encrypt($request->{password});
    $self->SUPER::write_secondary($filename, $request);
    $self->update_password_file($filename);
    
    return;
}

1;
