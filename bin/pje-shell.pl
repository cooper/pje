#!/usr/bin/perl

use warnings;
use strict;
use 5.010;

our %dir;
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

use JE;

my $j = JE->new;

while (1) {
    print '> ';
    my $next   = <STDIN>;
    my $result = $j->eval($next);
    say defined $result ? jsify($result) : 'undefined';
}

sub jsify {
    my $what = shift;
}
