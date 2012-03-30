#!/usr/bin/perl

use warnings;
use strict;

our $dir;
BEGIN {
    chdir($dir = shift @ARGV or die "Run directory not specified.\n")
    or die "Unable to switch working directory.\n";
    unshift @INC, $dir;
}
