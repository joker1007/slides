## **ワークフローエンジン**
# **Rukawaの紹介と**
# **その裏側**

@joker1007

---

## **self.inspect**
- @joker1007
- Freelance

![icon](icon.jpg)

---

## **バッチ処理の依存関係定義が辛い**

---

## **簡単なものだったらRakeでも**

```ruby
namespace :batch do
  task :job1 do
    Job1.run
  end

  task job2: [:job1] do
    Job2.run
  end

  task job3: [:job1] do
    Job3.run
  end

  task Job4: [:job2, :job3] do
    Job4.run
  end
end
```

---

## Rakeだと辛い点

- 数が増えてくると依存関係が分かり辛い
- 並列で実行制御するのが難しい
  - (multitaskとかあるんだけど……)
- 定義場所を分割し辛い
- 途中から実行を継続できない
- 依存を無視して単独でタスクを実行できない

解決するために[rukawa](https://github.com/joker1007/rukawa)を作った

---

## **Job定義のサンプル**
```ruby
class SampleJob < Rukawa::Job
  def run
    sleep rand(5)
    ExecuteLog.store[self.class] = Time.now
  end
end

class Job1 < SampleJob
  set_description "Job1 description body"
end
class Job2 < SampleJob
  def run
    raise "job2 error"
  end
end
class Job3 < SampleJob
end
class Job4 < SampleJob
  # inherited by subclass
  set_dependency_type :one_success
end
```

---

## **JobNet定義のサンプル**

```ruby
class SampleJobNet < Rukawa::JobNet
  class << self
    def dependencies
      {
        Job1 => [],
        Job2 => [Job1], Job3 => [Job1],
        Job4 => [Job2, Job3],
      }
    end
  end
end
```

---

**実行タスクと依存関係を別々に定義する**

**定義方法はRubyのクラスを実装するだけ**

---

# DEMO

---

## **大体、一週間弱で出来た**

---

## **Rukawaを支えたもの**

- tsort
- concurrent-ruby

---

## tsort

**Rubyの組み込みライブラリの一つ**

**トポロジカルソートを行う**

有向非巡回グラフ(DAG)の各ノードを線形の順序に並び替える

要は依存関係を定義したDAGがあれば順番に並び替えられる

---

## **tsortのサンプル**

```ruby
require 'tsort'

class Hash
  include TSort
  alias tsort_each_node each_key
  def tsort_each_child(node, &block)
    fetch(node).each(&block)
  end
end

sorted = {1=>[2, 3], 2=>[3], 3=>[], 4=>[]}.tsort
p sorted #=> [3, 2, 1, 4]
```

---

## **tsortを使うと**
## **Hashから依存関係の順番が取れる**

別にHashじゃなくても良いけど

---

## **その順番を使って**
## **DAGツリーを構築する**

---

## **並列実行に[concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby)**

並列/並行処理に便利な各コンポーネントの集合

- Async
- Future
  - Dataflow :star:
- Promise
- ScheduledTask
- ThreadPool

他にもカウントダウンラッチとかセマフォとか

スレッドセーフなコレクションの実装とか

超便利、自分でこんなの作るのは辛い

---

## **Futureとは**

処理を非同期で実行した時の未来の結果を表すオブジェクト

```ruby
future = Concurrent::Future.execute { sleep 1; 42 }

future.state # => :pending
future.value(0) # => nil (まだ値が返ってきてない)
sleep 1
future.state # => :fulfilled
future.value # => 42
```

---

## Dataflow

複数のFutureを待ち受けて、結果が揃ったら続きを実行する

```ruby
a = Concurrent::dataflow { 1 }
b = Concurrent::dataflow { 2 }
c = Concurrent::dataflow(a, b) { |av, bv| av + bv }
```

---

## **ThreadPoolで実行**

```ruby
pool = Concurrent::FixedThreadPool.new(5)

Concurrent.dataflow_with(pool, *depend_dataflows) do |*results|
  # do something
end
```

上記の例だと5つまでのdataflowが並列で実行される

処理のキューイングも勝手にやってくれる

---

## **難しい並列実行制御を**
## **concurrent-rubyに丸投げして**
## **開発を簡易化**

---

## **ワークフローエンジン**
## **Rukawaをよろしく**

<a aria-label="Star joker1007/rukawa on GitHub" data-count-aria-label="# stargazers on GitHub" data-count-api="/repos/joker1007/rukawa#stargazers_count" data-count-href="/joker1007/rukawa/stargazers" data-style="mega" data-icon="octicon-star" href="https://github.com/joker1007/rukawa" class="github-button">Star</a>
<script async defer id="github-bjs" src="https://buttons.github.io/buttons.js"></script>
