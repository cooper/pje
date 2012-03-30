package JE::Core;

use warnings;
use strict;

our $s = $JE::s;

sub parseInt {
	my ($self, $scope, $str, $radix) = @_;
	$radix = defined $radix ? $radix->to_number->value : 0;
	$radix == $radix and $radix != $radix+1 or $radix = 0;
	
	if(defined $str) {
		($str = $str->to_string)
			=~ s/^$s//;
	} else { $str = 'undefined' };
	my $sign = $str =~ s/^([+-])//
		? (-1,1)[$1 eq '+']
		:  1;
	$radix = (int $radix) % 2 ** 32;
	$radix -= 2**32 if $radix >= 2**31;
	$radix ||= $str =~ /^0x/i
	?	16
	:	10
	;
	$radix == 16 and
		$str =~ s/^0x//i;

	$radix < 2 || $radix > 36 and return
		JE::Number->new($self,'nan');
		
	my @digits = (0..9, 'a'..'z')[0
		..$radix-1];
	my $digits = join '', @digits;
	$str =~ /^([$digits]*)/i;
	$str = $1;

	my $ret;
	if(!length $str){
		$ret= 'nan' ;
	}
	elsif($radix == 10) {
		$ret= $sign * $str;
	}
	elsif($radix == 16) {
		$ret= $sign * hex $str;
	}
	elsif($radix == 8) {
		$ret= $sign * oct $str;
	}
	elsif($radix == 2) {
		$ret= $sign * eval
			"0b$str";
	}
	else { my($num, $place);
	for (reverse split //, $str){
		$num += ($_ =~ /[0-9]/ ? $_
		    : ord(uc) - 55) 
		    * $radix**$place++
	}
	$ret= $num*$sign;
	}

	return JE::Number->new($self,$ret);
}

sub eval {
	my ($self, $code) = @_;
	return $self->undefined unless defined
		$code;
	return $code if typeof $code ne 'string';
	my $old_at = $@; # hope it's not tied
	defined (my $tree = 
		($JE::Code::parser||$self)
		->parse($code))
		or die;
	my $ret = execute $tree
		$JE::Code::this,
		$JE::Code::scope, 1;

	ref $@ ne '' and die;
	
	$@ = $old_at;
	$ret;
}

sub parseFloat {
	my ($self, $scope, $str, $radix) = @_;
	
	defined $str or $str = '';
	ref $str eq 'JE::Number' and return $str;
	ref $str eq 'JE::Object::Number'
	 and return $str->to_number;
	return JE::Number->new($self, $str =~
		/^$s
		  (
		    [+-]?
		    (?:
		      (?=[0-9]|\.[0-9]) [0-9]*
		      (?:\.[0-9]*)?
		      (?:[Ee][+-]?[0-9]+)?
		        |
		      Infinity
		    )
		  )
		/ox
		?  $1 : 'nan');
}

sub isNaN {
    JE::Boolean->new(shift, !defined $_[0] || shift->to_number->id eq 'num:nan');
}

sub isFinite {
	my ($self, $val) = @_;
	JE::Boolean->new($self,
		defined $val &&
		($val = $val->to_number->value)
			== $val &&
		$val + 1 != $val
	);
}

1
