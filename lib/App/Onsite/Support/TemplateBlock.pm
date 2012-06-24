use strict;
use warnings;
use integer;

package App::Onsite::Support::TemplateBlock;

#----------------------------------------------------------------------
# Parse a template into a data structure

sub new {
    my ($pkg, $lexer)  = @_;

    return bless({LEXER => $lexer}, $pkg);
}

#----------------------------------------------------------------------
# Report a block mismatch error and die

sub block_mismatch {
    my ($self, $end) = @_;

    my $begin = $self->{NAME} || '';
    die "App::Onsite::Support::NestedTemplate: " .
		"Mismatched begin/end ($begin/$end)\n";
}

#----------------------------------------------------------------------
# Copy a template

sub copy {
	my ($self) = @_;

	my $ref = ref $self;
	my %template = %$self;
	@{$template{BLOCKS}} = @{$self->{BLOCKS}};

	return bless(\%template, $ref);
}

#----------------------------------------------------------------------
# Return hash of values of all blocks contained in this block

sub data {
    my ($self) = @_;
    return $self->{VALUE} unless $self->has_blocks();
    
	my $data = {};
    foreach my $block (@{$self->{BLOCKS}}) {
        my $value = $block->data();
		next unless defined $value;

		my $name = $block->{NAME};
		if (exists $data->{$name}) {
			my $oldvalue = $data->{$name};

			if (ref $oldvalue eq 'ARRAY') {
				push(@$oldvalue, $value);
			} else {
				$data->{$name} = [$oldvalue, $value];
			}

		} else {
			$data->{$name} = $value;
		}
    }

	$data = $self->{VALUE} unless %$data;
    return $data;
}

#----------------------------------------------------------------------
# Build data structure to render with the template

sub distribute_data {
    my ($self, $object, $data) = @_;

    my $result;
    foreach my $block (@{$self->{BLOCKS}}) {                
        my $name = $block->{NAME};
        my $cmd = "build_$name";

        if ($object->can($cmd)) {
            $result->{$name} = $object->$cmd($data);
        } else {
            $result->{$name} = $data;
        }
    }

    return $result;
}

#----------------------------------------------------------------------
# Test if template block has any sub-blocks

sub has_blocks {
    my ($self) = @_;
    
    return @{$self->{BLOCKS}} > 0;    
}

#----------------------------------------------------------------------
# Return list of information of all blocks contained in this block

sub info {
    my ($self) = @_;
    return $self->{VALUE} unless $self->has_blocks();
    
    my $info = [];
    foreach my $block (@{$self->{BLOCKS}}) {
        my $item = $block->info_item();
		next unless defined $item;

		$item->{NAME} = $block->{NAME};
		$item->{VALUE} = $block->info();

        push(@$info, $item);
    }

    return $info;
}

#----------------------------------------------------------------------
# Parse the block arguments

sub info_item {
    my ($self) = @_;

    my $item = {};
    my @tags = $self->{ARGS} =~ /(\w+(?:="[^"]*")?)/g;

    foreach my $tag (@tags) {
        my ($tagname, $tagvalue) = $tag =~ /(\w+)(?:="([^"]*)")?/;

        $tagvalue = undef unless defined $tagvalue;
        $item->{lc($tagname)} = $tagvalue;
    }

    return $item;
}

#----------------------------------------------------------------------
# Find matching block name in template

sub match {
	my ($self, $names) = @_;
    return unless $names && $self->has_blocks();
    
	my @names = split(/\./, $names);

	my $name = shift @names;
	$names = join('.', @names);

	foreach my $block (@{$self->{BLOCKS}}) {
		if ($name eq 'any' ||
            $block->{NAME} eq 'any' ||
            $name eq $block->{NAME}) {

			my $template = $names ? $block->match($names) : $block;
			return $template if $template;
		}
	}

	return;
}

#----------------------------------------------------------------------
# Parse a block and the blocks it contains, recursively

sub parse {
    my ($self, $tokens) = @_;

    my $value = '';
    my @blocks = ();
    my ($left, $right) = $self->{LEXER}->meta_split('block');
    my $marker = $left;

    while (@$tokens) {
		my $token = shift @$tokens;

		if ($token eq $marker) {
			my $cmd = shift @$tokens;
			my $name = shift @$tokens;
			my $args = shift @$tokens;

            if ($cmd eq 'end') {
                # Check block name

                $self->block_mismatch($name) unless exists $self->{NAME};
                $self->block_mismatch($name) if $name ne $self->{NAME};

                # Remove whitespace surrounding value
                $value =~ s/^\s+//;
                $value =~ s/\s+$//;

                $self->{VALUE} = $value;
                $self->{BLOCKS} = \@blocks;
                return $self;

            } else {
				my $ucmd = ucfirst($cmd);
                my $pkg =  "App::Onsite::Support::${ucmd}TemplateBlock";
                my $block = $pkg->new($self->{LEXER});
                $block->{CMD} = $cmd;
                $block->{NAME} = $name;
                $block->{ARGS} = $args;

                $block->parse($tokens);

                # Add reference to it in containing block
                my $index = @blocks;
                push(@blocks, $block);
                $value .= $self->{LEXER}->meta_replace('macro', $index);
            }

        } else {
            # Append text to current block
            $value .= $token;
        }
    }

    $self->block_mismatch('') if $self->{NAME};

    $self->{BLOCKS} = \@blocks;
    $self->{VALUE} = $value;
    return $self;
}

#----------------------------------------------------------------------
# Render a data structure using the template block

sub render {
    my ($self, $data) = @_;
    
    my $pattern = $self->{LEXER}->build_macro_pattern();
    my $result = $self->{VALUE};
    return '' unless defined $result;

    my $bin =  App::Onsite::Support::Bin->new($data);
    if ($result !~ s/$pattern/$self->render_macro($bin, $1)/ge) {
        $result = $self->render_data($data);
    }

    return $result;
}

#----------------------------------------------------------------------
# Render a template block

sub render_block {
    my ($self, $bin) = @_;

    my $data = $bin->get($self->{NAME});
    return $self->unparse() unless defined $data;

    my $result;
    if ($data =~ /ARRAY/) {
        # Take each element of the array, render, and concatenate the results

        my @results;
        foreach my $datum (@$data) {
            push(@results, $self->render($datum));
        }

        $result = join("\n", @results);

    } else {
        $result = $self->render($data);
    }

    return $result;
}

#----------------------------------------------------------------------
# Get the rendered value of a data structure

sub render_data {
    my ($self, $data, $cycles) = @_;
    $cycles = {} unless defined $cycles;

    my $result;
    if (! ref $data) {
	$result = $data;

    } else {
        # Check for cycles in the data to prevent an endless loop

        return "$data" if $cycles->{$data};
        $cycles->{$data} = 1;

        if ($data =~ /HASH/) {
            my @result;
            foreach my $key (sort keys %$data) {
                my $val = $self->render_data($data->{$key}, $cycles);

                push(@result, $self->{LEXER}->meta_replace('render_hash_name',
                                                           $key));
                push(@result, $self->{LEXER}->meta_replace('render_hash_value',
                                                           $val));
            }

            my ($left, $right) = $self->{LEXER}->meta_split('render_hash');
            $result = join("\n", $left, @result, $right);

        } elsif ($data =~ /ARRAY/) {
            my @result;
            foreach my $datum (@$data) {
                my $val = $self->render_data($datum, $cycles);
                push(@result, $self->{LEXER}->meta_replace('render_list_value',
                                                           $val));
            }

            my ($left, $right) = $self->{LEXER}->meta_split('render_list');
            $result = join("\n", $left, @result, $right);

        } elsif ($data =~ /SCALAR/) {
            $result = $$data;

        } else  {
            $result = "$data";
        }
    }

    return $result;
}

#----------------------------------------------------------------------
# Replace a macro with its rendered value

sub render_macro {
    my ($self, $bin, $name) = @_;

    my $result;
    if ($name =~ /^\d+$/) {
        my $block = $self->{BLOCKS}[$name];
        $result = $block->render_block($bin) if defined $block;

    } else {
        my $data = $bin->get($name, '');
        $result = $self->render_data($data);
    }

    $result = '' unless defined $result;
    return $result;
}

#----------------------------------------------------------------------
# Replace a block by a subtemplate block of the same name, if found

sub replace {
	my ($self, $block) = @_;

    my $new_block;
	my $subtemplate = $self->match($block->{NAME});

	if ($subtemplate) {
        if ($self->has_blocks() && $subtemplate->has_blocks()) {
            $new_block = $block->subtemplate($subtemplate);
        } else {
            $new_block = $subtemplate->copy();
        }
 
	} else {
		$new_block = $block->copy();
	}

	return $new_block;
}

#----------------------------------------------------------------------
# Replace blocks in template with block of sam name in subtemplate

sub subtemplate {
	my ($self, $subtemplate) = @_;

	my $blocks = $self->{BLOCKS};
	my $template = $subtemplate->copy();

	if (@$blocks) {
		my @new_blocks;
		$template->{VALUE} = $self->{VALUE};

        my $oldname= '';
		foreach my $block (@$blocks) {
            if ($block->{NAME} ne $oldname) {
                $oldname = $block->{NAME};
                push(@new_blocks, $subtemplate->replace($block));
            }
		}

		$template->{BLOCKS} = \@new_blocks;
	}

	return $template;
}

#----------------------------------------------------------------------
# Recreate the source file from the parsed version

sub unparse {
    my ($self) = @_;

    my $source = '';
    if (exists $self->{VALUE}) {
        my ($left, $right) = $self->{LEXER}->meta_split('macro');
        my $pattern = quotemeta($left) . '\s*(\d+)\s*' . quotemeta($right);

        $source = $self->{VALUE};
        $source =~ s/$pattern/$self->{BLOCKS}[$1]->unparse()/ge;
    }

    return $source;
}

#----------------------------------------------------------------------
package App::Onsite::Support::TemplateSubBlock;

use base qw(App::Onsite::Support::TemplateBlock);

#----------------------------------------------------------------------
# Surround source with blockname comments

sub decorate {
    my ($self, $source) = @_;

    my $cmd = $self->{CMD};
    my $blockname = $self->{NAME};
    my $args = $self->{ARGS};

    my $begin = $self->{LEXER}->meta_replace('block', " $cmd $blockname$args");
    my $end = $self->{LEXER}->meta_replace('block', " end $blockname ");

    $source = join("\n", $begin, $source, $end);
    return $source;
}

#----------------------------------------------------------------------
# Recreate the source file from the parsed version

sub unparse {
    my ($self) = @_;

    my $source = $self->App::Onsite::Support::TemplateBlock::unparse();
    return $self->decorate($source);
}

#----------------------------------------------------------------------
package App::Onsite::Support::TemplateControlBlock;

use base qw(App::Onsite::Support::TemplateSubBlock);

#----------------------------------------------------------------------
# Return undef to make control blocks invisible

sub data {
    my ($self) = @_;
    return;
}

#----------------------------------------------------------------------
# Return undef to make with blocks invisible

sub info_item {
    my ($self) = @_;
    return;
}

#----------------------------------------------------------------------
# Match fails for control blocks

sub match {
	my ($self, $names) = @_;
	return;
}

#----------------------------------------------------------------------
# Render a data structure which has already been "processed"

sub render {
    my ($self, $bin) = @_;

    my $pattern = $self->{LEXER}->build_macro_pattern();
    my $result = $self->{VALUE};
    $result =~ s/$pattern/$self->render_macro($bin, $1)/ge;

    return $result;
}

#----------------------------------------------------------------------
# Replace is a copy for control blocks

sub replace {
	my ($self, $subtemplate) = @_;

	return $self->copy();
}

#----------------------------------------------------------------------
package App::Onsite::Support::BeginTemplateBlock;

use base qw(App::Onsite::Support::TemplateSubBlock);

#----------------------------------------------------------------------
# Render a data structure using the template block

sub render {
    my ($self, $bin) = @_;

    my $result = $self->App::Onsite::Support::TemplateBlock::render($bin);
    return $self->decorate($result);
}

#----------------------------------------------------------------------
package App::Onsite::Support::IfTemplateBlock;

use base qw(App::Onsite::Support::TemplateControlBlock);

#----------------------------------------------------------------------
# Conditionally render a template block

sub render_block {
    my ($self, $bin) = @_;

    my $result;
    if ($self->test($bin)) {
        $result = $self->render($bin);

    } else {
        $result = '';
    }

    return $result;
}

#----------------------------------------------------------------------
# Render a data structure using the template block

sub test {
    my ($self, $bin) = @_;

    my $test;
    my $data = $bin->get($self->{NAME});

    my $ref = ref $data;
    if (! $ref) {
        $test = 1 if $data;

    } elsif ($data =~ /HASH/) {
        my $name = $self->{NAME};
        $test = 1 if %$data;

    } elsif ($data =~ /ARRAY/) {
        $test = 1 if @$data;

    } elsif ($data =~ /SCALAR/) {
        $test = 1 if $$data;

    } else  {
        $test = 1;
    }

    return $test;
}

#----------------------------------------------------------------------
package App::Onsite::Support::SetTemplateBlock;

use base qw(App::Onsite::Support::BeginTemplateBlock);

#----------------------------------------------------------------------
# Surround source with blockname comments

sub decorate {
    my ($self, $source) = @_;

    my $cmd = $self->{CMD};
    my $name = $self->{NAME};
    my $args = $self->{ARGS};
    $args .= $self->{LEXER}->meta_replace('value', $source) . ' ';

    $source = $self->{LEXER}->meta_replace('block', " $cmd $name$args");
    return $source;
}

#----------------------------------------------------------------------
# Parse a set command

sub parse {
    my ($self, @lexes) = @_;

    my ($left, $right) = $self->{LEXER}->meta_split('value');
    my $pattern = quotemeta($left) . '(.*)' . quotemeta($right);
    $self->{ARGS} =~ s/$pattern\s*//s;

    $self->{VALUE} = defined $1 ? $1 : '';
    $self->{BLOCKS} = [];

    return $self;
}

#----------------------------------------------------------------------
# Render a data structure using the template block

sub render_block {
    my ($self, $bin) = @_;

    my $data = $bin->get($self->{NAME}, '');
    return $self->decorate($data);
}

#----------------------------------------------------------------------
package App::Onsite::Support::WithTemplateBlock;

use base qw(App::Onsite::Support::TemplateSubBlock);

#----------------------------------------------------------------------
# Return undef to make with blocks invisible

sub data {
    my ($self) = @_;
    return;
}

#----------------------------------------------------------------------
# Return undef to make with blocks invisible

sub info_item {
    my ($self) = @_;
    return;
}

#----------------------------------------------------------------------
# Match fails for with blocks

sub match {
	my ($self, $names) = @_;
	return;
}

#----------------------------------------------------------------------
package App::Onsite::Support::UnlessTemplateBlock;

use base qw(App::Onsite::Support::IfTemplateBlock);

#----------------------------------------------------------------------
# Conditionally render a template block

sub render_block {
    my ($self, $bin) = @_;

    my $result;
    if ($self->test($bin)) {
        $result = '';
    } else {
        $result = $self->render($bin);
    }

    return $result;
}

#----------------------------------------------------------------------
# Bin holds the data used for interpolation

package App::Onsite::Support::Bin;

sub new {
    my ($pkg, @args) = @_;

    my %self;
    foreach my $arg (@args) {
        if (ref($arg) =~ /HASH/) {
            %self = (%self, %$arg);

        } else {
                die "App::Onsite::Support::NestedTemplate: " .
				"Can't have more than one anonymous object\n"
                    if exists $self{''};
                $self{''} = $arg;
        }
    }

    return bless(\%self, $pkg)
}

#----------------------------------------------------------------------
# Get the named value or the default value

sub get {
    my ($self, $name, $default) = @_;

    my $rest;
    if ($name =~ /\./) {
        ($name, $rest) = split(/\./, $name, 2);
    }

    my $val;
    if (exists $self->{$name}) {
        $val = $self->{$name};
        if (defined $rest) {
            my $bin = App::Onsite::Support::Bin->new($val);
            $val = $bin->get($rest, $default);
        }

    } elsif  (exists $self->{''}) {
        $val = $self->{''};

    } else {
        $val = $default;
    }

    return $val;
}

1;
