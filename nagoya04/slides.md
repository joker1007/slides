---
class: invert
style: |
  section.larger h1 {
    font-size: 120px;
  }
  h1 {
    font-size: 56px;
  }
  section {
    font-size: 34px;
  }
---

# †Ruby黒魔術経典†

### @joker1007 (Repro inc. CTO)
### 名古屋Ruby会議04

---

# self.inspect

- @joker1007
- Repro inc. CTO
- Data Engineering, Architect
- Rubyで悪事を働く人と見做されている

---

![Repro](repro_logo.png)
We provide a web service as ...
- Analytics of Mobile Apps, Web Apps.
- Marketing Automation.

## We're hiring!!

---

https://youtu.be/1mauqP9zWbM?t=31

---

# 大いなる力には
# 大いなる責任が
# 伴う

---

# メタプログラミングや魔術的な挙動をする
# コードは強力だが
# 侵してはならないこともある

---

# 今日の議題

以下の内容について話す。

- 黒魔術において守るべきルール
- 実際に魔術を編み出すために使えるパーツ
- 考え方の具体例

---

# Part1 守りの黒魔術

---

# 守りの黒魔術 その1

## 組込みクラスを壊さない

特に
- requireしただけで挙動を変えない
- 上書きさせたい場合は、必ずユーザーに指定させる

組込みのクラス・メソッドは全てのRubyユーザーが期待している挙動がある。(当たり前の話)
暗黙的に弄って挙動を変えたら、何が起こるのか分からなくなる。

---

# 守りの黒魔術 その2

## スタックが追える様にすること

evalを使う場合に定義場所のロケーションを適切に設定する。
でないと例外が発生した時にどこで定義されたコードなのか分からない。
実はRubyの例外のバックトレースは自分で上書きできるので、ノイズになりそうな情報を隠すこともできる。


---

# 守りの黒魔術 その3

## パフォーマンスを意識すること

evalやbindingは負荷が高い。
呼び出し回数を少なくするために以下の様な方法が使える。

- クラスレベルでソースコードをキャッシュする
- クラス定義時や初回実行時のみ動作する様にする
  - メソッド定義にだけ利用する
  - 初回実行時にメソッドを上書きする

---

# 守りの黒魔術 その4

## TracePointの利用は明示的に

そして、絶対にensureでdisableすること。
途中で例外が発生するとtraceが有効のままになる。
traceが有効のままになるとマジで何が起きるか分からない。
フックが暴走してstack level too deepになるのはまだ良い方。

---


# Part2 黒魔術に使えるAPIの探し方

---

# 基本はリファレンスをひたすら読むこと

それだけだと雑過ぎるので、もうちょい解説する。

---

# るりまのここを読むべし

- BasicObject
- Object
- Module/Class
- Method
- Proc
- Kernel
- (ObjectSpace)

---

一回読んでも忘れるから、
とりあえずこの辺りを読み返す癖を付けておく。
ちなみに、`RubyVM::AbstractSyntaxTree`はまだるりまが無いです。 
(プルリクチャンス)

---

# 使えそうな機能の例

- 評価コンテキスト操作
  - eval系
- トリガー/フック
  - メソッドフック, TracePoint, included, inherited, method\_missing, trace\_var, trap, finalizer
- 大域脱出
  - throw/catch, Fiber

---

# 使えそうな機能の例 (続き)

- オブジェクト参照
  - \_variable\_get系, const\_get, ObjectSpace
- 変数/定数操作
  - \_variable\_set系, const\_set
- メタデータ取得
  - MethodやProcから取れる情報
- メソッドの動的定義
  - define\_method, module\_eval

---

# メタプログラミングパターン

- メソッド定義
- DSL
- 動的解析
- 静的解析
- 自動的/暗黙的処理の追加
- 言語拡張

↓に向かう程魔術度が増す

---

# Part3 考え方の具体例
# 暗黙のブロック引数 `it` を作ってみよう

see. https://bugs.ruby-lang.org/issues/15897

---

**procの中で暗黙の内に`it`でパラメータを参照できるとは、
Rubyの動作に置き換えるとどういうことかを考えてみる。**

- 評価コンテキスト内で`it`というローカル変数に値が入っている
- procのselfに`it`というメソッドが定義されていて、パラメータを取得できる
- procの外側で`it`が定義されている。
  - ローカル変数 or 引数

これらのどれかが実現できれば良さそう。

---

# ローカル変数追加方式について検討

- local\_variable\_setが使えそう
- local\_variable\_setは変数書き換えは簡単だが、新規に追加するのは難しい
  - bindingが毎回新しく生成されるため
- bindingを固定してevalしなければならない
- そもそもブロック呼び出しに実際に使われている値をどうやって事前に取得する？
  - なんか無理っぽい

---

# メソッド追加方式について検討

- 評価コンテキストにおけるselfは取得できる
  - Proc#bindingやTracePointで可能
- 単純にメソッドを定義するとあるクラスのインスタンス全てが影響する
  - 特異メソッドとして定義すれば可能かも
- しかしスコープを抜けた後も参照できてしまう
- Refinementsは使えないか
  - ブロックの定義が別の場所なのでevalが必要
- ローカル変数方式と同様の問題がある

---

# 外側でitを定義する方法について検討

- 新しいprocでラップして追加できる
- ブロックに渡される引数を事前に知る必要が無い
- やはりevalする必要がある

---

# 結論:
## 恐らくevalが必須
## そしてprocでwrap方式が現実的
## evalするためにはソースコード断片が必要

---

# ブロックのソースコードを取る方法
## RubyVM::AST.of or parser gemで位置を特定し読む

(またお前か)

---

# 特定のメソッドを対象にPoCを書く

```ruby
module Ext
  def map(*args, &block)
    source = File.readlines(block.source_location[0])
    proc_binding = block.binding
    ast = RubyVM::AbstractSyntaxTree.of(block)
    args_tbl = ast.children[0]
    block_node = ast.children[2]
    if args_tbl.empty?
      extracted = extract_source(
        source,
        block_node.first_lineno,
        block_node.first_column,
        block_node.last_lineno,
        block_node.last_column)
      new_block = proc_binding.eval("proc { |it| #{extracted} }")
      super(*args, &new_block)
    else
      super(*args, &block)
    end
  end
end
Array.prepend(Ext)

n = 3
[1, 2, 3].map { p it + n }
# => [4, 5, 6]
```

---

# 出来た！
# 後はgemにするだけ

---

**こんな感じで、自分の場合はゴールから逆算して考える。
やりたい事が出来るとはRubyにおいてオブジェクトの状態や変数のスコープ、メソッドの定義がどうなっていればいいかを想像し、そこに至る方法を逆向きに辿って実現可能な方法を考える。**

---

# ちなみに、実はこれ
# RubyKaigi2019で話したものと同じ
# パターンを使っている


---

# 最後に

**黒魔術を使うためにはRubyの挙動や各オブジェクトが何なのかということを詳しく知る必要がある。
魔術的な挙動を起こす方法を知ることは、安全なコードの書き方を知ることにも繋がる。
いざという時の選択肢も増える。
Rubyより深く楽しみ、より良いコードに繋げよう**
