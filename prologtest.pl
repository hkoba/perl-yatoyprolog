#!/usr/bin/env perl
use strict;
use warnings FATAL => qw/all/;
use FindBin;
use lib "$FindBin::Bin/lib";
use Prolog qw/List/;


my $p = new Prolog;
$p->assert([member=> \'A', [cons=> \'A', \'B']]);
$p->assert([member=> \'A', [cons=> \'C', \'B']]
	   => [member=> \'A', \'B']);
print "#\n---\nmember([c, V], [[a, a], [b, b], [c, c], [d, d], [c, q]]) =>\n";
$p->query([member => [c => \'V']
			, List([a => 'a'],
			       [b => 'b'],
			       [c => 'c'],
			       [d => 'd'],
			       [c => 'q'])]);
print "\n\n";

$p->assert([parent =>         'john', 'sally']);
$p->assert([parent =>         'john', 'joe'  ]);
$p->assert([parent => 'mary',         'joe'  ]);
$p->assert([parent => 'phil', 'beau']);
$p->assert([parent => 'jane', 'john']);

$p->assert([grandparent => \'X',\'Z'],
	   [parent => \'X',\'Y'],
	   [parent =>    \'Y',\'Z']);
#$p->dump;
#$env = {};
#$x = $p->varintern($env, [grandparent, jane, \'X']);
#$p->dump; $p->execute([$x]);
print "#\n---\ngrandparent(jane, X) =>\n";
$p->query([grandparent=> 'jane', \'X']);

print "#\n---\nparent(jane, X), parent(X, Y) =>\n";

#$p->dump(26);
$p->query([parent => 'jane', \'X']
	  , [parent => \'X', \'Y']);
