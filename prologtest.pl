require "./prolog";
no strict;
$p = new Prolog;
$p->assert(
 [append => 'nil', \Y, \Y]);
$p->assert(
 [append => [cons => \A, \X], \Y, [cons => \A, \Z]],
 [append => \X, \Y, \Z]);
#$ans = $p->query(
# [append => [cons => 'a', [cons => 'b', 'nil']],
#            [cons => 'c', 'nil'],
#            [cons => 'a', [cons => 'b', [cons => 'c', 'nil']]]
# ]);
$p->dump;

$p->query(
 [append => [cons => 'a', 'nil'],
            [cons => 'b', 'nil'],
            \X,
 ]);



__END__
# $x =$p->varintern({},"append", [cons => undef, undef], \"HEKEKE" ,\"HEKEKE");
# $y =$p->varintern({},"append", undef , \"UHOHO" ,undef);



$p->dump;
print "unify: ", $p->unify($x, $y),"\n";
$p->dump;
