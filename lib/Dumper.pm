package Dumper;
use Exporter qw/import/;
our @EXPORT = qw/dump/;


sub dump {
  local($Prolog::self) = shift;
  my($from, $to) = @_;
  my $output = $sink;
  $from ||= 0;
  $to   ||= $cfree -1;
  $output->clear;
  my($i);
  for($i = $from; $i <= $to; $i++){
    my $out = "";
    # この位置の情報
    my($cont) = $cells->[$i];
    if(! defined $cont ){
      $out = "undef";
    } elsif( ref $cont ){
      $out = ref($cont) .  "(". $cont->printname . ")";
    } else {
      # ↑ 終端
      # else
      # ↓ 非終端: 行った先が有るなら, その情報
      $out = sprintf("%3d => ", $cont);
      my($deref) = $self->value($i);
      $cont = $cells->[$deref];
      if(! defined $cont ){
	$out .= "undef";
      } elsif( ref $cont ){
	$out .= "($deref) ". ref($cont) . "(" . $cont->printname. ")";
      }
    }
    $output->printf("%3d: %s\n", $i, $out);
  }
}
sub FileHandle::printf {
  local($this) = shift;
  printf $this shift, @_;
}
sub FileHandle::clear { ; }
sub Tk::RefListbox::clear {
  shift->delete(0 , 'end');
}
sub Tk::RefListbox::printf {
  my $self = shift;
  my $str = sprintf( shift, @_ );
  $self->insert(end => $str);
  $self;
}
1;
