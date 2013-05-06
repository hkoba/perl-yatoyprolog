package InstanceVariables;
# -*- mode: perl; coding: utf-8 -*-
use strict;
use Carp;
use warnings FATAL => qw/all/;

# 継承を可能にするためには,
# このパッケージを利用するクラスのインスタンス全てについて,
# ↓ユニークな id を与える必要が有る.
our $uniq_id = 0;

our $debug = 0;
our $debug_template = 0;

# storage{$PACK::self} → storage[$PACK::self]
# にした方が速いが, 継承が使えなくなる…
# 一々 PACK::VAR::array と書かずに, 先頭で
# package 文を使えばそれでしまいのような…
our $array_template = <<'EODef';
{ package PACK::VAR::array;
  use strict;
  our %storage;
  sub TIEARRAY {
    my($v) = "";
    print "  tie array\tPACK::VAR\n"
      if $InstanceVariables::debug;
    bless \$v;
  }
  sub FETCH {
    InstanceVariables::Die("PACK", "VAR", "array") if !defined $PACK::self;
    $storage{$$PACK::self}->[$_[1]];
  }
  sub STORE {
    InstanceVariables::Die("PACK", "VAR", "array") if !defined $PACK::self;
    $storage{$$PACK::self}->[$_[1]] = $_[2];
  }
  sub FETCHSIZE {
    InstanceVariables::Die("PACK", "VAR", "array") if !defined $PACK::self;
    # print "~~", $#{$storage{$$PACK::self}}, "\n" ;
    my $ref = $storage{$$PACK::self} or return 0;
    scalar @$ref;
  }
  sub length {
    InstanceVariables::Die("PACK", "VAR", "array") if !defined $PACK::self;
    # print "~~", $#{$storage{$$PACK::self}}, "\n" ;
    $#{$storage{$$PACK::self}};
  }
  tie @PACK::VAR, 'PACK::VAR::array';
}
EODef

our $hash_template = <<'EODef';
{ package PACK::VAR::hash;
  use strict;
  our %storage;
  sub TIEHASH {
    my($v) = "";
    print "  tie hash\tPACK::VAR\n"
      if $InstanceVariables::debug;
    bless \$v;
  }
  sub FETCH {
    InstanceVariables::Die("PACK", "VAR", "hash") if !defined $PACK::self;
    $storage{$$PACK::self}->{$_[1]};
  }
  sub STORE {
    InstanceVariables::Die("PACK", "VAR", "hash") if !defined $PACK::self;
    $storage{$$PACK::self}->{$_[1]} = $_[2];
  }
  sub EXISTS {
    InstanceVariables::Die("PACK", "VAR", "hash") if !defined $PACK::self;
    exists $storage{$$PACK::self}->{$_[1]};
  }
  sub FIRSTKEY {
    InstanceVariables::Die("PACK", "VAR", "hash") if !defined $PACK::self;
    my($k, $v) = each %{$storage{$$PACK::self}};
    $k;
  }
  sub NEXTKEY {
    InstanceVariables::Die("PACK", "VAR", "hash") if !defined $PACK::self;
    my($k, $v) = each %{$storage{$$PACK::self}};
    $k;
  }
  tie %PACK::VAR, 'PACK::VAR::hash';
}
EODef

our $scalar_template = <<'EODef';
{ package PACK::VAR::scalar;
  use strict;
  our %storage;
  sub TIESCALAR {
    my($v) = "";
    print "  tie scalar\tPACK::VAR\n"
      if $InstanceVariables::debug;
    bless \$v;
  }
  sub FETCH {
    InstanceVariables::Die("PACK", "VAR", "scalar") if !defined $PACK::self;
    $storage{$$PACK::self};
  }
  sub STORE {
    InstanceVariables::Die("PACK", "VAR", "scalar") if !defined $PACK::self;
    $storage{$$PACK::self} = $_[1];
  }
  tie $PACK::VAR, 'PACK::VAR::scalar';
}
EODef

{
  package InstanceVariables::Object;
  sub new {
    my ($pack) = shift;
    my ($id) = ++$InstanceVariables::uniq_id;
    my ($self) = bless \$id, $pack;
    if (my $sub = $self->can("init")) {
      $sub->($self, @_);
    }
    $self;
  }
  # XXX: This DESTROY is *NOT* working, sorry.
  sub DESTROY {
    my ($self) = @_;
    print STDERR "<destroy: $$self>\n" if $InstanceVariables::debug;
    foreach (@PACK::HAS){
	if( s/^\@// ){
	    delete ${"PACK::${_}::array::storage"}{$self};
	} elsif( s/^\%//) {
	    delete ${"PACK::${_}::hash::storage"}{$self};
	} elsif( s/^\$// || m/^\w/ ){
	    delete ${"PACK::${_}::scalar::storage"}{$self};
        } else {
	    die "Unknown specifier: $_";
	}
    }
  }
}

sub globref {
  my ($class, $name) = @_;
  no strict 'refs';
  \*{join("::", $class, $name)};
}

sub import {
    my ($callpack) = caller;
    # caller の HAS の各要素毎に
    # package を作る.
    my $pack = shift;

    my $has = globref($callpack, 'HAS');

    if(!defined *{$has}{ARRAY} && @_) {
      # 引数を, HAS に set.
      *$has = [@_]
    }
    foreach (@{*{$has}{ARRAY}}) {
	if( s/^\@// ){
	  my $sym = globref($callpack, $_);
	  *$sym = [];
	    &do_eval($array_template, $callpack, $_);
	    # tie @{"${callpack}::$_"},"${callpack}::${_}::array";
	} elsif( s/^\%//) {
	  my $sym = globref($callpack, $_);
	  *$sym = {};
	    &do_eval($hash_template, $callpack, $_);
	} elsif( s/^\$// || m/^\w/ ){
	  my $sym = globref($callpack, $_);
	  *$sym = \ (my $var = undef);
	    &do_eval($scalar_template, $callpack, $_);
        } else {
	    die "Unknown specifier: $_";
	}
    }

    {
      my $isa = globref($callpack, 'ISA');
      *$isa = ["InstanceVariables::Object"];
    }
}
sub do_eval {
    my($template, $callpack, $varname) = @_;
    $template =~ s/PACK/$callpack/g;
    $template =~ s/VAR/$varname/g if $varname;
    print "===\n$template---\n" if $debug_template;
    eval $template;
    die $@ if $@;
}

sub Die {
  my($pack, $var, $type) = @_;
  croak "lack of \$self: $type $var in $pack";
}

1;

__END__
