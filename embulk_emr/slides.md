# EmbulkをEMRで実行しスケーラブルにする

@joker1007 (Repro.inc)

---

## self.inspect

- joker1007
- Repro.inc CTO
- 最近はバッチ処理基盤を弄っていることが多い
- embulk plugin作ったり、fluentd pluginのメンテナやったり
  - embulk-filter-ruby_proc
  - embulk-parser-avro
  - fluentd-plugin-bigquery

---

## Embulk
- TD社製のバルクローダツール
- JavaとJRubyで書かれている
- プラグイン機構 (JavaかRubyで書く)
- Hadoopで実行できる <- これの話

---

## Hadoop上での実行方法

```yaml
exec:
  type: mapreduce
  config_files:
    - /etc/hadoop/conf/core-site.xml
    - /etc/hadoop/conf/hdfs-site.xml
    - /etc/hadoop/conf/mapred-site.xml
  config:
    fs.defaultFS: "hdfs://my-hdfs.example.net:8020"
    yarn.resourcemanager.hostname: "my-yarn.example.net"
    dfs.replication: 1
    mapreduce.client.submit.file.replication: 1

in:
  # ...

out:
  # ...
```

---

## ざっくり仕組み

- Javaで普通にHadoopのMapReduceジョブを定義している。
- 基本的にはMapジョブで各ノードでEmbulkを実行している。
- EmbulkはJavaプログラム上で直接実行できるAPIがある。
- 再分散をしない場合はinput taskの数がそのまま並列数になる
- 現時点で再分散は時間データによるパーティショニングのみ

---

```java
```

---

## EMRで実行するために

- Hadoopのバージョンに注意
- EMR上のHadoop config fileを利用できる
- 一部の設定はオーバーライド必須
- ロガーの調整
- バッチへの組込み方

---

## Hadoopバージョン
現時点でHadoop YARN-2.6.0向けに構築されてる。
2.7系だとログが上手く吐けなくてエラーになった。
解決方法はあるかもしれないが、自分では分からなかった。

---

## configの例

`config_files`で基本的なEMR上のYARNの設定を引っ張ってくる。
`config`で必要な設定をオーバーライド

```yaml
exec:
  type: mapreduce
  config_files:
    - /etc/hadoop/conf/core-site.xml
    - /etc/hadoop/conf/hdfs-site.xml
    - /etc/hadoop/conf/mapred-site.xml
    - /etc/hadoop/conf/yarn-site.xml
  config:
    mapreduce.task.timeout: 72000000
    mapreduce.map.speculative: false
    mapreduce.map.memory.mb: 2560
    mapreduce.reduce.memory.mb: 16
    mapreduce.map.java.opts: -Xmx1792m
    mapreduce.reduce.java.opts: -Xmx16m
```

---

## config解説

- timeoutを伸ばす
  - デフォルトのタイムアウト(10分)だと短か過ぎる
  - 再分散を行わないとMapジョブだけで処理するので、Hadoopが処理が進んでいないと判断する
- 投機的実行を無効にする
  - EmbulkはMapReduceジョブの終了ステータスを無視する
  - 自身でステートファイルを書き出して終了ステータスを判断する
  - 投機的実行で、一部ジョブが強制終了するとそれをエラーと報告する
- 再分散を行わない場合はmap側にメモリを振り分ける
  - Reduce側はダミーなのでメモリが無駄になる

---

## 追加jars

```yaml
exec:
  type: mapreduce
  config_files:
    # ...
  config:
    # ...
  libjars:
    - /home/hadoop/.m2/repository/ch/qos/logback/logback-core/1.1.3/logback-core-1.1.3.jar
    - /home/hadoop/.m2/repository/ch/qos/logback/logback-classic/1.1.3/logback-classic-1.1.3.jar
  exclude_jars: [log4j-over-slf4j.jar, log4j-core-*, slf4j-log4j12*]
```

その他、プラグインが必要とする依存関係がちゃんと解決されてない場合があるので別途追加しておく必要がある。

---

## 追加jars解説

- embulk本体がlogbackの実装に直接依存している
  - (これあんま良くないんじゃないか)
- EMR上のHadoopはslf4j-log4jを使ってる様でlogback持ってない
  - ログ吐けなくて死ぬ
- loggerの実装選択で競合しない様にexcludeで調節する必要があるかもしれない
  - 自分は適当にそれっぽいのをexcludeしたら一応動作したが本当に必要かは未検証

---

## バッチの実行方法

- 自作のワークフロー管理gemを利用
- embulkをEMR上で実行する処理を自動化するgemを作成

---

## emrakul

- EMRのAPIを叩いてクラスタを起動
- sshkitを利用してマスターノードに接続
- マスターノードにembulkとGemfileを転送
- プラグインのインストール
- 追加でスクリプトを実行する
  - mavenで依存対象のjarをDLする
  - S3から追加で必要な認証情報を取得
    - KMSで暗号化済み
- マスターノード上でembulkを実行
  - ログはsshkitで出力 + YARNマネージャーで確認
- 終了したらクラスタを落とす

---

## Tips

- 時間軸でパーティションしない場合は、一回embulkを噛まして入力ファイルを事前に分割する
- 直接HDFSに書き込むのは、今のところEMRでは難しい、S3を入出力の場所に使うのが良い
