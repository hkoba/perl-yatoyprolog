package CellElem;
use strict;
# ������־�����Ǥ�ɽ������.
# ��¤Ū¦�̤�ô��.

use Carp;
sub size  { croak "->size is not implemented!" ;}
sub arity { croak "->arity is not implemented!" ;}
sub printname { "noname";}
sub IsCompound { 0; }
sub IsAtomic   { 0; }

package CellElem::Atomic; our @ISA = qw(CellElem);
use Carp;
sub IsAtomic   { 1; }
# ������1�� ��������(����/����ܥ�)��, �١������饹
sub lastix{ 0;}
sub size  { 1;}
sub arity { 0;}  ; *argnum = \&arity;
sub replicate_self {
  croak " this is not a compound! ";
}

package CellElem::Compound; our @ISA = qw(CellElem);
# ������N�Υ������Ǥδ��������ͤȤʤ륪�֥������Ȥ�
# �١������饹.
BEGIN { sub new {
    my($pack, $cells, $size) = @_;
    # �������֥������Ȥ������. ���������Τϳ��Ǻ�������.
    bless [$cells, $size ], $pack;
}}
use DefStruct qw(cells size headix lastix);

# ��������פ뤫��.�� �ä�, ��˴ؤ��Ƥϡ�
sub IsCompound { 1; }
sub arity { shift->size - 1 }
sub relocatelimit { shift->lastix }
sub functor {
  my $self = shift;
  $self->cells->fetch( $self->headix );
}
sub regist {
  my $self = shift;
  # @_ ��, ź������.
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
# ��
sub isTerm {1;}

package SimpleTerm;   our @ISA = qw(CellElem::Atomic   Term);
# ñ���

package CompoundTerm; our @ISA = qw(CellElem::Compound Term);
# ʣ���
sub printname {
  my $self = shift;
  $self->functor->printname . "/" . $self->arity;
}

package Symbol;      our @ISA = qw(SimpleTerm);
# ���� �� ñ���
#%OVERLOAD = ( "==" => \&numcomp,);
use DefStruct qw(cells id printname);
1;
