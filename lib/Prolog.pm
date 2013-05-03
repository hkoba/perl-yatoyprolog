package Prolog;
# -*- mode: perl; coding: utf-8 -*-
use strict;
use InstanceVariables   qw( maxid %intern @clauses
			    cells cfree topgoals c
			    sink
			    topenv
			    @trail tp
			  );
use Exporter qw/import/;
our @EXPORT_OK = qw/List/;

use Carp;
our $self;
our $debug;
sub init {
  local($self) = shift;
  $cfree = 0;
  $tp = 0;
  $maxid = 0;
}
sub fetch {
  local($self) = shift;  return $cells->[$self->value(shift)];
}
sub store {
  local($self) = shift;  my($x, $val) = @_;
  $cfree = $x + 1 if ($x >= $cfree);  # extend
  $cells->[$x] = $val;  return $self;
}
# dereference 処理
# 引数, 返り値, ともに添字として valid であるべし.
sub value {
  local($self) = shift;   my($x) = shift;
  my($y);
  confess "Undefined cell index" if !defined $x;
  $x = $y while defined($y = $cells->[$x]) && !ref $y;
  # 条件式より,
  #    $cells->[$x] == undef
  # || $cells->[$x] == defined ref
  return $x; # index が返るって事に注意!
}
sub remember {
  local($self) = shift;
  $tp += 1;
  $trail[$tp] = shift;
  return $self;
}
# 引数は, ちゃんと deref してから渡す事!.
sub unify {
  local($self) = shift;
  my($t1, $t2) = @_;
  # print STDERR "   $t1 <-> $t2\n";
  return 1 if $t1 == $t2;

  my ($a, $b) = ($cells->[$t1] , $cells->[$t2]);
  if (!defined $b){
    $cells->[$t2] = $t1;    $self->remember($t2); return 1;
  } elsif (!defined $a){
    $cells->[$t1] = $t2;    $self->remember($t1); return 1;
  } 
  # ここでは, どちらも ref になっている.
  # print STDERR "? $a == $b ";
  if( $a == $b ){
    # 同じ関係名を持つ.
    # → 同じパタンかどうか検査.
    my($arity) = $cells->[$t1]->argnum;
    my($i);
    foreach $i (1 .. $arity){
      return 0 unless $self->unify($self->value($t1+$i),
				   $self->value($t2+$i));
    }
    return 1;
  } else {
    # CoQu 用の処理.
    # print STDERR "   -----\n";
    my($s);
    eval { $s = $a->unify($b) };
    return 0 if $@;
    # unify は有った. 成功したとは限らないが.
    return 0 if ! defined $s;
    
    return 1 if  $s->isok ;
    return 0;
  }
  die "Why?";
}

{
  package Symbol;
  #%OVERLOAD = ( "==" => \&numcomp,);
  use InstanceVariables
    qw( myhome printname myid argnum);
  our $self;
  sub init {
    local($self) = shift;
    my($name, $narg, $home, $id) = @_;
    print STDERR "Symbol<($name, $home, $id)>\n" if $Prolog::debug;
    $printname = $name;
    $myid = $id;
    $argnum = $narg;
    $myhome = $home;
    return $self;
  }
  sub id {
    local($self) = shift;
    return $myid if !@_;
    die "too many args (@_)";
  }
  sub printname {
    local($self) = shift;
    return $printname if ! @_;
    $printname = shift ; return $self;
  }
  sub argnum {
    local($self) = shift;
    return $argnum if ! @_;        # fetch
    $argnum = shift; return $self; # store
  }
}

{
  package Number;
  our %OVERLOAD = ('==' => \&numeq,
		   '""' => \&printname,
		   # 'bool' => \&bool,
		  );
  sub numeq {
    my($a, $b, $flag) = @_;
    return $$a == $$b;
  }
  sub argnum { 0;};
  sub printname { my($me) = shift; $$me; }
  sub new { my($pack, $val) = @_; bless \$val, $pack;}
}

sub assert {
  local($self) = shift;
  my($head) = shift;
  my($env) = {};

  my $hindex    = $self->varintern($env, $head);
  my $goals     = $#_; # 後で, $bodybegin .. $goals とやるから.
  my $bodybegin = $self->varintern($env, @_);
  my $bodyend   = $cfree - 1;
  my $id = $cells->[ $self->value($hindex) ]->id;

  push(@{ $clauses[$id] },
       [ $hindex, $bodybegin, $goals,  $bodyend ]);
  #$self->dump($hindex, $bodyend);
  return $hindex;
}
sub clauses {
  local($self) = shift;   my($id) = shift;
  return @{$clauses[ $id ]};
}
sub query {
  local($self) = shift;
  my($env) = {};
  my($topgoal) = $self->varintern($env, @_);
  my($end) = $cfree - 1;
  my(@args) = $topgoal .. $topgoal + $#_;
  # print STDERR "<<@args>>\n";
  $topenv = $env;
  if($self->execute([@args])){
    my(@res) = $self->varextern({}, @args);
    $self->printenv($env);
    return wantarray ? @res : [@res];
  }
  return undef;
}
sub printenv {
  local($self) = shift; my($env) = shift;
  my($k);
  foreach (sort keys %$env){
    # 変数毎の値の出力
    my($val) = $cells->[ $self->value($env->{$_}) ];
    print "$_ = ",
    defined $val ? $val->printname : "(undef)", "\n";
  }
  return $self;
}
sub execute {
  local($self) = shift;
  my @goals = @{ shift; }; # [@_];
  my @stack;
  my $goal = $self->value($goals[0]);
  my $val  = $cells->[ $goal ];    die if ! defined $val;
  # $val は, 必ず ref である. 通常のシンボルのはず.
  my(@alt) = @{ $clauses[ $val->id ] };
  die "no clause" if !@alt;# @alt が空だったら? 失敗
  my ($tp0,$cf0) = ($tp,$cfree);
  my ($temp, $subgoals);
  while(1){
    do {
      if (!@goals){
	$self->printenv($topenv); # 成功!
	print "\n\n";
      } else {
	# print STDERR "goals:<@goals>\n";
      }
      # 別解探索の準備
      until (@goals and @alt){
	# print STDERR "goals:<@goals>\n";
	return undef if !@stack;
	my ($alt, $goals);
	($tp0, $cf0, $alt, $goals) = @{ pop @stack };
	@alt = @$alt; @goals = @$goals;
      }
      my $tptmp = $tp;
      $cells->[ $trail[$tptmp--] ] = undef while $tptmp > $tp0;
      $tp = $tp0; $cfree = $cf0;
    } until((($temp, $subgoals) = $self->replicate(shift @alt)),
	    $self->unify($goal, $self->value($temp)));
    # 単一化に成功 → 展開する(積む)
    push(@stack,[$tp0 ,$cf0 ,[@alt],[@goals]]);
    shift @goals;
    unshift(@goals, @$subgoals);
    # print STDERR " expand!<@goals>($tp0,$cf0=>$tp,$cfree)\n";
    ($tp0, $cf0) = ($tp, $cfree);
    # 次の準備
    while (@goals) {
      $goal = $self->value($goals[0]);
      $val  = $cells->[ $goal ];
      if (eval {  $val->isCode }) {
	# 特殊ゴール
	my($num) = $val->argnum;
	last if !$self->CallInlineSub($val, $goal+1..$goal+$num);
	# 実行に失敗→ 別解の探索へ進む…って, 勝手に行くか?
	#  →大丈夫らしい. 奇跡的だね^^;
	# 実行に成功→ 次のゴールをセットする.
	shift @goals;
      } else {
	# $val は, 必ず ref である. 通常はシンボルのはず.
	@alt = @{ $clauses[ $val->id ] };
	last;
	# メインループの先頭に戻る
      }
    }
  }
  die "no stack w/no goal" if ! @stack;
}
sub replicate {
  local($self) = shift;
  my($clause) = shift;
  my($src, $bodybegin, $goals, $end) = @$clause;
  # print STDERR "   <<--($src, $bodybegin, $goals, $end)--\n";
  my($diff) = $cfree - $src;
  my($result) = $cfree;
  for( $sink = $cfree,   $cfree += $end - $src + 1
      ; $src <= $end; $src++, $sink++){
    my($val) = $cells->[ $src ];
    #print STDERR "ho($val,$end)",
    #defined $val , !defined ref $val, "\n";
    if( defined $val && !ref $val &&  ($val < $end) ) {
      #print STDERR "kolemo?", $val < $end , "\n";
      $cells->[ $sink ] = $val + $diff;
      # 差分を足す.
    } else {
      $cells->[ $sink ] = $val;
    }
  }
  my $subgoal = $bodybegin + $diff ;
  return ($result, [  $subgoal ..  $subgoal + $goals]);
}

# おまけ. 
{
  package InlineSub;
  sub new {
    my($pack, $code, $argc) = @_;
    bless [$code, $argc], $pack;
  }
  sub isCode { 1; }
  sub code { shift->[0]; }
  sub printname { shift->[0]; }
  sub argnum    { shift->[1]; }
}
sub CallInlineSub {
  local($self) = shift;
  my($sub) = shift;
  my($code)= $sub->code;
  # 引数は添字!
  #print STDERR "[@_]\n";
  #$self->dump(0, $_[-1]);
  my(@indices) = map { $self->value($_) } @_;
  my(@result) = map { defined $_ ?
			$_->printname
			: $_} @{$cells}[ @indices ];
  printf STDERR "[<<@indices/%s ->",
  join(",", map {defined $_? $_ : "(undef)"} @result);
  my($bool) = &$code(@result);
  printf STDERR "%s:$bool>>]\n",
  join(",", map {defined $_? $_ : "(undef)"} @result);
  @{$cells}[@indices] = map { new Number($_) } @result;
  return $bool;
}

sub List {
  #my($x) = shift;
  my($y); my $z = "nil";
  while ($y = pop @_) {
    # ↓これではかえってまずい.
    # $y = List(@$y) if(defined ref $y and ref $y eq "ARRAY");
    $z = [cons => $y, $z];
  }
  return $z;
}
# 可変長の cons! ... にはなっていないね^^;
# 引数は intern 済か, 否か.     → 否.
# 述語記号は intern 済か, 否か. → 否.
sub varintern {
  local($self) = shift;
  my $env   = shift;      # 第一引数は,局所変数入れ場
  my $arg0  = $cfree;     # 先頭
  $cfree    = $arg0 + @_; # 部屋だけは先に確保.
  my $index = $arg0;
  foreach (@_){
    my($val);
    #print STDERR "---<$_>---\n";
    if(!defined $_){              # undef はそのまま代入.
      $val =  $_;
    } elsif( m/^-?(\d*\.)?\d+/ ){ # 数は, Number にする
      $val =  new Number($_);
    } elsif(ref $_) {
      if(ref $_ eq "ARRAY") {
	# ARRAY なら, 再帰.
	my $head = shift @$_;
	my $narg = @$_;
	# 先頭を取り出して, 先に intern
	#print STDERR "$name/$narg, @$_\n";
	if( ref $head and ref $head eq "CODE"){
	  $head = new InlineSub($head, $narg);
	} else {
	  $head = $self->intern($head, $narg);
	}
	$val =  $self->varintern($env, $head, @$_);
	# 一括して varintern しないと, 連続領域に
	# 入ってくれない.
      }elsif(ref $_ eq "SCALAR"){ # SCALAR なら, 局所変数とする.
	if( exists $env->{$$_} ){ # 再出現
	  $val = $env->{$$_};
	} else {                  # 初出
	  $val = undef;
	  $env->{$$_} = $index;
	}
      } else {                    # いずれでもない, 未知の ref
	$val = $_;    # → perl の object.
      }
    } else {
      # いずれでもないなら, シンボル. 
      $val =  $self->intern($_, 0);
    }
    $cells->[ $index ] = $val;
    $index++;
  }
  return $arg0;
}
sub intern {
  local($self) = shift;
  my($name, $narg) = @_;
  return $intern{$name} if exists $intern{$name};

  # else new symbol
  $maxid += 1;   # $maxid ++ は, コアを吐く.
  my $sym = Symbol->new($name, $narg, $self, $maxid);
  $intern{$name} = $sym;
  return $sym;
}
sub varextern {
  local($self) = shift;
  my($env) = shift;
  my($goal, @res);
  while( $goal = shift ){
    push( @res, $self->extern($env, $goal) );
  }
  return wantarray ? @res : [@res];
}
sub extern {
  # 引数: $goal ＝＝ セル上の添字
  local($self) = shift;
  my($env, $goal) = @_;
  my(@result);
  # deref が要るかどうかは, この時点では不明,と.
  return undef if ! defined $goal ;
  #print STDERR "<x<$goal>\n";
  #return $env->{$goal} if exists $env->{$goal};

  #my($valindex) = $self->value($cells->[$goal]);
  # ↑こんな事をすると, value の戻り値が添字でなく,
  #   ref そのものになる時が有る!
  my($valindex) = $self->value($goal);
  my($val) = $cells->[ $valindex ];
  #print STDERR "<-$valindex/$val->\n";
  return undef if ! defined $val;
  # さもなくば, $val は ref であるはず.

  if ( ref $val ){
    my($name, $args) = ($val->printname, $val->argnum);
    #print STDERR "$valindex:my($name, $args)\n";
    if( $args ){
      return [$name,
	      map { $self->extern($env, $_) } 
	      $valindex + 1 .. $valindex + $args];
    } else {
      return $name;
    }
    # extern に渡すのは添字.  値じゃないよん.

  } else {
    die 'そんなばかな!';
  }
}
sub dump {
  local($Prolog::self) = shift;
  my($from, $to) = @_;
  $from ||= 0;
  $to   ||= $cfree -1;
  my($i);
  for($i = $from; $i <= $to; $i++){
    printf "%3d: ", $i;

    # この位置の情報
    my($cont) = $cells->[$i];
    if(! defined $cont ){
      print "undef\n";
      next;
    } elsif( ref $cont ){
      print ref $cont, "(", $cont->printname, ")\n";
      next;
    }
    # ↑ 終端
    # else
    # ↓ 非終端: 行った先が有るなら, その情報
    printf "%3d => ", $cont;
    my($deref) = $self->value($i);
    my($cont2) = $cells->[$deref];
    if(! defined $cont2 ){
      print "undef\n";
      next;
    } elsif( ref $cont2 ){
      print "($deref) ", ref $cont2, "(", $cont2->printname, ")\n";
      next;
    }
  }
}
sub execute_old {
  local($self) = shift;
  my(@goals) = @{$_[0]};
  return 1 if ! @goals ;  # goals が空 → 成功

  print STDERR "goals:<@goals>\n";
  #$self->dump;
  # else
  # カレントゴールの indexを取り出す.
  my( $goal ) = $self->value(shift @goals);
  my( $val  ) = $cells->[ $goal ];

  # 特殊ケースの処理をここで行う. 例えば…
  while(defined $val
	and $val->can('isCode') and $val->isCode ){
    # これって, 結構時間食うよね?
    my($num) = $val->argnum;
    my($bool)=
      $self->CallInlineSub($val, $goal + 1 .. $goal + $num);
    if (!$bool) {
      print STDERR "     inline failed($goal)\n";
      #$self->dump;
      return 0 ;
    }
    #print STDERR "($goal)----------@goals-------\n";
    return 1 if ! @goals;
    $goal = shift @goals;
    $goal = $self->value($goal);
    $val = $cells->[ $goal ];
    #print STDERR "<<<<< $val >>>>\n" if defined $val;
  }
  # @goals は壊さない.
  my($tp0, $cf0) = ($tp, $cfree);
  
  foreach ( @{ $clauses[ $val->id ] } ){
    # カレントゴールに対応する各候補毎に
    my ($temp, $subgoals) = $self->replicate($_);
    #$self->dump($temp);
    if ( $self->unify($goal, $self->value($temp)) ){
      # @$othergoal は, 毎回壊す.
      my( $othergoals ) = [ @$subgoals, @goals ];
      if ( $self->execute_old($othergoals) ){
	#print STDERR "ok(@goals//@$othergoals)\n";
	$self->printenv($topenv);
	print STDERR "tp0=$tp0, cf0=$cf0\n";
	#return 1;
      } else {
	print STDERR "ng\n";
      }
    } else {
      print STDERR   "   try other\n";
    }
    # ここで, backtrack を行う.
    my($tptmp) = $tp;
    $cells->[ $trail[ $tptmp-- ] ] = undef while $tptmp > $tp0;
    $tp = $tp0;
    $cfree = $cf0;
  }
}
1;
__END__
parent(john,sally).
parent(john,joe). 
parent(mary,joe).
parent(phil,beau).
parent(jane,john).
grandparent(X,Z) :- parent(X,Y),parent(Y,Z).

$a = '?- grandparent(GPARENT,GCHILD).';

$a = 'member(A,[A|_]).';
$b = 'member(A,[_|B]) :- member(A,B).'; #Classic member
$a = '?- member(c(V),[a(a),b(b),c(c),d(d),c(q)]).';
$p->query(
 [member, [c, \V],
    [cons ,[a, a], 
      [cons , [b, b],
        [cons,  [c, c],
          [cons,   [d, d],
             [cons,  [c, "q"], nil
             ]]]]]]);;    

$p->assert([parent => john,sally]);
$p->assert([parent => john,joe]);
$p->assert([parent => mary,joe]);
$p->assert([parent => phil,beau]);
$p->assert([parent => jane,john]);

$p->assert([grandparent => \X,\Z],
[parent => \X,\Y],
[parent => \Y,\Z]);

% perl5 -e '
require "./prolog";
$p = new Prolog;
$p->assert([fact=> 0, 1]);
$p->assert([fact => \N, \R],
[ sub { $_[0] > 0 }, \N],
[ sub { $_[0] = $_[1] - 1;1; }, \SubProb, \N],
[ fact => \SubProb, \SubRes ],
[ sub {$_[0] = $_[1] * $_[2];}, \R, \SubRes, \N]
);
$p->query([fact => 8, \X]);
#$p->dump;
'
% perl5 -e '
require "./prolog";
$p = new Prolog;
$p->assert([qw(parent       john sally)]);
$p->assert([qw(parent       john joe) ]);
$p->assert([qw(parent  mary     joe)]);
$p->assert([qw(parent  phil beau)]);
$p->assert([qw(parent  jane john)]);

$p->assert([grandparent => \X,\Z],
[parent => \X,\Y],
[parent =>    \Y,\Z]);
$p->query([grandparent => "jane", \X]);
#$p->query([parent, jane, \X], [parent, \X, \Y]);
'
