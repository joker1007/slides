# 令和時代のRails運用

## @joker1007

---

# self.inspect

- @joker1007
- Repro inc. CTO
- 最近は専らKafkaを触っており、実は余りRailsを触っていない。

という訳でインフラ寄りの話をします。

---

![repro_logo.png](repro_logo.png)
## から来ました。

---

# コンテナが一般化した現代のRails運用の話
弊社は3年以上前からproductionでのコンテナ運用を採用している。

---

# 話すこと
- コンテナに至るまでの歴史
- RailsのDockerイメージ作成 2020年版
- コンテナ化した時のベストプラクティス
  - 弊社で作ったgemの紹介

# 話さないこと
- コンテナとは何か
- k8s関連

---

# はじめに: インフラ管理の歴史を振り返る
何故コンテナが使われているのか

---

# 太古: 手順書

暖かみのある手作業での構築。
手順書に書かれていないことを実行すると怒られる。
流石にRailsの現場では見なかった。

---

# 古代: シェルスクリプト

手順書をスクリプトにまとめたもの。
メンテされている内は良いが、現状と乖離すると面倒なことになる。
既に構築済みのサーバを変更するには使えない。
手作業による変更を反映させて後の作業に利用するぐらい。

---

# 中世: chef, ansible等の構成管理ツール

DSLによるサーバの自動構成を行うツールを利用する。
構築後の変更もコードによって管理できる。
適用後の状態を安定に保つために、コードを羃等にする必要がある。
(何度適用しても同じ結果になる様にする)
Infrastracture as Codeの始まり。
しかし、羃等なコードを保つのがかなり難しい。
また、未知の状況から設定を作り込む負荷が高め。

---

# 近代: ゴールデンイメージ

クラウド環境が一般化し、インスタンスイメージとインスタンスを必要に応じて作り直すことが可能になった。
packer等のツールを使うことでイメージ構築を簡易化し常に0から作り直すことで、羃等性を意識しなくて良くなる。
インスタンスを容易に破棄出来る様になった。
Disposable Infrastractureの始まり。

---

# 現代: コンテナ

アプリケーションコードとミドルウェア等のサーバ構成のためのコンポーネントを丸ごとパッケージ化する。
VMより小さいオーバーヘッドで、いくつもアプリケーションを独立させて動かせる様になり、リソース効率が上昇。
アプリケーションに必要なインフラだけを管理すれば良くなり、手元の環境でproductionとほぼ同等の環境が再現可能に。
ゴールデンイメージより遥かにフィードバックのサイクルが早く、アプリケーションと一体で扱える。

---

# RailsのDockerイメージ作成 1

buildkitを使ったモダンなRailsアプリケーションイメージの構成方法を紹介する。

```
# syntax = docker/dockerfile:experimental
```

後述するマウントキャッシュの活用のため冒頭に記述しておく

---

# RailsのDockerイメージ作成 2

余計なレイヤーキャッシュ削除の工夫をしなくて済む様にnodejsはmulti stageビルドで入れる

```
# Node.jsダウンロード用ビルドステージ
FROM ruby:2.6.5 AS nodejs

WORKDIR /tmp

# Node.jsのダウンロード
RUN curl -LO https://nodejs.org/dist/v12.14.1/node-v12.14.1-linux-x64.tar.xz
RUN tar xvf node-v12.14.1-linux-x64.tar.xz
RUN mv node-v12.14.1-linux-x64 node
```

---

# RailsのDockerイメージ作成 3

```
FROM ruby:2.6.5

# nodejsをインストールしたイメージからnode.jsをコピーする
COPY --from=nodejs /tmp/node /opt/node
ENV PATH /opt/node/bin:$PATH

# アプリケーション起動用のユーザーを追加
RUN useradd -m -u 1000 rails
RUN mkdir /app && chown rails /app
USER rails

# yarnのインストール
RUN curl -o- -L https://yarnpkg.com/install.sh | bash
ENV PATH /home/rails/.yarn/bin:/home/rails/.config/yarn/global/node_modules/.bin:$PATH

# ruby-2.7.0でnewした場合を考慮
RUN gem install bundler
```

---

# RailsのDockerイメージ作成 4

```
WORKDIR /app

# Dockerのビルドステップキャッシュを利用するため
# 先にGemfileを転送し、bundle installする
COPY --chown=rails Gemfile Gemfile.lock package.json yarn.lock /app/

RUN bundle config set app_config .bundle
RUN bundle config set path .cache/bundle
# mount cacheを利用する
RUN --mount=type=cache,uid=1000,target=/app/.cache/bundle bundle install && \
  mkdir -p vendor && \
  cp -ar .cache/bundle vendor/bundle
RUN bundle config set path vendor/bundle

RUN --mount=type=cache,uid=1000,target=/app/.cache/node_modules bin/yarn install --modules-folder .cache/node_modules && \
  cp -ar .cache/node_modules node_modules

COPY --chown=rails . /app

RUN --mount=type=cache,uid=1000,target=/app/tmp/cache bin/rails assets:precompile

#実行時にコマンド指定が無い場合に実行されるコマンド
CMD ["bin/rails", "s", "-b", "0.0.0.0"]
```

---

# コンテナ化した時の設定値の扱いについて

イメージ管理を簡単にするためには設定値をイメージに含めたくはない。
環境毎の差異は外部から注入するとイメージが一つで済む。

---

# 基本: 環境変数化

```
# database.ymlの例

production: &default
  adapter: mysql2
  encoding: utf8mb4
  charset: utf8mb4
  collation: utf8mb4_bin
  pool: 5
  timeout: 5000
  username: <%= ENV["MYSQL_USERNAME"] || "app" %>
  password: <%= ENV["MYSQL_PASSWORD"] || "password" %>
  host: <%= ENV["MYSQL_HOST"] || "127.0.0.1" %>
  port: <%= ENV["MYSQL_PORT"] || "3306" %>
```

---

# 環境変数の限界

秘匿情報をどこで管理するのかの問題は無くならない。
参照権限の管理も必要になる。

---

# KeyManagementService(KMS)の利用

AWSやGCP等のクラウド環境であればIAMと統合された暗号鍵管理の仕組みが利用できる。
アクセス権限がIAMで管理できるため、自分でマスターキー等を管理する仕組みが必要無い。

---

# S3にKMSで暗号化した設定ファイルを配置する

```
aws s3 cp --sse aws:kms --sse-kms-id <key-arn> configs/secretdata.yml s3://myapp-configs/secretdata.yml
```

---

# 起動時に秘匿情報を取得するラッパー

```
#!/bin/bash

set -xe

# AWSはファイルのメタデータとして暗号化情報を記録してあるため、何も指定せずに復号化しつつ取得できる
# 鍵に対するアクセス権限が無ければ、エラーになる
aws s3 cp s3://myapp-configs/secretdata.yml configs/secretdata.yml

# execを経由してプロセスを丸ごとRailsのものに置き換える
# シェルの子プロセスとして起動してしまうとシグナルの管理が煩雑になる
exec bin/rails s -b 0.0.0.0
```

---

# Parameter Storeの活用

AWSならKMSと連携したParameter StoreやSecure Managerが利用できます。
自分は起動時にAPIを叩いて環境変数に設定するラッパーツールを書いたりしました。
https://github.com/joker1007/prmstore-exec

---

# ログ出力とエラー管理

コンテナを活用する様になると基本的にサーバにログインしたりローカルストレージを利用することは非推奨になります。
コンテナが状態を持つとDisposableでは無くなります。
なので、ログ出力をどこに出すか考える必要があります。

---

# Logging Driver

Dockerのログドライバはコンテナアプリケーションの標準出力、標準エラー出力からログを読み取ります。
なので、Railsのログを標準出力に出せる様にしておく必要があります。

```ruby
# config/environments/production.rb

# 省略

# Prepend all log lines with the following tags.
# config.log_tags = [ :subdomain, :uuid ]

config.logger = ActiveSupport::Logger.new($stdout)
$stdout.sync = true # syncを有効にしないと、バッファリングされてログが一定量溜まらないと出力されない
```

---

# 最終出力先

cloudwatch logs等のログ管理サービスを利用するのが現代的。
Kibanaを活用するためにElasticSearchに転送することもある。
弊社ではfluentdのログドライバを使ってfluentdの集約サーバに転送し、そこからS3やpapertrail等に転送している。

---

# エラートラッキング

エラートラッキングのためのツールは以前から活用されてきたが、最近は自前でホストするより外部サービスに頼るケースが多い。
sentryやrollbar等が流行っている印象がある。

---

# デプロイ

コンテナとオーケストレーションサービスが一般化し、SSHでファイルを転送するという形式ではなくなった。
イメージをリポジトリに登録しておき、デプロイはオーケストレーションのAPIを叩いたり、k8sの設定を変更するという形になった。
弊社ではECSを利用しているのでcapistranoのプラグインを自作してデプロイとイメージビルドをcapコマンドに統合した。
https://github.com/reproio/capistrano-dockerbuild
https://github.com/reproio/ecs_deploy

---

# 運用コマンド実行

利用しているオーケストレーションサービスに依って詳細は異なるが、APIを叩いて特定のコンテナイメージにコマンド引数を渡し起動することは大抵可能である。
弊社の例だと、ECSを利用しているのでタスク定義の更新、APIリクエスト、ログ出力のpolling、結果の取得までを自動でやってくれるgemを作って運用している。
https://github.com/reproio/wrapbox

AWSだとFargteを利用することで、必要になった時だけリソースを確保してコマンド実行が可能になった。
現在はバッチ処理の実行等で活用している。

---

# テストの並列実行

コンテナ化の恩恵としてテストを並列実行することが容易になった。
先に紹介したgemの様な任意のコマンドをオーケストレーションクラスタで実行するツールがあれば、引数をコントロールするだけで任意の並列数でテストが実行可能になる。
テスト実行の単位ごとにRDBを分けるのも容易い。
弊社ではFargate Spotを使って32並列でテストを実行している。

---

# 最後に宣伝
今日話した様な内容も含んだRails本、パーフェクトRailsの第二版が著者陣により執筆中です。
まだ発売日は未定ですが、近日発売できると良いなあという状況です。
発売されたらよろしくお願いします。
