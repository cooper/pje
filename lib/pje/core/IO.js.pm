# Copyright (c) 2012, Mitchell Cooper
package M::IO;

our $VERSION = '1.0';

use strict;
use warnings;
use base 'JE::Object';

require JE::Object;

sub new {
    my ($class, $global) = @_;
    my $self = $class->SUPER::new($global);

    $self
}

sub class { 'IO' }

1
