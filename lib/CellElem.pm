package CellElem;
use strict;
# セル空間上の要素を表現する.
# 構造的側面を担当.

use Carp;
sub size  { croak "->size is not implemented!" ;}
sub arity { croak "->arity is not implemented!" ;}
sub printname { "noname";}
sub IsCompound { 0; }
sub IsAtomic   { 0; }

package CellElem::Atomic; our @ISA = qw(CellElem);
use Carp;
sub IsAtomic   { 1; }
# サイズ1の セル要素(数値/シンボル)の, ベースクラス
sub lastix{ 0;}
sub size  { 1;}
sub arity { 0;}  ; *argnum = \&arity;
sub replicate_self {
  croak " this is not a compound! ";
}

package CellElem::Compound; our @ISA = qw(CellElem);
# サイズNのセル要素の管理代理人となるオブジェクトの
# ベースクラス.
BEGIN { sub new {
    my($pack, $cells, $size) = @_;
    # 外部オブジェクトを作るだけ. セル上の本体は外で作成する.
    bless [$cells, $size ], $pack;
}}
use DefStruct qw(cells size headix lastix);

# 再定義が要るかも.↓ 特に, 節に関しては…
sub IsCompound { 1; }
sub arity { shift->size - 1 }
sub relocatelimit { shift->lastix }
sub functor {
  my $self = shift;
  $self->cells->fetch( $self->headix );
}
sub regist {
  my $self = shift;
  # @_ は, 添字の列.
  my $size = $self->size;
  if (defined $size and $size == @_){
    $self->headix($_[0])->lastix($_[-1]);
  }
  $self;
}
sub copyrange {
  my $self = shift;
  my @range = ($self->headix, $self->lastix);
  wantarray ? @range : [@range];
}
sub replicate {
  my $self  = shift;
  my $cells = $self->cells;
  ref($self)->new($cells, $self->size);
  $cells->relocate( $self->headix, $self->lastix,
		   $self->relocatelimit );
}
package Term; our @ISA = qw(CellElem);
# 項
sub isTerm {1;}

package SimpleTerm;   our @ISA = qw(CellElem::Atomic   Term);
# 単純項

package CompoundTerm; our @ISA = qw(CellElem::Compound Term);
# 複合項
sub printname {
  my $self = shift;
  $self->functor->printname . "/" . $self->arity;
}

package Symbol;      our @ISA = qw(SimpleTerm);
# 記号 ＝ 単純項
#%OVERLOAD = ( "==" => \&numcomp,);
use DefStruct qw(cells id printname);
1;
