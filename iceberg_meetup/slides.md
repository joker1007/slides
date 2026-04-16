---
title: ReproでのicebergのStreaming Writeの検証と実運用にむけた取り組み
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
        font-size: 20pt;
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
        color: var(--subtle);
    }
    li {
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
# ReproでのicebergのStreaming Writeの検証と<br>実運用にむけた取り組み

### joker1007 (Repro株式会社)
### Apache Iceberg Meetup

---

<!--
footer: ![w:100 h:32](logo_white.png)
-->

# 自己紹介

- 橋立友宏 (@joker1007)
- Repro株式会社 チーフアーキテクト
- 元々はRailsエンジニアだったが、最近はJavaばかり書いている
- 日本酒とクラフトビールが好き

![bg right:40% height:320px](./icon.jpg)

---

# Asakusaから来ました
活動中のRubyコミュニティで日本最古
(自分は本当に浅草に住んでます)

![bg right height:640px](asakusarb.png)

---

# 最近の仕事
![repro height:200px](logo_white.png)
チーフアーキテクトとして、サービス全体の中長期的な技術選定、設計アドバイス、全体アーキテクチャのデザインなどをしている。

---

# Reproの事業
マーケティングオートメーションサービスを提供している。
マーケティングオートメーションとは、

- ユーザーの行動を分析・分類し
- 複数のチャネルで適切なキャンペーンを配信することで
- 顧客とエンドユーザーのコミュニケーションを支援する

SaaS事業だけでなく、サービスグロースの総合的な支援も提供しています。

---

# 背景

Reproでは大体200億件ぐらいのレコードを持つテーブルから1000万件前後を取得するワークロードと、普通にWebリクエストで1件単位で取得するワークロードが混在している。
出来る限り短いリードタイムで利用可能になっていて欲しい。(目安として大体5分以内)

この目的のために、ReproではCassandraをバックエンドとし、テーブルのパーティションキー及びクラスタリングキーを工夫してbucketingなどのテクニックを活用することで対応してきた。
大規模な読み込みワークロードではTrinoを利用し、その他のリクエストでは普通にCassandra Clientから読み取りを行っている。

また、Kafkaを利用したストリームアプリケーションとRocksDBを利用して各ノードローカルで処理することで、高速にエンドユーザーを分析し振り分ける処理などもある。

---

# 課題

Cassandraはバルクロードに向いた構造とは言い難く、現状Trinoの並列読み込みとテーブルのbucketingにより機能として動作はしているがコスパが悪い状態。
得意とは言えないユースケースなので将来的なスケーラビリティにも不安がある。

しかし、開発メンバーが運用できる基盤にも限りがあるので、できる限り運用負荷は上げたくない。

そこで、S3に配置可能なOpen Table Formatが以前から気になっていた。

---

# 前回

OTF StudyでHudiについて検証した結果を発表させてもらった

[本番のトラフィック量でHudiを検証して見えてきた課題](https://speakerdeck.com/joker1007/ben-fan-notorahuitukuliang-dehudiwojian-zheng-sitejian-etekitake-ti)

この時はTrinoのHudi対応が余り積極的ではなかった点、Sparkとかなり処理が結合していてCompactionタイミングや負荷のコントロールがやり辛かった点、などを考慮して実運用を目指すところまでは踏み切らなかった。

---

# IcebergとHudiとの比較

icebergの方が明らかにシンプルで仕組みが分かり易い。
特にMerge On Readの仕組みとConcurrency Control。

HudiはAvroを利用したレコードタイプのフォーマットとカラムナを組み合わせておりクエリが複雑になる。
一方でIcebergはmanifestとDeleteレコードの組み合わせで実現しており基本的にParquet(Orc)で完結する。

Hudiはより低レイテンシの書き込みに価値を置いている分、書き込みもクエリも仕組みが複雑になる印象。

---

# 検証により知りたかったこと

Reproのデータ量及び書き込みのワークロードに対して、以下の要素がそれぞれどうなるのか。

- icebergの書き込みとcommitにかかるノードのリソースコストがどの程度になるのか
- commitとcompactionがどれぐらいの実行頻度ならバランスが取れるのか
- compactionにどれぐらいの負荷がかかるのか

Hudiの検証で得た知識として、この手のストリーミング書き込みでは断片化したsmall fileの増加を抑えるcompactionが非常に重要かつ負荷がかかることが分かっていたので、ここに注目して検証を実施。

---

# 検証内容

- 現行のcassandraへの書き込みと同様にKafkaからレコードを受け取ってicebergテーブルの書き込みを行う。
- コミット及びcompaction処理がReproの機能・運用面で現実的な頻度の実行で処理が可能かどうかを検証し、productionで必要になるノード数を見積る。
- trinoでクエリをする時の簡単なクエリパターンの実験・検討を行い挙動を確認する。

---

# データの傾向

レコードの内容はエンドユーザーに関するメタデータを保持するuser_id+キーバリューというシンプルな構造のレコードであり、Updateも頻繁に発生する。

同一の内容であれば処理をスキップする仕組みは既に前段に構築済み。
そのため、本当に書き込みを必要とするスループットはそこまで高くない。
大体秒間6000件程度がカバーできれば現状は対応可能。

---

# 書き込み方式
EMR-7.10を利用してFlinkでS3にデータを書き込む。
書き込みにFlinkを利用するのはEquality Deletionを利用するため。

テーブルの管理にはAWS Glue Data Catalogを利用し、spark-sqlを利用したDDLで構築する。
Glue Data Catalogを利用するのは、Catalog管理の運用コストを削減するためと、Glueが持つIcebergのテーブル最適化の機能を利用したいため。

---

# メンテナンスタスク

メンテナンスタスクは以下の様なやり方で実施。

- expire_snapshot: Glueに任せる
- rewrite_data_files: Sparkで実行する
- rewrite_manifests: Sparkで実行する
- delete_orphan_files: Glueに任せる

全部Glueの機能で完結すれば楽だったのだが、rewrite_data_filesの負荷が高過ぎてGlueの機能ではコンピューティングリソースが不足し失敗する。

---

# データ規模

- 全体のデータ量: 2TB程
- レコード数: 200億件超
- 更新頻度: 5000件 / sec

bucketingの結果、バラつきはあるが大体1パーティションが平均1GBぐらいになる様にして検証。(バケットサイズ、ファイルサイズは実運用時には要調整)

---

# DDL

spark-sqlで実行する。

```sql
CREATE TABLE IF NOT EXISTS glue.testdb_production.test_tables (
  app_id bigint NOT NULL,
  user_id bigint NOT NULL,
  key string NOT NULL,
  value string
)
USING iceberg
PARTITIONED BY (bucket(32, app_id), bucket(8, key))
TBLPROPERTIES (
  'write.object-storage.enabled'='true',
  'write.delete.mode'='merge-on-read',
  'write.update.mode'='merge-on-read',
  'write.merge.mode'='merge-on-read',
  'history.expire.max-snapshot-age-ms'='86400000'
)
LOCATION 's3://repro-experimental-store/production/testdb_production/test_tables';

ALTER TABLE glue.testdb_production.test_tables WRITE ORDERED BY insight_id, key;

ALTER TABLE glue.testdb_production.test_tables SET IDENTIFIER FIELDS insight_id, user_id, key;
```

---

# パラメーターについて

Flinkで高頻度に書き込むことでsnapshotが大量に増えるためmax-snapshot-age-msを短く設定
merge-on-readとobject storage向けの最適化(prefixをばらけさせることで書き込みスループットのキャップを回避する)を有効化。

---

# パーティショニング設定

クエリのワークロードは基本的にapp_idごとに閉じた形で行われる。
値を直接利用せずにbucketingしているのは、パーティションに利用するには数が多過ぎ、またデータ量のばらつきも非常に大きいため。

Icebergの良い点として、manifest構造の中にパーティション定義を持っていて、後から変更可能になっているので調整がしやすい。

---

# EMRクラスタサイズ

以下のクラスタサイズ、設定内容は試行錯誤の結果落ち着いた値。

書き込みクラスタサイズ: r8g.2xlarge * 3
テーブルメンテナンス用クラスタサイズ: r8g.2xlarge * 20 (メンテナンスタスク実行時のみ必要)

---

# Sparkパラメーター

rewrite_data_filesの実施に多大なメモリが必要になるため以下の項目を調整。

- spark.driver.memory
- spark.executor.memory
- spark.memory.fraction
- GCパラメーター (効果の程は微妙)

---

# Flinkパラメーター

- jobmanager.memory.process.size
- taskmanager.memory.managed.fraction
- taskmanager.memory.process.size

同じくメモリサイズの割り当てを調整。
こちらはそこまで負荷にはならなかった。
ただKafkaにレコードが大量に溜まっていて台数が多いケースだとjobmanagerのメモリが不足するケースがあった。

---

# 初期構築

Flinkで書き込みを行う前に、既存のデータを元に初期データを投入し本番と同等のサイズのテーブルを構築する。

既存のデータはcassandraに蓄積されているため、これを変換してTrino経由でicebergテーブルに投入する。

```sql
INSERT INTO iceberg.testdb_production.test_tables (app_id, user_id, key, value)
SELECT app_id, user_id, key, value FROM cassandra.repro.test_tables;
```

先述のデータ規模を投入するのにr8g.2xlarge 10台のtrinoクラスタで2時間半ぐらいの所要時間で完了する。

---

# Flinkによる書き込み設定

confluentのschema registryを利用したKafkaトピックからのストリーム書き込みを行うため、以下の準備をする。

```sh
# confluent registrtyに対応したflink sql connectorのjarファイルをDL
wget https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-avro-confluent-registry/1.20.0/flink-sql-avro-confluent-registry-1.20.0.jar
```

```sh
# flinkセッション起動
flink-yarn-session -Dparallelism.default=2 -d
```

```sh
# flink SQLの実行
flink-sql-client -j flink-sql-avro-confluent-registry-1.20.0.jar -f insert.sql
```

---

# flink-sqlでチェックポイント間隔を調整

```sql
SET state.backend.type = 'rocksdb';
SET execution.checkpointing.storage = 'filesystem';
SET execution.checkpointing.dir = 's3://repro-experimental-store/production/flink-checkpoints';
SET execution.checkpointing.savepoint-dir = 's3://repro-experimental-store/production/flink-checkpoints';
SET execution.checkpointing.num-retained = '1';
SET execution.checkpointing.interval = '15min';
SET execution.checkpointing.timeout = '10min';
SET execution.checkpointing.min-pause = '1min';
```

クエリ自体は単純にKafkaからconfluet-schema-registryを利用してデータを取得、upsertで書き込む単純なクエリを利用した。
`execution.checkpointing.interval`がicebergのcommit間隔になる。今回は調整の結果15分とした。

---

# commit間隔とファイル数の関係

1タスクで15分に1回コミットなので、15分に凡そ1パーティションに1ファイルづつparquetファイルが増えていく。
24時間で 4(1hで4回) * 24h * 2(data file & delete file) = 96ファイル程増えることになる。
並列数がもっと必要であれば、その分作成されるファイル数も増える。

これを定期的なcompactionで解消できるかどうかを検証した。

---

# メンテナンスタスクの実行

expire_snapshotは12時間に1回実行、delete_orphan_filesは24時間に1回実行し48時間より前のファイルを削除する用に設定した。
compactionはEMRのcommand-runnerステップを利用して24時間に1回spark-sqlコマンドを利用して以下のクエリを実行する。

```sql
CALL glue.system.rewrite_data_files(
    table => 'testdb_production.test_tables',
    strategy => 'sort',
    options => map(
        'min-input-files', '50',
        'partial-progress.enabled', 'true',
        'partial-progress.max-commits', '20',
        'remove-dangling-deletes', 'true',
        'rewrite-job-order', 'files-desc'));
```

---

# compaction実行ペースと実際の処理時間

24時間で1パーティションごとに最低でも96ファイル + deletesファイル分の小さいファイルが生成されるので、それをcompactionにより大きなparquetファイルに結合する。
このファイル増加ペースであれば、大体r8g.2xlarge * 20台で1時間〜2時間ぐらいの処理時間でタスクが完了する。

24時間に1度、2時間の所要時間の実行ペースで十分追い付けると分かった。

---

# クエリ方法

icebergを利用しつつ現状のcassandraに対するクエリと同様に数分以内のリードタイムでデータを利用可能にするために工夫が必要だった。

- TrinoのKafka connectorとiceberg connectorをUNIONしたviewを構成し、そのviewに対してクエリを行うことで最新のデータだけをKafkaから取得可能にする方法を考案。
- 検証実験では、現在時刻から30分以内のtimestampに限定してKafka connectorでクエリを行いそれ以外のデータはicebergからクエリを行う様にする。

---

# Kafkaと組み合わせたクエリデータの規模と負荷

Kafkaから読み込むデータ量は直近30分に限定すると、約2.7GBで2700万レコードに相当する。

Kafka上のデータはicebergと同様のパーショニングは行えないが、直近30分程度のデータ量であれば無駄を承知の上でレコードを読んでもそれなりの負荷で済む。
10台前後のtrinoクラスタがあれば数秒で読むことが出来るしKafkaクラスタにかかる負荷も許容範囲の小さいものだった。

但し、単発では問題ないレベルという状態だったのでそのまま実運用可能かは要確認。

---

# GlueカタログとViewについて

Trinoのiceberg catalogをGlue Catalogに設定して構成していた場合、icebergテーブルが所属しているcatalog及びdatabaseに対してviewを生成すると**Glue Data Catalog側に永続化される**ことが分かった。

そのためクラスタの停止や入れ替えを伴ってもviewを再作成する手間はかからないことも確認できた。

将来的には[Apache Fluss](https://fluss.apache.org/)を活用できたりすると効率が良さそうと考えているが、現状ではTrinoからのクエリがサポートされていないしバックエンドのicebergサポートも計画中という感じなので、今後の展開に注目していきたい。

---

# 総評

- Flinkによる書き込みは動きがシンプルなので動作自体は非常に軽い。
- 15分単位のupsert書き込みを継続している状態で、compactionの実行が遅れると割と顕著にパフォーマンスに影響を与えることが分かった。compactionの定期実行はやはり重要。
- compactionはかなり処理負荷が高くメモリもCPUリソースもかなり必要になる。
- **特に今のicebergで普及しているテーブル仕様のバージョン(v2)とsparkの実装では、非常に大量の小さなファイル(特にdeleteファイル)が存在すると、compactionに膨大なメモリが必要になるため、compactionが長期に渡って実行されないとテーブルのメンテナンス自体が困難になる可能性があって危険。**

現時点でcompactionの所要時間をそれなりに抑えて安定して実行できる様にするにはかなり大きめのsparkクラスタがいる。

---

# 現在、本番導入に向けて作業中

- [x] 必要なインフラのコード化
- [x] メトリック取得とアラートモニタの整備
- [ ] 実際に利用する新しいクエリの構築

---

# 実装済みのモニタリング・監視

- 各種AWSリソース、アラート定義のterraform化
- flinkがちゃんと動作していることを監視し、マシンリソースと書き込みペースのメトリックをdatadogで取得できる様にする。
- EventBridgeとStepFunctionで定期的にcompactionのためのEMRを動かすデプロイスクリプトと権限設定。
    - compactionの失敗時にアラート
- icebergのテーブルメタデータによるモニタリング
    - パーティションごとのファイル数やファイルサイズ合計をメタテーブルから取得、datadogに送信するシェルスクリプトを書いて書き込みクラスタのsystemd timerで定期実行。

---

# Next Step

- 実際に利用しているクエリの置き換え
- Kafkaと直接組み合わせるのではなく、Flussの様な仕組みを簡易的に自作できないか検証。
  - ストリーミングアプリケーション上にApache Arrowでデータを溜めてtrinoからクエリ可能にするアイデア。
- V3フォーマットのサポート状況を定期的に確認

