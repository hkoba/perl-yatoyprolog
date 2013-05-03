Proof of concept, experimental Prolog written in Perl5.
====================

Note: This code is very old. I wrote this in 1995. At that time
I was a university student and I was still experimenting what perl5 can do
and what prolog is, so I wrote this, with crazy style.
Do *NOT* follow this style use of eval + tie for OOP in perl5.

このコードは私 hkoba が学生時代(1995)に書いたものです。
perl5 の ref をタグメモリの代わりに、local をバックトラック用に
使えば簡単に prolog を実装できるのではないか?と気付いて実験したものでした。

お手本として参考にしたのは、雑誌 bit の 1986年 9月号に掲載された、pascal で記述された
prolog です。セルメモリの操作や value 関数の振る舞いは、ほぼそのまま移植したはずです。

[bit-1986](http://memo.ptie.org/bit/1986)

prolog を勉強したいのなら、(私のこのコードを読むよりも、)
上記の記事を図書館などでコピーさせてもらい、
自分の慣れた言語に移植してみるのが、最も勉強になると思います。

例
--------------------

実験目的なのでパーサーは省略しました。その代わり、perl の ARRAY 構造として
prolog のプログラムを投入、問い合わせることができます。

具体的には以下の prolog プログラムに対し、

```prolog
parent(john, sally).
parent(john, joe  ).
parent(mary, joe  ).
parent(phil, beau).
parent(jane, john).

grandparent(X,Z) :-
	   parent(X, Y),
	   parent(Y, Z).

%

?- grandparent(jane, X). 
% X = sally
% X = joe
```

この perl コードでは以下のように書きます。


```perl
use Prolog;
my $p = new Prolog;
$p->assert([parent =>         'john', 'sally']);
$p->assert([parent =>         'john', 'joe'  ]);
$p->assert([parent => 'mary',         'joe'  ]);
$p->assert([parent => 'phil', 'beau']);
$p->assert([parent => 'jane', 'john']);

$p->assert([grandparent => \'X',     \'Z'],
	   [parent =>      \'X',\'Y'],
	   [parent =>           \'Y',\'Z']);

print "grandparent(jane, X) => \n";
$p->query([grandparent=> 'jane', \'X']);
```


* prolog の functor? は perl の array へ。
* prolog の symbol は、perl のただの文字列へ, ただし、  
シンボルを変数として扱うか否かの区別は大文字かどうかではなく、
代わりに perl の側で SCALAR REF `\'X'` として渡すことで表現します。


なお、リストを用いるサンプルは、現時点では妙な動作をしているようです。
append が変ですねorz...

InstanceVariables.pm について
--------------------

当時の私はまだ perl5 に書き慣れておらず、それゆえに、
perl5 でインスタンス変数へのアクセスに `$self->` を書くことを
嫌っていました。

```perl
 $self->{instvar}   # Too long!

 $instvar           # What I want!
```

あれこれ悩んだ結果、個々の変数を tied 変数にしたらどうか?と考えたのでした。
でも、今では `$self->` と書くことにも慣れ、 `use fields` のメリットも
感じるようになったので、この方式は皆さんにはお薦めしません。

もし機会があったら、 use fields で書き直してみたいものです...
