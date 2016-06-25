# **RailsアプリをECSで本番運用するためのStep by Step**

[@joker1007](https://github.com/joker1007)

---

## self.inspect
- @joker1007
- パーフェクトRuby, パーフェクトRails 著者
- Asakusa.rb, Yokohama.rb, Shibuya.rb
- fluent-plugin-bigqueryメンテナ
- (株)Repro

---

## **Repro**

---

## **現在のECSの活用状況**
- 主要システムはほぼECSに移行完了
- クラスタは基本で15台  
ASでその倍から3倍ぐらいまで増える
- 開発者用ステージング、QA環境等にも利用

---

## **何故ECS化したのか**

- ミドルウェアのバージョン管理の容易さ
  - Ruby, nginx, fluentd ...
  - TaskDefinitionのリビジョンでロールバックできる

- 無停止デプロイメントの簡易化
- AutoscaleのためのAMI管理不要
- pull型のデプロイアーキテクチャ
- CentOS6ェ……

---

## **現実に必要なこと**
- コンテナイメージデザイン
- 各環境の管理 (staging, QA, production)
- デプロイ、ロールバックスクリプト
- ロギング
- メンバーへの展開
- Autoscale
- 移行 (今日話さない)

---

## **RailsアプリのDockerイメージ**
- 各環境毎の設定をどう管理するか
  - 起動時に外部から取得する
  - 全環境分を管理対象に含める
- 非同期処理のワーカーをどうするか
- assets:precompile

---

## **全環境を管理対象に含める**
- リポジトリ自体の管理を楽にする
- 秘匿情報をどう扱うか
  - KMSで暗号化して起動時に複合化して読み込む
  - ECSならIAMロールで複合化権限を管理できる
  - [yaml_vault](https://github.com/joker1007/yaml_vault)
  - ファイルとして持っておきたいものもS3に暗号化して配置

---

## **Entrypoint**
- いくつかの起動モードを切り替えられるようにしておく
  - アプリケーションプロセス
  - 非同期処理のWorkerプロセス
  - Rakeの実行

- TaskDefinitionの定義時や[EntryKit](https://github.com/progrium/entrykit)で調整
- graceful stopが出来るようにsignal handlerを調整する
  - unicornはSIGTERMで即死するので要調整

---

## **assets:precompile**
- 全環境分のデータを事前に作成する
- assetファイル自体はイメージ構築時にS3に

---

## **1イメージで全環境対応のイメージが完成**

---

## **ビルドサーバーの構築**
- docker環境を各チームメンバーが持たなくて良い
- CIサービスでのデータキャッシュ管理に制約が多い
  - ビルドイメージやprecompileの結果をキャッシュする
  - docker cpでビルド後のイメージから結果を引っぱりだす
- capistranoで任意のコミットからイメージを作成できるようにする

---

## **デプロイスクリプト**
- 既存の運用と同じ使い勝手を実現する
- [ecs_deploy](https://github.com/reproio/ecs_deploy)
  - capistranoのタスクを定義するgem
  - ECSのAutoscaling機能込み (後述)

---

## **ecs_deployの挙動**
- 任意のコミットのSHA1を利用してdocker imageを特定
- TaskDefinitionをregister
- db:migrate等の即時実行タスクをECS上で実行
- serviceの定義を新しいTaskDefinitionで更新
- serviceの状態が収束するまで待ち受ける

---

## **デプロイの課題**
- デプロイ時にminimum healthy percent分の余剰ノードが必要
- でないとサービスが収束せずにタイムアウトする
- 自動でEC2のノードを伸縮させる仕組みが必要

---

## **ロギング**
- fluentd log driverを利用
- 最終的には[papertrail](https://papertrailapp.com/)に転送する
- 今ならcloudwatch logsが楽そう
- アプリケーションのエラーは[rollbar](https://rollbar.com)

---

## **メンバーへの展開と開発環境**
- docker自体に習熟していないメンバーも居る
- docker-composeで1発起動可能に準備
- 使いたくなった時にすぐ使えるように準備して、  
後は各自の習熟に任せる

---

## **Autoscale**
- TokyoリージョンにService Autoscaleが無い
- 雑に車輪を再発明
- cloudwatchアラームをpollingしてtask countを調節
- 設定はyamlから読み込む
- EC2のノード数も計算して同時にスケールさせる
- 正直、ちょっと虚しい……。
- Autoscaler自体もECS上で実行

---

## **Autoscaleの際の注意点**
- EC2ノードレベルでは何のコンテナが動いているか分からない
- 停止時に抱えたコンテナが停止しているとは限らない
- 複数のアプリを混ぜると巻き込まれる

---

## **得られた成果**
- デプロイ速度の向上
- ミドルウェアアップデートの仕組み
- Chefレシピを大幅に削減
- ゼロダウンタイム

---

## **Tips**
- 1プロセス1コンテナをちゃんと守る
  - ロギングや監視のやり易さ
- できるだけ直接コンテナを見なくて済むように
- ネイティブライブラリのコンパイルオプションに注意
  - marchオプションが指定されてるとポータビリティが……
- 環境変数を増やし過ぎないように工夫する

---

## **AWSへの要望**
- 監視に使えるメトリック増やして欲しい
- EC2のノード数を自動調整して欲しい。
- net=hostを使いたい

---

## **やっぱりコンテナ便利 :+1:**
