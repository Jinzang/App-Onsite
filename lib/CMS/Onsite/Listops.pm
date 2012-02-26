use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Create an object that performs list operations

package CMS::Onsite::Listops;

use base qw(CMS::Onsite::Support::ConfiguredObject);

#----------------------------------------------------------------------
# Add or replace an item in the list

sub list_add {
    my ($self, $list, $data) = @_;
    $list = [$list] if ref $list ne 'ARRAY';

    my $changed;
    my @new_list = @$list;
    foreach my $item (@new_list) {
        if ($item->{id} eq $data->{id}) {
            $changed = 1;
            $item = $data;
        }
    }

    push(@new_list, $data) unless $changed;
    return \@new_list;
}

#----------------------------------------------------------------------
# Delete an object from a list, if present

sub list_delete {
    my ($self, $list, $id) = @_;
    $list = [$list] if ref $list ne 'ARRAY';

    my @new_list;
    foreach my $item (@$list) {
        push (@new_list, $item) unless $item->{id} eq $id;
    }

    return \@new_list;
}

#----------------------------------------------------------------------
# Escape html in list items

sub list_escape {
    my ($self, $list) = @_;

    my @escaped_list;
    foreach my $hash (@$list) {
        my $escaped_hash = {};

        foreach my $name (keys %$hash) {
            if (ref $hash->{$name}) {
            $escaped_hash->{$name} = $hash->{$name};

            } else {
            my $value = $hash->{$name};
            $value =~ s/&/&amp;/g;
            $value =~ s/</&lt;/g;
            $value =~ s/>/&gt;/g;

            $escaped_hash->{$name} = $value;
            }
        }

        push(@escaped_list, $escaped_hash);
    }

    return \@escaped_list;
}
#----------------------------------------------------------------------
# Retrieve an item from a list by id

sub list_find {
    my ($self, $list, $id) = @_;
    $list = [$list] if ref $list ne 'ARRAY';

    my @new_list;
    foreach my $item (@$list) {
        return $item if $item->{id} eq $id;
    }

    return;
}


#----------------------------------------------------------------------
# Retrieve the item from the list with the largest id

sub list_max {
    my ($self, $list) = @_;
    $list = [$list] if ref $list ne 'ARRAY';

    my $maxitem;
    foreach my $item (@$list) {
        if ($maxitem) {
            $maxitem = $item if $item->{id} gt $maxitem->{id};
        } else {
            $maxitem = $item;
        }
    }

    return $maxitem;
}

#----------------------------------------------------------------------
# Compare two lists for equality

sub list_same {
    my ($self, $list1, $list2) = @_;
    $list1 = [$list1] if ref $list1 ne 'ARRAY';
    $list2 = [$list2] if ref $list2 ne 'ARRAY';

    return unless @$list1 == @$list2;

    for my $i (0 .. $#{$list1}) {
        return unless ref $list1->[$i] eq 'HASH' &&
                  ref $list1->[$i] eq 'HASH';

        # Operation is not symmetric
        # We only check for fields in the first list

        foreach my $field (keys %{$list1->[$i]}) {
            return unless $list1->[$i]{$field} eq $list2->[$i]{$field};
        }
    }

    return 1;
}

#----------------------------------------------------------------------
# Sort a list of items

sub list_sort {
    my ($self, $list, $sort) = @_;
    $list = [$list] if ref $list ne 'ARRAY';

    my $order;
    my $sort_field;

    if (defined $sort) {
        $sort_field = $sort;
        $sort_field =~ s/^([+-])//;
        $order =  $1 || '+';

    } else {
        $sort_field = 'id';
        $order = '+';
    }

    @$list = sort {$a->{$sort_field} cmp $b->{$sort_field}} @$list;
    @$list = reverse @$list if $order eq '-';

    return $list;
}

1;
