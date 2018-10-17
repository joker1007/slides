# ActiveRecordだけで戦うには
# この世界は複雑過ぎる

### @joker1007
### 銀座Rails #2

---

# Self-intro
- @joker1007
- Repro inc. CTO (要は色々やる人)
  - Ruby/Rails
  - fluentd/embulk
  - RDB
  - Docker/ECS
  - Bigquery/EMR/Hive/Presto/Cassandra

---

# Railsがカバーする主戦場
- Webブラウザ/スマホからのデータ入力
- RDBに永続化し、必要な時はそこから読み出す
- 一人の人間が同時に必要とするデータはそこまで多くない
- 出力データはHTMLかJSON

基本的には、これで大体のWebアプリケーションの基盤は作れる

---

# そのRailsの便利さを支えるのがActiveRecordであり、
# そして、最終的に最も頼りにならない箇所でもある

コントローラーがどうやってアクセスハンドリングするかとか、ビューがどうやってテンプレート探してるかとかは、普段のアプリ開発ではそこまで意識しなくてもやっていける。

---

# 現実は複雑である
弊社の様なデータ収集が基盤にあるサービスや、IoTのためにセンサーから大量のトラフィックがあるサービス、外部サービスと連携してデータを受け渡しするサービスでは入力ソースは多岐に渡る。

- S3/SQS
- Kinesis/Kafka
- MQTT

弊社では顧客アプリケーションからのセッションデータ受け取りにS3とSQSの連携を利用している。

---

# データソースがRDBじゃない世界
受け取って、そのままRDBに流して済むならARに渡せばいい
しかし、そう簡単に行かないこともある

- レガシーデータとの整合性を保つためのデータ変換
- データ取得の堅牢性
  - エラー処理とリトライハンドリング
  - ロギング
- パフォーマンス要求
- 将来的な言語移植の可能性
- そもそも出力先がRDBでないケース

それなりのロジックが必要になることも多い。

---

# 最終的にRDBに入るのであれば、
# ActiveRecordモデルのクラスに書いてしまってもやれないことはない……。
# が、そうすると責務が肥大化して凝集度が下がるし、色々な所と結合してめっちゃテストがしづらくなる。

---

# ARではないモデルを用意する
弊社ではSQSをデータソースとしたモデルがある
フラットに置くかネームスペースを切るかはコーディングスタイルに依る

---

# Example

```ruby
class SessionMessage
  class << self
    def deque(&block)
      poller.poll(skip_delete: true) do |msg|
        data = Oj.load(msg.body)
        
        begin
          yield new(data)
          poller.delete_message(msg)
        rescue => e
          Rails.logger.warn(e)
        end
      end
    end
    
    private def poller
      # omit
    end
  end
end
```

---

# こういったモデルを作る時に便利
- Struct + ActiveModel::Validations
- ActiveModel/Model + ActiveModel::Attributes

---

# Struct
JSON -> Hashの一歩先へ
`keyword_init: true`でめっちゃ使い易くなった

- Railsに依存しない
- 処理が軽い
  - Cレベルで定義が完了するため、普通にクラス定義するより1.2から1.5倍ぐらい早い
- バリデーションやデフォルト値の定義先を明確にできる
  - 単体テストが簡単

---

# ActiveModel::Attributes

ついにRails公式で、ActiveModelにリッチアトリビュートが

- 型変換
- デフォルト値 (proc対応)
- カスタムタイプキャスター対応
- 値オブジェクトとの親和性
  - 同一性の検証
  - 透過的なシリアライズ/デシリアライズ

雑にJSONからマッピングしても、型やデフォルト値を上手くマッピングしてくれる

ちなみにRails5.2より前に、自分でタイプキャストしてStructにマッピングしているコードが結構ある

---

# 中間まとめ
- モデルといってもデータソースは様々
  - SQSとかKinesisとかKafkaとかだったり
- シリアライズされたものからオブジェクトにマッピングする
- 複雑な構造のデータは単純にHashに割り当てずに、ちゃんとクラスを定義する
- タイプキャストをネストすれば、入れ子構造にも対応できる
  - 複雑なモデルはツリー構造になる
- オブジェクトマッピングの処理とドメインロジックをごっちゃにしない
- データソースとのやり取り、値変換、バリデーション、メインロジックが独立してテストできる様に、クラスやメソッドを分割する

---

# 汎用のマッパーまでやるか？
例えばRedisとかは汎用のオブジェクトマッパーのgemがある。
gem化するとか、3つ以上そういうモデルがあるならやってもいいけど、その必要が無いことも多いと思う。
重要なのは抽象化ではなく、責務が独立していてテスト境界が明確であること。

---

# ここまでは主に入力について
# 続いて出力についての話

---

# ActiveRecordでやってはいけないこと
# 代表格が集計

何故かというと、単純に効率がめちゃくちゃ悪いから。

- ActiveRecordの様なオブジェクト作るだけで重いもので大量にデータを読み込むものではない
- 基本的にシングルスレッドでしか動かないのでリソースを効率良く使うのが難しい
- 出力も正規化とは程遠かったりする

**つまり、SQLを書くのをサボってはいけないということ**

---

# だからって集計用のSQLをArelでゴリゴリ組み立てるとか絶対地獄なので止めましょう
やっていいのは簡単なクエリだけ
SQLを部品ごとに再利用しようなんてのは幻想
また、完結したクエリ単位ならある程度再利用できる

---

# SQLを書く時に良く使うもの
- #select
- #find_by_sql
- ConnectionAdapterの#execute類
- ERB

---

# selectをちゃんと使う
ARのメソッドだけでもある程度の集計をSQLにやらせて結果を受け取ることができる。

```ruby
result = User.left_outer_joins(posts: :rates).select(
  "COUNT(DISTINCT rates.user_id) AS rated_users",
  "IF(rates.user_id IS NULL, 0,
    MIN(rates.review)) AS min_review",
  "MAX(rates.review) AS max_review",
  "AVG(rates.review) AS avg_review",
).group(:id).take!

p result.class #=> User
p result.rated_users # => レーティングした人の数
```

ただ、簡易なものに留めておくのが無難。
そして、出来るだけSQLそのものの構造に似せて書いた方が後々剥がす時に楽。

---

# find_by_sqlでのINLINE埋め込み

```ruby
result = User.find_by_sql([<<~SQL, authorized: 1])
  SELECT
    COUNT(DISTINCT
      CASE WHEN rates.authorized = :authorized THEN
        rates.user_id
      ELSE
        NULL
      END
    ) AS rated_users,
    MIN(rates.review) AS min_review,
    MAX(rates.review) AS max_review,
    AVG(rates.review) AS avg_review
  FROM users
  LEFT OUTER JOIN posts ON
    users.id = posts.user_id
  LEFT OUTER JOIN rates ON
    posts.id = rates.post_id
SQL
```

---

# execute with ERB

```sql
INSERT INTO aggregated_sessions
SELECT DISTINCT
  insight_id
  , unit
  , started_at
  , custom_event_id
  , SUM(CASE WHEN platform IN ('ios', 'android', 'web') THEN frequency ELSE 0 END) AS all_frequency
  , SUM(CASE WHEN platform = 'ios' THEN frequency ELSE 0 END) AS ios_frequency
  , SUM(CASE WHEN platform = 'android' THEN frequency ELSE 0 END) AS android_frequency
  , SUM(CASE WHEN platform = 'web' THEN frequency ELSE 0 END) AS web_frequency
FROM `aggregated_sessions_<%= unit %>`
WHERE
  dt >= '<%= from.strftime("%Y%m%d") %>'
  AND dt < '<%= to.strftime("%Y%m%d") %>'
  AND first_access = false
GROUP BY
  insight_id
  , unit
  , conversion_started_at
  , custom_event_id
```

---

```ruby
class QueryRenderer < OpenStruct
  def self.render(template_file, **variables)
    new(template_file: template_file, **variables).render
  end
  
  def render
    ERB.new(File.read(template_file), nil, "-")
      .result(binding)
  end
end

result = ActiveRecord::Base.connection.execute(
  QueryRenderer.render(template_file, {
    unit: "day", from: 1.day.ago, to: Time.current
  }),
)
```

---

# 後者になる程、生SQLとして個別に管理しやすくなる
# この手の集計・分析処理は高負荷であり、データ量が増えるとすぐに破綻する
# 特化したDWHか分散処理基盤が必要になった時にSQLをベースにしておけば、移行がしやすい

---

# バッチの依存関係
集計に限らず、時間のかかるバッチ処理は複数のジョブによって構成され、処理同士に依存関係がある場合が多い。

---

# ワークフローツールの導入
ツールに必要な要素
- 処理の依存関係と処理自体の定義を分離する
- 依存関係が一見して確認できることが望ましい
- 依存関係の無い処理は並列に実行できる
- 複数の処理の終了を待ち受けてから処理を開始できる
- 任意の処理から実行を再開できる

オプショナルな要素
- 実行スケジュールの管理ができる
- ワーカーとフローのコントローラを分離できる
- Web UI
- コンテナ対応

---

# 最近選択肢が増えてきている
ツール/ソフトウェア
- rukawa (拙作)
- digdag
- airflow
- luiji
- Jenkins

サービス
- AWS Batch
- CircleCI
- Github Actions **(NEW)**

---

# バッチ処理の基本
- 一つ一つの処理は独立して実行可能な1目的の処理にする
- 処理結果が羃等(繰り返し実行しても同じ結果)になる様にする
  - 複数の処理を組み合わせて結果的に羃等でも良い
- 途中からリトライできる様にする
- どこまで実行できたか、簡単に把握できる様にする
- エラー通知ができる様にする
- 過去のものを再実行できる様にする

---

# 弊社の例
# rukawa + Amazon Fargate

---

# rukawaの活用
https://github.com/joker1007/rukawa

- Railsアプリから成長してきたので、いくつかのデータやロジックをRailsのapp/modelsから参照している
- Rubyで直接コントロールできて、Railsをそのまま読み込めるrukawaを作ったのはそういう理由に依る
- ヘルパーメソッドを定義して、集計時刻等のパラメーターを渡し易くしている
- 大体の処理はテンプレートを元にクエリをレンダリングしてBigqueryやHive/Presto等にリクエストをする

---

```ruby
class WorkflowSample < Rukawa::JobNet
  def self.dependencies
    {
      AggregatedClipsDay => [],
      ConversionFactsDay => [AggregatedClipsDay],
      ExportConversionFactsDay => [ConversionFactsDay],
      CopyConversionFactsDay => [ExportConversionFactsDay],
      ImportConversionFactsDay => [CopyConversionFactsDay],

      RetentionFactsDay =>
        [AggregatedClipsDay, ConversionFactsDay],
      ExportRetentionFactsDay => [RetentionFactsDay],
      CopyRetentionFactsDay => [ExportRetentionFactsDay],
      ImportRetentionFactsDay => [CopyRetentionFactsDay],
    }
  end
end
```

---

# Amazon Fargate
- EC2インスタンス無しで、コンテナ上で処理を実行できる
- 必要なタイミングでECSのAPIを叩いて、特定のイメージでコマンドを実行するジョブをrukawaで定義する
  - コマンド引数や環境変数、S3等を利用してデータを引き渡す
  - セキュリティはTask Roleでコントロールする
- クリーンで運用負荷の無いジョブ実行環境が、Fargateの制限に到達するまではいくつでも並行に用意できる
- アプリイメージの外にembulkやrcloneやhiveクライアント等のコマンドラインツールを用意して独立して管理できる

---

# wrapbox
https://github.com/reproio/wrapbox
RubyからECSのAPIを叩いてコンテナ上でコマンドを実行して、終了を待ち受けるgem

hako oneshotみたいなもの

元々はECS上でRSpecを実行するために作ったが、Fargateが日本に来たタイミングでバッチ処理と相性が良さそうだったため、改修してFargate対応した

rukawaと組み合わせることで、並列度の高いバッチワークフロー実行環境が低価格で手に入った

---

# 余談 (時間があれば口頭で)

- fluentdへの転送処理の実装上の工夫
- cassandraの使い方
- prestoとRDBのデータの組み合わせ

---

# まとめ

昨今のWebアプリケーションは、RDBに入れて出して済む程に簡単ではない

多くの複雑な問題に対処するためには、適切な解決方法を常に選択し続けていく必要がある

実装上の工夫をしたり、採用ツールの枠を広げたり、新しいサービスを活用したりして、新しい問題に立ち向かっていく態勢を準備する必要がある

今日話しをしたのはその一例に過ぎない

大きく成長するアプリケーションを支える開発者は色々と考えることが多いが、そこが面白いところでもある