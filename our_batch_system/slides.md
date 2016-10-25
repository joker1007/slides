## **Base of Batch Processes**
## **For Not Big Player**

@joker1007 (Repro inc. CTO)

---

## **self.inspect**
- @joker1007
- Repro inc. (newbie) CTO
- Rails/JS/Docker/ECS/terraform/Spark/Bigquery/fluentd/embulk
- https://repro.io/

![icon](icon.jpg)

---

## **My gems, or My contributions**

- [activerecord-cause](https://github.com/joker1007/activerecord-cause)
- [yaml_vault](https://github.com/joker1007/yaml_vault)
- [activemodel-associations](https://github.com/joker1007/activemodel-associations)
- [emrakul](https://github.com/joker1007/emrakul)
- [rukawa](https://github.com/joker1007/rukawa) ← Talk about this

<hr>

- [fluent-plugin-bigquery](https://github.com/kaizenplatform/fluent-plugin-bigquery)

---

## We're *seriously* hiring now :rocket:

---

## **Complexity of Batch process is getting more and more.**

even if we are not IT giant, it is inevitable. 

---

## **Main purpose of batch process**

- aggregate logs
- settlement
- data deletion
- backup

etc, etc

---

## **And some batch processes has dependency to others**

---

## **Requirements of Complicated Batch**
- Define, visualize dependency of jobs
  - Fork and merge job route
  - namely **DAG**
- Concurrent execution
- Control concurrency
- Retry any jobs
- Re-usable jobnet

---

## **Batch process is DAG**

DAG = Directed Acyclic Graph.

[有向非巡回グラフ - Wikipedia](https://ja.wikipedia.org/wiki/%E6%9C%89%E5%90%91%E9%9D%9E%E5%B7%A1%E5%9B%9E%E3%82%B0%E3%83%A9%E3%83%95)

[library tsort (Ruby 2.3.0)](https://docs.ruby-lang.org/ja/latest/library/tsort.html)

---

## Rake is sometimes painful

- Hard to control concurrent execution
- Hard to understand complicated job dependencies
- Cannot Resume jobs freely
- Hard to ignore dependency even when necessary

**To solve thease probrem, I developed [rukawa](https://github.com/joker1007/rukawa)**

---

## **Why not luiji, airflow, azkaban ?**

Because We're Rubyist :trollface:

And Rails application can use this seamlessly.

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
  - Rukawa is single process currently
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

Join some Futures, and continue to process.

```ruby
a = Concurrent::dataflow { 1 }
b = Concurrent::dataflow { 2 }
c = Concurrent::dataflow(a, b) { |av, bv| av + bv }
```

I use dataflow as simple job queue.

---

## **Execute on ThreadPool**

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
- I don't focus it

---

## **We have ActiveJob**

- Many implementations already exist
- I only write simple wrapper of ActiveJob
- Rukaha do only few things
  - Define dependency
  - Kick ActiveJob
  - Track job status

---

## **Pragmatic attitude**

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
