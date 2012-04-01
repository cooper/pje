# Copyright (c) 2012, Mitchell Cooper
package M::IO;

our $VERSION = '1.0';

use strict;
use warnings;
use base 'JE::Object';

require JE::Object;

sub new {
    my ($class, $global) = @_;
    $global->{IOHandle} or return; # tells JE to load IOHandle module
    my $self = $class->SUPER::new($global);

    $self->prop({
        name      => 'out',
        value     => M::IOHandle->new($global, \*STDOUT),
        dontdel   => 1,
        readonly  => 1
    });

    $self->prop({
        name      => 'in',
        value     => M::IOHandle->new($global, \*STDIN),
        dontdel   => 1,
        readonly  => 1
    });

    $self
}

sub class { 'IO' }

1
