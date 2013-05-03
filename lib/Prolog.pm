package Prolog;
use strict;
use Tk::Pretty;
use Benchmark;
use integer;
use Carp;
use InstanceVariables   qw( maxid %intern @clauses
			    cells cfree topgoals
			    topenv
			    @trail tp
			    cont time
			    sink
			  );
use FileHandle;
use CellElem;
use Reader;
use Dumper;

our $self;

sub reader {  Reader->new( shift ); }
sub sink {
  local($self) = shift;
  return $sink if ! @_;
  $sink = shift; return $self;
}
sub init {
  local($self) = shift;
  $cells = [];
  $cfree = 0;
  $tp = 0;
  $maxid = 0;
  $sink = bless \*STDOUT, 'FileHandle';
}
sub cellalloc {
  # セル上の, 領域を確保. その先頭 index を返す.
  local($self) = shift;
  my $cfree0 = $cfree;
  $cfree = $cfree0 + shift;
  return $cfree0;
}
sub cells {
  local($self) = shift;
  return $cells if ! @_;
  $cells = shift; return $self;
}
sub cfree {  local($self) = shift; return $cfree ;}# -1+1
sub fetch {
  local($self) = shift;  return $cells->[$self->value(shift)];
}
sub store {
  local($self) = shift;  my($x, $val) = @_;
  $cfree = $x + 1 if ($x >= $cfree);  # extend
  $cells->[$x] = $val;  return $self;
}
sub relocate {
  # リロケーション付きコピー.
  local($self) = shift;
  #print "REL: <@_>\n";
  my ($from, $to, $limit) = @_; # already derefed.
  $limit ||= $to;
  my $c = $cells;
  my $relbase = 0; # XXX: ???
  push @$c,
  map { defined $_ && !ref($_) &&
	  $_ >= $from && $_ <= $limit
	    ? $relbase + $_ : $_ }
  @{$c}[ $from .. $to ];
  $cfree = @$c;
  return $self;
}
sub multistore {
  local($self) = shift;
  my($head, $size) = (shift, shift);
  croak "invalid multistore size: " . @_ if @_ != $size ;
  @{$cells}[ $head .. $head + $size - 1] = @_;
  return $self;
}
sub append {
  local($self)   = shift;  my ($cf0, $index);
  $index = $cf0 = $cfree; my $c = $cells;
  $c->[$index++] = shift while @_; # pushかsplice で実装するべき
  $cfree  = $index;
  return $cf0;
}
# dereference 処理
# 引数, 返り値, ともに添字として valid であるべし.
BEGIN { *value = \&deref; }
sub deref {
  local($self) = shift;  my $x = shift;
  my $y;
  croak "arg is undef" if !defined $x;
  $x = $y while defined($y = $cells->[$x]) && !ref($y);
  # 条件式より,
  #    $cells->[$x] == undef
  # || $cells->[$x] == ref
  # 手繰りの深さが 20 を越える事は無さそう…
  return $x; # index が返るって事に注意!
}
sub remember {
  local($self) = shift;  $tp += 1;  $trail[$tp] = shift;
  return $self;
}
sub label {
  local($self) = shift; my $key = shift;
  return $topenv->{ $key } if exists $topenv->{ $key };
  return undef if ! @_;
  $topenv->{ $key } = shift;
  return $self;
}
sub printlabel {
  # 変数毎の値の出力
  local($self) = shift; my($env) = $topenv;
  my($k);
  foreach (sort keys %$env){
    print "$_ = ",
    Pretty($self->value($env->{$_})),"\n";
    # 添字を渡す
  }
  return $self;
}
sub intern {
  local($self) = shift;
  my $name = shift;
  return $intern{$name} if exists $intern{$name};
   # else new symbol
  $maxid += 1;   # $maxid ++ は, コアを吐く.
  my $sym = Symbol->new($self, $maxid, $name);
  $intern{$name} = $sym;
  return $sym;
}
sub execute_old {
  local($self) = shift;
  my(@goals) = @{$_[0]};
  return 1 if ! @goals ;  # goals が空 → 成功
  print STDERR "goals:<@goals>\n";

  # カレントゴールの indexを取り出す.
  my $goalix = $self->value(shift @goals);
  my $goalobj  = $cells->[ $goalix ];

  my($tp0, $cf0) = ($tp, $cfree);
  my @alt = $self->clauses( $goalobj->id );
  while ($_ = shift @alt){
    my ($temp,	$subgoal_indices) = $self->replicate($_); #
    if ( $self->unify($goalix, $self->value($temp)) ){
      my( $othergoals ) = [ @$subgoal_indices, @goals ];
      if ( $self->execute_old($othergoals) ){
	$self->printlabel($topenv);
	# return 1;
      } else {
	#print STDERR "ng\n";
      }
    } else {
      #print STDERR   "   try other\n";
    }
    # ここで, backtrack を行う.
    my($tptmp) = $tp;
    $cells->[$trail[$tptmp--]] = undef while $tptmp > $tp0;
    $tp = $tp0;
    $cfree = $cf0;
  }
}
1;
__END__
require "./prolog";
$p = new Prolog;
$r = $p->reader;
use Tk::RefListbox;
$mw = MainWindow->new;
($l = $mw->RefListbox)->pack(-fill => "both", -expand => 1);
$p->sink($l);
$r->Term(["abc" => ["def" => "ghi", "jkl"], "mno"]);
$p->dump;






