package Reader;
use strict;
use Carp;
sub new {  my $pack = shift;  bless [ shift ], $pack;}
## まず最初に, 何が欲しいかを明確にイメージしよう.
## 次に, プロトタイプをどんどん書こう.
## あと, このプロトタイプを使って何か仕事をする
## メソッドを書こう. やっぱ, それが基本だよね?

sub type {
  return 'Undef'   if ! defined $_[0];
  return 'Number'  if $_[0] =~ m/^-?(?:\d*\.)?\d+$/;
  if(defined  ref $_[0] and ref($_[0]) ){
    my $key = ref $_[0];
    if($key eq 'ARRAY'){
      if(defined $_[0]->[0]
	 and defined ref $_[0]->[0]
	 and ref $_[0]->[0] eq 'ARRAY'){
	return 'LogicExpr';
      }
      return 'CompoundTerm';
    }
    return 'InlineSub' if $key eq 'CODE';
    return 'LocalVar'  if $key eq 'SCALAR';
    return 'PerlObj';
  }
  return 'Symbol';
}
sub Undef::IsCompound { 0; }
sub Number::IsCompound {0;}
sub LogicExpr::IsCompound {1;}
sub CompoundTerm::IsCompound {1;}
sub InlineSub::IsCompound {0;}
sub LocalVar::IsCompound {0;}
sub PerlObj::IsCompound  {0;}
sub Symbol::IsCompound {0;}

sub cells {  shift->[0]; }
sub Undef  { &cells->append(undef); }
sub Number { &cells->append(Number->new(shift));}
sub InlineSub {}
sub LocalVar {
  my ($reader, $key) = @_;
  my $cells = $reader->[0];
  my $index_exists = $cells->label( $$key );
  if(defined $index_exists){
    return $cells->append($index_exists) ;
  } else {
    my $index = $cells->append(undef); 
    $cells->label( $$key, $index );
    return  $index;
  }
}
sub PerlObj {}
sub Symbol {
  #print " Sym(@_)\n";
  my $c = &cells;
  $c->append( $c->intern( shift ) );
}
## あと, 本当は EVA も活用したい.
sub PredList {
}
sub LogicExpr {
  
}
sub And {}

sub TermList {
  my $reader = shift;
  my $cells = $reader->[0];
  my ($expr, @result, @delay);
  foreach $expr ( @_ ){
    my $type = type($expr);
    my $elem = $reader->$type($expr);
    push @result, $elem;
    push @delay,[$elem, $expr] if $type->IsCompound; 
  }
  #print "--",$cells->cfree,"\n";
  # ここまで上で, 何を保証するのか?
  # ここから下で, 何を保証するのか?
  foreach (@delay){
    my ($elem, $expr) = @$_;
    my @elems = $reader->TermList(@$expr);
    print "  <<@elems>>", Tk::Pretty::Pretty($expr),"\n";
    $cells->fetch($elem)->regist(@elems);
  }
  return wantarray ? @result : $result[-1];
}
sub CompoundTerm {
  my ($reader, $expr) = @_;
  my $size = $#$expr + 1;
  $reader->[0]->append(CompoundTerm->new($reader->[0], $size))
}
1;
__END__

% perl5 -e 'require "./prolog";
$p = new Prolog;
$r = $p->reader;
$r->Term(["abc" => ["def" => "ghi", "jkl"], "mno"]);
$p->dump;
'
require "./prolog";
$p = new Prolog;
$r = $p->reader;
$c = $p->cells;
$p->store(3,8);
use Tk::RefListbox;
$mw = MainWindow->new;
($l = $mw->RefListbox)->pack(-fill => "both", -expand => 1);
$l->configure(-variable => $c);
$l->refresh;; 

% perl5 -e 'require "./prolog";
$p = new Prolog;
$r = $p->reader;
$x =  $r->Term(["abc", ["def" => "ghi"], "jkl"]);
print join(",", @{ $p->fetch($x);}),"\n";
$p->cellalloc(3);
$p->multistore(7,3, "a".."c");
$p->dump;
'
% perl5 -e 'require "./prolog";
$p = new Prolog;
$r = $p->reader;
@x =  $r->TermList("xyz", \X, ["abc", ["def" => \X, => "ghi"], "jkl"], "mno");
print "<@x>\n";

$p->copy( $p->fetch(4)->copyrange);
$p->dump;
'
<0 1 4 3>
