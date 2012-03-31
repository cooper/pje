# Copyright (c) 2012, Mitchell Cooper
package M::process;

our $VERSION = '1.0';

use strict;
use warnings;

our @ISA = 'JE::Object';

require JE::Object;

sub new {
    my ($class, $global) = @_;
    my $self = $class->SUPER::new($global);

    $self->prop({
        name      => 'pid',
        value     => JE::Number->new($global, $$),
        dontdel   => 1,
        readonly  => 1
    });

    $self->prop({
        name      => 'name',
        dontdel   => 1,
        readonly  => 1
    });

    $self
}

sub prop {
    my $self = shift;

    # program name
    if ($_[0] eq 'name') {
        $0 = $_[1] if defined $_[1];
        return JE::String->new($self->global, $0);
    }

    # other
    $self->SUPER::prop(@_);
}

sub class { 'process' }

1
