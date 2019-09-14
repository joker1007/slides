# What a cool Ruby-2.7 is !!

## 大阪Ruby会議02
## @joker1007

---

# self.inspect

- @joker1007
- Repro inc. CTO
- 最近はKafkaを触っていてJavaばっかり書いている
- 黒魔術芸人

---

# Ruby-2.7の新機能は熱い！

- implicit block parameter
- pattern match
- method reference syntax
- REPL improvement

---

# というわけで、(REPL以外の)全部の機能を使って
# 2.7以降で使える新しい書き方のスタイルを提案する
# gemを書いてみた

一番重要なのはmethod reference syntax

---

# joker1007/method_plus
Method Extensions for method reference syntax.

---

# Usage

```ruby
foo = Foo.new

promise1 = foo.:slowly_foo.async(sleep_time: 0.1)
promise1.value # => wait and return value


pr = foo.:with_args.partial(0.1, b: _any)
foo.call(b: 3) # => call foo.with_args(0.1, b: 3)

[1, 2, 3].each do |i|
  foo.:exec_later.defer(i) # => resolve arguments here

  p 1
  # => call exec_later(i)
end

foo.:heavy.memoize(10) # => save result on foo instance_variable

```

---

# Methodオブジェクトが自然に取得できるのでMethodクラスに色々生やせれば便利！(かも)

---

# 各追加メソッドの実装解説

---

# async

```ruby
check_arity(*args)

Concurrent::Promises.future_on(:io, *args) do |*args|
  call(*args, &block)
end
```

concurrent-rubyをwrapしてるだけで簡単、と思いきや引数のチェックがめんどい。
引数間違いとか実行時に即指摘したいが、Rubyの引数チェックはCの実装の中に組込まれていて再利用できない。
特に引数の定義に合わせて適切なメッセージでArgumentError出すのが……。
(このチェック処理をRuby側にexportして欲しい気がする。)

---

# check_arity

こういう構造化情報でパターンが一杯あるケースはパターンマッチがめっちゃ便利。

```ruby
parameters.each do |pr|
  case pr
  in [:req, _]
    req_size += 1
  in [:opt, _]
    opt_size += 1
  in [:rest, _]
    has_rest = true
  in [:keyreq, name]
    has_kw = true
    keyreqs << name
  in [:key, _]
    has_kw = true
  in [:keyrest, _]
    has_kw = true
  else
  end
end
```

マッチングと抽出が同時に出来るのが大事。

---

# 補足

これは2.6でも使えるけど、無限Rangeも便利。

```ruby
args_range = has_rest ? (req_size..) : (req_size..req_size + opt_size + (has_kw ? 1 : 0))
```

---

# partial

lambdaでラップしてPlaceholderオブジェクトに置き換えておいて、
callした時に実際に値を嵌め込み直して呼ぶ。

```ruby
def partial(*args, **kw, &block)
  ->(*args2, **kw2, &block2) do
    placeholder_idx = 0
    new_args = args.each_with_object([]) do |a, arr|
      if a.is_a?(MethodPlus::Placeholder)
        if (args2.size - 1) >= placeholder_idx
          arr << args2[placeholder_idx].tap { placeholder_idx += 1 }; end
      else
        arr << a; end; end
    # ...
    new_block = block2 || block
    call(*new_args, **new_kw, &new_block)
  end
end
```

---

# defer

TracePointです。(いつもの)

ブロック呼び出し毎にstacklevelを記録して、合致する時にmethodをcallするTracePointを動かす。
かなり単純化するとこんな感じ。

```ruby
stack_level = 0
trace = TracePoint.new(*events) do |tp|
  if tp.event == :b_call
    stack_level += 1; next; end

  if tp.event == :b_return && stack_level > 0
    stack_level -= 1; next; end

  tp.disable
  call(*args, &block)
end
trace.enable(target: iseq) # => important
```

実際は、もうちょっと工夫が要る。

---

# TracePoint.enable(target: iseq)

2.6からTracePointが動作する対象をiseqレベルで絞れる様になった。
つまり特定のブロックや特定のメソッドの中だけで動作するフックが作れる。
しかし、ちょっと困った課題がある。

---

# TracePointをターゲット指定する時の課題

今処理中のブロックのiseqを取得する方法が、ほとんど無い。
それが取れれば、iseqが持ってる情報が色々使えたり、b_returnフックで使い易くなるのだが……。
一応、抜け道は(自分の知る限り)一つだけある。


ちなみに、メソッドは自身の処理中に`method(:__callee__)`でMethodが取れる。

---

# DebugInspector

CRubyに組込みのAPIだがRuby側から触れるAPIが無いのでラッパーgemを利用する。

```ruby
# numbered parameter is Good!
iseq = RubyVM::DebugInspector.open { @1.frame_iseq(2) }
```

これを利用してスタックを遡ってiseqを取得することができる。
このiseqを使うことで、処理中のブロックを抜けた時だけ発動するTracePointを仕込むことができる。

ちなみにこのgemのREADMEにはこう書いてある。

> do not use this library outside of debugging situations.

---

# まとめ

- Method Reference Syntaxを使った新しい書き方のスタイルを提案してみた。
  - `foo.:long_method.async(:bar)`
- 組込みクラスを拡張する点はちょっと危ういのでRefinementsの方が良いかも。
- パターンマッチもNumbered Parameterも便利！
- TracePointのtarget指定を活用しよう。
- IseqはDebugInspectorで取れる。

