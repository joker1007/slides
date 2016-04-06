# fluentd x embulk x bigqueryで作るバッチ集計処理基盤

@joker1007

```ruby
p "hoge"
```

メインのバッチ集計処理基盤としてbigqueryを利用するために今取り組んでいること、
そしてそれを支えるfluentdとembulkのbigqueryプラグインの現状を解説します。

---

## 利用背景
- MySQLの限界
- 割とヘビーな集計
- 公平な算出

--------------

## 構成イメージ図
アプリ自体はAWSでGCP周りはBigqueryだけ使っている
![イメージ図](bq_sushi.png)

--------------

## RedshiftやEMRに行かなかった理由
- ストレージコスト (Redshift)
- 構築コスト (EMR)
- 分散キーの設計負荷
- データ量が中途半端

Bigqueryはイニシャルコストがほぼ0なので試し易い

将来的にはそちらに移行することもあり得る



## 現在の使い方
- 日次・週次・月次のバッチ集計処理
- google-api-ruby-clientを自前のRubyクラスでラップ
- SQLのテンプレートをerbで書いてジョブを投入。基本は結果を待ち受ける。
- 実行はRundeckでトリガーし、細かい依存はRakeで制御
  - 割とすぐに辛くなってきた
  - ワークフロー管理ツール検討中


## Rundeckの辛い点
- アプリ上のコードとジョブの起動部分が乖離する可能性がある
- スクリプトのバージョン管理がやり辛い (できなくはない)
- ジョブの並列実行、Joinして待ち受けができない


## その他やっていること
- Railsアプリのidの扱いを改修
  - RDBにインサートしないと各項目との関連が定義できないのは辛い
  - 最終的にはRailsアプリから独立できるように
- google-api-client gemを直す
  - 割とバグとか機能不足を踏む


## 雑感
- ウインドウ関数が割と揃ってる
- UNIONはめっちゃ早い
  - けどやり過ぎるとbillingTierが上がる
- カラムに転換するようなクエリは遅い
- REPEATED型便利
- NEST関数をトップレベルで使いたい
  - 今仕方なくUDFを使っている
- flattenResultsをfalseにすると場合によって変な挙動をする
- テーブル分割は大事


## fluentd x embulkによるデータ転送


## 基本はfluentd
- fluent-plugin-bigquery-custom
  - オリジナルを自分でforkして改造
  - 日付毎にテーブルを分ける
- file bufferに溜めて一定間隔でLOAD

## embulkの利用
- embulk-output-bigquery
- 更新があるデータの再投入
- テーブル追加時の過去データ投入

## fluent-plugin-bigquery-custom
### 本家マージ済み
- time sliced方式を採用
- load方式に対応 (未リリース)
### 本家にはない
- ignoreUnknownValues etcに対応
- templateSuffixに対応
- loadジョブでもtemplateSuffixもどき

## ちなみに本家のメンテナもやってます :smile:
fluent-plugin-bigqueryにじわじわ還元中
本当は一本化したいんだけど、割とアグレッシブに変えたので……。

## スキーマの管理
- bigQuery側にベースのテーブルを作る
- fluentdもembulkもそこからスキーマを取得する
- 大本の定義はソースコードと共に管理
- 変更が必要な時
  - ペイロードのカラムを増やす
  - ベースのテーブルを作り直す
  - ignoreUnknownValuesで無視する
  - 新規にテーブルが作られる時に変更後のベースのテーブルを参照する

## embulk-output-bigquery
必要な機能をいくつかPR
- 羃等な投入を可能にするmode
- スキーマ管理のためtemplate_tableオプションの追加
- 並列処理時にアップロードの高速化


## embulk-output-bigqueryの今
JavaからJRubyに書き直すPRがある


## RubyとJavaが書けるとカスタムし易い

## テストデータの投入
拙作のbq_fake_viewというgemを使っている
UNIONの速さを利用して、RubyのHash in Arrayなデータ構造を
一行づつ静的なSQLに変換し、viewとしてBigquery上に定義する

ストリーミングインサートのコスト不要、Loadと違って即クエリ可能。
事前にテーブルを準備する必要もない。

カラムの参照がテーブルとviewでは完全に同じというわけではないらしい。

テストが終わったらdata_setごと削除して作り直す

## 開発データの投入
自動expireするdata_setを作って、embulkで投入
embulkのコンフィグファイルは拙作のyaml_masterでパラメーター化して動的に生成する


## 集計結果の受け取りが課題
- embulk-input-bigqueryを作る？
- GCSにexportしてからembulkで取る
- 集計結果のストアもRDBだとそろそろ辛い

知見ある人が居たら、教えてください


