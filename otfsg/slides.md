# 本番のトラフィック量でHudiを検証して見えてきた課題

## @joker1007
## Repro inc.

---

<!--
footer: ![w:80 h:32](logo.png)
-->

---

# 自己紹介

- 橋立友宏 (@joker1007)
- Repro inc. チーフアーキテクト
- 人生における大事なことは
ジョジョから学んだ
- 日本酒とクラフトビールが好き
- Asakusa.rb メンバー

---

# Reproについて

マーケティングオートメーションを行うためのWebサービスを提供している。
大まかに言えば、端末のプッシュ通知やアプリ内のポップアップ、Webサービス上での表示などを利用して顧客とコミュニケーションを取るツール。

エンドユーザーの行動ログが届くので、トラフィック量としてはかなりの規模になる。

---

# 更新を伴うハイトラフィックなレコードを
# バルクで扱うための方法としてHudiの検証を行なった。

---

# 実験データ

### データ構造

| カラム名 | タイプ |
| ---------- | --------- |
| partition_id | INT |
| id | BIGINT |
| key | STRING |
| value | STRING |
| updated_at | TIMESTAMP |

---

テーブルのカラム名は現実の値とは異なっているが、型のスキーマは変えていない。

パーティションキーは数千以上の値のバリエーションがあり、その数だけパーティションが増えることになる。

またデータに非常に偏りがあって時系列でも無いため、純粋に全データを分析するだけならパーティションキーとして最適とは言えないが、利用する可能性の高いクエリパターンを優先した結果この様に設定した。

---

# データ規模
全体で30億件ぐらいで、秒間4000件程度のデータ入力がある。
1レコードは数十バイト程度。

---

# データソース
Kafkaトピックをデータソースとする。
Kafkaレコードのシリアライズ形式はAvroフォーマット。

---

# 検証のやり方
Kafkaトピックのoffsetをearliestに設定し、想定しているスループットの入力ラインを上回る書き込みパフォーマンスが出せるか。
それによって先頭まで追い付くのにどれぐらいの時間がかかりそうかを検証した。

---

# 検証基盤 (Spark)

## 各種バージョン
- Amazon EMR 7.1.0
    - hudi-0.14.1
    - spark-3.5.0

## インスタンス
- r7g.xlarge x 25

---

# Config (初期検証時)

```properties
hoodie.index.type=SIMPLE
hoodie.datasource.write.hive_style_partitioning=true
hoodie.datasource.hive_sync.jdbcurl=jdbc:hive2://localhost:10000/
hoodie.datasource.hive_sync.database=default
hoodie.datasource.hive_sync.table=output_table
hoodie.datasource.hive_sync.partition_fields=partition_id
hoodie.datasource.hive_sync.enable=true
hoodie.parquet.compression.codec=zstd
hoodie.datasource.compaction.async.enable=true
hoodie.cleaner.commits.retained=5

# ...省略...
hoodie.streamer.source.kafka.enable.commit.offset=true
hoodie.archive.merge.enable=true

hoodie.clustering.inline=true
hoodie.clustering.inline.max.commits=4
hoodie.clustering.plan.strategy.sort.columns=key
```

---

# 実行コマンド

```sh
spark-submit \
  --conf spark.streaming.kafka.allowNonConsecutiveOffsets=true \
  --class org.apache.hudi.utilities.streamer.HoodieStreamer /usr/lib/hudi/hudi-utilities-bundle.jar \
  --props s3://repro-config/hudi-kafka-source.properties \ # 上記properties
  --schemaprovider-class org.apache.hudi.utilities.schema.SchemaRegistryProvider \
  --source-class org.apache.hudi.utilities.sources.AvroKafkaSource \
  --source-ordering-field updated_at \
  --target-base-path s3://repro-batch-store/experiment/UserProfiles \
  --table-type MERGE_ON_READ \
  --target-table UserProfiles \
  --enable-sync \
  --continuous \
  --op UPSERT
```

---

# 重要な設定項目 その1

- `hoodie.index.type`: index方式の決定。初期検証時はSIMPLEだった。性能に大きく影響するので詳細は後述する。
- `hoodie.datasource.write.partitionpath.field`: hudiテーブルのパーティションキーを指定する。
- `hoodie.datasource.compaction.async.enable`: HoodieStreamerによる書き込み時に非同期Compactionを実行する。同じ書き込みプロセス内で実行されるが書き込み自体はブロックしない。
- `hoodie.cleaner.commits.retained`: cleanプロセスで削除せずに維持する直近のコミット数。commitの数であってdeltacommitの数ではないことに注意。

---

# 重要な設定項目 その2

- `hoodie.archive.merge.enable`: hudiは一定以上commitが蓄積されるとmetadataを一つのファイルにまとめてアーカイブする。その時アーカイブファイルのマージを有効にするかどうか。S3の様な追記をサポートしないファイルシステムだと小さいファイルが大量に出来る可能性があるのでそれをマージできるようにする。
- `hoodie.streamer.source.kafka.enable.commit.offset`: Kafkaからデータを受け取る時にConsumer Groupとしてgroup.idを登録して受信状況をcommitする。この設定を有効にしておくと、Kafka側のconsumer lagの監視で遅延状況が監視できる様になる。
- `hoodie.clustering.inline`: 書き込み処理と同じプロセスで同期的にclustering処理を行う。これは書き込み処理をブロックするが別途clusteringジョブを運用する必要がなくなる。

---

# 初期検証の結果

結論から言えば、全然パフォーマンスが追いつかなかったどころか書き込みが完了しないレベルだった。

書き込み開始当初は問題無いのだが、一定以上ファイルが溜まると劇的にパフォーマンスが劣化し、deltacommitすら完了しない状態になった。

Sparkのコンソールから時間がかかっている処理を特定し周辺の処理のソースコードを確認した所、一番の問題はindexからのlookupだった。

自分が検証した範囲ではSparkのSIMPLE indexで大規模なデータレイクを構築するのはかなり難しいのではという印象だ。

という訳で、一番大きな問題であったインデックス選択について詳しく見ていく。

---

# そもそもSIMPLE indexとは

公式のリファレンスによると以下の様に書かれている。

> SIMPLE (default for Spark engines): This is the standard index type for the Spark engine. It executes an efficient join of incoming records with keys retrieved from the table stored on disk. It requires keys to be partition-level unique so it can function correctly. 

see. https://hudi.apache.org/docs/indexing

---

# SIMPLE indexの動き方

つまり、入ってきたレコードのキーをディスク上に実際に保存されているテーブルファイルから取得したキーの一覧とJOINして、ファイルを特定する。

GLOBALでないSIMPLEインデックスなら特定パーティション内でしか検索は発生しないとはいえ、対象となるファイル数やキーの数を考えると、結構な数の組み合わせが発生する。

実際、投入されたレコード1件ごとにこの処理が行われるため、処理時間の増大や処理中のメモリの肥大化に繋がり一定以上ベースのテーブルのデータ量が多くなると、まともに処理が継続できなくなった。

今回利用したデータの傾向として、パーティション数の増大及びレコード数の偏ったパーティションが多く発生するなどがあったことが、ファイル数の増大に繋がり悪影響を及ぼしていると考えられる。

---

# SIMPLE indexを利用していた理由

公式リファレンスの[Index Strategy](https://hudi.apache.org/docs/indexing#indexing-strategies)の項目における"Workload 3: Random updates/deletes to a dimension table"に該当したため。

初手から余りAdvancedな設定に手を出すべきではないと考え一旦リファレンスに則ることにした。

結果的にはどうにもならなかったので、再度検討することになった。

---

# BUCKET indexの採用

最終的にBUCKET indexを採用することにした。

> BUCKET: Utilizes bucket hashing to identify the file group that houses the records, which proves to be particularly advantageous on a large scale. To select the type of bucket engine—that is, the method by which buckets are created—use the hoodie.index.bucket.engine configuration option.

これはレコードのキーをハッシュ関数にかけてバケット(つまりfile group)を特定し、それをレコードの所在と判断する方式だ。O(1)で即レコードを特定できるので大幅な書き込み対象lookupの高速化が狙える。

---

# BUCKET indexの詳細

BUCKET indexには二つの方式があり、それぞれSIMPLEとCONSISTENT_HASHINGになる。

> SIMPLE(default): This index employs a fixed number of buckets for file groups within each partition, which do not have the capacity to decrease or increase in size. It is applicable to both COW and MOR tables. Due to the unchangeable number of buckets and the design principle of mapping each bucket to a single file group, this indexing method may not be ideal for partitions with significant data skew.
CONSISTENT_HASHING: This index accommodates a dynamic number of buckets, with the capability for bucket resizing to ensure each bucket is sized appropriately. This addresses the issue of data skew in partitions with a high volume of data by allowing these partitions to be dynamically resized. As a result, partitions can have multiple reasonably sized buckets, unlike the fixed bucket count per partition seen in the SIMPLE bucket engine type. This feature is exclusively compatible with MOR tables.

---

SIMPLEは全パーティション一律で固定サイズのバケット数を割り当てる。名前の通り単純で管理コストが不要なのがメリットだが、データの偏りがあると極端に小さいファイルが大量に発生したり、逆に極端に大きいサイズのファイルが発生する可能性がある。

CONSISTENT_HASHINGはハッシュ関数をかけて出力される64 bitの整数値空間をバケット数の幅で区分けしてバケットを区分けに対応させる形で割り当てる。この方式はパーティションごとにバケットサイズを可変にできるのが利点で、SIMPLEバケットでは対応できなかったデータ量の偏りに対処できるが、パーティションごとにconsistent_hashing_metadataというものを作成する必要があり、そのファイルを読み込んでバケット数を取得するコストが発生する。
また、バケットサイズを変更するには専用のclusteringジョブを動かす必要があり、それなりに処理時間・負荷がかかる。

---

# 今回は、インプットデータの特性としてかなりデータ量に偏りがあることが分かっていたのでCONSISTENT_HASHING方式を選択した。

---

# チューニング後の重要なコンフィグ差分

```properties
hoodie.index.type=BUCKET
hoodie.index.bucket.engine=CONSISTENT_HASHING
hoodie.bucket.index.hash.field=user_id
hoodie.bucket.index.num.buckets=2
hoodie.bucket.index.min.num.buckets=1
hoodie.bucket.index.max.num.buckets=1024
# CONSISTENT_HASHING利用時はmetadataテーブルを利用できない
hoodie.metadata.enable=false
hoodie.storage.layout.type=BUCKET

hoodie.compact.inline.max.delta.commits=10
hoodie.compaction.strategy=org.apache.hudi.table.action.compact.strategy.UnBoundedCompactionStrategy

hoodie.streamer.kafka.source.maxEvents=40000000
hoodie.clustering.plan.strategy.max.num.groups=10000
```

---

# コンフィグ詳細 その1

`hoodie.index.type=BUCKET`, `hoodie.index.bucket.engine=CONSISTENT_HASHING`はCONSISTENT_HASHING方式でBUCKET indexを利用する設定になる。
現時点での制約としてmetadataテーブルと同時に有効にすることができないらしいので、metadataテーブルを明示的にオフにする。

`hoodie.bucket.index.num.buckets`はSIMPLE方式のバケッティングの時の固定バケット数の設定とCONSISTENT_HASHING方式における初期バケット数の両方の設定値になる。
`hoodie.bucket.index.[min,max].num.buckets`はCONSISTENT_HASHINGのバケット区分を再割り当てした時の最小のバケット数と最大のバケット数になる。データ量の偏りに合わせて設定するのが良いだろう。
(上記の設定のmax値が1024になっているが、これは引っかからない様に非常に大きくした値なので今回利用したデータではこんなに大きな値は必要無かった。)

---

# コンフィグ詳細 その2

`hoodie.compact.inline.max.delta.commits=10`はいくつのdeltacommitごとにcompactionをスケジュールするかを設定する。
`hoodie.compaction.strategy=org.apache.hudi.table.action.compact.strategy.UnBoundedCompactionStrategy`はcompactionの実行戦略を設定する。デフォルトではcompactionの実行時間の見通しを立て易くするために、一度の処理で一定のファイルサイズを越える量のcompactionを行わない様にフィルタされる。`UnBoundedCompactionStrategy`は常に全てのファイルを対象にcompactionを行う様に設定を変更する。設定を変更している理由は、一部のパーティションのcompactionだけ実行されてない状態になると、trinoからのクエリ時に読み取れる情報に差が出てしまうからだ。

---

# コンフィグ詳細 その3

```properties
# Hoodie Streamerジョブが一度の書き込みサイクルでKafkaから取得するレコードの上限
hoodie.streamer.kafka.source.maxEvents=40000000
```

1回のdeltacommitの処理においてKafkaトピックから取得するレコードの上限を設定する。デフォルトは5000000。今回はかなり値を増やしている。
HoodieStreamerを利用したレコード書き込みでは、1回ごとにconsistent_hashing_metadataを全て再読み込みする挙動になる。今回利用したデータの様にパーティションが数千を越える規模になると読み込みだけで1分以上の時間がかかってしまった。1回のdeltacommitでのデータ量を少なくしてもこの時間は短縮できない。そのためdeltacommitで書き込むデータ量を増やして書き込み効率を上げる狙いがあった。

---

# コンフィグ詳細その4
```properties
hoodie.clustering.plan.strategy.max.num.groups=10000
```

`hoodie.clustering.plan.strategy.max.num.groups`は一度のclusteringジョブで処理できるfile groupの上限を設定する。デフォルトの値は30。

今回のデータの様にパーティションが大量に存在し、デフォルトのバケット数が2である状態だと、凡そ数千 * 2のfile groupが存在することになる。デフォルトの設定値である30では、何度clustering jobを実行しても到底全パーティションまでclustering処理が実行できない。そのため大幅に設定値を上げている。

---

# 検証結果
上記の設定で大体1回のdeltacommitのパフォーマンスは2000万レコード / 3minだった。
しかし、compactionの実行を全ファイル対象にすると凡そ15分ほど実行に時間がかかる。この処理時間は実行インターバルを短くしても余り短縮できない。

全体のスループットを平均して1秒ごとに均すと、 75000rpsぐらいのペースでレコードを書き込むことができる。但し、リアルタイムクエリが可能であってもcompaction中の15分はデータが更新できない時間帯が存在する。

書き込みペースとしては十分なパフォーマンスが出せるという結果が得られたが、リアルタイムクエリが可能なクエリエンジンに制限がある状況では、実際に利用可能なデータが得られるまでのリードタイムは最悪の場合45分程度とかなり長くなってしまう。

---

# 運用上の課題

---

# Clusteringジョブの実行方法

非常に長時間かかるclusteringジョブの実行をどうするかを考える必要がある。バケット数の調整だけを目的とするなら一定のデータが蓄積したパーティションで1回実行すれば、当分は実行しなくても問題は無いし、任意のパーティションだけを対象にジョブを実行することは可能なので、何とかできなくはないがどういうタイミングで実施するのかを決めて運用に組込む必要がある。

---

# EMRFSのコネクションリークっぽい挙動

continuousモードで書き込みを続けているとEMRFSによるS3接続のコネクションがCLOSE_WAIT状態で残り続けてTCPのコネクション数もしくはfdが枯渇する問題があった。

問題になるのはSparkのDriverノードだけなので、そのノードで定期的に`ss state close-wait --kill`などを実行しておけば何とかなるが、地味に面倒な問題だった。sysctlでtcpのkeepaliveを変更しても効果が無かったので、コネクションがどこかでリークしている可能性がある。S3AFileSystemを使えば解消するかもしれない。

---

# リアルタイムクエリをサポートするクエリエンジン

MORテーブルに対してリアルタイムクエリを実行できるクエリエンジンの制約だ。Spark, Hive, Prestoは対応しているが、現時点でTrinoやImpalaなどは対応していない。現在弊社のメインのクエリエンジンはTrinoでありPrestoから移行した後なのだが、このためにまたPrestoに戻すのはかなり無駄な感じがしている。対応計画自体は存在しているらしいが、今後どうなるかは分からない。

---

# 結論

更新可能なparquetデータレイクが構築可能であるという性質は非常に有用で、全体的な書き込みスループットもチューニング次第で要求に耐えるところまで到達できることが分かった。またストレージがS3だけで完結できる点も嬉しい。

一方で、compaction、clusteringの実行をどうコントロールするかはかなり考える必要があるし、動きが怪しい箇所もまだ見受けられる。Spark以外にFlinkでの書き込みも検証したのだが、書き込みに大きな影響を及ぼすバグを踏んで検証が中断してしまった。

という訳で、将来的には有用な選択肢と言えるが、現状すぐに導入するにはそれなりにハードルがあるという結論になった。
今回検証に用いたデータは、継続的に大量のパーティションに対してランダムに書き込みがあるという点で、hudiのユースケースとしてはかなりハードなものだったので、ある程度の課題が発生するのは予想通りでもあった。

---

# 今後

icebergなども検証したいが、とりあえず先にNewSQLの検証に入るタスクが立ってるので、そちら側からのアプローチを試すことになりそう。
