# Copyright (c) 2012, Mitchell Cooper
package M::IOHandle;

our $VERSION = '1.2';

use strict;
use warnings;
use base 'JE::Object';

use Scalar::Util 'reftype';

sub new {
    my ($class, $global, $handle) = @_;
    return if !ref $handle || reftype $handle ne 'GLOB';
    my $self = $class->SUPER::new($global, { prototype => $global->prototype_for('IOHandle') });
    $$self->{handle} = $handle;
    $self
}

sub _new_constructor {
    my $global = shift;
    my $construct_cref = sub { __PACKAGE__->new(@_) };

    my $f = JE::Object::Function->new({
        name             => 'IOHandle',
        scope            => $global,
        function         => $construct_cref,
        function_args    => ['global', 'args'],
        length           => 1,
        constructor      => $construct_cref,
        constructor_args => ['global', 'args'],
    });

    bless my $proto = $f->prop({
        name     => 'prototype',
        dontenum => 1,
        readonly => 1
    });

    # print()
	$proto->prop({
		name  => 'print',
		value => JE::Object::Function->new({
			scope    => $global,
			name     => 'print',
			length   => 0,
			no_proto => 1,
            argnames => ['data'],
			function_args => ['this', 'args'],
			function => \&_print
		}),
		dontenum => 1
	});

    # say()
	$proto->prop({
		name  => 'say',
		value => JE::Object::Function->new({
			scope    => $global,
			name     => 'say',
			length   => 0,
			no_proto => 1,
            argnames => ['data'],
			function_args => ['this', 'args'],
			function => \&_say
		}),
		dontenum => 1
	});

    # read()
	$proto->prop({
		name  => 'read',
		value => JE::Object::Function->new({
			scope    => $global,
			name     => 'read',
			length   => 0,
			no_proto => 1,
            argnames => ['length', 'offset'],
			function_args => ['this', 'args'],
			function => \&_read
		}),
		dontenum => 1
	});

    # sysread()
	$proto->prop({
		name  => 'sysread',
		value => JE::Object::Function->new({
			scope    => $global,
			name     => 'sysread',
			length   => 0,
			no_proto => 1,
            argnames => ['length', 'offset'],
			function_args => ['this', 'args'],
			function => \&_sysread
		}),
		dontenum => 1
	});

    $global->prototype_for('IOHandle', $proto);

    $f
}

sub _print {
    my ($self, $data) = @_;
    return $self->global->true if $$self->{handle}->print($data);
    $self->global->true
}

sub _say {
    my ($self, $data) = @_;
    return $self->global->true if $$self->{handle}->say($data);
    $self->global->true
}

sub _read {
    my ($self, $length, $offset) = @_;
    $$self->{handle}->read(my $data, $length, $offset);
    $data
}

sub _sysread {
    my ($self, $length, $offset) = @_;
    $$self->{handle}->sysread(my $data, $length, $offset);
    $data
}

sub class { 'IOHandle' }

1
