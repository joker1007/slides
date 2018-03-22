# Realworld Domain Model on Rails
### @joker1007

---

# self.inspect
- @joker1007
- Repro inc. CTO (要は色々やる人)
  - Ruby/Rails
  - fluentd/embulk
  - RDB
  - Docker/ECS
  - Bigquery/EMR/Hive/Presto

最近、kafkaを触り始めました

---

# Rubykaigi 2018 登壇予定
tagomorisさんと共同でTracePointを中心にした黒魔術テクニックの話をする予定です。
お楽しみに！

---

# Repro.inc について
- モバイルアプリケーションの行動トラッキング
- 分析結果の提供と、それと連動したマーケティングの提供
- コンテナ化対応企業
- Ruby biz Grand prix 2017 特別賞

---

# We are hiring

- 複雑なRailsごりごり書きたい人
- データ量の多いサービスに興味がある人
- DBパフォーマンスに敏感な人
- BigqueryやPresto等の分散クエリエンジンを触りたい人
- コード化されたインフラの快適度を更に上げたい人

色々と仕事あります！お声がけください！

---

# 本題

---

# この話のテーマ

継続してアプリケーションを改善し続けるためにDDDという概念を知ることは有用だと思う。
しかし、RailsはWebの開発効率に特化したフレームワークであり、相性が悪い点が多々ある。
一方で、現実にはRailsでかなり複雑な業務を表現しなければならないケースも増えてきている。
Railsにおいて、現実的でかつ複雑なアプリに耐えうるモデルの表現方法を考えてみたい。

---

# Railsの基本構成要素
- Model
- View
  - Helper
- Controller
- Job

それぞれが何であり、どういう捉え方をするべきか改めて復習しておこう

---

# Model
アプリケーションロジックの本体。
業務に関する概念を定義し振舞いを表現する。
Railsにおいて全ての中心。

---

# View
アプリケーションの出力を表現する。
出力先はHTTPである。
HTMLに限らず、JSONやCSV等出力を表現するものはViewである。

---

# Controller
アプリケーションの入力に対するインターフェース。
入力元はHTTPである。
URLが各アクションのエントリポイントであり、フォームパラメータやJSON等を入力値とする。
業務ロジックを表現するものではない。

---

# Job
非同期処理実行のためのインターフェース。
メッセージキューを入力として、処理の実行を開始する。
入力元は異なるがControllerと同種の役割を持つ。
Railsにおいては、キュー投入のインターフェースやメッセージ規約も兼ねる。

---

# オプショナルな構成要素
これまで良く利用されてきた追加の構成レイヤー。

- Form
- Decorator / View Object
- Service

---

# Form
Railsは基本がWebなのでWebからの入力を意識した名前が付けられているが、実質的にはファクトリやオブジェクトビルダーと言える。
ユーザからの入力データを元に複数のモデルや構造が複雑なモデルを生成する。
入力に対するバリデーションも行う。
永続化のためのインターフェースは持つが、処理自体は内部のモデルに移譲する。
実は、かなり重要な要素であると思う。詳しくは後述。

---

# Decorator / View Object
表示のための加工処理をオブジェクト指向的に行うためのもの。
Helperだとポリモーフィズムが難しいので、どうしても分岐が増えてとっ散らかるので、それを避けるためのレイヤー。

---

# Service
[似非サービスクラスの殺し方](https://speakerdeck.com/joker1007/number-ginzarb)

業務上重要な振舞いそのものに名前を付けてクラスとして表現したもの。
複数のモデルオブジェクトに跨る処理を管理しまとめる。

---

# 大事なことは、それぞれの責任範囲を守ること
# そして、ちゃんと命名規約を守ること
# でないとフレームワークというものの利点を自ら潰すことになる

---

# DDDの概念とのマッピング
直接の対応関係にある訳ではないが、Railsが基本的に持っている要素の中で最も近いと考えられるもの。

- エンティティ -> Model (AR or not AR)
- 値オブジェクト -> Model (not AR)
- リポジトリ -> ActiveRecord
- アプリケーションサービス -> Controller
- ドメインサービス -> Model (Service Class)

---

# 設計とは何か (私見)
設計の半分以上は概念を発見して名前を付けることだと思う。
基本的にアプリケーションの動作は、何かを入力して何かを出力するI/Oの管理である。
どこから入ってきたデータを、どういう名前の処理を経由してどういう形式でどこに出力するのか、それを決めるのが設計。

---

# コンテキストマッピング
大事なことは地図を作ること。
責任範囲の境界にしっかり線を引き、それぞれの範囲に名前を付けられる様にする。
各コンテキストは独立しており、通常は他のコンテキストを触らずその中で処理が完結する様にする。
コンテキスト間で連携が発生する場合は、処理の流れを一方向に限定し、依存関係をコントロールする。

---

# 処理のブレイクダウン
コンテキスト内部でも、原則として処理は一方向に進むことを維持する。
複雑さのコントロールとして重要であり、読み易さにも大きく影響する。

---

# ルート集約

あるコンテキストの処理を実行する場合、境界の外から触っていいエントリポイントを明確にしておく必要がある。
そして、それ以外の場所から決して内側のオブジェクトを触ってはいけない。
集約はデータの整合性を守る単位である。
モデル間の依存関係は基本的にツリー上になっていて、そのルートのみが境界の外側からのメッセージを受け付けるのが健全。

---

# 辛さの根源
- 境界が不明瞭でどこから処理が呼ばれるか分からない
  - 特にデータの流入元が複数あって把握が困難なケース
- 依存関係が明確でなく、弄った時に一緒に壊れるクラスが多数ある
- 一連の処理フローの中で、各オブジェクトを行ったり来たりする
- 処理フローにおいて分岐の場所が散乱している

一連の処理そのものの複雑さや長さそのものはそこまで重要ではない
オブジェクト同士の関係性の地図が無いことが辛さを生む。

---

# Railsにおける集約の表現
難しいのは、どのクラスが集約のルートに位置するかを明示すること。
Rubyは可視性の制約が緩いので、外から触ってはいけない場所を強制できない。
現実的には以下の様になると思う。

- ネームスペースを区切り、ネームスペースのルートを集約のルートとする
- コメントやドキュメントで明示する

---

# Railsアプリの成長に伴う変化
開発当初はActiveRecordをそのまま利用するケースが多いと思う。
ARのままでも集約境界とルートがコントロールできるなら問題ない。

```ruby
class Order < ActiveRecord::Base
  has_many :order_details
end

class OrderDetail < ActiveRecord::Base
  belongs_to :order
end

# OrderDetailはOrderからしか触らないし生成されない
```

---

# Railsアプリの成長に伴う変化
アプリが大きくなると、データベースのレコードは共通だが、コンテキストが異なるケースが出てくる。
ARをロジックからインフラレイヤー寄りの役割に寄せて、レコードレベルの整合性だけを任せる。
コンテキスト毎に、新しい集約クラスをPOROで定義し、全体の整合性はそこでコントロールする。

---

# 再びFormオブジェクトの役割について
複数のモデルに跨り、ケース毎の整合性を保ってARのレコードを生成・更新する。
かつRailsにおいては、ビューに引き渡して、表示を行うためのインターフェースも兼用する。
実質的には、集約のルートに近いと言える。
ただ、そうなるとFormという名前がフィットしないかも。

---

# Formオブジェクトのvalidationについて
validationをARと二重でやるかについては好みがある。
私はARに移譲できるものはARに任せて、errorsを収集する方が良いと思う。

```ruby
GiftForm = Struct.new(:budget, :details, keyword_init: true) do
  include ActiveModel::Validations

  def valid?
    validity = @gift_details.all?(&:valid?)
    @gift_details.each_with_index do |gift_detail, idx|
      gift_detail.errors.each do |attr, message|
        self.errors.add("gift_detail[#{idx}]", message: message)
      end
    end
  end
end
```

# コレクションの表現
Railsにおいて、微妙に扱いに困るものがコレクション。
ActiveRecordが変にクラスレベルでレコードコレクションを扱うので、そこに色々定義しがちになる。
scopeを触るだけで済まなくなってきたら、コレクションクラスを自分で定義するか`extending`等を使う方が良い。

---

# クラスメソッドの弊害

- 内包しているデータが無いので、引数でしかデータを渡せない。
- クラスレベルからは基本的にpublicメソッドのみしか使えない(使わない)
- マルチスレッドで扱う時に危険 (sidekiqとか)

これらの弊害に加えて、あるクラスの責任範囲が過剰に広くなる。
実際には、もう一つ上のレイヤーで処理すべきことである。

---

# 集約ルートとの関係
集約がコレクションを包含することは、よくある。
一行単位のレコードと、集合全体の情報両方が必要な場合等。
(ex, ページネーションやデータ分析の結果を表示するケース等)

その他、一時的なデータリポジトリが必要になるケースもある。
大体、パフォーマンス上の理由による。

---

# 単純なコレクションクラスの例

---

# ここまでのまとめ

- 責任範囲の境界を明確にするための地図を作る
- 境界の外から触っていいI/Fを最小化する
- 成長と共にARを複数管理する集約ルートとしてのPOROを作る

集約ルートが肥大化しない様に、子になるオブジェクトに処理を移譲することを意識する。
責任は小さく。

---

# 単一のレコードレベルでの複雑さ
個別のエンティティレベルの複雑さの根源は、状態管理の複雑さだと思う。
オブジェクトが不変であれば、インスタンスがあるか無いかしか知らなくていい。

---

# 状態管理の悪い例
deviseが典型的に駄目な例なので、それを元に話をする。
(devise自体が駄目という話ではなく、サンプルとか使われ方が駄目という話)

---

# テーブル定義の例

```ruby
create_table :users do |t|
  t.string   :email, null: false
  t.string   :name
  t.string   :encrypted_password
  t.string   :confirmation_token
  t.datetime :confirmed_at
  t.datetime :confirmation_sent_at
  t.string   :invitation_token
  t.datetime :invitation_created_at
  t.datetime :invitation_sent_at
  t.datetime :invitation_accepted_at
end
```

---

# 駄目な理由
- NULLABLEカラムの嵐になる
- 状態によって整合性を管理しなければならない範囲が変化する
  - 登録完了時には必須だが、confirm待ちや招待の承認前は不要
  - 他オブジェクトとの関連が、必須になったり初期化できなかったりする

自身の状態とどういう遷移を経てきたかを管理する必要が出てくる
それはそのまま、分岐の氾濫や整合性違反に繋がる

---

# 改善方法
User、UserRegistration, UserInvitationに分割する

---

# Userの例

```ruby
create_table :users do |t|
  t.string   :email, null: false
  t.string   :name, null: false
  t.string   :encrypted_password, null: false
end
```

```ruby
class User < ActiveRecord::Base
  validates :email, presence: true
  validates :name, presence: true
  validates :encrypted_password, presence: true
end
```

---

# UserRegistrationの例

```ruby
create_table :users do |t|
  t.string   :email, null: false
  t.string   :confirmation_token, null: false
  t.datetime :confirmed_at
  t.datetime :confirmation_sent_at, null: false
end
```

```ruby
class UserRegistration < ActiveRecord::Base
  validates :email, presence: true
  validates :confirmation_token, presence: true
end
```

FormオブジェクトがUserRegistrationの整合性を確認
`confirmed_at`の記録とUserの永続化を行う

---

# UserInvitationの例

```ruby
create_table :users do |t|
  t.string   :email, null: false
  t.string   :invitation_token, null: false
  t.datetime :invitation_created_at, null: false
  t.datetime :invitation_sent_at, null: false
  t.datetime :invitation_accepted_at
end
```

UserRegistrationと同様Formオブジェクトが整合性を確認
`invitation_accepted_at`の記録とUserの永続化を行う
この時FormオブジェクトはUserRegistrationの処理とは異なる

---

# どう変わったか
- Registration, Invitationはそれぞれ自分の中で2値の状態だけ管理すれば良い
- UserはNOT NULLカラムonlyになり、バリデーションが単純化する
- 通知のコールバック等を定義する場所が明確になる
- Userを利用する際に、登録に関するカラムやメソッドが邪魔にならない

---

# 正規化？
この例はデータベースのテーブル設計が責任や状態管理の分離と上手く合致するが、常にそう上手くはいかない。
Railsにおいては、どうやってもテーブル構造とモデル構造の癒着が避けられない。
現実的には、どちらも意識して設計する必要がある。
モデル設計とテーブル設計は別と書かれている書籍が多いが、RailsではARで表現しやすい形に落としこむのも重要。

---

ちなみに弊社のテーブルは自分で駄目だと言っている例そのまんまです :sweat:
現実は色々あって厳しい……。

---

# 不変を更に推し進める
レコードの更新コストは結構高い。また不変であれば、分散処理との親和性が高くなりスケーラビリティの向上が見込める。
レコード自体は不変に保ち、イベントを記録することで現在の状態を再現することで、追加のみでデータの更新を表現できる。
これはイミュータブルデータモデルと呼ばれる。
これをDDDに意識的に組込んだものが、ドメインイベントとイベントソーシングだと思う。
(この辺り、成り立ちについての知識が無いため、私見です)

---

# Railsでのイベントの表現
[rails_event_store](https://github.com/RailsEventStore/rails_event_store)がかなり現実的に見える。
ただ、私はこれをproductionで利用したことがないため、正しく理解している自信はない。
あくまで参考程度として聞いて欲しい。

---

# イベントの発行

```ruby
stream_name = "order_1"
event = OrderPlaced.new(data: {
  order_id: 1,
  order_data: "sample",
  festival_id: "b2d506fd-409d-4ec7-b02f-c6d2295c7edd"
})

#publishing an event for a specific stream
event_store.publish_event(event, stream_name: stream_name)
```

---

# イベントの購読

```ruby
class InvoiceReadModel
  def call(event)
    # Process an event here.
  end
end

subscriber = InvoiceReadModel.new
event_store.subscribe(subscriber, to: [InvoiceCreated, InvoiceUpdated])
```

---

# ARのテーブル構造

```ruby
create_table(:event_store_events_in_streams, force: false) do |t|
  t.string      :stream,      null: false
  t.integer     :position,    null: true
  t.references  :event, null: false, type: :string
  t.datetime    :created_at,  null: false
end
add_index :event_store_events_in_streams, [:stream, :position], unique: true
add_index :event_store_events_in_streams, [:created_at]
add_index :event_store_events_in_streams, [:stream, :event_id], unique: true

create_table(:event_store_events, id: false, force: false) do |t|
  t.string   :id, limit: 36, primary_key: true, null: false
  t.string   :event_type,  null: false
  t.text     :metadata
  t.text     :data,        null: false
  t.datetime :created_at,  null: false
end
```

---

# イベント駆動アーキテクチャの利点
イベントをベースにすることで以下の様な利点が得られる

- 任意の状態のオブジェクトを再現できる
- オブジェクトの更新理由が明確になり、再取得できる
- 処理同士がイベントで繋がるため疎結合化が進む
  - 分散処理やマイクロサービスと親和性が高い

---

# イベント駆動アーキテクチャの不利な点
一方で、以下の点が懸念材料となる

- 読み込み時のコスト
  - 特にイベントが蓄積された後にどうするか
- トランザクションのコントロールが難しい
- ユーザーへの戻り値のコントロールが難しい
- 今迄とは異なる概念でデータの流れを捉える必要がある

純粋に技術的な難易度が上がるのでリスクも多い。

---

