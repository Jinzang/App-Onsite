use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Simple website editor

package App::Onsite::Form;

use App::Onsite::FieldValidator;

use base qw(App::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
                      form_title => 'Onsite Editor',
                      wf => {DEFAULT => 'App::Onsite::Support::WebFile'},
                    );

    return %parameters;
}

#----------------------------------------------------------------------
# Create the form to receive user input

sub create_form {
    my ($self, $request, $msg) = @_;

    my $results = {};
    $results->{error} = $msg || '';
    $results->{title} = $self->{form_title};

    my $form = $self->get_command($request);
    $form->{hidden} = $self->get_hidden_fields($request);
    $form->{visible} = $self->get_visible_fields($request);
    $form->{buttons} = $self->get_buttons($request);
    $results->{form} = $form;

    return $results;
}

#---------------------------------------------------------------------------
# Build the hidden fields on the form

sub get_buttons {
    my ($self, $request) = @_;

    my @fields;
    for my $button (('cancel', $request->{cmd})) {
        my $field = $self->get_field('cmd', ucfirst($button), 'submit');
        push(@fields, {field => $field});
    }

   return \@fields;
}

#----------------------------------------------------------------------
# Create form to send request

sub get_command {
    my ($self, $request) = @_;

    my %command;
    my $field_info = $request->{field_info};

    $command{url} = $request->{script_url};
    $command{encoding} = 'application/x-www-form-urlencoded';

    foreach my $info (@{$field_info}) {
        my $validator = App::Onsite::FieldValidator->new(%$info);
        $command{encoding} = 'multipart/form-data'
            if $validator->field_type($info->{style}) eq 'file';
    }

    return \%command;
}

#---------------------------------------------------------------------------
# Build a form field

sub get_field {
    my ($self, $name, $value, $info) = @_;

    my ($style, $valid);
    if (ref $info) {
        $style = exists $info->{style} ? $info->{style} : '';
        $valid = exists $info->{valid} ? $info->{valid} : '';
    } else {
        $valid = '';
        $style = "type=$info";
    }

    my $validator = App::Onsite::FieldValidator->new(valid => $valid);
    return $validator->build_field($name, $value, $style);
}

#---------------------------------------------------------------------------
# Build the hidden fields on the form

sub get_hidden_fields {
    my ($self, $request) = @_;

    my @fields;
    my $field_info = $request->{field_info};
    my @hidden_fields = ('subtype', 'id');

 
    foreach my $info (@$field_info) {
        my $validator = App::Onsite::FieldValidator->new(%$info);

        push(@hidden_fields, $info->{NAME})
            if $validator->field_type($info->{style}) eq 'hidden';
    }

    foreach my $name (@hidden_fields) {
        next unless exists $request->{$name};
        my $value = $request->{$name};

        my $field = $self->get_field($name, $value, 'hidden');
        push(@fields, {field => $field});
    }

    my $field = $self->get_field('nonce', $self->{wf}->get_nonce(), 'hidden');
    push(@fields, {field => $field});

    return \@fields;
}

#---------------------------------------------------------------------------
# Build the visible fields on the form

sub get_visible_fields {
    my ($self, $request) = @_;

    my @fields;
    my $field_info = $request->{field_info};

    foreach my $info (@$field_info) {
        my $validator = App::Onsite::FieldValidator->new(%$info);
        next if $validator->field_type($info->{style}) eq 'hidden';

    	my %field;
    	my $name = $info->{NAME};
        my $value = exists $request->{$name} ? $request->{$name} : '';

        $field{title} = $info->{title} || ucfirst($name);
        $field{class} = $validator->{required} ? 'required' : 'optional';
        $field{field} = $self->get_field($name, $value, $info);
        push(@fields, \%field);
    }

    return \@fields;
}

1;
