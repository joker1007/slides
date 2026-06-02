---
title: Ruby::Boxにできること、Refinementsにできること
theme: default
paginate: true
style: |
    /* @theme rose-pine */
    /*
    Rosé Pine theme create by RAINBOWFLESH
    > www.rosepinetheme.com

    palette in :root
    */

    @import "default";
    @import "schema";
    @import "structure";

    :root {
        --base: #191724;
        --surface: #1f1d2e;
        --overlay: #26233a;
        --muted: #6e6a86;
        --subtle: #e0def4;
        --text: #e0def4;
        --love: #eb6f92;
        --gold: #f6c177;
        --rose: #ebbcba;
        --pine: #31748f;
        --foam: #9ccfd8;
        --iris: #c4a7e7;
        --highlight-low: #21202e;
        --highlight-muted: #403d52;
        --highlight-high: #524f67;

        font-family: Pier Sans, ui-sans-serif, system-ui, -apple-system,
            BlinkMacSystemFont, Segoe UI, Roboto, Helvetica Neue, Arial, Noto Sans,
            sans-serif, "Apple Color Emoji", "Segoe UI Emoji", Segoe UI Symbol,
            "Noto Color Emoji";
        font-weight: initial;

        background-color: var(--base);
    }
    /* Common style */
    h1 {
        font-size: 46pt;
        color: var(--rose);
        padding-bottom: 2mm;
        margin-bottom: 12mm;
    }
    h2 {
        color: var(--rose);
    }
    h3 {
        color: var(--rose);
    }
    h4 {
        color: var(--rose);
    }
    h5 {
        color: var(--rose);
    }
    h6 {
        color: var(--rose);
    }
    a {
        color: var(--iris);
    }
    p {
        font-size: 28pt;
        font-weight: 600;
        color: var(--text);
    }
    code {
        color: var(--text);
        background-color: var(--highlight-muted);
    }
    text {
        color: var(--text);
    }
    ul {
        font-size: 28pt;
        color: var(--subtle);
    }
    li {
        font-size: 26pt;
        color: var(--subtle);
    }
    img {
        background-color: var(--highlight-low);
    }
    strong {
        color: var(--gold);
        font-weight: inherit;
        font-weight: 800;
    }
    mjx-container {
        color: var(--text);
    }
    marp-pre {
        background-color: var(--overlay);
        border-color: var(--highlight-high);
    }

    /* Code blok */
    .hljs-comment {
        color: var(--muted);
    }
    .hljs-attr {
        color: var(--foam);
    }
    .hljs-punctuation {
        color: var(--subtle);
    }
    .hljs-string {
        color: var(--gold);
    }
    .hljs-title {
        color: var(--foam);
    }
    .hljs-keyword {
        color: var(--pine);
    }
    .hljs-variable {
        color: var(--text);
    }
    .hljs-literal {
        color: var(--rose);
    }
    .hljs-type {
        color: var(--love);
    }
    .hljs-number {
        color: var(--gold);
    }
    .hljs-built_in {
        color: var(--love);
    }
    .hljs-params {
        color: var(--iris);
    }
    .hljs-symbol {
        color: var(--foam);
    }
    .hljs-meta {
        color: var(--subtle);
    }


---

<style scoped>
h1, h2, h3 {
  color: white;
}
</style>
# Ruby::Boxにできること、Refinementsにできること

### joker1007 (Repro株式会社)
### 松江Ruby会議 12

---

<!--
footer: ![w:100 h:32](logo_white.png)
-->

# self.inspect

- 橋立友宏 (@joker1007)
- Repro inc.
- Chief Architect
- RefinementsとTracePointが好き

---

# 松江は10回ぐらい来てると思う

日本酒と熱燗にハマった人間としては、世界的に重要な街です。

---

# 本題

---

# RubyKaigi 2026のLTにて

Do Ruby::Box dream of Modular Monolith? という発表をした。

RailsのURL毎にRuby::Boxによってオブジェクト空間を分けるデモ。

これについて、もうちょっと丁寧に解説しておこうと思う。

---

# Ruby::Boxについておさらい

Namespaceと言われていた機能だが、Rubyの世界ではNamespaceという用語はmoduleで区切られた定数スコープを指す言葉として利用されていたので、新しくRuby::Boxという名前が付けられた。

Ruby::Boxは、クラスやメソッドの定義を隔離するための機能。

Boxの中でRubyのコードを評価することで、そこで定義されたクラスやメソッドはそれぞれ独立した場所に定義される。

---

# どうやって動くのか

もの凄く単純化するとrb_classext_tという構造体をBoxごとにcopy-on-writeで複製している。(自分の調べた限りでは)

Boxの中でオープンクラスすると定義が複製されて、そこで変更が行われる。

呼び出し時にはフレーム情報から現在のBoxを特定して、rb_classext_tを辿る。

(To-モリスさん: これ合ってます？)

---

# Ruby::Boxで何が嬉しいのか

完全に同一の名前のクラスやメソッドを複数個持てる様になる。

開発当初から想定されていたユースケースとして、同一gemの複数バージョンを1つのプロセスで動かしたりできる様になる。

例えば、Javaの世界ではクラスローダーを分けることで同一のライブラリの複数のバージョンを読み込むことが出来る。(これはこれで問題になることも多いが)

---

# 隔離 = 破壊防止

クラスやメソッドの定義が隔離されているということは、あるBoxで上書きした動作はそのBoxにしか影響を与えないということ。

モンキーパッチやDSLのために生やしたメソッドなどを、特定のBoxの中に閉じ込められる。

---

# モジュラーモノリスへの応用可能性

例えば、同じUserというActiveRecordのモデルでもコンテキストに依って必要なメソッドは変わる。

モジュールやファイルの分割で意図を分けたとしても、参照可能であるなら意図しない使い方をされる可能性はある。

コンテキスト境界を明確に意識するのは大規模な開発プロジェクトでは重要。

そもそもメソッドもクラスも見えない、という状況なら境界を越えるのに明確な意志を要求できるし、意図しない変更範囲の波及も防止できる。

---

# Update From RubyKaigi 2026

ruby-headでデモが出来る様になった！
ありがとうモリスさん！

---

# 動作の仕組み (再掲)

Boxで読み込むためのモジュールを二つ用意する。
```ruby
module BoxA
  def foo
    puts "BoxA" + Ruby::Box.current.inspect
    super
  end
end
```

```ruby
module BoxB
  def foo = puts "BoxB" + Ruby::Box.current.inspect
end
```

---

それぞれのBoxでモジュールを読み込んだ後、それをメインBoxのクラスにinclude/prependする。

```ruby
A = Ruby::Box.new; A.require_relative "box_a"
B = Ruby::Box.new; A.require_relative "box_a"
class Foo
  prepend A::BoxA
  include B::BoxB
  def foo
    puts "Main" + Ruby::Box.current.inspect
    super
  end
end

Foo.new.foo # =>
```
```
returns:
BoxA#<Ruby::Box:3,user,optional>
Main#<Ruby::Box:2,user,main>
BoxB#<Ruby::Box:4,user,optional>
```

---

# メソッド探索チェインの中にBoxを組込むことで、superの呼び出しや特定のメソッドの呼び出しのみを別Boxに切り替えることが出来る。

---

![bg height:700px](rails_box_flow.png)

---

# ところで、Rubyにはメソッド定義を特定の領域に閉じ込める機能が他にもある。

---

# 皆大好きなRefinements

---

# Example

```ruby
module StringRefinement
  refine String do
    def foo
      "#foo: " + self
    end
  end
end

using StringRefinement
puts "hoge".foo # => "#foo: hoge"
```

---

# Refinementsの仕組み

`refine`を呼ぶと、Refinements用の特殊なモジュールが生成され、defはそのモジュールに登録される。
`using`を呼ぶと、現在のスコープにRefinements用のモジュールが登録されメソッドエントリが置き換えられる。
この時メソッドキャッシュがクリアされたり、呼び出し時にスコープからRefinementsモジュールを探索する処理が入るのでパフォーマンスには影響がある。

(To-Shugoさん: これ合ってます？)

---

# Ruby::BoxとRefinementsの違い

実装方法も大分異なっているが、利用者から見て大きな違いは**局所性**, **組込みクラスの扱い**, **自由度**にある。

---



---
