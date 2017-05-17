<!-- $theme: gaia -->
<!-- template: invert -->

# CRubyプロダクトにおけるembulkの活用法
#### @joker1007

---

# self.inspect
- @joker1007
- Repro inc. CTO (要は色々やる人)
  - Ruby/Rails
  - fluentd/embulk ← 今日はこの辺
  - Docker/ECS
  - Bigquery/EMR/Hive/Presto

---

# Reproのサービス
- モバイルアプリケーションの行動トラッキング
- 分析結果の提供と、それと連動したマーケティングの提供
- 大体Ruby・RailsでほぼAWS上で稼動している
- Dockerやterraform等も活用している

会社規模の割にデータ量が多い。
そのためデータエンジニアリングも必要。

---

## 開発・メンテしてるもの

#### embulk
- embulk-filter-ruby_proc
- embulk-output-influxdb
- embulk-parser(formatter)-avro
- embulk-output-s3_per_record

#### その他
- fluent-plugin-bigquery
- rukawa (自作のワークフローエンジン)

---

# embulkの主な用途
- Bigqueryで集計した結果の整形、取得 (日次バッチ)
- データの洗い替え (データメンテナンス)

---

# embulkの採用理由
- CRubyより高速に処理できる
- かつRubyでプラグインを書くことでアドホックな加工ができる
- プラグイン管理にRubyistにとって馴染みのあるBundlerが使える
  - Gemfile.lockによるバージョンロックが楽
  - プラグインインストールの方法がプロダクトと揃う

JRubyやプラグイン機構がRubyistフレンドリーな点が良い。

---

### バッチ処理に組込むために必要なもの
- 自動実行のためのスケジューラ -> Rundeck
- 実行日付を元に設定をパラメーター化 -> yaml_master
- 処理同士の依存関係や並列数を定義できるワークフローエンジン -> rukawa

digdagがあればいい。
が、現在、digdagは使っていないw
digdagリリースの前に設計・構築したので。

---

# rukawaについては以下を参照
###### http://joker1007.github.io/slides/introduce_rukawa/slides/index.html

---

### embulk利用例詳細

1. 更新が発生するデータをembulkでBqに転送
1. fluentdで蓄積しているログと結合しBqで集計
1. 集計後のデータとそれに紐付くユーザーIDをAVROでexport
1. GCSからS3にembulkでデータを転送する
1. S3に転送したAVROファイルをembulkでRDBにimport
1. S3に転送したAVROファイルをembulkでレコード単位にばらして別バケットに保存

---

# Bqへのデータ転送
- 日次バッチで必要なデータを都度丸ごと上書き
- 更新のある小規模のデータで羃等性を担保するため
- embulk-output-bigqueryを普通に利用している

---

# Bqでのデータ集計
- いくつかのSQLジョブをワークフローエンジンで定義して実行
- 処理が終わった側からexportしてはembulkでデータを転送する

---

# GCSからS3へのデータ転送
- embulk-input-gcsとembulk-output-s3を使用
- ファイルフォーマットにAVROを利用するため以下のプラグインを開発
  - [embulk-parser-avro](https://github.com/joker1007/embulk-parser-avro)
  - [embulk-formatter-avro](https://github.com/joker1007/embulk-formatter-avro)

---

## embulk-parser-avro

```yaml
in:
  type: file
  path_prefix: "items"
  parser:
    type: avro
    avsc : "./item.avsc"
    columns:
      - {name: "id", type: "long"}
      - {name: "name", type: "string"}
      - {name: "flag", type: "boolean"}
      - {name: "price", type: "long"}
      - {name: "item_type", type: "string"}
      - {name: "tags", type: "json"}
      - {name: "options", type: "json"}

out:
  type: stdout
```

---

## AVROスキーマ サンプル

```json
{
  "type" : "record",
  "name" : "Item",
  "namespace" : "example.avro",
  "fields" : [
    {"name": "id", "type": "int"},
    {"name": "name", "type": "string"},
    {"name": "flag", "type": "boolean"},
    {"name": "spec", "type": {
      "type": "record",
      "name": "item_spec",
      "fields" : [
        {"name" : "key", "type" : "string"},
        {"name" : "value", "type" : ["string", "null"]}
      ]}
    }
  ]
}
```

---

## AVROを使う理由
- Bqからexportした時のデータ型の問題
  - JSONだとINTが文字列になる
  - INTの配列も文字列になる
- スキーマを後から変えられる
- スキーマ側からデフォルト値を差し込める
- Hadoopエコシステムで処理しやすい

cf. http://avro.apache.org/docs/current/spec.html

---

## レコードをばらしてS3に書き込む
- サービス上の要請による
- embulk-output-s3_per_recordを利用
- Pageをaddする時に都度S3に書き込む
- 効率がめっちゃ悪いので遅いが仕方なく

---

## embulk-output-s3_per_record

config
```yaml
out:
  type: s3_per_record
  bucket: your-bucket-name
  key: "sample/${id}.txt"
  mode: multi_column
  serializer: json
  data_columns: [id, payload]
```

output
```
{"id": 5, "payload": "foo"}
```

---

### 設定ファイルの生成とembulkの実行
- yaml_masterというgemを作り設定ファイルを生成
  - ERBを利用してRubyからプロパティを突っ込んでyamlを出力する
  - Liquidより表現力が高い
  - CRubyのプロダクトが持つ情報を元に直接生成しやすい
- CRubyからの呼び出しはpopen3を利用してプロセスを起動する
  - Rukawaで呼び出しのためのヘルパーを書いている

---

## Embulkを効果的に使うには
- システムに組込むには、いくつか周辺のヘルパーを用意する必要がある
- 自分達が使うフォーマットに合わせてプラグインを作れる様にしておく
- パフォーマンス要求がきつくないデータ加工にはembulk-filter-ruby_procをオススメする

---

## プラグイン開発で意識していること
- できるだけ機能を限定する
- カラムの操作などfilterでやれることは単体のfilterに任せる
- データのparse, encodeはJavaの方が良い
  - ネストしたデータ構造を扱うのは面倒だが
- マルチスレッドで動作することを意識する
  - 特にRubyプラグイン
- 実行フェイズ毎にシリアライズを挟む場合があることを知っておく
