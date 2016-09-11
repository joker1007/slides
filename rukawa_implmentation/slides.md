## **ワークフローエンジン**
# **Rukawaと**
# **実装のサボり方**

@joker1007

---

## **self.inspect**
- @joker1007
- Repro inc. (newbie) CTO

![icon](icon.jpg)

---

## **時間が無いので会社の説明とか**
## **面倒なことはしません**

---

## **Requirements of Complicated Batch**
- Define, visualize dependency of jobs
  - Fork and merge job route
  - DAG
- Concurrent execution
- Control concurrency
- Retry any jobs
- Re-usable jobnet

---

## Rake is sometimes painful

- Hard to control concurrent execution
- Hard to understand complicated job dependencies
- Cannot Resume jobs freely
- Hard to ignore dependency even when necessary

To solve thease probrem, I developed [rukawa](https://github.com/joker1007/rukawa)

(My talk proposal is lost to pwrake :cry:)

---

## **Sample Job**
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
  set_dependency_type :one_success
end
```

---

## **Sample JobNet**

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

**Separates actual job implementation and job dependencies**

**User needs only to inherit base class and implement `run`**

---

# **DEMO**

---

## **Features of Rukawa**

- Visualize dependency (Graphviz)
- Change dependency type
  - all\_success, one\_success, all\_failed, and ...
  - inspired by Airflow
- Define `resource_count` (like Semaphore)
- Visualize results (Graphviz and colored node)
- Variables from cli options
- ActiveJob Integration

---

## **Rukawa focuses**

- Creating DAG
- Simple Ruby Class Interface

---

## **Rukawa not focuses**

- Implements job queue
- Implements concurrency control
- Distributed execution on multi nodes
- No GUI, No Web UI
- No Cron like scheduler

---

## Concurrent execution

I don't want to implement base of concurrent execution.
Because it is very hard.
It is over technorogy for normal human being.

---

## **Use concurrent-ruby**

---

## **Dataflow**

複数のFutureを待ち受けて、結果が揃ったら続きを実行する

```ruby
a = Concurrent::dataflow { 1 }
b = Concurrent::dataflow { 2 }
c = Concurrent::dataflow(a, b) { |av, bv| av + bv }
```

簡易プロセス内ジョブキューとして使える

---

## **ThreadPoolで実行**

```ruby
pool = Concurrent::FixedThreadPool.new(5)

Concurrent.dataflow_with(pool, *depend_dataflows) do |*results|
  # do something
end
```

---

## **Throws hard work to concurrent-ruby**
## **My work becomes light :smile:**

---

## **Distrubuted execution**

- It is very hard to develop seriously
- Need to define usage of datastore outside of Ruby

---

## **We have ActiveJob**

- Many implementations already exist
- I only write simple wrapper of ActiveJob
- Rukaha do only few things
  - Define dependency
  - Kick ActiveJob
  - Track job status

---

## 割り切り

- Use rundeck as scheduler
- I don't use Ruby, when large scale distributrd computation
  - Hadoop, Spark, Bigquery, Redshift
- What I really need is kicking other job framework
  - GIL of Ruby is not serious performance probrem

---

## **It is important to make compact tool what you really need for myself**
## **and rely on ecosystem as much as possible**
## **In order to effective use of limited resource**

---

## **ワークフローエンジン**
## **Rukawaをよろしく**

<a aria-label="Star joker1007/rukawa on GitHub" data-count-aria-label="# stargazers on GitHub" data-count-api="/repos/joker1007/rukawa#stargazers_count" data-count-href="/joker1007/rukawa/stargazers" data-style="mega" data-icon="octicon-star" href="https://github.com/joker1007/rukawa" class="github-button">Star</a>
<script async defer id="github-bjs" src="https://buttons.github.io/buttons.js"></script>
