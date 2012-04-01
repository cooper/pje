# Copyright (c) 2012, Mitchell Cooper
package M::Socket;

use strict;
use warnings;

our $VERSION = '1.0';
our @ISA     = 'M::IOHandle';
P::load('IOHandle');

use IO::Socket::IP;

sub new {
    my ($class, $global, $opts) = @_;
    $global->{IOHandle} or return; # tells JE to load IOHandle module
    return if !ref $opts || (ref $opts ne 'HASH' && !UNIVERSAL::can($opts, 'typeof'));
    $opts = $opts->value if UNIVERSAL::can($opts, 'typeof');
    my %opts = %$opts;

    # lowercasify them
    $opts{lc($_)} = $opts{$_} foreach keys %opts;

    # create options hash
    my %ropts = (
        Proto  => $opts{proto} || 'tcp',
        Domain => _domainify($opts{domain}),
        Type   => _typify($opts{type}) || Socket::SOCK_STREAM()
    );

    # re-casify them
    $ropts{$_} = $opts{lc($_)} foreach qw(PeerPort PeerAddr LocalPort LocalAddr Listen);

    # delete empty options
    foreach (qw|PeerPort PeerAddr LocalAddr LocalPort Listen Domain|) {
        delete $ropts{$_} if !$ropts{$_};
    }

    my $socket = IO::Socket::IP->new(%ropts) or return;
    my $self   = $class->SUPER::new($global, $socket) or return;
    $$self->{prototype} = $global->prototype_for('Socket');
    $self
}

# turns 'stream' into Socket's SOCK_STREAM consant
sub _typify {
    my $type = 'SOCK_'.uc(shift || '');
    if (my $code = Socket->can($type)) {
        return $code->();
    }
    return
}


# turns 'inet' into Socket's AF_INET constant
sub _domainify {
    my $type = 'AF_'.uc(shift || '');
    if (my $code = Socket->can($type)) {
        return $code->();
    }
    ''
}

sub _new_constructor {
    my $global = shift;
    my $construct_cref = sub { __PACKAGE__->new(@_) };

    my $f = JE::Object::Function->new({
        name             => 'Socket',
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
    $proto->prototype($global->prototype_for('IOHandle'));
    $global->prototype_for('Socket', $proto);

    $f
}

sub class { 'Socket' }

1
