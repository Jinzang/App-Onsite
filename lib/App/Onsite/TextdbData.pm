use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# A module to read and write from a free form text database

package App::Onsite::TextdbData;

use base qw(App::Onsite::FileData);

#----------------------------------------------------------------------
# Construct command links for page from page id

sub command_links {
	my ($self, $id, $commands) = @_;
    
    my @links;
    $commands ||= $self->{commands};
    my ($parentid, $seq) = $self->{wf}->split_id($id);
    
    foreach my $cmd (@$commands) {
        next unless $self->check_command($id, $cmd);
        
        my $query = {cmd => $cmd};  

        if ($cmd eq 'add' || $self->is_parent_command($cmd)) {
            $query->{id} = $parentid;
            my $type =$self->has_one_subtype($id);
            if ($type) {
                $query->{type} = $type;
                $query->{subtype} = $type if $cmd eq 'add';
            }

        } else {
            $query->{id} = $id;
            $query->{type} = $self->get_type();
        }
        
        my $link = $self->single_command_link($query);
        push (@links, $link);
    }
 
    return \@links;
}

#----------------------------------------------------------------------
# Get field information from first record of file

sub field_info {
    my ($self, $id) = @_;

	my ($filename, $extra) = $self->id_to_filename($id);
	my $info = $self->read_info($filename);

	my %field_info;
	foreach my $key (sort keys %$info) {
		my ($field, $attribute) = split(/\./, $key, 2);

		$field_info{$field} = {NAME => $field}
			unless exists $field_info{$field};
		$field_info{$field}{$attribute} = $info->{$key}
			if defined $attribute;
	}

    my @field_info;
	foreach my $field (reverse sort keys %field_info) {
		push(@field_info, $field_info{$field});
	}

    return \@field_info;
}

#---------------------------------------------------------------------------
# Get fields from info block

sub get_fields {
    my ($self, $info) = @_;
    
	my %fields = (id => 1);
	foreach my $key (sort keys %$info) {
		my ($name, $attribute) = split(/\./, $key, 2);
        $fields{$name} = 1;
	}

    return \%fields;
}

#---------------------------------------------------------------------------
# Return type as subtype of parent

sub get_subtypes {
    my ($self, $id) = @_;

    my @subtypes;    
    my ($filename, $extra) = $self->id_to_type($id);

    push(@subtypes, $self->get_type()) unless $extra;
    return \@subtypes;
}

#----------------------------------------------------------------------
# Return true if there is only one subtype

sub has_one_subtype {
    my ($self, $id) = @_;
    
    my ($filename, $extra) = $self->id_to_type($id);
    return $self->get_type() unless $extra;
    
    return;
}

#----------------------------------------------------------------------
# Get the type of a file given its id

sub id_to_type {
    my ($self, $id) = @_;

    my ($filename, $extra) = $self->id_to_filename($id);
    my $basename = $self->{wf}-> get_basename($filename);

    my $type = $basename;
    $type =~ s/\.[^\.]*$//;
    
    return $type;
}

#---------------------------------------------------------------------------
# Read a text database with records separated by double bars

sub read_every_record {
    my ($self, $filename) = @_;

    my @records;
    my $text = $self->{wf}->reader($filename);

    if ($text) {
        my @lines = split(/\n/, $text);

        my $oldname;
        my $record = {};

        foreach (@lines) {
            if (/^\|\|\s*$/) {
                push (@records, $record) if %$record;
                $oldname = '';
                $record = {};

            } else {
                my ($name, $value) = split (/\s*\|\s*/, $_, 2);

                unless (defined $value) {
                    $value = $name;
                    $name = $oldname;
                }

                $value =~ s/\s+$//;

                if (exists $record->{$name}) {
                    $record->{$name} .= "\n$value";
                } else {
                    $record->{$name} = $value;
                }

                $oldname = $name;
            }
        }

        push (@records, $record) if %$record;
    }

    return \@records;
}

#---------------------------------------------------------------------------
# Read info, which is in first record of file

sub read_info {
	my ($self, $filename) = @_;

	my $records = $self->read_every_record($filename);

	my $info = shift @$records;
	return $info;
}

#----------------------------------------------------------------------
# Create a fake data record for the primary

sub read_primary {
    my ($self, $filename) = @_;

    my $id = $self->filename_to_id($filename);
    my $type = $self->id_to_type($id);
    
    my $utype = ucfirst($type);
    my $title = "$utype Data";
    my $summary =  "Make changes to the $type data";
    
    return {title => $title, summary => $summary, id => $id};
}

#---------------------------------------------------------------------------
# Read info, which is in first record of file

sub read_secondary {
	my ($self, $filename) = @_;

	my $records = $self->read_every_record($filename);
	my $info = shift @$records;

	return $records;
}

#---------------------------------------------------------------------------
# Write a text database with records separated by double bars

sub write_secondary {
    my ($self, $filename, $request) = @_;

	# Read info record or generate if new file

	my $info;
    my $records;
	if (-e $filename) {
        $records = $self->read_every_record($filename);
        $info = shift @$records;
        
	} else {
		$info = {};
        $records = [];
		foreach my $field (keys %$request) {
			next if $field eq 'id';
			$info->{"$field.valid"} = '';
		}
	}
    
    $records = $self->{lo}->list_change($records, $request);
    $records = $self->{lo}->list_sort($records);

	# Add info record to output
	unshift(@$records, $info);

    my $count = 0;
    my $output = '';
    my $fields = $self->get_fields($info);

    foreach my $record (@$records) {
        while (my ($name, $value) = each %$record) {
            $output .= "$name|$value\n" if $count == 0 || $fields->{$name};
        }

        $output .= "\|\|\n";
        $count ++;
    }

    $self->{wf}->writer($filename, $output);

    return;
}

#---------------------------------------------------------------------------
# Module documentation

=head1 NAME

Textdb is a module that implements a simple text database.

=head1 SYNOPSIS

    @db = read_dbase ($filename);
    for $record (@db) {
	$record->{date} = localtime;
	print "== Record ==\n";
	for $field (keys %$record) {
	    print $field, " = ", $record->{$field}, "\n";
	}
   }

   write_dbase ($filename, @db);

=head1 DESCRIPTION

Textdb implements a simple text database for the information that cannot
be stored  in a web page. The file format is designed to be easy to create and
update with a text editor. The database consists of a set of records
and each record has fields that can vary from record to
record. Records are separated from each other by a line containing
only a double bar (C<||>). Fields have a name and a value. The name is
separated from the value by a single bar (C<|>). Blank space
immediately preceding and following the bar is ignored. Normally each
field occupies a single line, but fields can extend onto following
lines as long as these lines do not contain a bar character. The bar
character was chosen as a delimeter as it does not normally occur in
text. Here is an example of the database format.

    name.valid |&
    password.valid |&
    password.style |type=password
    mail.valid |&/@/
    ||
    name| John Doe
    password|ae57f2
    mail|doe721@yahoo.com
    ||
    name| Mary Smith
    password | 56ac41
    mail| mary.smith@google.com
    ||

The first record in the file holds the information for each field in
the database. The file is read into a list of hashes. Each hash is
a database record and each key-value pair in the hash is a database
field. This class implements the minimal interface required by
MultiRecordFileData:

=over 4

=item field_info

Returns a list of attributes for each field in the database

=item read_primary

Read a (faked) summary of the database contents

=item read_secondary $filename

Read a text database file into memory. This function returns a list of
hashes.

=item write_secondary $filename $records

Write a list of hashes to a file.

=back

=head1 AUTHOR

Bernie Simon

=cut

1;
