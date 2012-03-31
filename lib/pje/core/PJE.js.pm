package M::PJE;

our $VERSION = '1.0';

use strict;
use warnings;

our @ISA = 'JE::Object';

require JE::Object;

sub new {
    my ($class, $global) = @_;
    my $self = $class->SUPER::new($global);

    $self->prop({
        name      => 'version',
        value     => JE::String->new($global, $P::VERSION),
        dontdel   => 1,
        readonly  => 1
    });

    $self->prop({
        name      => 'jeVersion',
        value     => JE::String->new($global, $JE::VERSION),
        dontdel   => 1,
        readonly  => 1
    });

    $self->prop({
        name      => 'baseVersion',
        value     => JE::String->new($global, $JE::VERSION),
        dontdel   => 1,
        readonly  => 1
    });

    # moduleExists()
    $self->prop({
        name  => 'moduleExists',
        value => JE::Object::Function->new({
            scope    => $global,
            name     => 'moduleExists',
            argnames => [qw/module/],
            no_proto => 1,
            function_args => ['global', 'args'],
            function => \&_moduleExists,
        })
    });

    # moduleLoaded()
    $self->prop({
        name  => 'moduleLoaded',
        value => JE::Object::Function->new({
            scope    => $global,
            name     => 'moduleLoaded',
            argnames => [qw/module/],
            no_proto => 1,
            function_args => ['global', 'args'],
            function => \&_moduleLoaded,
        })
    });

    # moduleFile()
    $self->prop({
        name  => 'moduleFile',
        value => JE::Object::Function->new({
            scope    => $global,
            name     => 'moduleFile',
            argnames => [qw/module/],
            no_proto => 1,
            function_args => ['global', 'args'],
            function => \&_moduleFile,
        })
    });

    $self
}

sub _moduleExists {
    my ($global, $module) = @_;
    if (exists $P::MODULES{$module}) {
        return $global->true;
    }
    return $global->false;
}

sub _moduleLoaded {
    my ($global, $module) = @_;
    if (exists $P::LOADED{$module}) {
        return $global->true;
    }
    return $global->false;
}

sub _moduleFile {
    my ($global, $module) = @_;
    if (exists $P::MODULES{$module}) {
        return $P::MODULES{$module};
    }
    return $global->undefined;
}

sub class { 'PJE' }

1
