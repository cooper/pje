package JE;

use 5.008003;
use strict;
use warnings;
no warnings 'utf8';

our $JE_VERSION = '0.059';
our $VERSION    = '1.7';

use Carp 'croak';
use JE::Code 'add_line_number';
use JE::_FieldHash;
use Scalar::Util 1.09 qw'blessed refaddr weaken';

our @ISA = 'JE::Object';

require JE::Core;
require JE::Null;
require JE::Number;
require JE::Object;
require JE::Object::Function;
require JE::Parser;
require JE::Scope;
require JE::String;
require JE::Undefined;

our $s = qr.[\p{Zs}\s\ck]*.;

sub new {
    my $class = shift;

    # I can't use the usual object and function constructors, since
    # they both rely on the existence of  the global object and its
    # 'Object' and 'Function' properties.
    if (ref $class) {
        croak "JE->new is a class method and cannot be called " .
            "on a" . ('n' x ref($class) =~ /^[aoeui]/i) . ' ' .
             ref($class). " object."
    }

    my $self = bless \{
        keys => [],
        props => {

            Object => bless(\{

                func_name     => 'Object',
                func_argnames => [],
                func_args     => ['global','args'],
                function      => sub { JE::Object->new( @_ ) },

                constructor_args => ['global', 'args'],
                constructor      => sub { JE::Object->new( @_ ) },

                keys  => [],
                props => {
                    prototype => bless(\{
                        keys  => [],
                        props => {},
                    }, 'JE::Object')
                },
                prop_readonly => {
                    prototype => 1,
                    length    => 1,
                },
                prop_dontdel  => {
                    prototype => 1,
                    length    => 1,
                },
            }, 'JE::Object::Function'),

            Function => bless(\{
                func_name     => 'Function',
                func_argnames => [],
                func_args     => ['scope','args'],
                function      => sub {
                    JE::Object::Function->new($${$_[0][0]}{global}, @_[1..$#_])
                },

                constructor_args => ['scope','args'],
                constructor      => sub {
                    JE::Object::Function->new($${$_[0][0]}{global}, @_[1..$#_])
                },

                keys  => [],
                props => {
                    prototype => bless(\{
                        func_argnames => [],
                        func_args     => [],
                        function      => '',
                        keys          => [],
                        props         => {}
                    }, 'JE::Object::Function')
                },
                prop_readonly => {
                    prototype => 1,
                    length    => 1,
                },
                prop_dontdel => {
                    prototype => 1,
                    length    => 1,
                },
            }, 'JE::Object::Function')

        },

    }, $class;

    # create object and function prototypes and constructors
    my $obj_proto  = (my $obj_constr  = $self->prop('Object'))->prop('prototype');
    my $func_proto = (my $func_constr = $self->prop('Function'))->prop('prototype');

    # set global context and scope
    my $scope     = bless [$self], 'JE::Scope';
    $$_->{global} = $self  for $self, $obj_proto, $obj_constr, $func_proto, $func_constr;
    $$_->{scope}  = $scope for $func_constr, $obj_constr;

    # setup prototypes
    $self->prototype       ($obj_proto);
    $obj_constr->prototype ($func_proto);
    $func_constr->prototype($func_proto);
    $func_proto->prototype ($obj_proto);

    # create length attribute
    $_->prop({
        name     => 'length',
        dontenum => 1,
        value    => JE::Number->new($self, 1)
    }) foreach $obj_constr, $func_constr, $func_proto;

    # destroyer
    if ($JE::Destroyer) { JE::Destroyer::register($_) for $obj_constr, $func_constr }

    # Before we add anything else, we need to make sure that our global
    # true/false/undefined/null values are available.
    @{$$self}{'t', 'f', 'u', 'n'} = (
        JE::Boolean->new($self, 1),
        JE::Boolean->new($self, 0),
        JE::Undefined->new($self),
        JE::Null->new($self),
    );

    $self->prototype_for('Object',   $obj_proto);
    $self->prototype_for('Function', $func_proto);
    JE::Object::_init_proto($obj_proto);
    JE::Object::Function::_init_proto($func_proto);

    # fill the table.
    $self->_add_constructors();
    $self->_add_context_variables();
    $self->_add_context_methods();

    # Constructor args
    my %args = @_;
    $$self->{max_ops}   = delete $args{max_ops};
    $$self->{html_mode} = delete $args{html_mode};

    if ($args{autoload} && ref $args{autoload} eq 'HASH') {
        foreach my $name (keys %{$args{autoload}}) {
            my $pkg = $args{autoload}{$name};
            $self->prop({
                name => $name,
                autoload => "require $pkg;
                            if ($pkg\->can('_new_constructor')) {
                                return $pkg\::_new_constructor(\$global)
                            }
                            $pkg\->new(\$global)",
                dontenum => 1
            });
        }
    }

    return $self;
}

sub eval {
    my $code = shift->parse(@_);
    return if $@;
    $code->execute;
}

sub max_ops {
    my $self = shift;
    if (@_) { $$$self{max_ops} = shift; return }
    else { return $$$self{max_ops} }
}

sub html_mode {
    my $self = shift;
    if(@_) { $$$self{html_mode} = shift; return }
    else { return $$$self{html_mode} }
}




fieldhash my %wrappees;

sub upgrade {
    my @__;
    my $self = shift;
    my ($classes, $proxy_cache);
    for (@_) {
        if (defined blessed $_) {
            ($classes, $proxy_cache) = @$$self{'classes', 'proxy_cache'} if !$classes;
            my $ident = refaddr $_;
            my $class = ref;
            my $what  = $_;
            if (exists $classes->{$class}) {
                if ($proxy_cache->{$ident}) {
                    $what = $proxy_cache->{$ident};
                }
                else {
                    $what = $proxy_cache->{$ident} = exists $$classes{$class}{wrapper} ? do {
                        my $proxy = $$classes{$class}{wrapper}($self, $_);
                        weaken($wrappees{$proxy} = $_);
                        $proxy
                    } : JE::Object::Proxy->new($self, $_);
                }
            }
            push @__, $what;
        }
        else {
            push @__,
              !defined()
            ?    $self->undefined
            : ref($_) eq 'ARRAY'
            ?    JE::Object::Array->new($self, $_)
            : ref($_) eq 'HASH'
            ?    JE::Object->new($self, { value => $_ })
            : ref($_) eq 'CODE'
            ?    JE::Object::Function->new($self, $_)
            : $_ eq '0' || $_ eq '-0'
            ?    JE::Number->new($self, 0)
            :    JE::String->new($self, $_)
            ;
        }
    }
    @__ > 1 ? @__ : @__ == 1 ? $__[0] : ();
}

sub prototype_for {
	my $self = shift;
	my $class = shift;
	if(@_) {
		return $$$self{pf}{$class} = shift
	}
	else {
		return $$$self{pf}{$class} ||
		  ($self->prop($class) || return undef)->prop('prototype');
	}
}

sub _upgr_def {
# ~~~ maybe I should make this a public method named upgrade_defined
    defined $_[1] ? shift->upgrade(shift) : undef
}

sub parse     { goto &JE::Code::parse }
sub compile   { goto &JE::Code::parse }
sub undefined { $${+shift}{u}         }
sub true      { $${+shift}{t}         }
sub false     { $${+shift}{f}         }
sub null      { $${+shift}{n}         }
sub class     { 'JavaScriptContext'   }

sub _add_constructors {
    my $self = shift;

    # Array object
    $self->prop({
        name => 'Array',
        autoload =>
            'require JE::Object::Array;
             JE::Object::Array::_new_constructor($global)',
        dontenum => 1
    });

    # String object
    $self->prop({
        name => 'String',
        autoload =>
            'require JE::Object::String;
            JE::Object::String::_new_constructor($global)',
        dontenum => 1
    });

    # Boolean object
    $self->prop({
        name => 'Boolean',
        autoload =>
            'require JE::Object::Boolean;
            JE::Object::Boolean::_new_constructor($global)',
        dontenum => 1
    });

    # Number object
    $self->prop({
        name => 'Number',
        autoload =>
            'require JE::Object::Number;
            JE::Object::Number::_new_constructor($global)',
        dontenum => 1
    });

    # Date object
    $self->prop({
        name => 'Date',
        autoload =>
            'require JE::Object::Date;
            JE::Object::Date::_new_constructor($global)',
        dontenum => 1
    });

    # RegExp object
    $self->prop({
        name => 'RegExp',
        autoload => 
            'require JE::Object::RegExp;
             JE::Object::RegExp->new_constructor($global)',
        dontenum => 1
    });

    # Error
    $self->prop({
        name => 'Error',
        autoload =>
            'require JE::Object::Error;
             JE::Object::Error::_new_constructor($global)',
        dontenum => 1
    });

    # No EvalError

    # RangeError
    $self->prop({
        name => 'RangeError',
        autoload => 'require JE::Object::Error::RangeError;
                     JE::Object::Error::RangeError
                      ->_new_subclass_constructor($global)',
        dontenum => 1
    });

    # ReferenceError
    $self->prop({
        name => 'ReferenceError',
        autoload => 'require JE::Object::Error::ReferenceError;
                     JE::Object::Error::ReferenceError
                      ->_new_subclass_constructor($global)',
        dontenum => 1
    });

    # SyntaxError
    $self->prop({
        name => 'SyntaxError',
        autoload => 'require JE::Object::Error::SyntaxError;
                     JE::Object::Error::SyntaxError
                      ->_new_subclass_constructor($global)',
        dontenum => 1
    });

    # TypeError
    $self->prop({
        name => 'TypeError',
        autoload => 'require JE::Object::Error::TypeError;
                     JE::Object::Error::TypeError
                      ->_new_subclass_constructor($global)',
        dontenum => 1
    });

    # URIError
    $self->prop({
        name => 'URIError',
        autoload => 'require JE::Object::Error::URIError;
                     JE::Object::Error::URIError
                      ->_new_subclass_constructor($global)',
        dontenum => 1
    });

    # Math object
    $self->prop({
        name  => 'Math',
        autoload => 'require JE::Object::Math;
                     JE::Object::Math->new($global)',
        dontenum  => 1
    });

}

sub _add_context_variables {
    my $self = shift;

    # NaN
    $self->prop({
        name     => 'NaN',
        value    => JE::Number->new($self, 'NaN'),
        dontenum => 1,
        dontdel  => 1
    });

    # Infinity
    $self->prop({
        name     => 'Infinity',
        value    => JE::Number->new($self, 'Infinity'),
        dontenum => 1,
        dontdel  => 1
    });

    # undefined
    $self->prop({
        name     => 'undefined',
        value    => $self->undefined,
        dontenum => 1,
        dontdel  => 1
    });

}

sub _add_context_methods {
    my $self = shift;

    # eval()
    $self->prop({
        name  => 'eval',
        value => JE::Object::Function->new({
            scope    => $self,
            name     => 'eval',
            argnames => ['x'],
            function_args => ['args'],
            function => sub { JE::Core::eval($self, @_) },
            no_proto => 1,
        }),
        dontenum => 1
    });

    # parseInt()
    $self->prop({
        name  => 'parseInt',
        value => JE::Object::Function->new({
            scope    => $self,
            name     => 'parseInt', # E 15.1.2.2
            argnames => [qw/string radix/],
            no_proto => 1,
            function_args => [qw< scope args >],
            function => sub { JE::Core::parseInt($self, @_) },
        }),
        dontenum  => 1
    });

    # parseFloat()
    $self->prop({
        name  => 'parseFloat',
        value => JE::Object::Function->new({
            scope    => $self,
            name     => 'parseFloat', # E 15.1.2.3
            argnames => [qw/string/],
            no_proto => 1,
            function_args => [qw< scope args >],
            function => sub { JE::Core::parseFloat($self, @_) },
        }),
        dontenum  => 1
    });

    # isNaN()
    $self->prop({
        name  => 'isNaN',
        value => JE::Object::Function->new({
            scope    => $self,
            name     => 'isNaN',
            argnames => [qw/number/],
            no_proto => 1,
            function_args => ['args'],
            function => sub { JE::Core::isNaN($self, @_) }
        }),
        dontenum  => 1
    });

    # isFinite()
    $self->prop({
        name  => 'isFinite',
        value => JE::Object::Function->new({
            scope    => $self,
            name     => 'isFinite',
            argnames => [qw/number/],
            no_proto => 1,
            function_args => ['args'],
            function => sub { JE::Core::isFinite($self, @_) },
        }),
        dontenum  => 1
    });

    # decodeURI()
    $self->prop({
        name  => 'decodeURI',
        autoload => q{ require 'JE/escape.pl';
            JE::Object::Function->new({
                scope  => $global,
                name   => 'decodeURI',
                argnames => [qw/encodedURI/],
                no_proto => 1,
                function_args => ['scope','args'],
                function => \&JE'_decodeURI,
            })
        },
        dontenum  => 1
    });

    # decodeURIComponent()
    $self->prop({
        name  => 'decodeURIComponent',
        autoload => q{ require 'JE/escape.pl';
            JE::Object::Function->new({
            scope  => $global,
            name   => 'decodeURIComponent',
            argnames => [qw/encodedURIComponent/],
            no_proto => 1,
            function_args => ['scope','args'],
            function => \&JE'_decodeURIComponent
            })
        },
        dontenum  => 1
    });

    # encodeURI()
    $self->prop({
        name  => 'encodeURI',
        autoload => q{ require 'JE/escape.pl';
            JE::Object::Function->new({
            scope  => $global,
            name   => 'encodeURI',
            argnames => [qw/uri/],
            no_proto => 1,
            function_args => ['scope','args'],
            function => \&JE'_encodeURI,
            })
        },
        dontenum  => 1
    });
    $self->prop({
        name  => 'encodeURIComponent',
        autoload => q{ require 'JE/escape.pl';
            JE::Object::Function->new({
            scope  => $global,
            name   => 'encodeURIComponent',
            argnames => [qw/uriComponent/],
            no_proto => 1,
            function_args => ['scope','args'],
            function => \&JE'_encodeURIComponent,
            })
        },
        dontenum  => 1
    });

    # escape()
    $self->prop({
        name  => 'escape',
        autoload => q{
            require 'JE/escape.pl';
            JE::Object::Function->new({
                scope  => $global,
                name   => 'escape',
                argnames => [qw/string/],
                no_proto => 1,
                function_args => ['scope','args'],
                function => \&JE'_escape,
            })
        },
        dontenum  => 1
    });

    # unescape()
    $self->prop({
        name  => 'unescape',
        autoload => q{
            require 'JE/escape.pl';
            JE::Object::Function->new({
                scope  => $global,
                name   => 'unescape',
                argnames => [qw/string/],
                no_proto => 1,
                function_args => ['scope','args'],
                function => \&JE'_unescape,
            })
        },
        dontenum  => 1
    });
}

1

__END__

=head1 AUTHOR, COPYRIGHT & LICENSE

Based entirely on JE, the pure-Perl JavaScript engine on CPAN.

Copyright (C) 2007-12 Father Chrysostomos <sprout [at] cpan [dot] org>

This program is free software; you may redistribute it and/or modify
it under the same terms as perl.

Some of the code was derived from L<Data::Float>, which is copyrighted (C)
2006, 2007, 2008 by Andrew Main (Zefram).

=head1 ACKNOWLEDGEMENTS

Some of the

Thanks to Max Maischein, Kevin Cameron, Chia-liang Kao and Damyan Ivanov
for their
contributions,

to Andy Armstrong, Yair Lenga, Alex Robinson, Christian Forster, Imre Rad
and Craig Mackenna
for their suggestions,

and to the CPAN Testers for their helpful reports.

=cut
