# シン・リファインメンツ 劇場版

@joker1007

---

![syosa.jpg](syosa.jpg)
# 私はRefinementsが好きだ

---

# しかし理想的ではない
# 何とかしてproc限定でrefineしたい

```ruby
refining(Ext) do
  "joker1007".hello # => "Hello joker1007"
end
```

---

![syosa2.jpg](syosa2.jpg)
# よろしい ならばevalだ

---

# ただ単純にevalするだけだと

```ruby
module Kernel
  def refining(mod)
    TOPLEVEL_BINDING.eval(<<~RUBY)
      using #{mod.to_s}

      "joker1007".hello
    RUBY
  end
end
```

---

# 決め打ちしかできねえ
# 何とかしてproc渡したい
# ソースコードが欲しい
# 大丈夫！parser & unparserがある！

---

## parser, unparserを使ってprocからsourceを取るproc_to_astというgemを昔作った
```ruby
require 'proc_to_ast'

  def refining(mod, &block)
    matched = block.to_source
      .match(/do(.*)end/m)
    proc_source = "proc #{matched[0]}"

    TOPLEVEL_BINDING.eval(<<~RUBY)
      using #{mod.to_s}

      pr = #{proc_source}
      pr.call
    RUBY
  end
```

---

# これでいける？

```ruby
refining(Ext) do
  "joker1007".hello
end

module Dummy; end

refining(Dummy) do
  "tagomoris".hello
end
```

---

# 実は駄目

```ruby
refining(Ext) do
  "joker1007".hello
end

module Dummy; end

refining(Dummy) do
  "tagomoris".hello # => 呼べてしまう！
end
```

---

# TOPLEVEL_BINDINGは常に同じbinding
# 一回evalでusingしたら効果が残る
![mada_awateru.jpg](mada_awateru.jpg)
# 大丈夫！Class.newがある！

---

```ruby
  def refining(mod, &block)
    proc_source = block.to_source
      .match(/do(.*)end/m)
      .yield_self { |m| m[0] }

    c = TOPLEVEL_BINDING.eval(<<~RUBY)
      Class.new do
        using #{mod.to_s}

        def self.process
          pr = #{wraped_source}
          pr.call
        end
      end
    RUBY
    c.process
  end
```

---

```ruby
refining(Ext) do
  "joker1007".hello
end

module Dummy; end

refining(Dummy) do
  "tagomoris".hello # => NoMethodError
end
```

---

# やったか?! => やってない
 
---

# 評価コンテキストの壁

```ruby
class Foo
  def initialize
    @name = "joker1007"
  end

  def hello
    refining(Ext) do
      @name.hello
    end
  end
end

Foo.new.hello # => dead
```

---

# まずは落ち着け
![otituke.jpg](otituke.jpg)
# 落ち着いてobjectを渡せばいい
# instance_execだ

---

```ruby
  def refining(obj, mod, &block)
    proc_source = block.to_source
      .match(/do(.*)end/m)
      .yield_self { |m| "proc #{m[0]}" }

    c = TOPLEVEL_BINDING.eval(<<~RUBY)
      Class.new do
        using #{mod.to_s}

        def self.process(obj) # => 引数を増やす
          pr = #{proc_source}
          obj.instance_exec(&pr) # => コンテキストゲット
        end
      end
    RUBY
    c.process(obj) # => 引数で渡す
  end
```

---

```ruby
class Foo
  def initialize
    @name = "joker1007"
  end

  def hello
    refining(Ext, self) do
      @name.hello
    end
  end
end

Foo.new.hello # => Yay
```

---

# いけるやん！
![sonnafuuni.jpg](sonnafuuni.jpg)

---

# ローカル変数がッ！ procはクロージャ！

```ruby
class Foo
  def hello(name)
    refining(Ext, self) do
      name.hello
    end
  end
end

Foo.new.hello("joker1007") # => Dead again!!
```

---


# Binding「俺様の出番の様だな」
![amanuma.jpg](amanuma.jpg)

---

```ruby
  def refining(b, mod, &block)
    proc_source = block.to_source
      .match(/do(.*)end/m)
      .yield_self { |m| "proc #{m[0]}" }

    c = TOPLEVEL_BINDING.eval(<<~RUBY)
      Class.new do
        using #{mod.to_s}

        def self.process(b)
          #{b.local_variables.map do |v|
             "#{v} = b.local_variable_get(:#{v})"
           end.join("\n")} # => ローカル変数をevalでコピー
          pr = #{proc_source}
          b.receiver.instance_exec(&pr)
        end
      end
    RUBY
    c.process(b)
  end
```

---

# 勝ったッ！
![dai3bu_kan](dai3bu_kan.jpg)

---

# ブロック内で使わないローカル変数……

```ruby
class Foo
  def hello(name)
    refining(Ext, binding) do
      name.hello
    end
  end

  def hello_koic
    process = proc { "koic".hello }
    refining(Ext, binding, &process)
  end
end

Foo.new.hello("joker1007") # => Yay!
Foo.new.hello_koic # => unused local variable `process`
```

---

# あーもう、めちゃくちゃだよ！
# もういいや、AST使おう

---

## parser gemの出力を読んでブロック内のローカル変数読み出しっぽい所を全部リストアップする

```ruby
  def get_local_variable_names(ast, buf = [])
    if ast.type == :send
      params = ast.to_a
      if params[0].nil? && params.length == 2
        buf << params[1]
      end
    end

    ast.children.each do |node|
      if node.is_a?(Parser::AST::Node)
        get_local_variable_names(node, buf)
      end
    end

    buf
  end
```

---

```ruby
  def refining(b, mod, &block)
    block_source = block.to_source
    matched = block_source.match(/do(.*)end/m)
    proc_source = "proc #{matched[0]}"
    used_local_variables = get_local_variable_names(Parser::CurrentRuby.parse(matched[1]))

    c = TOPLEVEL_BINDING.eval(<<~RUBY)
      Class.new do
        using #{mod.to_s}

        def self.process(b)
          # 使っている可能性のあるローカル変数だけをコピる
          #{b.local_variables
          .select { |v| used_local_variables.include?(v) }
          .map { |v| "#{v} = b.local_variable_get(:#{v})" }.join("\n")}
          pr = #{proc_source}
          b.receiver.instance_exec(&pr)
        end
      end
    RUBY
    c.process(b)
  end
```

---

# なんかbinding渡すのダサくね？
# 「ドーモ、バインディング・ニンジャです」
![aisatsu.jpg](aisatsu.jpg)
# アイエエエエ！ニンジャ？！

---

# binding_ninjaでbinding渡しを隠蔽する

```ruby
  extend BindingNinja
  auto_inject_binding def refining(b, mod, &block)
    block_source = block.to_source
    matched = block_source.match(/do(.*)end/m)
     # ...
  end
```

---

# 最終系

```ruby
class Context
  def initialize(name = nil)
    @name = name
  end

  def hello(str)
    TrueRefinements.refining(Ext) do
      str.hello
    end
  end

  def hello2
    TrueRefinements.refining(Ext) do
      @name.hello
    end
  end
end

Context.new("joker1007").hello2
Context.new.hello("hoge")
```

---

# 圧倒的じゃないか！
![beam.jpg](beam.jpg)

---

# 実はprocのソース化がめっちゃ危うい…
# procの開始と終端取れるAPI
# 欲しいです！

---

# パフォーマンス？何ですか、それ?

```
Warming up --------------------------------------
    plain   153.770k i/100ms
 refining    56.000  i/100ms
Calculating -------------------------------------
    plain    2.094M (± 3.3%) 
 refining  560.413  (± 1.2%) 

Comparison:
    plain:  2093833.1 i/s
 refining:      560.4 i/s - 3736.23x  slower
```

ソースコードパースして、ASTからソースコードに戻して、evalして動的にクラス定義してbinding作って、ローカル変数引っ張ってきてbindingからオブジェクト取得してinstance_execしている結果がこれだよ。

---

# ローカル変数さえ諦めれば10倍でFA

```
Warming up --------------------------------------
    plain   145.078k i/100ms
 refining    18.123k i/100ms
Calculating -------------------------------------
    plain      1.941M (± 3.0)
 refining    189.518k (± 2.6)

Comparison:
    plain:  1941491.1 i/s
 refining:   189518.0 i/s - 10.24x  slower
```

procって大変ですね