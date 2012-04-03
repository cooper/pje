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

search_directory($_) foreach @J_INC;

sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(%opts);

    $self->prop({
        name => $_,
        autoload => "load(\$global, '$_')",
        dontenum => 1
    }) foreach keys %MODULES;

    $self->prop({
        name     => 'context',
        value    => $self,
        dontenum => 1,
        readonly => 1
    });

    $self
}

sub load_js {
    my ($global, $mod) = @_;
    if (!$LOADED{$mod}) {
        my $j = __PACKAGE__->new;
        $$j->{class} = $mod;
        open my $fh, $MODULES{$mod};
        my @lines = <$fh>;
        my $res   = $j->eval(join "\n", @lines);
        $LOADED{$mod} = 1;
        return $j->{_new} ? create_js_package($global, $mod, $j) : $res;
    }        
}

sub load_pm {
    my ($global, $mod) = @_;
    if (!$LOADED{$mod}) { do $MODULES{$mod} or return }
    $LOADED{$mod} = 1;
    if (my $code = "M::$mod"->can('_new_constructor')) {
        return $code->($global);
    }
    "M::$mod"->new($global);
}

sub load_now ($) {
    my $mod = shift;
    do $MODULES{$mod} if !$LOADED{$mod}
}

sub load {
    my ($global, $mod) = @_;
    return if $LOADED{$mod} || !$MODULES{$mod};
    given ($MODULES{$mod}) {
        when (/\.pm$/) { return load_pm($global, $mod) }
        when (/\.js$/) { return load_js($global, $mod) }
        default        { return }
    }
}

sub create_js_package {
    my ($global, $mod, $context) = @_;
    my $new  = delete $context->{_new};
    my $self = JE::Object->new($global);
    my $construct_cref = sub { $new->apply($self, @_) };

    my $f = JE::Object::Function->new({
        name             => $mod,
        scope            => $global,
        function         => $construct_cref,
        function_args    => ['global', 'args'],
        length           => 1,
        constructor      => $construct_cref,
        constructor_args => ['global', 'args'],
    });

    bless my $proto = $$self->{prototype} = $f->prop({
        name     => 'prototype',
        dontenum => 1,
        readonly => 1
    });
    $global->prototype_for($mod, $proto);

    # add prototype functions beginning with _
    foreach my $function (keys %$context) {
        if ($function =~ m/^_(.+)/) {
            my $fref = delete $context->{$function};
            $function = $$fref->{func_name} = $1;
            $proto->prop({
                name     => $function,
                value    => $fref,
                dontenum => 1
            });
        }
        else {
            $f->{$function} = delete $context->{$function};
        }
    }

    undef $context;
    $f
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
            next if $next !~ m/(.+?)\.(js.pm|js)$/;
            $MODULES{$1} = "$curr/$next" unless $MODULES{$1};
        }
        $curr = $last_curr;
    }
}

1
