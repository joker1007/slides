# Pragmatic Monadic Programming in Ruby

---

# self.inspect

- @joker1007
- Repro inc. CTO
- I familiar with ...
  - Ruby/Rails
  - Bigquery
  - fluentd
  - Hive/Presto/Cassandra
  - Data enginieering

---

# Asakusa.rb

I am a member of amazing Ruby community.

---

# In ruby-2.6, Proc is very interesting!!

---

# Compose proc by `Proc#>>`, `Proc#<<`

---

# RubyVM::AST.of can receive a Proc

---

# TracePoing#enable can receive a Proc

---

# To begin with, What is "Proc"?

---

# "Proc" is object of Procedure
# In other words, Function object.

---

# "Proc" is closure.

```ruby
def counter
  x = 0

  proc { x += 1 }
end

c = counter
counter.call # => 1
counter.call # => 2
```

Proc keep enviornment of the scope where it is created.

---

# Method can receive "Proc" as block

```ruby
def with_retry(exception, &block)
  block.call
rescue exception
  retry
end
```

---

# In fact, Ruby ...

- has function object as First-class object
- can receive functions as return value
- can pass functions as method arguments

In other words, Ruby has a factor of functional programming.

---

# Some FP languages have a very interesting feature.

---

# Monad

```
In functional programming, a monad is a design pattern[1] that allows structuring programs generically while automating away boilerplate code needed by the program logic. Monads achieve this by providing their own data type, which represents a specific form of computation, along with one procedure to wrap values of any basic type within the monad (yielding a monadic value) and another to compose functions that output monadic values (called monadic functions).
```

from Wikipedia https://en.wikipedia.org/wiki/Monad_(functional_programming).

---

# :thinking_face: :question:
# It seems difficult.

---

# But, Monad is very simple and useful pattern actually.
# And syntax sugar is very important for monad.
# I think that Ruby may be able to implement Monad syntax sugar by black magics.
# If I can implement, I realize very useful and very general abstraction in Ruby.

---

# Let's get down to the main topic.

---

# Agenda

- Functor in Ruby
- Applicative Functor in Ruby
- Monad in Ruby
- Syntax sugar for monad
- Implement monadic syntax in Ruby

Today, I will not explain mathmatics.
I will talk about only programming technique.

---

# Functor

Functor is a container having a context for specific purpose.
Functor is a object that can be mapped by any function.

Most popular functor in Ruby is "Array".

```ruby
[1,2,3].map { |i| i.to_s }
```

In Haskell, `map` for Functor is called `fmap`.

---

# Why Functor is useful

Without functor and map, a container needs to implement all methods for any object that it may contain.
Functor makes a container enable to collaborate any methods.

---

# Functor requires some laws

```ruby
functor.fmap(&:itself) == functor
```

```ruby
functor.fmap(&(proc_a >> proc_b)) == functor.fmap(&proc_a).fmap(&proc_b)
```

These laws ensure that behaviors of a functor is proper.

---

# Applicative Functor (1)

If you want to process with more than two functor objects,
But `fmap` cannot handle more than two functors.

```ruby
[1,2,3].map do |i|
  [5,6,7].map do |j|
    i + j
  end
end
```

This sample outputs nested array.
Of course, we can use `flat_map`.
But we have more functional approach.

---

# Applicative Functor (2)

Applicative Functor can contain functions.
And contained functions apply other objects contained by each functor.

```ruby
array_plus = [:+.to_proc]

array_plus.ap([2, 3], [4]) # => [6, 7]
array_plus.ap([2, 3], [5, 6, 7]) # => [7, 8, 9, 8, 9, 10]
array_plus.ap([2, 3], []) # => []
```

---

# Applicative Functor (3)

```ruby
def ap(*targets)
  curried = ->(*extracted) { fmap { |pr| pr.call(*extracted) } }.curry(targets.size)
  applied = targets.inject(pure(curried)) do |pured, t|
    pured.flat_map do |pr|
      t.fmap { |v| pr.call(v) }
    end
  end
  applied.flat_map(&:itself)
end
```

Maybe you think "Hey, you use `flat_map`!!".
Sorry, it is the reason why I want to implement easily.

---

#  Applicative Functor requires some laws

But laws of Applicative Functor are more complicated than one of Functor.

Sorry, I omit explaining details.

---

# What is difference between Applicative and Monad

Applicative Functor can not express multiple dependent effects.

For example, a calculations that may fail depends on whether past calculations succeeded or failed.

In such cases, Monad is useful.

---

# Monad

Monad is a container like Functor and Applicative.

In Haskell, Monad requires some implementations.

```haskell
class Monad m where
  (>>=)  :: m a -> (a -> m b) -> m b
  (>>)   :: m a ->  m b       -> m b
  return ::   a               -> m a
  fail   :: String -> m a
```

Especially, `(>>=)` is most important.
it is called "bind operator".

---

# What is >>= (bind operator) ?

In case of array,

`Array#bind` receives a function that receives item contained the array and outputs new array.

like following.

```ruby
["foo","bar"].bind { |s| s.split(//) }
# => ["f","o","o","b","a","r"]
```

In fact, it's `flat_map`

---

# Monad in Scala

Scala has syntax sugar for monad.

```scala
for {
  x <- Some(10)
  y <- functionMaybeFailed()
} yield x + y
```

Scala transforms this codes to `flat_map` style internally.
Like below.

```scala
Some(10).flatMap { x =>
  functionMaybeFailed().flatMap { y =>
    x + y
  }
}
```

---

# Syntax sugar for monad

Some functional languages have syntax sugar for monad.
Haskell has do-syntax, Scala has for-syntax.

Because the main purpose of monad is a chain of contextual computation,
and syntax sugar is very effective to use easier.

---

# Nested `flat_map` is not readable

```scala
Some(10).flatMap { x =>
  functionA(x).flatMap { y =>
    fuctionB.flatMap { z =>
      z.process
    }
  }
}
```

---

# Scala is hybrid paradigm language
# Ruby is similar to Scala in a sense
# I copied code transformation from Scala

---

# Monad syntax in Ruby

```ruby
calc = ->(*val) do
  val.monadic_eval do |x|
    a = x.odd? ? x : x / 2
    y <<= [a + 14]
    z <<= [y, y + 1, y + 2]
  end
end

expect(calc.call(7, 8)).to \
  eq([21, 22, 23, 18, 19, 20])
```

This code is valid syntax!!
There is no warning.

---

# My idea is very simple.

- `a <<= <statement>` transform to `flat_map do |a| <statement>`

It's all.

Important discovery is `<<=`!!

---

# `<<=` is assignment with operator

`a <<= foo` equals `a = a << foo`

This is valid ruby code.
And Ruby treats `a` as assigned local variable!
Moreover, most ruby programmers have not written such codes.

In other words, I can take posession of the syntax!!
I can change the behavior freely!!

---

# Review transformation

```ruby
[1,2,3].monadic_eval do |i|
  j <<= [i, i*2]
  j.select(&:odd?)
end
```

transform to

```ruby
[1,2,3].flat_map do |i|
  [i, i*2].flat_map do |j|
    j.select(&:odd?)
  end
end
```

---

# It is difficult to resolve nested do-end

# OK, I use AST Transformation!!

---

# Use RubyVM::AbstractSyntaxTree

It is very useful for handling AST.

- Extract AST from given block by `RubyVM::AST.of`
- Detect a pattern like `a <<= foo`
- Extract fragments of source code
- Reconstruct source code
- Wrap into new proc (to cache reconstructed code)
- Eval new source code

---


