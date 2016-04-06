# Bigqueryとembulkとembulkプラグインの作り方

Tomohiro Hashidate
@joker1007



## 自己紹介
- @joker1007
- フリーランス
- Ruby/Railsを中心にした何でも屋みたいな
- 最近はBigqueryおじさん



## Bigqueryは「早い」「安い」「美味い」
でも、しばしばハマる
その辺の話はbq_sushiでやると思う



## Bigqueryにデータを投入する方法は二種類
- Load Job
- Streaming Insert



## RubyistにはBigqueryにデータを投入するための強力な道具がある
- fluentd-plugin-bigquery (Streaming Insert)
- fluentd-plugin-bigquery-custom (Streaming Insert, Load)
- embulk-output-bigquery (Load)



## embulk
TD社製のオープンソースバルクデータローダー

- 大量のデータを高速でロードする
- プラグイン機構
  - 様々なデータストアに対する読み書き
  - filter処理によるデータ加工
  - CSV, JSON, lined JSON等様々なフォーマット
  - JavaとJRubyどちらでもプラグインが書ける



## なぜembulkか
- プラガブルなので潰しが効く
- 大量のデータロード、加工、転送はCPU負荷が高い
- マルチスレッドによる並行処理が重要
- Ruby/Rails向いてない



## fluentdだけじゃ駄目な理由
- 初期データ投入
- 過去分の再投入
- 更新が発生するデータ
- バッチ処理の羃等性維持



## 自分が関係しているembulkプラグイン
- embulk-filter-ruby_proc
- embulk-output-bigquery (コントリビュート)
- embulk-output-influxdb



## Rubyで書く場合



## Javaで書く場合



## 現状ドキュメントが余り無い
ソースコードを読む必要がある
でも、Rubyのコードなら割と読めますよね？
Ruby製のプラグインのコードをパクる



## ちゃんと動作を理解したい場合
embulkのソースコードのここを読め

(現在Java7ベースでラムダが無いので読むのは多少辛い…)

- [BulkLoader.java](https://github.com/embulk/embulk/blob/master/embulk-core/src/main/java/org/embulk/exec/BulkLoader.java "embulk/BulkLoader.java at master · embulk/embulk") (処理の起点)
  - ここのdoRunの処理を追いかける
- [LocalExecutorPlugin.java](https://github.com/embulk/embulk/blob/master/embulk-core/src/main/java/org/embulk/exec/LocalExecutorPlugin.java "embulk/LocalExecutorPlugin.java at master · embulk/embulk") (どうやって各スレッドでタスクを実行しているか)

