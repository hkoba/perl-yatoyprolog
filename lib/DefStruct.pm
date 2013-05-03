package DefStruct;

=head1 DefStruct.pm

Define access method of ANON ARRAY.

=head1 SYNOPSIS

In your package PKG,

  package PKG;
  use DefStruct qw(X Y Z);

then you can use 

 $obj = new PKG;  # automatically generated 'new'.
                  # If you want to override this,
                  # BEGIN { sub new {..} }
		  # __BEFORE__ use DefStruct.

 $obj->X(3);      # set 3 to attribute 'X'
 print $obj->X;   # fetch value of attribute 'X'

 X($obj,3);
 print X($obj);   # Similar, but faster. for Internal use.

 $index = $obj->_index_X; # get direct index.
 $obj->[ $index ] = 8;    # Now, attribute 'X' is 8.

 push @$obj, 1..8;                # To add AD-HOC element.
 $rest = $obj->_rest_index;       # Beginning index of AD-HOCs.
 print @{$obj}[ $rest .. $#$obj ] # fetch them.

=cut

use strict;
BEGIN {  $DefStruct::debug ||= undef; }
sub import  {
  shift;
  my $pkg = caller;
  my @indices = @_;
  {
    no strict 'refs';
    local( *PKG:: ) = \%{ $pkg ."::" };
    *{ $pkg . "::_new" } =
      sub { my $pack = shift; bless [@_], $pack; };
    *{ $pkg . "::_rest_index"} = sub { $#indices + 1; };
    *{ $pkg . "::new" } = $PKG::{"_new"} if !exists $PKG::{"new"};
  }
  my $i;
  for($i = 0; @indices; $i++){
    my $index = $i;
    my $key = shift @indices;
    print "$key/$index\n" if $DefStruct::debug;
    my $code =
      sub {
	my $self = shift;
	return $self->[ $index ] if ! @_;
	$self->[ $index ] = shift; return $self;
      }
    ;
    { no strict 'refs';
      *{ $pkg . "::$key" } = $code;
      *{ $pkg . "::_index_${key}" } = sub { $index; };
    }
  }
  
}
1;


__END__

IV の方でも, アクセスメソッドの自動定義をやった方が良いだろう.

 new の中で, [ (undef) x $size  ] ぐらいの事は した方が良いだろう.

  DefStruct::ARRAY;
  DefStruct::HASH ;  2通り用意するのは, どうだい?

  use DefStruct qw(item); ってやると,
  $x->item;               だけじゃなくて,
  item($x);               同一モジュール内なら これも効く.
                          この方が, 早いし, 静的検査も効く.

  $x->index::item が使えると嬉しいんだけど…
  $x->Tk::bind() って, どうやってやっているんだろう?
  ひょっとして, AUTOLOAD で工夫をしている?

  $x->_ref_item ってのも, 有ると嬉しい.

  $x->push ってのも有るべきか?
  $x->keys とかも?

## おうい,
##      1      use Const;
##      2      const $x = 1;
##      3      print $x;
##      4      $x += 3;
##      5      print $x;
## こんなのもあるそうな.

@ISA=('Exporter');
@EXPORT=qw(defstruct defstruct_indexvar);
use Exporter;
# qw(goal open eval closed result)
sub defstruct {
    my($callpack) = caller;
    my($elems) = $#_ + 1;
    my($i) = 0;
    while($sym = shift){
	eval <<"END"
         sub ${callpack}::$sym {\$_[0]->[$i]}
         sub ${callpack}::set$sym {\$_[0]->[$i]=\$_[1];\$_[0]}
END
    } continue{ $i++ }
    *{"${callpack}::allocate"} =
       sub {
	   bless [(0) x $elems], $_[0];
       };
}
# 定数関数が最適化されたら, これの意義も出るでしょう.
sub defstruct_indexfunc {
    my($callpack) = caller;
    my($elems) = $#_ + 1;
    my($i) = 0;
    while($sym = shift){
	eval qq( sub ${callpack}::$sym {$i} );
    } continue{ $i++ }
    *{"${callpack}::allocate"} =
       sub {
	   bless [(0) x $elems], $_[0];
       };
}
# とりあえず, ↓こちらの方が実用的か.
sub defstruct_indexvar {
    my($callpack) = caller;
    my($elems) = $#_ + 1;
    my($i) = 0;
    while($sym = shift){
	eval qq( \$${callpack}::I$sym = $i );
    } continue{ $i++ }
    *{"${callpack}::allocate"} =
       sub {
	   bless [(0) x $elems], $_[0];
       };
}

# sub import {
#     
# }
1;

__END__

## あとで直そうね…
    while( $key =~ m/([\%\@])/g ){
	if(@args){
	    if( $1 eq '%' ){
# これやると,破壊された…
		$body = $body->{shift(@args)};
	    } elsif( $1 eq '@'){
		$body = $body->[shift(@args)]
	    } else {
		die "What's happened?";
	    }
	} else {
	    return $body;
	}
    }

% perl5 -le '$body = [[[[4..8]]]];@args=(0) x 4;  
print $body->[0]->[0]->[0]->[0];
$ref[0] = $body;
foreach(0..3){
  push(@ref, $ref[$_]->[shift(@args)]);
  print join(", ", @ref);
}
'
4
ARRAY(0xb54f8), ARRAY(0xb5438)
ARRAY(0xb54f8), ARRAY(0xb5438), ARRAY(0xb548c)
ARRAY(0xb54f8), ARRAY(0xb5438), ARRAY(0xb548c), ARRAY(0xb12f0)
ARRAY(0xb54f8), ARRAY(0xb5438), ARRAY(0xb548c), ARRAY(0xb12f0), 4
Z-dsl2(pts/0)%

あと, ベンチマーク… どうにも遅い！ (約10倍)
### 参照
% perl5 -le 'package TEST;use DefStruct;
BEGIN{defstruct(qw(alpha beta))}; sub new {allocate(@_)};
package main;
use Benchmark; $x = TEST->new;
$x->alpha(1);  $i = 0;
$t1 = new Benchmark;
$i += $x->[0]  while $i<=100000;
$t2 = new Benchmark;
print $t2->timediff($t1)->timestr, "\n";

$x->alpha(1);  $i = 0;
$t3 = new Benchmark;
$i += $x->alpha  while $i<=100000;
$t4 = new Benchmark;
print $t4->timediff($t3)->timestr, "\n";
 
'
 2 secs ( 1.44 usr  0.00 sys =  1.44 cpu)
21 secs (21.17 usr  0.00 sys = 21.17 cpu)

### 代入
% perl5 -le 'package TEST;use DefStruct;
BEGIN{defstruct(qw(alpha beta))}; sub new {allocate(@_)};
package main;
use Benchmark; $x = TEST->new;
$x->alpha(1);  $i = 0;
$t1 = new Benchmark;
$x->[0] = 1  while $i++<=100000;
$t2 = new Benchmark;
print $t2->timediff($t1)->timestr, "\n";

$x->alpha(1);  $i = 0;
$t3 = new Benchmark;
$x->alpha(1)  while $i++<=100000;
$t4 = new Benchmark;
print $t4->timediff($t3)->timestr, "\n";

'
 2 secs ( 2.22 usr  0.00 sys =  2.22 cpu)
26 secs (25.88 usr  0.00 sys = 25.88 cpu)

#### 凝っていない call の場合…
% perl5 -le 'package TEST;use DefStruct;
sub new { bless [] };
sub alpha { $_[0]->[0] };
package main;
use Benchmark; $x = TEST->new;
$x->[0] = 1 ; $i = 0;
$t1 = new Benchmark;
$i += $x->[0] while $i<=100000;
$t2 = new Benchmark;
print $t2->timediff($t1)->timestr, "\n";

$x->alpha(1);  $i = 0;
$t3 = new Benchmark;
$i += $x->alpha  while $i<=100000;
$t4 = new Benchmark;
print $t4->timediff($t3)->timestr, "\n";

'
 2 secs ( 1.31 usr  0.00 sys =  1.31 cpu)
 8 secs ( 8.36 usr  0.00 sys =  8.36 cpu)

% perl5 -le 'package TEST;use DefStruct;
sub new { bless [] };
sub alpha { $_[0]->[0]= $_[1] };
package main;
use Benchmark; $x = TEST->new;
$x->alpha(1); $i = 0; 
$t1 = new Benchmark;
$x->[0]  =  1 while $i++<=100000;
$t2 = new Benchmark;
print $t2->timediff($t1)->timestr, "\n";

$x->alpha(1);  $i = 0;
$t3 = new Benchmark;
$x->alpha(1)  while $i++<=100000;
$t4 = new Benchmark;
print $t4->timediff($t3)->timestr, "\n";

'
 2 secs ( 1.90 usr  0.00 sys =  1.90 cpu)
10 secs ( 9.49 usr  0.00 sys =  9.49 cpu)

# 定数関数も, まだ遅い！
% perl5 -le 'package TEST;
sub new { bless [] };
sub alpha { 0 }; sub beta {1};
package main;
use Benchmark; $x = TEST->new;
print &timeit(100000, q( $y = $x->[&TEST::alpha]  ) )->timestr;
print &timeit(100000, q( $y = $x->[0]  ) )->timestr;
 4 secs ( 4.32 usr  0.00 sys =  4.32 cpu)
 2 secs ( 0.81 usr  0.00 sys =  0.81 cpu)

# ちなみに, csl1 で計ると,
14 secs (13.27 usr  0.02 sys = 13.28 cpu)
 3 secs ( 2.65 usr  0.00 sys =  2.65 cpu)

# 似た事を v4 でやると…
% time perl -le 'sub alpha { 0 }; $y = $x[&alpha] 
while $i++<=100000; '
23.604s real  22.920s user  0.150s system  97% 
% time perl -le 'sub alpha { 0 }; $y = $x[0]
 while $i++<=100000; '
7.666s real  7.480s user  0.110s system  99%

## ↓ 最後の有り得る解が, ↓これだ.
% perl5 -le 'package TEST;
sub new { bless [] };
sub alpha { 0 }; sub beta {1};
package main;
use Benchmark; $x = TEST->new; $i = 0;
print &timeit(100000, q( $y = $x->[$i]  ) )->timestr;
print &timeit(100000, q( $y = $x->[0]  ) )->timestr;
'
 0 secs ( 0.90 usr  0.00 sys =  0.90 cpu)
 0 secs ( 0.86 usr  0.00 sys =  0.86 cpu)

### set...を使った代入(現在のバージョン)
% perl5 -le 'package TEST;use DefStruct;
BEGIN{defstruct(qw(alpha beta))}; sub new {allocate(@_)};
package main;
use Benchmark; $x = TEST->new;
$x->alpha(1);  $i = 0;
$t1 = new Benchmark;
$x->[0] = 1  while $i++<=100000;
$t2 = new Benchmark;
print $t2->timediff($t1)->timestr; 

$x->alpha(1);  $i = 0;
$t3 = new Benchmark;
$x->setalpha(1)   while $i++<=100000;
$t4 = new Benchmark;
print $t4->timediff($t3)->timestr;
'
 2 secs ( 1.89 usr  0.00 sys =  1.89 cpu)
10 secs ( 9.89 usr  0.00 sys =  9.89 cpu)
# 5.232 倍

### こんなのも思い付いてしまった. ( ref を返させて… )
% perl5 -le 'sub setref { ${$_[0]} = $_[1] };
$x = [1..8];
use Benchmark;
print &timeit(100000, q(&setref(\$x->[0], 3)))->timestr;
print &timeit(100000, q(${\$x->[0]} =  3))->timestr; 
print &timeit(100000, q($x->[0] =  3))->timestr;
'
Identifier "main::x" used only once: possible typo at -e line 2.
 9 secs ( 7.59 usr  0.00 sys =  7.59 cpu)
 3 secs ( 2.01 usr  0.00 sys =  2.01 cpu)
 0 secs ( 1.03 usr  0.00 sys =  1.03 cpu)
# 7.368 倍
# 1.951 倍

