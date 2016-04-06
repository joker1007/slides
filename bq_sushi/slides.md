# **fluentd x embulk x bigqueryで作る**
# **バッチ集計処理基盤**

@joker1007

---

#### メインのバッチ集計処理基盤として
#### bigqueryを利用するために今取り組んでいること、
#### そしてそれを支えるfluentdとembulkの
#### bigqueryプラグインの現状を解説します。

---

## self.inspect

- @joker1007
- Freelance (Ruby/Rails/JS/Redshift/Bigquery)
- パーフェクトRubyとかパーフェクトRailsとか
- 最近はアプリより基盤寄りの仕事が多い
- (株)Reproで仕事中

[Repro Inc.の最新情報 - Wantedly](https://www.wantedly.com/companies/repro "Repro Inc.の最新情報 - Wantedly")

Hireling Now :exclamation:

---

資料作成サボってて時間がやばくなってしまい、

業務時間使って資料作ってたので、

宣伝を入れるからってことで許してもらいました :trollface:

---

## **BQの利用背景**
- MySQLの限界
  - 将来的にもデータ量は増え続ける
- 割とヘビーな集計処理がある
- できるだけ同時に算出したい

---

## **構成イメージ図**
アプリ自体はAWSでGCP周りはBigqueryだけ使っている
![イメージ図](bq_sushi.png)

---

## **RedshiftやEMRに行かなかった理由**
- ストレージコスト (Redshift)
- 構築コスト (EMR)
- 分散キーの設計負荷
- データ量が中途半端

Bigqueryはイニシャルコストがほぼ0なので試し易い

将来的にはそちらに移行することもあり得る

---

## **現在の使い方**
- 日次・週次・月次のバッチ集計処理
- google-api-ruby-clientを自前のRubyクラスでラップ
- SQLのテンプレートをerbで書いてジョブを投入。基本は結果を待ち受ける。
- 実行はRundeckでトリガーし、細かい依存は[Rukawa](https://github.com/joker1007/rukawa)で制御
  - Rukawaは自作のワークフロー管理ツール
  - LuigiとかAirflowをもっと単純にしてRubyにしたもの
  - 分散処理とかは考えてない
  - Rakeで制御するのは辛い

---

## **実行主体はこんな感じ**

```ruby
module Bigquery
  module QueryJobs
    class CalculationJob1 < Base
      self.template_name = "calculation_job_1"
    end
  end
end
```

```sql
-- calculation_job_1.sql.erb
SELECT id, COUNT(*) FROM <%= table_name %> GROUP BY id
```

---

## **Rukawaの例**

```ruby
module Workflow
  class CalculationJob1 < Rukawa::Job
    def run
      Bigquery::QueryJobs::CalculationJob1.run_with_wait(
        {table_name: "foo"},
        destination_table_name: "foo_count"
      )
    end
  end
end
```

---

## **Rundeckの辛い点**
- アプリ上のコードとジョブの起動部分が乖離する可能性がある
- スクリプトのバージョン管理がやり辛い (できなくはない)
- ジョブの並列実行、Joinして待ち受けができない

というわけで、今の所集約スケジューラとして利用

---

## **その他やっていること**
- Railsアプリのidの扱いを改修
  - Railsは基本的にIDが連番
  - RDBにインサートしないと各項目との関連が決定できないのは辛い
  - 基本的に処理はRailsアプリから独立させている
- google-api-client gemを直す
  - 割とバグとか機能不足を踏む
  - タイムアウト値が上書きできないとか……
  - 困る箇所は直したので、今ならそんなに問題無いと思う

---

## **BQ雑感**
- ウインドウ関数が割と揃ってる
- UNIONはめっちゃ早い
  - けどやり過ぎるとbillingTierが上がる
- CASE式でカラムに転換するようなクエリは遅い
- REPEATED型便利
- NEST関数をトップレベルで使いたい
  - 今仕方なくUDFを使っている
- Queryがテーブルに書き出す時にスキーマ指定したい
  - 全部NULLABLEは微妙
  - 今仕方なくUDFを使っている
- flattenResultsをfalseにすると場合によって変な挙動をする
- テーブル分割は大事

---

# **fluentd x embulkによるデータ転送**

---

## **基本はfluentd**
- fluent-plugin-bigquery-custom
  - オリジナルを自分でforkして改造
  - 日付毎にテーブルを分ける
- file bufferに溜めて一定間隔でLOAD

---

## **embulkの利用**
- embulk-output-bigquery
  - 更新があるデータの再投入
  - テーブル追加時の過去データ投入
  - データの洗い替え
- embulk-input-gcs
  - 集計結果のインポート
- configファイルの生成を支援する仕組みを用意
  - [yaml\_master](https://github.com/joker1007/yaml_master)というyaml生成ツールを自作
  - 一つのmaster.ymlから個別の設定を書き出す
  - 認証情報の一元管理
  - ERBを間に噛ませるのでliquidよりは自由

---

## **fluent-plugin-bigquery-custom**
### **本家マージ済み**
- time sliced方式を採用
- load方式に対応 (未リリース)

--------

### **本家にはない**
- ignoreUnknownValues etcに対応
  - エラーハンドリングの向上
- templateSuffixに対応
- loadジョブでもtemplateSuffixもどき
  - これでスキーマを変更できる (後述)

---

## **実は本家のメンテナもやってます** :smile:
fluent-plugin-bigqueryにじわじわ還元中

本当は一本化したいんだけど、割とアグレッシブに変えたので……。

---

## **スキーマの管理**
- BigQuery側にベースのテーブルを作る
- fluentdもembulkもそこからスキーマを取得する
- 大本の定義はソースコードと共に管理
- 変更が必要な時
  1. fluentdのペイロードを修正する
  1. ベースのテーブルを作り直す
  1. ignoreUnknownValuesで無視する
  1. 日次で新規にテーブルが作られる時にベースから新スキーマを参照する

---

## **embulk-output-bigquery**
必要な機能をいくつかPR

- 羃等な投入を可能にするmode
  - delete\_in\_advance
  - replace
  - replace\_backup
- スキーマ管理のためtemplate_tableオプションの追加
- 並列処理時のアップロードを高速化

---

## **embulk-output-bigqueryの今**
sonots先生により、JavaからJRubyにガツっと書き変わった。

なので、Rubyが書けるとカスタムし易い

---

# **その他の開発Tips**

---

## **ユニットテスト用のデータの投入**
拙作の[bq\_fake\_view](https://github.com/joker1007/bq_fake_view)というgemを使っている

BQのUNIONの速さを利用して、RubyのHash in Arrayなデータ構造を

一行づつ静的なSQLに変換し、viewとしてBigquery上に定義する

---

## **メリット**
- ストリーミングインサートのコスト不要
- Loadと違って即クエリ可能
- 事前にテーブルを準備する必要もない

テストが終わったらdata\_setごと削除して作り直す

----

## **デメリット**
- テーブルとviewでは完全に同じというわけではないらしい
  - カラムの参照ルールが微妙に違う
  - テーブル名を省略するとエラーになったり
- 大量のデータには向かない
  - UNIONで無茶してるので :sweat_smile:

---

## **開発データの投入**
自動expireするdata\_setを作って、embulkで投入

Rukawaにパラメーターを渡して実行すると投入できるようにしている

---

## **集計結果の受け取りが課題**
BQ上での集計結果をアプリ側に戻す必要がある

- GCSにexportしてからembulkで取得する
  - CPU数上げれば並列できる
  - 最悪EMRでMapReduce Executorが使える？
- 集計結果のストアがRDBだとそろそろ辛い
  - DynamoDBの検討
  - ElasticSearchの検討

知見ある人が居たら、教えてください

---

## **まとめ**

- BQは安いし早いし楽
  - 時々ハマったりクエリ刺さったりするけど
- REPEATED型もうちょっと使い易くしてください :bow:
- スキーマがもうちょっと変え易ければ :bow:
- ワークフロー管理エンジンは何かしら必要
  - Ruby製はあんまり手頃なのが無かった
- fluentdとembulkとgoogle-api-client、大分整備したので使えるよ
  - custom版は早く本家に還元します…… :sweat:

