---
title: Do Ruby::Box dream of Modular Monolith?
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
# Do Ruby::Box dream of Modular Monolith?

### joker1007 (Repro株式会社)
### Rubykaigi 2026 LT

---

<!--
footer: ![w:100 h:32](logo_white.png)
-->

# self.inspect

- 橋立友宏 (@joker1007)
- Repro inc.
- Chief Architect
- I love 🍺, 🍶, and Karaoke

![bg right:40% height:320px](./icon.jpg)

---

# I come from Asakusa(.rb)

![bg right height:640px](asakusarb.png)

---

# Ruby::Box comes!!

It's very interesting feature!!

---

# Have you touched Ruby::Box?

---

# I tried to use Ruby::Box <br> on Ruby on Rails.

I want to separate the domain logic by Ruby::Box.
To achieve a fully independent modular monolith.

---

# And It works!! <br> (minimal and not practical)

However, it required a few workarounds.


---

# Demo time!!

---

# Yeah!! <br> The class space is separated for each URL!!



---

# Good parts (?) of Ruby::Box

- Ruby::Box instances can freely reference one another.
- In other words, a class in one box can be inherited by a class in another box.
- Of course, you can also prepend or include modules in another box.

see. [Ruby::Box ダイジェスト紹介（Ruby 4.0.0 新機能） - STORES Product Blog](https://product.st.inc/entry/2025/12/25/134453)

---

# How it works

There are 2 boxes.
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

Just by calling `super` you can seamlessly switch between the Box.

**dangerous (interesting)!!** 😄

![bg right:45% height:700px](method_chain.png)

By the way, tagomoris-san said.
![tagomoris](./tagomoris.png)

---

# Applying to Rails

- A controller within a box inherits `ApplicationController` in the main box.
- You can evaluate controller and model logic within the child box,
- And once the controller logic is complete, transparently transfer process to the controller running in the main box.
- Render views in the main box.
- Views invoke model method, the logic works on the child box.

---

![bg height:700px](rails_box_flow.png)

---

# Thank you tagomoris-san!!
# Ruby::Box is fun!!

---

# What you need to get started

For now, we need to apply a patch to zeitwerk
we need to override `Ruby::Box#require` to work automatic module generation.
Otherwise, if you run it with `RUBY_BOX=1`, it can't load rails components.

This issue is related.
https://bugs.ruby-lang.org/issues/21830

---

# By the way, can't we use Ruby::Box with Rails::Engine?

---

# It crashes for now :cry:

`require` fails to execute in the first place.

---

# Actually, this demo app crashes with a SEGV quite often when it starts up.
# I recommend ruby-4.0.2 to run this sample.

---

# Things I want related to Ruby::Box

- `require` doesn't crash
- `Ruby::Box#name`: `Box#inspect` is confusing. I want to rename it to make it clearer.
- `Ruby::Box#fork`: I want to create a box while retaining the LOADED_FEATURE that has already been required in the base box.

---

# Difficulties

How to coordinate zeitwerk.
When you cross between boxes, it becomes unclear which box the `autoload` `require` is being executed in.

---

# Conclusion

Currently, it is possible to run Ruby::Box on Rails.
However, it’s very minimal and very experimental.
Still, the way Box works is really interesting!!
I can sense its potential!!

Let's try to use Ruby::Box and play around with it!!

---

# For more details

at the **松江Ruby会議**.
Stay Tuned!!
