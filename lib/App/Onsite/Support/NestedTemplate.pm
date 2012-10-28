use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Parse a template into a data structure

package App::Onsite::Support::NestedTemplate;

use App::Onsite::Support::TemplateBlock;
use base qw(App::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Return strings that represent patterns

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
		wf => {DEFAULT => 'App::Onsite::Support::WebFile'},
		cache => {DEFAULT => 'App::Onsite::Support::CachedFile'},
		lexer => {DEFAULT => 'App::Onsite::Support::NestedTemplateLexer'},
    );

    return %parameters;
}

#----------------------------------------------------------------------
# Return hash of all blocks in containing block

sub data {
    my ($self, @sources) = @_;

    my $template = $self->parse(@sources);
    return $template->data();
}

#----------------------------------------------------------------------
# Return list of all registered blocks in containing block

sub info {
    my ($self, @sources) = @_;

    my $template = $self->parse(@sources);
    return $template->info();
}

#----------------------------------------------------------------------
# Check to see if string is a template

sub is_template {
    my ($self, $source) = @_;

    my $pattern = $self->{lexer}->build_macro_pattern();
    return 1 if $source =~ /$pattern/;

    my $block_pattern = $self->{lexer}->build_block_pattern();
    return 1 if $source =~ /$block_pattern/;

    return;
}

#----------------------------------------------------------------------
# Create a new template only containing blocks in a mask

sub mask_template {
    my ($self, $mask, @sources) = @_;
    
    my $template = $self->parse(@sources);
    return $template->mask_template($mask);
}

#----------------------------------------------------------------------
# Match a block in the template by its name

sub match {
    my ($self, $names, @sources) = @_;

    my $template = $self->parse(@sources);
    return $template->match($names);
}

#----------------------------------------------------------------------
# Parse template source files

sub parse {
    my ($self, @sources) = @_;

	my @templates;
    foreach my $source (@sources) {
		if (defined($self->{cache}->fetch($source))) {
			# Parsed source has been cached
			push(@templates, $self->{cache}->fetch($source));
            
        } elsif (ref $source &&
                 $source->isa('App::Onsite::Support::TemplateBlock')) {
    		# Already parsed
            push(@templates, $source);
            
        } else {
            my $key = $source;
            
            if (ref $source) {
                if ($source->isa('IO::Handle')) {
                    # Uploaded file
                    $source = do {local $/; <$source>};

                } else {
                    die ref($source) .  " is not a template\n";
                }

			} elsif (! $self->is_template($source)) {
                $source = $self->{wf}->reader($source)                
            }
        
            # Parse string into template
 
            my $tokens = $self->{lexer}->tokenize($source);
            my $tb = App::Onsite::Support::TemplateBlock->new($self->{lexer});
            my $template = $tb->parse($tokens);
    
            # Cache the parsed source for later use
            
            $self->{cache}->save($key, $template);
            push (@templates, $template);
        }
    }

    return $self->subtemplate(@templates);
}

#----------------------------------------------------------------------
# Render a data structure using the template block

sub render {
    my ($self, $data, @sources) = @_;

    my $template = $self->parse(@sources);
    return $template->render($data);

}

#----------------------------------------------------------------------
# Combine template and subtemplates

sub subtemplate {
	my ($self, @templates) = @_;

	my $template;
	while (@templates) {
		my $subtemplate = pop(@templates);
		$template = pop(@templates);

		if ($template) {
			push(@templates, $template->subtemplate($subtemplate));

		} else {
			$template = $subtemplate;
		}
	}

	return $template;
}

#----------------------------------------------------------------------
# Recreate the source file from the parsed version

sub unparse {
    my ($self, $template) = @_;

    return $template->unparse();
}

1;

__END__

=head1 NAME

App::Onsite::Support::NestedTemplate inserts and extracts data from a template

=head1 SYNOPSIS

    $obj = App::Onsite::Support::NestedTemplate->new();
    $template = $obj->parse($template_source, $subtempate_source);
    $template_source = $obj->unparse($template);
    $page = $obj->render($data, $template);
    $data = $obj->data($template_source);
    $info = $obj->info($template_source);

=head1 DESCRIPTION

The purpose of any template class is to simplify the presentation of data, most
usually as a web page. This template class was written to allow the two way
manipulation of data. Data can be both written and then read back. Similarly,
the template can be parsed from source, manipulated as an object, and then
unparsed back to source again. The reason for supporting all these functions
is to allow static web pages and their templates to be edited by the end user.

This class produces text from a data structure and a template. The data
structure may contain any combination of scalars, lists, and hashes, nested to
any depth. How the data is included in the template is controled by macros and
block commands contained in the template source. Macros indicate where the items
in the data should be inserted. The code

    $t = App::Onsite::Support::NestedTemplate->new();
    $template = $t->parse($template_source);

produces a template from its source file and the code

    $output = $t->render($data, $template);

substitutes the items in the data structure into the template to
produce the output text.

The template

    <p>My name is {{name}}. I have a {{things}}</p>

contains two macros. If App::Onsite::Support::NestedTemplate renders the
template using the hash

    {name => 'Bernie', things => 'computer'}

it will output a text string with the macros replaced by the
corresponding values in the hash.

    <p>My name is Bernie. I have a computer</p>

If the hash contains additional elements, they are ignored. And if the
hash does not contain an element with the same name as the macro, that is not an
error, the macro is replaced by nothing. Macro names should only include Perl
word characters: letters, numbers, and underscores.

If your data item contains something more complex than a scalar,
App::Onsite::Support::NestedTemplate will render it using its default formats:
an unordered list for lists and a definition list for hashes. For example
when App::Onsite::Support::NestedTemplate uses this template to render the hash

    {name => 'Bernie, things => ['computer, 'cell phone']}

it produces

    <p>My name is Bernie. I have a
    <ul>
    <li>computer</li>
    <li>cellphone></li>
    </ul>
    </p>

 and it renders the hash

    {name => 'Bernie',
     things => {computer => 'Imac',  cellphone => 'Iphone'}}

as

   <p>My name is Bernie. I have a
    <dl>
    <dt>cellphone></dt>
    <dd>Iphone</dd>
    <dt>computer</dt>
    <dd>Imac</dd>
    </dl>
    </p>

Note that the hash elements are sorted by key when they are rendered. Hashes and
lists can be nested to any depth and will produce a corresponding output of
definition lists and unordered lists.

App::Onsite::Support::NestedTemplate's defaults are useful for dumping your data
when you are debugging your script, but usually you want more control over how
your data is rendered. Blocks allow you to control how the substructures in
your data are rendered. By replacing the macro {{things}} with a block so that
the template looks like

    <p>My name is {{name}}. I have a
    <!-- with things -->{{computer}} computer and a
    {{cellphone}} cellphone<!-- end things --></p>

App::Onsite::Support::NestedTemplate will produce the output

    <p>My name is Bernie. I have a
    Imac ccomputer and a
    Iphone cellphone</p>

A with block acts like macro, but provides additional information for rendering
complex data structures. How it renders the data depnds on what kind of data it
is given. If it is given a hash, it replaces macros with matching values from
the hash, as seen above. If it is given a list, it renders each element of the
list with the block and concatenates the results. The most common case is a list
of hashes. For example, if the template looks like

    <p>My name is {{name}}.
    <!-- with things -->I have a {{name}} {{object}}.<!-- end things -->
    </p>

and the data is

    {name => 'Bernie',
     things => [
                {name => 'Imac', object => 'computer'},
                {name => 'Iphone', object => 'cellphone}
               ]
    }

the ouput will be

    <p>My name is Bernie.
    I have a Imac computer.
    I have a Iphone cellphone.
    </p>

This example is worth noting, as it represents a very common case. The data is
a hash containing some fields describing all the records and a list of hashes
where each hash represents one of the records.

Another case is when the list contains either scalar elements or other lists,
In this case App::Onsite::Support::NestedTemplate replaces the macro in the
block with the list element. It doesn't matter what the macro name is, because
list elements have no name. For example, if the template is:

    <table>
    <!-- with books -->
    <tr><td>{{title}}</td></tr>
    <!-- end books -->
    </table>

and the data is

    {books => ['Silas Marner', 'Moby Dick']}

the output will be

    <table>
    <tr><td>Silas Marner</td></tr>
    <tr><td>Moby Dick</td></tr>
    </table>

Similarly, if a block is used to render a simple scalar, the macro in the block
is replaced by the value of the scalar, no matter what the macro name is. There
is one other case, when the name in the with block does not match any data. In
that case the output contains the original contents of the with block.

App::Onsite::Support::NestedTemplate also supprts conditional blocks. If blocks
are rendered if the data item associated with the block name is Perl true
(non-zero or not an empty array or hash). For example, the following code will
print the number of results (a scalar) or an error message if no results are
found from a search.

    <!-- if results -->
    <p>Your search matched {{results}} records.</p>
    <!-- end if --><!-- unless results -->
    <p>No matches were found.</p>
    <!-- end unless -->

To summarize, a CGI script produces a complex data structure that it wants
to render. The data structure contains scalars, lists, and hashes in some
combination. Wherever you have a hash containing scalars, use a macro. If you
have text you want included conditionally, surround it with a block with an
expression. If the hash contains lists or other hashes, place a block within the
hash to show how render it. Apply these rules recursively to render your data
structure.

App::Onsite::Support::NestedTemplate supports subtemplates to simplify
producing several pages with common text. A subtemplate replaces blocks in
the main template with blocks from the subtemplate, allowing you to use the
parts of the main template that do not change between the two. You apply a
subtmplate with the code:

    $t = App::Onsite::Support::NestedTemplate->new();
    $template = $t->parse($template_source, $subtemplate_source);
    $output = $t->render($data, $template);

Methods in App::Onsite::Support::NestedTemplate check their arguments to see
if the template has been compiled, is a source file, or is the name of a file
contaiing the source. If the argument is a source file, it first calls the parse
method. This is even true of parse. If it is passed a compiled template, it
simply returns that template. So it is not necessary to call parse before render,
although if a template is being used more than once, it is more efficient to
parse it first. If the methods of App::Onsite::Support::NestedTemplate are
passed the name of a file, the file is read and then parsed. A string is
considered a filename if it does not contain any template markup. If a method
is called with a filename, the parsed source is cached for the next method call.

Here is an example of the render method calling parse implicitly:

    $t = App::Onsite::Support::NestedTemplate->new();
    $output = $t->render($data, $template_source);

These two lines can be combined to create a single line to render a data file
using a template

    $output = App::Onsite::Support::NestedTemplate->new()->render($template_source, $data);

The source file for a template can be recreated by calling the method unparse.
This allows you to modify the parsed data structure and create a new source file
with the modifications. A template is most often modified by subtemplating it

    $t = App::Onsite::Support::NestedTemplate->new();
    $template = $t->parse($template_source, $subtemplate_source);
    $new_source = $t->unparse($template);

TODO describe data and info calls

=head1 AUTHOR

Bernie Simon, E<lt>bernie.simon@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bernie Simon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
