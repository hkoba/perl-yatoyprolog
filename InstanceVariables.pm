package InstanceVariables;
# 継承を可能にするためには,
# このパッケージを利用するクラスのインスタンス全てについて,
# ↓ユニークな id を与える必要が有る.
$InstanceVariables::uniq_id = 0;

# storage{$PACK::self} → storage[$PACK::self]
# にした方が速いが, 継承が使えなくなる…
# 一々 PACK::VAR::array と書かずに, 先頭で
# package 文を使えばそれでしまいのような…
$array_template = <<'EODef';
{ package PACK::VAR::array;
  use integer;
  sub TIEARRAY {
    my($v) = "";
    print "  tie array\tPACK::VAR\n"
      if defined $InstanceVariables::debug;
    bless \$v;
  }
  sub FETCH {
    Die("PACK", "VAR", "array") if !defined $PACK::self;
    $storage{$$PACK::self}->[$_[1]];
  }
  sub STORE {
    Die("PACK", "VAR", "array") if !defined $PACK::self;
    $storage{$$PACK::self}->[$_[1]] = $_[2];
  }
  sub length {
    Die("PACK", "VAR", "array") if !defined $PACK::self;
    print "~~", $#{$storage{$$PACK::self}}, "\n" ;
    $#{$storage{$$PACK::self}};
  }
  tie @PACK::VAR, PACK::VAR::array;
}
EODef
$hash_template = <<'EODef';
{ package PACK::VAR::hash;
  use integer;
  sub TIEHASH {
    my($v) = "";
    print "  tie hash\tPACK::VAR\n"
      if defined $InstanceVariables::debug;
    bless \$v;
  }
  sub FETCH {
    Die("PACK", "VAR", "hash") if !defined $PACK::self;
    $storage{$$PACK::self}->{$_[1]};
  }
  sub STORE {
    Die("PACK", "VAR", "hash") if !defined $PACK::self;
    $storage{$$PACK::self}->{$_[1]} = $_[2];
  }
  sub EXISTS {
    Die("PACK", "VAR", "hash") if !defined $PACK::self;
    exists $storage{$$PACK::self}->{$_[1]};
  }
  sub FIRSTKEY {
    Die("PACK", "VAR", "hash") if !defined $PACK::self;
    my($k, $v) = each %{$storage{$$PACK::self}};
    $k;
  }
  sub NEXTKEY {
    Die("PACK", "VAR", "hash") if !defined $PACK::self;
    my($k, $v) = each %{$storage{$$PACK::self}};
    $k;
  }
  tie %PACK::VAR, "PACK::VAR::hash";
}
EODef
$scalar_template = <<'EODef';
{ package PACK::VAR::scalar;
  use integer;
  sub TIESCALAR {
    my($v) = "";
    print "  tie scalar\tPACK::VAR\n"
      if defined $InstanceVariables::debug;
    bless \$v;
  }
  sub FETCH {
    Die("PACK", "VAR", "scalar") if !defined $PACK::self;
    $storage{$$PACK::self};
  }
  sub STORE {
    Die("PACK", "VAR", "scalar") if !defined $PACK::self;
    $storage{$$PACK::self} = $_[1];
  }
  tie $PACK::VAR, PACK::VAR::scalar;
}
EODef

$allocater_template =  <<'EODef';
use integer;
 sub PACK::new {
   my($id) = ++$InstanceVariables::uniq_id;
   my($self) = \$id;
   my($pack) = shift;
   # \$self ではない！ \$id だって点が, 味噌.
   bless $self, $pack;
   $self->init(@_) if exists $PACK::{"init"};
   $self;
 }
sub PACK::DESTROY {
    my($self) = @_;
    print STDERR "<destroy: $$self>\n";
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
EODef

sub import {
    my($callpack) = caller;
    # caller の HAS の各要素毎に
    # package を作る.
    shift; # 自分の名前は捨てる.
    if(!defined @{"${callpack}::HAS"} && @_) {
	# 引数を, HAS に set.
	@{"${callpack}::HAS"} = @_; # 
    }
    foreach (@{"${callpack}::HAS"}) {
	if( s/^\@// ){
	    &do_eval($array_template, $callpack, $_);
	    # tie @{"${callpack}::$_"},"${callpack}::${_}::array";
	} elsif( s/^\%//) {
	    &do_eval($hash_template, $callpack, $_);
	} elsif( s/^\$// || m/^\w/ ){
	    &do_eval($scalar_template, $callpack, $_);
        } else {
	    die "Unknown specifier: $_";
	}
    }

    &do_eval($allocater_template, $callpack);
}
sub do_eval {
    my($template, $callpack, $varname) = @_;
    $template =~ s/PACK/$callpack/g;
    $template =~ s/VAR/$varname/g if defined $varname;
    print "===\n$template---\n" if defined $debug_template;
    eval $template;
}

sub Die {
  my($pack, $var, $type) = @_;
  die "lack of \$self: $type $var in $pack";
}

1;

__END__
