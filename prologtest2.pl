require "./prolog";
use Tk::Pretty;
$p = new Prolog;
$p->assert([member=> \A, [cons=> \A, \B]]);
$p->assert(
  [member=> \A, [cons=> \C, \B]],
  [member=> \A, \B]);
pretty($p->query(
 List(member => [c => \V],
      [a => 'a'], 
      [b => 'b'],
      [c => 'c'],
      [d => 'd'],
      [c => 'q'])));
$p->assert([parent =>         'john', 'sally']);
$p->assert([parent =>         'john', 'joe'  ]);
$p->assert([parent => 'mary',         'joe'  ]);
$p->assert([parent => 'phil', 'beau']);
$p->assert([parent => 'jane', 'john']);

$p->assert([grandparent => \X,\Z],
[parent => \X,\Y],
[parent =>    \Y,\Z]);
#$p->dump;
#$env = {};
#$x = $p->varintern($env, [grandparent, jane, \X]);
#$p->dump; $p->execute([$x]);
print pretty($p->query([grandparent=> 'jane', \X]));
#$p->dump(26);
print pretty($p->query([parent => 'jane', \X], [parent => \X, \Y]));
