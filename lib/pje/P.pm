# Copyright (c) 2012, Mitchell Cooper
package P;

use warnings;
use strict;
use base 'JE';
use 5.010;

use JE;
use IO::Dir;

our $VERSION = '1.0';

# search directories
our @J_INC = (
    '.', './lib', './script',       # running directory
    "$main::dir{lib}/core",         # core module directory
    "$main::dir{lib}/extensions"    # installed module directory
);

our (%MODULES, %LOADED);

search_directories();

sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(%opts);
    $self->prop({
        name => $_,
        autoload => "
                    if (!\$LOADED{$_}) { do '$MODULES{$_}' or return; }
                    \$LOADED{$_} = 1;
                    if (M::$_\->can('_new_constructor')) {
                        return M::$_\::_new_constructor(\$global)
                    }
                    M::$_\->new(\$global)",
        dontenum => 1
    }) foreach keys %MODULES;
    $self
}

sub load ($) {
    my $mod = shift;
    return if $LOADED{$mod};
    $LOADED{$mod} = do $MODULES{$mod} or return;
}

# find autoload modules
sub search_directories {
    search_directory($_) foreach @J_INC;
}

# search a directory for modules
sub search_directory {
    my $dir = shift;
    return if $dir eq '..';
    my $curr = $dir;
    my $d = IO::Dir->new($dir);
    while ($d and my $next = $d->read) {
        next if $next eq '.' || $next eq '..';
        my $last_curr = $curr;
        if (-d "$curr/$next") {
            search_directory("$curr/$next");
        }
        elsif (-f "$curr/$next") {
            next if $next !~ m/(.+?)\.(pjs|js|jsc|pjsc|js.pm)/;
            $MODULES{$1} = "$curr/$next" unless $MODULES{$1};
        }
        $curr = $last_curr;
    }
}

1
