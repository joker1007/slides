# プラグイン開発者から見るv1.0の活用法

### @joker1007

---

## self.inspect

- Repro inc. CTO
- やってること
  - DBのスキーマ改善、データ仕様の変更
  - fluentdを中心にしたデータフローの設計構築
  - Bigqueryやhive, prestoを使ったバッチフローの設計構築
  - インフラのコード化とメンテ
  - Docker, ECSの利用環境を整備

---

## 狩人業
8年ぶりぐらいに狩人になりました。(1日の時間が足りない!)

---

## fluentdとの関わり
- 一昨年ぐらいから社内でデータフローを構築する基盤として採用。
- それまでは余り触ってなかった
- ちょうど0.14が出たぐらいの時期
- 主にアプリデータをBQとS3に転送するために利用している
- 0.14には比較的早めにアップデートして利用を開始、現在1.0.2。

---

## プラグイン開発とメンテナ業
使い始めると色々と不満が出てくるので、PRを出したり自分で作ったりすることになる。
割とメンテを諦めているプラグインがいくつかあるので、PRを何度か出した上で、話をしてコミット権を頂くことになったものがいくつかある。

- fluent-plugin-cloudwatch-put (作者)
- fluent-plugin-filter-single_key (作者)
- fluent-plugin-bigquery (メンテナ)
- fluent-plugin-remote_syslog (メンテナ)
- fluent-plugin-dd (メンテナ)

その他、PR出したりしたものがいくつか。

---

## fluent-plugin-bigquery
メインで触る人が転々と移り変わって、今私が良く弄っている。

- いかつい
- 複雑
- 総ダウンロード数が多い

開発する上で知見をいくつか獲得

---

## v1.0(v0.14)の利点
### parser, formatter, bufferが明確に分離されたconfigセクションとして独立したこと
今迄、inputやoutputプラグインの中でフラットに設定が記述されていて、標準的なやり方が無かった。
v1.0になることで、それらを選択設定する方法が確定したので、各プラグインに対するポータビリティがめっちゃ向上した。
filterで頑張って加工しなくても、データの入出力に任意のフォーマットを利用できる様になった。

---

## プラグイン開発者がやるべきこと
独自のパース処理やフォーマット処理ではなくplugin helperを利用する

```ruby
formatter_config = conf.elements("format")[0]
@formatter = formatter_create(
  usage: 'out_bigquery_for_load',
  conf: formatter_config,
  default_type: 'json'
)
```

```ruby
def format(tag, time, record)
  @formatter.format(tag, time, row)
end
```

---

## v1.0のoutputプラグイン開発
最も大きく機能が変わったのがoutputプラグインのAPI

- metadataを利用したchunkをサポート
- これによりTimeSlicedの区別が無くなる
- delay commitのサポート
- chunk_limit_recordsのサポート

これに加えて各種プラグインヘルパーにより開発がとても楽になった。

---

## chunk with metadata
v1.0からmetadataをキーにしてbuffer chunkを分けられる様になった。
metadataとは以下のものを差す。

- tag
- time
- recordのproperty

そして、キーに利用したメタデータはconfig上でplaceholderとして利用可能になる。

---

## fluent-plugin-bigqueryの例

```
<match bq.{http_logs,app_logs}>
  @type bigquery

  table   ${tag[1]}$%Y%m%d
  schema_path schemas/${tag[1]}.json

  <buffer tag, time>
    timekey 1d
  </buffer>
</match>
```

---

## プラグイン側の対応方法
`placeholder_validate!`と`extract_placeholders`を利用する

```ruby
placeholder_params =
  "project=#{@project}/dataset=#{@dataset}/table=#{@tablelist.join(",")}/fetch_schema_table=#{@fetch_schema_table}/template_suffix=#{@template_suffix}"
placeholder_validate!(:bigquery, placeholder_params)
```

```ruby
project = extract_placeholders(@project, chunk.metadata)
dataset = extract_placeholders(@dataset, chunk.metadata)
```

---

## metadataとplaceholderによりforestプラグインが不要になる
## ただし、どの項目でplaceholderが利用できるかはプラグインの対応状況によって変わる

---

## helperによるデータ加工方法の共通化
よく利用する処理がplugin helperとして再利用可能になり、configの項目も標準化されたため、プラグインでのデータ加工が簡単になった。
利用しやすいものは以下。

- extract (レコードからタグや時間として利用するものを抽出する)
- inject (レコードにタグやタイムスタンプ等のメタデータを注入する)
- record_accessor (レコードの中のデータを文字列のフォーマットを利用して取得する)

これらを利用することで、プラグイン独自に対応しなければいけない範囲はかなり少なくなる

---

## 新しいプラグインのAPIを利用することで、かつて利用されていたmixinモジュールの大半は不要になり、似た設定や実装が氾濫することがなくなる

---

## その他、プラグイン開発で意識しておくこと

- 多機能化はダメ絶対！
  - fluent-plugin-bigqueryは悪い例
- 本体に組込みのhelperやその組み合わせで解決できないか考えること
  - threadや子プロセスを利用する場合のハンドリング等
- 無理にマルチバージョンサポートをしない
  - 0.12系はそろそろ機能追加等を打ち切って良い
- どうにもメンテできない場合は、人に譲る

---

## v1.0は便利！
## まだ0.12系を利用しているなら、頑張って上げる価値がある
## 特にプラグイン自体の構造をシンプルに維持したまま柔軟性を上げられる点が大きい
## 自分のプラグインの改修や、PRを出すチャンスも
