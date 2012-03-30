#!/usr/bin/perl

use warnings;
use strict;
use 5.010;

our %dir;
my  %used;
$| = 1;
BEGIN {
    my $dir = shift @ARGV or die "Run directory not specified.\n";
    $dir =~ s/\/bin$//;
    %dir = (
        bin   => "$dir/bin",
        lib   => "$dir/lib/pje",
        share => "$dir/share/pje"
    );
    unshift @INC, $dir{lib};
}

use Scalar::Util 'blessed';
use JE;

my $j = JE->new;

while (1) {
    print '> ';
    my $next   = <STDIN>;
    my $result = $j->eval($next);
    say defined $result ? jsify($result) : 'undefined';
    %used = ();
}

sub jsify {
    defined(my $val = shift) or return;
    return $val unless blessed($val);

    # array
    if ($val->isa('JE::Object::Array') || ($val->isa('JE::Object') && $val->is_array)
        || ($val->can('class') && $val->class eq 'Array')) {
        return '(used)' if ref $val && $used{$val->id};
        my @str;
        foreach my $elem (@$val) {
            my $str = jsify($elem);
            $str =~ s/\n/\n    /g;
            push @str, $str;
        }
        $used{$val->id} = 1 if ref $val;
        return "[\n    ".join(",\n    ", @str)."\n]";
    }

    # string
    if ($val->isa('JE::String') || $val->typeof eq 'string') {
        return '"' . $val . '"';
    }

    # Error
    if ($val->isa('JE::Object::Error')) {
        return $val->name.': '.$val->{message};
    }

    # Object
    if ($val->isa('JE::Object') || $val->typeof eq 'object') {
        return '(used)' if ref $val && $used{$val->id};
        my @str;
        foreach my $key (keys %$val) {
            my $str = $key.': '.(jsify($val->{$key}));
            $str =~ s/\n/\n    /g;
            push @str, $str;
        }
        $used{$val->id} = 1 if ref $val;
        return "{\n    ".join(",\n    ", @str)."\n}";
    }

    # other
    $val
}
