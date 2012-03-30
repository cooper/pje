package JE::Object::JE;

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
        value     => JE::Number->new($global, $JE::VERSION),
        dontdel   => 1,
        readonly  => 1
    });

    $self->prop({
        name      => 'baseVersion',
        value     => JE::Number->new($global, $JE::VERSION),
        dontdel   => 1,
        readonly  => 1
    });

    $self
}

sub class { 'JE' }

1
