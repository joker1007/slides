# tree-sitter-rbsを作って学ぶパーサージェネレーター

## joker1007 (Tomohiro Hashidate)

---

# 自己紹介

- id: joker1007
- Repro inc. チーフアーキテクト 
- パーフェクトRuby/パーフェクトRails
- 最近は専らJavaを書いてる
- **Vimmer (neovim)**

---

![bg contain](asakusarb.png)

---

# 今日Asakusaの裏番組ですw

---

# tree-sitterについて

neovimやemacsでシンタックスハイライトを行うために利用されているRust製のパーサージェネレーター。
パーサーの実装はGLRに基く。

https://tree-sitter.github.io/tree-sitter/

---

# tree-sitterについて

JavaScriptのDSLで文法を記述することでパーサーを生成する。
DSLだけで表現できないものは、external scannerという機能を使ってCで手書きすることで対応できる。
色々な言語向けのbindingや出力があり言語非依存で利用できる。

---

# tree-sitter-ruby 

もちろんRubyのパーサーもある。但し言語処理系とは無関係にメンテされているので処理系の挙動とは微妙に異なる。
ユニバーサルパーサー化が進んで、こういうのも処理系のパーサーからの派生物としてコントロールできる様になればいいなあと思う。

---

# なぜエディタにパーサーが要るのか

構文木の構造を利用してシンタックスハイライトをする方がリッチでメンテしやすい。

構文木の情報を活用した別のプラグインに簡単に対応できる。
ex. アウトライン、自動end追加、範囲選択、置換

---

# tree-sitter-rbsを作った

モチベーションとしては、

- Rubyのパーサーを書くのはめっちゃしんどいがRBSならDSLだけでも書けそうだった。
- neovimでRBSを書く環境を便利にしたかった。(VSCodeは興味が無い……)

nvim-treesitterにも取り込まれたので、`:TSInstall rbs`でインストール可能。

---

# Demo

---

# tree-sitterのDSLについて

数字の足し算が読める簡単なパーサーを書いてみる。

```js
module.exports = grammar({
  name: "sample",

  // spaceや改行を読み飛ばす
  extras: $ => [
    /\s/,
    /\r?\n/
  ],

  rules: {
    program: $ => repeat(choice($.hello, $.expr)),

    hello: $ => "hello", // この文字列の並びにのみマッチする
    number: $ => /\d+/, // 終端は正規表現でも書ける
    expr: $ => choice($.number, $.plus), // どちらかにマッチする
    plus: $ => prec.left(seq($.expr, "+", $.expr)), // (A + B) + Cなのか、A + (B + C)なのか
  }
});
```

see. https://tree-sitter.github.io/tree-sitter/creating-parsers

---

# BNFだとこんな感じ

`0`頭をどうするかとかは省略。

```
digit ::= "0" | "1" | "2"| "3"| "4"| "5"| "6"| "7"| "8"| "9"
integer ::= <digit>+
expr ::= <integer> | <plus>
plus ::= <expr> "+" <expr>
```

tree-sitterのDSLだと終端定義を正規表現で楽できる。

---

# JavaScript DSLの良い点

- 英語で大体意味が分かる
- かなりBNFっぽく書ける
- 関数定義を連ねてるだけなので、パターン化ができる。
  - Lramaに導入されたParameterized Ruleや！(https://rubykaigi.org/2024/presentations/ydah_.html#day2)

```js
function sep1(rule, separator) {
  return seq(rule, repeat(seq(separator, rule)));
}

// comma区切りの1つ以上の繰り返しパターン。
function commaSep1(rule) {
  return sep1(rule, ',');
}
```

---

# JavaScript DSLの悪い点

- **細かい状態管理ができない。**
- 状態が見えない中で競合の解決をしなければならない
- bisonのactionsみたいなのは書けない

---

# parseしてみる

`tree-sitter generate`でパーサーを作成。
`tree-sitter parse <text>`でパースできる。

---

input:
```
123
hello
123 + 234 + 512
```

output:
```
(program [0, 0] - [3, 0]
  (expr [0, 0] - [0, 3]
    (number [0, 0] - [0, 3]))
  (hello [1, 0] - [1, 5])
  (expr [2, 0] - [2, 15]
    (plus [2, 0] - [2, 15]
      (expr [2, 0] - [2, 9]
        (plus [2, 0] - [2, 9]
          (expr [2, 0] - [2, 3]
            (number [2, 0] - [2, 3]))
          (expr [2, 6] - [2, 9]
            (number [2, 6] - [2, 9]))))
      (expr [2, 12] - [2, 15]
        (number [2, 12] - [2, 15])))))
```

---

# 簡単！(本当か？)

---

# RBSの文法

see. https://github.com/ruby/rbs/blob/master/docs/syntax.md

**注: RBSのパーサーはCで手書きされているので、BNFは実装と異なる可能性がある。**

---

# tree-sitter-rbsの実装の流れ

基本的にBNFをDSLに書き写すだけ。
要は終端に至るまで選択と連接と繰り返しを書けば済む。

### 流石にそんな簡単ではなかった

---

# メソッド引数のパターン

ドキュメントだとざっくりこう書かれている。
```
_parameters_ ::= `(` _required-positionals_ _optional-positionals_ _rest-positional_ _trailing-positionals_ _keywords_ `)`
```

しかし、これは順番がこうであるというだけで、それぞれ省略が効く。
ドキュメントはドキュメントであって実装ではない。

---

# DSLに展開すると……

```js
parameters: $ => seq(
  "(",
  optional(choice(
    seq($.required_positionals),
    seq($.required_positionals, ",", choice($.optional_positionals, $.rest_positional, $.keywords)),
    seq($.required_positionals, ",", $.optional_positionals, ",", choice($.rest_positional, $.trailing_positionals, $.keywords)),
    seq($.required_positionals, ",", $.optional_positionals, ",", $.rest_positional, ",", choice($.trailing_positionals, $.keywords)),
    seq($.required_positionals, ",", $.optional_positionals, ",", $.rest_positional, ",", $.trailing_positionals, ",", $.keywords),
    seq($.required_positionals, ",", $.optional_positionals, ",", $.trailing_positionals, ",", optional($.keywords)),
    seq($.required_positionals, ",", $.rest_positional, ",", choice($.trailing_positionals, $.keywords)),
    seq($.required_positionals, ",", $.rest_positional, ",", $.trailing_positionals, ",", $.keywords),
    seq($.optional_positionals),
    seq($.optional_positionals, ",", choice($.rest_positional, $.trailing_positionals, $.keywords)),
    seq($.optional_positionals, ",", $.rest_positional, ",", choice($.trailing_positionals, $.keywords)),
    seq($.optional_positionals, ",", $.rest_positional, ",", $.trailing_positionals, ",", $.keywords),
    seq($.optional_positionals, ",", $.trailing_positionals, ",", $.keywords),
    seq($.rest_positional),
    seq($.rest_positional, ",", choice($.trailing_positionals, $.keywords)),
    seq($.rest_positional, ",", $.trailing_positionals, ",", $.keywords),
    seq($.keywords),
  )),
  ")"
),
```
本当に合ってんのか……？

---

# `|`, `&`, `?`の結合順序

大体想像は付くがsyntax.mdだけ読んでも分からんので、実装を見に行くしかない。

そして、優先順序が分かっても、DSLでそれを細かくコントロールするのが思ったより大変。

どう解決されてるのか正確に分かってないのが問題。

---

# methodのoverloadとunion typeが衝突する

```rbs
def foo: () -> String | Integer | (Symbol) -> Symbol
```

`()`が常にあるなら簡単なんだけど……。

---

# その他色々とハマったが、なんとかクリア

一応、当初の目論見通りDSLで基本的なRBSはパース可能になった。
結果的には大体400行ぐらい。
一週間ぐらいで基本部分は出来たので、趣味プログラミングにちょうど良かった。
Ruby本体に比べたら天国みたいなもん！

---

# まとめ

- RBSのパーサーなら何とか書けた
- パーサージェネレーターは触ると楽しい。
  - ある程度触ってると怖くなくなる
- neovimでRBSを書く環境構築には割と詳しいと思うので質問歓迎
- Lramaで出力したパーサーをtree-sitterのexternal scannerに使えないだろうか……？(RubyKaigiのhasumikinさんの発表を聞き逃したのが悔やまれる)

