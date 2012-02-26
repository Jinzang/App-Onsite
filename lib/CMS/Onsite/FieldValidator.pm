use strict;
use warnings;

package CMS::Onsite::FieldValidator;

use CGI ':form';
use base qw(CMS::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Base class for form field validation

sub populate_object {
    my ($self, $configuration) = @_;
    my $valid = $configuration->{valid} || '';

    my ($type) = $valid =~ /^\&?(\w+)/;
	my $utype = defined $type ? ucfirst($type) : '';
    my $pkg = "CMS::Onsite::${utype}FieldValidator";

    return $self->parse($pkg, $valid);
}

#----------------------------------------------------------------------
# Parse the validaion expression

sub parse {
    my ($self, $pkg, $valid) = @_;

    $self->{required} = 1 if $valid =~ s/^\&//;
    $valid =~ s/^\w+//;

    my $parsed;
    if ($valid =~ /^[\[\(]/) {
        ($self->{limits}) = $valid =~ /^([\[\(].*[\]\)])$/;
        $parsed = 1 if defined $self->{limits};
    } elsif ($valid =~ /^\|/) {
        ($self->{selection}) = $valid =~ /^\|(.*)\|$/;
        $parsed = 1 if defined $self->{selection};
    } elsif ($valid =~ /^\//) {
        ($self->{regexp}) = $valid =~ /^\/(.*)\/$/;
        $parsed = 1 if defined $self->{regexp};
    } else {
        $parsed = 1 if length($valid) == 0;
    }

    die "Couldn't parse $self->{valid}" unless $parsed;
    return bless ($self, $pkg);
}

#----------------------------------------------------------------------
# Build an html field to accept input

sub build_field {
    my ($self, $name, $value, $style) = @_;
    $style = '' unless defined $style;

    my ($type, $args) = $self->field_defaults();
    $args->{"-value"} = $value;
    $args->{"-name"} = $name;
    $args->{"-id"} = "$name-field";

    my @pairs = split(/;/, $style);
    foreach my $pair (@pairs) {
        my ($pair_name, $pair_value) = split(/=/, $pair);
        $pair_value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;

        if ($pair_name eq 'type') {
            $type = $pair_value;
        } else {
            $args->{"-$pair_name"} = $pair_value;
        }
    }

    my $field;
    if ($type eq 'text') {
        $field = textfield(%$args);
    } elsif ($type eq 'textarea') {
        $field = textarea(%$args);
    } elsif ($type eq 'password') {
        delete $args->{'-value'};
        $field = password_field(%$args);
    } elsif ($type eq 'file') {
        $field = filefield(%$args);
    } elsif ($type eq 'submit') {
        delete $args->{"-id"};
        $field = submit(%$args);
    } elsif ($type eq 'hidden') {
         $field = hidden(%$args);
    } elsif ($type eq 'popup') {
        $args->{"-default"} ||= $args->{"-value"};
        $field = popup_menu(%$args);
    } elsif ($type eq 'radio') {
        $args->{"-default"} ||= $args->{"-value"};
        $field = radio_group(%$args);
    } else {
        $field = textfield(%$args);
    }

    $field =~ s/ +/ /g;
    return $field;
}

#----------------------------------------------------------------------
# Put value in canonical form

sub canonize {
    my ($self, $value) = @_;

    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    $value =~ s/\s+/ /g;

    return $value;
}

#----------------------------------------------------------------------
# Set field defaults from validation rules

sub field_defaults {
    my ($self) = @_;

    my $type = 'text';
    my $args = {};

    if (exists $self->{selection}) {
        $type = 'popup';
        my @selections = split(/\|/, $self->{selection});
        $args->{"-values"} = \@selections;
    }

    return ($type, $args);
}

#----------------------------------------------------------------------
# Get field type

sub field_type {
    my ($self, $style) = @_;
    $style = '' unless defined $style;

    my $type = exists $self->{selection} ? 'popup' : 'text';
    my @pairs = split(/;/, $style);

    foreach my $pair (@pairs) {
	my ($pair_name, $pair_value) = split(/=/, $pair);
        if ($pair_name eq 'type') {
            $type = $pair_value;
            last;
        }
    }

    return $type;
}

#----------------------------------------------------------------------
# Return 1 if field is required

sub required {
    my ($self) = @_;

    my $required;
    $required = 1 if exists $self->{required};

    return $required;
}

#----------------------------------------------------------------------
# Test if field value is valid

sub validate {
    my ($self, $value) = @_;

    $value = $self->canonize($value);

    if (length($value)) {
        return unless $self->valid_type($value);
        return if $self->{limits} && ! $self->valid_limits($value);
        return if $self->{selection} && ! $self->valid_selection($value);
        return if $self->{regexp} && ! $self->valid_regexp($value);

    } else {
        return if $self->{required} && length($value) == 0;
    }

    return 1;
}

#----------------------------------------------------------------------
# Test if value is valid for this type (stub)

sub valid_type {
    my ($self, $value) = @_;

    return 1;
}

#----------------------------------------------------------------------
# Validate value against limits

sub valid_limits {
    my ($self, $value) = @_;

    my $limits = $self->{limits};

    my ($min, $max);
    if ($limits =~ /^\[/) {
        ($min) = $limits =~ /^\[([^,]+),/;
        return if defined $min && $value < $min;
    } elsif ($limits =~  /^\(/) {
        ($min) = $limits =~ /^\(([^,]+),/;
        return if defined $min && $value <= $min;
    }

    if ($limits =~ /\]$/) {
        ($max) = $limits =~ /,([^,]+)\]$/;
        return if defined $max && $value > $max;
    } elsif ($limits =~  /\)$/) {
        ($max) = $limits =~ /,([^,]+)\)$/;
        return if defined $max && $value >= $max;
    }

    die "Coludn't parse $self->{valid}"
        unless defined $min || defined $max;

    return 1;
}

#----------------------------------------------------------------------
# Validate value against list

sub valid_selection {
    my ($self, $value) = @_;

    my @selections = split(/\|/, $self->{selection});

    my $found;
    foreach my $selection (@selections) {
        if ($selection eq $value) {
            $found = 1;
            last;
        }
    }

    return $found;
}

#----------------------------------------------------------------------
# Validate value against regular expression

sub valid_regexp {
    my ($self, $value) = @_;
    return $value =~ /^$self->{regexp}$/;
}

#----------------------------------------------------------------------
package CMS::Onsite::NumberFieldValidator;

use base qw(CMS::Onsite::FieldValidator);

#----------------------------------------------------------------------
# Check if the value is a number

sub valid_type {
    my ($self, $value) = @_;

    return $value =~ /^-?(?:\d+(?:\.\d*)?|\.\d+)$/;
}

#----------------------------------------------------------------------
# Check if value is in a list of values

sub valid_selection {
    my ($self, $value) = @_;
    return 1 unless $self->{selection};

    my @selections = split(/\|/, $self->{selection});

    my $found;
    foreach my $selection (@selections) {
        if ($selection == $value) {
            $found = 1;
            last;
        }
    }

    return $found;
}

#----------------------------------------------------------------------
package CMS::Onsite::IntegerFieldValidator;

use base qw(CMS::Onsite::NumberFieldValidator);

sub valid_type {
    my ($self, $value) = @_;

    return $value =~ /[\-\+]?\d+/;
}

#----------------------------------------------------------------------
package CMS::Onsite::StringFieldValidator;

use base qw(CMS::Onsite::FieldValidator);

#----------------------------------------------------------------------
# Sanitize html

sub canonize {
    my ($self, $value) = @_;

    $value =~ s/([^\s\w.,&#;-])/'&#'.ord($1).';'/ge;
    return $self->CMS::Onsite::FieldValidator::canonize($value);
}

#----------------------------------------------------------------------
# Anything is a string

sub valid_type {
    my ($self, $value) = @_;

    return 1;
}

#----------------------------------------------------------------------
# String limits are length limits

sub valid_limits {
    my ($self, $value) = @_;

    $value =~ s/&#(\d+);/chr($1)/ge;
    return $self->SUPER::valid_limits(length($value));
}

#----------------------------------------------------------------------
package CMS::Onsite::HtmlFieldValidator;

use base qw(CMS::Onsite::StringFieldValidator);

#----------------------------------------------------------------------
# Override html escaping

sub canonize {
    my ($self, $value) = @_;

    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    $value =~ s/[\t ]+/ /g;

    return $value;
}

#----------------------------------------------------------------------
# Set field defaults from validation rules

sub field_defaults {
    my ($self) = @_;

    my $type = 'textarea';
    my $args = {};

    if (exists $self->{selection}) {
        $type = 'popup';
        my @selections = split(/\|/, $self->{selection});
        $args->{"-values"} = \@selections;
    }

    return ($type, $args);
}

1;
