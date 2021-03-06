# Professional Rails on ECS
### @joker1007

---

# self.inspect
- @joker1007
- Repro inc. CTO (要は色々やる人)
  - Ruby/Rails
  - fluentd/embulk
  - RDB
  - Docker/ECS ← 今日はこの辺
  - Bigquery/EMR/Hive/Presto

---

# Repro.inc について
- モバイルアプリケーションの行動トラッキング
- 分析結果の提供と、それと連動したマーケティングの提供
- 主にAWSでBigqueryだけGCP
- コンテナ化対応企業
- Ruby biz Grand prix 2017 最終選考対応企業

---

# We are hiring

- 複雑なRailsごりごり書きたい人
- DBパフォーマンスに敏感な人
- BigqueryやPresto等の分散クエリエンジンを触りたい人
- コード化されたインフラの快適度を更に上げたい人

色々と仕事あります！

---

# 割とコンテナ周りは色々と発表した。
# 2017年末ってことで1年ぐらいの成果を総括して話をします。
### (時間足りないかも……)

---

# ECSとは

- Dockerコンテナを稼動するためのクラスタを管理してくれるAWSのサービス
- 使えるリソースを計測し、自動でコンテナの配置先をコントロールしてくれる
- kubernetesではない。最近、kubernetesが覇権取った感があって割と辛い
- 今はEC2が割とバックエンドに透けて見えるのだが、Fargateに超期待
- ECS or EKS :tired_face:

---

# RailsアプリのDockerize

オススメの構成

- 実際にデプロイするimageは一つにする
  - 例えばstagingやproduction等のデプロイ環境の違いはイメージでは意識しない
- 手元で開発する様のDockerfileは分ける
  - ディレクトリマウントやテスト用コンポーネントのインストール等のため

---

```dockerfile
FROM ruby:2.4.2

ENV DOCKER 1

# install os package
RUN <package install>

# install yarn package
WORKDIR /yarn
COPY package.json yarn.lock /yarn/
RUN yarn install --prod --pure-lockfile && yarn cache clean

# install gems

WORKDIR /app
COPY Gemfile Gemfile.lock /app/
RUN bundle install -j3 --retry 6 --without test development --no-cache --deployment
```

---

```
# Rails app directory
WORKDIR /app
COPY . /app
RUN ln -sf /yarn/node_modules /app/node_modules && \
  mkdir -p vendor/assets tmp/pids tmp/sockets tmp/sessions && \
  cp config/unicorn.rb.production config/unicorn.rb

ENTRYPOINT [ \
  "prehook", "ruby -v", "--", \
  "prehook", "ruby /app/docker/setup.rb", "--" ]

CMD ["bundle", "exec", "unicorn_rails", "-c", "config/unicorn.rb"]

ARG git_sha1 # どのコミットなのか中から分かる様にする

RUN echo "${git_sha1}" > revision.log
ENV GIT_SHA1 ${git_sha1}
```

---

# docker build
- circleCI 2.0とか使うのはお手軽
- キャッシュでハマる様ならビルドサーバーを用意する
- https://github.com/reproio/capistrano-dockerbuild
  - capistranoを利用してリモートサーバーでdocker buildを行う
  - リポジトリへのpush等もサポートする

---

# assets:precompile
RailsのDocker化における鬼門の一つ

- S3 or CDNを事前に整備しておくこと
- ビルド時に解決するがビルド自体とは独立させる (イメージには含めない)
- docker buildした後で、docker runで実行する

---

- ビルドサーバーのボリュームをマウントし、assets:precompileのキャッシュを永続化する
- キャッシュファイルが残っていれば、高速にコンパイルが終わる
- manifestをRAILS_ENV毎にrenameしてS3に保存しておく
この時、コミットのSHA1を名前に含めておく。(build時にargで付与したもの)

```sh
docker run --rm \
  -e RAILS_ENV=<RAILS_ENV> -e RAILS_GROUPS=assets \
  -v build_dir/tmp:/app/tmp app_image_tag \
  rake \
    assets:precompile \
    assets:sync \
    assets:manifest_upload
```


---

# prehook

ENTRYPOINTで強制的に実行する処理で各デプロイ環境毎の差異を吸収する

- ERBで設定ファイル生成
- 秘匿値の準備
- assets manifestの取得
  - さっきRAILS_ENV、コミット毎に名前付けてuploadしてたのをDLしてくる

---

# 秘匿値の扱い (弊社の場合)
- 設定ファイル自体を暗号化してイメージに突っ込む
  - 普通にgitで管理できて楽
  - 環境変数で直接突っ込むとECSのconsoleに露出する
  - 値の種類が多いと環境変数管理する場所が結局必要になる
- コンテナ起動時に起動環境の権限で複合化する
  - prehookで複合化処理を行う

---

# yaml_vault
https://github.com/joker1007/yaml_vault

- Rails5で入った、encrypted secrets.ymlの拡張版
- Passphrase, AWS-KMS, GCP-KMSに対応している
- KMSを利用すると秘匿値にアクセスできる権限をIAMで管理できる
- クラスタに所属しているノードのIAM Roleで複合化
- 設定をファイルに一元化しつつ安全に管理できる
- Railsの場合、secrets.ymlをメモリ上で複合化して起動できる
  - ファイルに展開後の値が残らない

---

# 開発環境

## docker-composeとディレクトリマウントで工夫する

---

```yaml
version: "2"
services:
  datastore:
    image: busybox
    volumes: #ちゃんと永続化する場所を定義しておく
      - mysql-data:/var/lib/mysql
      - vendor_bundle:/app/vendor/bundle
      - bundle:/app/.bundle

  app:
    build:
      context: .
      dockerfile: Dockerfile-dev
    environment:
      MYSQL_USERNAME: root
      MYSQL_PASSWORD: password
      MYSQL_HOST: mysql
    depends_on:
      - mysql
    volumes:
      - .:/app # プロジェクトディレクトリをマウント
    volumes_from:
      - datastore
    tmpfs:
      /app/tmp/pids
```

---

# ちなみにMacの場合
- ボリュームマウントが死ぬ程遅いので、何らかの工夫が必要
- dinghyかdocker-syncで頑張る
  - どっちも辛い
- Mac捨てるのがオススメ
  - GentooっていうLinuxがあってだな……


---

# 俺の開発スタイル

- 開発用Dockerfileでzshや各種コマンドを入れておく
- `docker-compose run --service-ports app zsh`
  - 一回shellを挟むのはサーバープロセスの再起動のため
- シェルスクリプトで自分の.zshrcやpeco等を`docker cp`で突っ込む
- その後`docker exec zsh`でzshを起動して中に入る
- ファイルの編集だけはホストマシンで行い、後は基本的にコンテナ内で操作する

---

```sh
set -e

container_name=$1

cp_to_container()
{
  if ! docker exec ${container_name} test -e $2; then
    docker cp -L $1 ${container_name}:$2
  fi
}

cp_to_container ~/.zshrc /root/.zshrc
if ! docker exec ${container_name} test -e /usr/bin/peco; then
  docker exec ${container_name} sh -c "curl -L -o /root/peco.tar.gz https://github.com/peco/peco/releases/download/v0.4.5/peco_linux_amd64.tar.gz && tar xf /root/peco.tar.gz -C /root && cp /root/peco_linux_amd64/peco /usr/bin/peco"
fi

docker exec -it ${container_name} sh -c "export TERM=${TERM}; exec zsh"
```

---

# デプロイの解説の前に
# ECSの概念について少し

---

# TaskDefinition

- 1つ以上のコンテナ起動定義のセット
  - イメージ、CPUのメモリ使用量、ポート、ボリューム等
  - 物理的に同じノードで動作する
- docker-composeの設定一式みたいなもの
- kubernetesでいうPodに近い
- 単調増加するrevision番号でバージョン管理される

---

# Task

- TaskDefinitionから起動されたコンテナ群
- 同一のTaskDefinitionから複数セット起動できる

---

# Service

- Taskをどのクラスタでいくつ起動するかを定義する
- ECSが自動でその数になるまで、コンテナを立てたり殺したりする
- コンテナの起動定義はTaskDefinitionを参照する
- コンテナが起動したノードをALBと自動で紐付ける
- kubernetesにも似た概念がある

---

# ECSへのデプロイの基本

1. TaskDefinitionを更新しバージョン番号を上げる
1. Serviceを更新し、新しいバージョンを参照する
1. 後はECSに任せる

---

# ecs_deploy
https://github.com/reproio/ecs_deploy

- capistrano plugin
- TaskDefinitionとServiceの更新を行う
- Service更新後デプロイ状況が収束するまで待機する
- 更新したTaskDefinitionのrevisionを他のタスクで参照できる
- TaskDefinitionやServiceの定義はRubyのHashで行う
  - Hash化できれば何でも良いので、YAMLでもJSONでも

---

# Why use Capistrano

- 既存の資産が多数ある
  - slack通知のフックとか
- デプロイのコマンドが変化しない
- 一気にコンテナ化することは早々無いので並行運用が楽
- 設定ファイルの場所や定義も大きく変化しない

---

# 個人別ステージング環境へのデプロイ
コンテナ化すると簡単に開発者が好きに使えるデプロイ先が手に入る
- アプリサーバーだけで良いなら割と容易に実現可能
- RDB等のデータストアを個別に持つなら色々難しい
- 弊社はアプリサーバーだけ個別にデプロイ可能
- データストアを弄る場合はフルセットの環境を使い、そこを占有する

---

# インフラの準備
terraform等で以下のものを準備する

- ALBを一つ用意する
- 個人別のサブドメインをRoute53に定義
- ALBのTarget Groupを個人別に定義
- ALBのホストベースルーティングを定義して、各Target Groupに関連付け

その後capistranoにmemberという環境を定義し、各メンバーが自分の名前でtarget_ groupやTaskDefinitionの名前を使ってデプロイ出来る様に諸々を変数化する

Serviceの仕組みを使うことで、各々の開発者自分のデプロイ先を意識しなくてもノードが勝手にTarget Groupに所属してトラフィックが流れてくる

---

# terraformの例

<かなり長くなるので、後日貼ります>

---

# デプロイ定義の例

<同上>

---

# Autoscale (近い内に不要になる話)
Fargate Tokyoリージョンはよ！

- 現時点でECS ServiceのスケールとEC2のスケールは独立している
- Service増やしてもEC2のノードを増やさないとコンテナを立てるところがない
- 増やすのは簡単だが減らす時の対象をコントロールできない

というわけでデフォルトで良い方法がない。

---

# ecs_deploy/ecs_auto_scaler
https://github.com/reproio/ecs_deploy

- CloudWatchをポーリングして自分でオートスケールする :cry:
- Serviceの数を制御し、EC2の数はServiceの数に合わせて自動で収束させる
- スケールインの際は、コンテナが動作していないノードを検出して落とす
- コンテナが止まるまではEC2のノードは落とさない

---

```yaml
polling_interval: 60

auto_scaling_groups:
  - name: ecs-cluster-nodes
    region: ap-northeast-1
    buffer: 1 # タスク数に対する余剰のインスタンス数

services:
  - name: app-production
    cluster: ecs-cluster
    region: ap-northeast-1
    auto_scaling_group_name: ecs-cluster-nodes
    step: 1
    idle_time: 240
    max_task_count: [10, 25]
    # 続く
```

---

```yaml
    scheduled_min_task_count:
      - {from: "1:45", to: "4:30", count: 8}
    cooldown_time_for_reach_max: 600
    min_task_count: 0
    upscale_triggers:
      - alarm_name: "ECS [app-production] CPUUtilization"
        state: ALARM
    downscale_triggers:
      - alarm_name: "ECS [app-production] CPUUtilization (low)"
        state: OK
```

---

# ecs_auto_scaler自体もコンテナに
- ecs_auto_scalerはシンプルなforegroundプロセス
- 簡単なDockerfileでコンテナ化可能
- こいつ自身もECSにデプロイする

---

# まあ、Fargateで不要になると思う :tired_face:

---

# コマンド実行とログ収集
ECSにおいて特定のノードにログインするというのは負けである
rails runnerやrakeをSSHで実行とかやるべきではない
コンテナ外にそういう場所を用意するのもダサい
そのサーバーの構成管理をしなければならなくなる

---

# wrapbox
https://github.com/reproio/wrapbox

- ECS用のコマンドRunner
  - 半端に素のdockerとの汎用性を持たせようとしたんでコードが微妙に……
- TaskDefinitionを生成、登録し、即タスクを起動する
- 終了までステータスをポーリングし待機する
- タスク起動権限はIAMを使ってクラスタ単位で管理できる
- 慣れるとSSHとかデプロイが不要だし、権限管理が固いのでむしろ楽

---

config
```yaml
default:
  region: ap-northeast-1
  container_definition:
    image: "<ecr_url>/app:<%= ENV["GIT_SHA1"]&.chomp || ENV["RAILS_ENV"] %>"
    cpu: 704
    memory: 1408
    working_directory: /app
    entry_point: ["prehook", "ruby /app/docker/setup.rb", "--"]
    environment:
      - {name: "RAILS_ENV", value: "<%= ENV["RAILS_ENV"] %>"}
```

実行例
```
GIT_SHA1=`git rev-parse HEAD` RAILS_ENV=dev_staging \
  be wrapbox ecs run_cmd -f config/wrapbox.yml \
    -c repro-development --cpu=1024 --memory=2048 \
    "bundle exec ./bin/embulk_runner users_to_bigquery"
```

設定とイメージファイルを工夫することで、任意のコミットの状態でコマンドを実行できる。

---

# wrapboxで実行したコマンドログの取得

- papertrailにログを転送し、別スレッドでポーリングしてコンソールに流すことができる
- 原理的に他のログ集約サービスでも実現可能だが、現在papertrailしか実装はない

---

config
```
default:
  # 省略
  log_fetcher:
    type: papertrail # Use PAPERTRAIL_API_TOKEN env for Authentication
    group: "<%= ENV["RAILS_ENV"] %>"
    query: wrapbox-default # syslogのタグと揃える
  log_configuration:
    log_driver: syslog
    options:
      syslog-address: "tcp+tls://logs.papertrailapp.com:<port>"
      tag: wrapbox-default
```

---

# db:migrate

capistranoのhookを利用しwrapboxで実行する

```ruby
def execute_with_wrapbox(executions)
  executions.each do |execution|
    runner = Wrapbox::Runner::Ecs.new({
      cluster: execution[:cluster],
      region: execution[:region],
      task_definition: execution[:task_definition]
    })
    parameter = {
      environments: execution[:environment],
      task_role_arn: execution[:task_role_arn],
      timeout: execution[:timeout],
    }.compact
    runner.run_cmd(execution[:command], **parameter)
  end
end

desc "execution command on ECS with wrapbox gem (before deployment)"
task :before_deploy do
  execute_with_wrapbox(Array(fetch(:ecs_executions_before_deploy)))
end
```

---

```ruby
set :ecs_executions_before_deploy, -> do
  # ecs_deployの結果からTaskDefを取得
  rake = fetch(:ecs_registered_tasks)["ap-northeast-1"]["rake"]
  raise "Not registered new task" unless rake

  [
    {
      cluster: "app",
      region: "ap-northeast-1",
      task_definition: {
        task_definition_name: "#{rake.family}:#{rake.revision}",
        main_container_name: "rake"
      },
      command: ["db:ridgepole:apply", "before_release:validate"],
      timeout: 600,
    }
  ]
end
```

---

# db:migrate -> ridgepole
- migrateのupとdownがめんどい
 - 特に開発者用ステージング
- ridgepoleならデプロイ時に実行するだけで、ほぼ収束する
- エラーが起きたらslackにログを出して、手動で直す
- productionはそもそも自動適用を止めた
- diffがあればリリースを停止させる
- diffを見てリリース担当者(俺ともう一人)が手動でDDLを発行する

---

# テストとCI
以下を参照。
https://speakerdeck.com/joker1007/dockershi-dai-falsefen-san-rspechuan-jing-falsezuo-rifang

---

# 長々と色々と解説しましたが、
# コンテナを真面目に運用するためには、結構色々考えることがあります
# 何かしら参考になれば幸いです
