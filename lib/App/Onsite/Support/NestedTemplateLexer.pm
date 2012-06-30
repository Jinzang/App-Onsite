use strict;
use warnings;
use integer;

package App::Onsite::Support::NestedTemplateLexer;

use base qw(App::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Return strings that represent patterns

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
        meta_char => '*',
    	block => '<!--*-->',
    	macro => '{{*}}',
        value => '[[*]]',
        render_hash => '<dl>*</dl>',
        render_hash_name => '<dt>*</dt>',
        render_hash_value => '<dd>*</dd>',
        render_list => '<ul>*</ul>',
        render_list_value => '<li>*</li>',
    	block_cmds => [qw(end with begin set if unless)],
    );

    return %parameters;
}

#----------------------------------------------------------------------
# Build the regular expression to match a block

sub build_block_pattern {
    my ($self) = @_;

    my ($left, $right) = $self->meta_split('block');

    my $block_pattern = '(' . quotemeta($left) . ')'
	. '\s*(' . join('|', @{$self->{block_cmds}})
        . ')\s+([\w\.]+)(.*?)'
	. quotemeta($right);

    return $block_pattern;
}

#----------------------------------------------------------------------
# Build the regular expression to match a macro

sub build_macro_pattern {
    my ($self) = @_;

    my ($left, $right) = $self->meta_split('macro');
    my $pattern = quotemeta($left) . '\s*([\w\.]+)\s*' . quotemeta($right);

    return $pattern;
}

#----------------------------------------------------------------------
# Replace meta character in field with string

sub meta_replace {
    my ($self, $field, $string) = @_;
    $string = '' unless defined $string;

    my $value = $self->{$field};
    die "Unknown parameter: ($field)\n" unless $value;

    my $meta = quotemeta($self->{meta_char});
    $value =~ s/$meta/$string/;

    return $value;
}

#----------------------------------------------------------------------
# Split string in two parts at macro character

sub meta_split {
    my ($self, $field) = @_;

    my $value = $self->{$field};
    die "Unknown parameter: ($field)\n" unless $value;

    my $meta = quotemeta($self->{meta_char});
    my ($left, $right) = split(/$meta/, $value, 2);
    $right = "\n" unless defined $right;

    return $left, $right;
}

#----------------------------------------------------------------------
# Return an object that returns token

sub tokenize {
    my ($self, $source) = @_;

    my $block_pattern = $self->build_block_pattern();
    my @tokens = split (/$block_pattern/s, $source);

	return \@tokens
}

1;
