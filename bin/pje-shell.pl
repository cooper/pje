#!/usr/bin/perl

use warnings;
use strict;

our %dir;
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

use JE;
