# Movable Type (r) Open Source (C) 2001-2011 Six Apart, Ltd.
# This program is distributed under the terms of the
# GNU General Public License, version 2.
#
# $Id$

package MT::ObjectDriver::SQL::SQLite;

use strict;
use warnings;
use base qw( MT::ObjectDriver::SQL );

sub new {
    my $class = shift;
    my %param = @_;
    my $cd = delete $param{count_distinct};
    my $stmt = $class->SUPER::new(%param);
    if ($cd) {
        $stmt->{count_distinct} = $cd;
    }
    return $stmt;
}

#--------------------------------------#
# Instance Methods

sub as_sql {
    my $stmt = shift;
    return $stmt->SUPER::as_sql(@_) unless exists $stmt->{count_distinct};
    my $cd  = delete $stmt->{count_distinct};
    my ($col) = each %$cd;
    my @select = @{$stmt->select};
    $stmt->select([$col]);
    my $class = ref $stmt;
    my $main_stmt = $class->new;
    $main_stmt->select(\@select);
    $main_stmt->from_stmt($stmt);
    $main_stmt->as_sql(@_);
}

sub field_decorator {
    my $stmt = shift;
    my ($class) = @_;
    return sub {
        my($term) = @_;
        my $field_prefix = $class->datasource;
        my $new_term = q();
        while ($term =~ /extract\((\w+)\s+from\s+([\w_]+)\)(\s*desc|asc)?/ig) {
            my $extract = "strftime('";
            if ('year' eq lc($1)) {
                $extract .= '%Y';
            } elsif ('month' eq lc($1)) {
                $extract .= '%m';
            } elsif ('day' eq lc($1)) {
                $extract .= '%d';
            }
            $extract .= "', $2)";
            $extract .= $3 if defined $3;
            $new_term .= ', ' if $new_term;
            $new_term .= $extract;
        }
        $new_term = $term unless $new_term;
        for my $col (@{ $class->column_names }) {
            $new_term =~ s/\b$col\b/${field_prefix}_$col/g;
        }
        return $new_term;
    };
}

1;
