# Professional Rails on ECS

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
- インフラは大体コード化済み
- Ruby biz Grand prix 2017 最終選考対応企業

---

# We are hiring

- 複雑なRailsごりごり書きたい人
- DBパフォーマンスに敏感な人
- BigqueryやPresto等の分散クエリエンジンを触りたい人
- コード化されたインフラの快適度を更に上げたい人

色々と仕事あります！

---

割とコンテナ周りは色々と発表した。
2017年末ってことで1年ぐらいの成果を総括して話をします。

---

# ECSとは

- Dockerコンテナを稼動するためのクラスタを管理してくれるサービス
- 使えるリソースを計測し、自動でコンテナの配置先をコントロールしてくれる
- kubernetesではない。最近、kubernetesが覇権取った感があって割と辛い
- 今はEC2が割とバックエンドに透けて見えるのだが、Fargateに超期待

---

# RailsアプリのDockerize

オススメの構成

- 実際にデプロイするimageは一つにする
  - 例えばstagingやproduction等のデプロイ環境の違いはイメージでは意識しない
- 手元で開発する様のDockerfileは分ける
  - ディレクトリマウントやテスト用コンポーネントのインストール等のため

---

```
FROM 113190696079.dkr.ecr.ap-northeast-1.amazonaws.com/repro/base:ruby-2.4.2-node-8.1.2-yarn-1.2.1-debian-rev1

ENV DOCKER 1

# install os package
RUN <package install>

# install yarn package
WORKDIR /root
COPY package.json yarn.lock /root/
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
RUN ln -sf /root/node_modules /app/node_modules && \
  mkdir -p vendor/assets tmp/pids tmp/sockets tmp/sessions && \
  cp config/unicorn/docker.rb config/unicorn.rb

ENTRYPOINT [ \
  "prehook", "ruby -v", "--", \
  "prehook", "ruby /app/docker/setup.rb", "--" ]

CMD ["bundle", "exec", "unicorn_rails", "-c", "config/unicorn.rb"]

ARG git_sha1

RUN echo "${git_sha1}" > revision.log
ENV GIT_SHA1 ${git_sha1}
```

---

# docker build
- circleCI 2.0とか使うのはお手軽
- キャッシュでハマる様ならビルドサーバーを用意する

---

# assets:precompile
RailsのDocker化における鬼門

- S3 or CDNを事前に整備しておくこと
- ビルド時に解決するがビルド自体とは独立させる
- docker buildした後で、docker runで実行する

---

ビルドサーバーのボリュームをマウントし、assets:precompileのキャッシュを永続化する
キャッシュファイルが残っていれば、高速にコンパイルが終わる。
管理が楽でストレスも余り無い。
ついでにmanifestをRAILS_ENV毎にrenameしてS3に保存しておく。
この時、コミットのSHA1を名前に含めておく。build時にargでふよ

```ruby
execute(:docker, "run --rm -e RAILS_ENV=#{fetch(:rails_env)} -e RAILS_GROUPS=assets -v #{fetch(:docker_build_base_dir)}/tmp:/app/tmp #{fetch(:docker_tag_full)} rake assets:precompile assets:sync assets:manifest_upload")
```


---

# prehook

ENTRYPOINTで強制的に実行する処理で環境毎の差異を吸収する。

- ERBで設定ファイル生成
- 秘匿値の準備
- assets manifestの準備
  - さっきRAILS_ENV毎に名前付けてuploadしてたのをDLしてくる

---


