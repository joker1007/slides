# ActiveRecordをOLAPに使うな

Tomohiro Hashidate
@joker1007



## 自己紹介
- @joker1007
- (株)ウサギィ -> フリーランス
- Ruby/Railsを中心にした何でも屋みたいな
- パーフェクトRuby, パーフェクトRuby on Rails著者
- vimmer

![pruby.jpg](pruby.jpg)
![prails.jpg](prails.jpg)



## 同人誌出しました
![rspec_hacking_guide.png](rspec_hacking_guide.png)
https://joker1007.booth.pm/items/128676



## 怖い話
SIer時代に、本番機を弄るための申請書をPDFで送ってるのにFAXで送る必要があった、とか
DC内の本番機にウイルスが侵入したけどアンチウイルスソフト入ってないし、WindowsNTとか残ってたとか

まあ、色々ある



## 本題



## 一日分のKPIを取るのに200 \* m \* n + 1ぐらいのクエリが流れる
この辺あんまりツイートしないように



## バッチでRDSのインスタンス一つの負荷一杯になる
この辺あんまりツイートしn(ry



## 集計バッチ怖い (辛い)



## ActiveRecordで無理にやるのが良くない
- そもそもJOIN禁止教っぽい実装とか
- GROUP BY一切使ってないとか
- scopeの名前がインチキとか

まあ、色々ある

この辺あんまりツイ(ry



## 集計の前にSQLの書き方を覚える
そりゃメンテコストはあるが、結局他弄った時に気付けなけりゃ一緒。

カラム弄ったりした時に中途半端に動くよりエラー吐いて止まる方が安全。



## SQLっぽい考え方
特定の日付とかを外部から与えて何発もクエリ打つのは効率が悪い。
集合の加工を意識する。

A と Bの結合 → 集約 → 条件付きカウント



## SQLで集計を完結させるために
SQLは「特定の状態で無い」ものを集計しにくい

ex. ある月の開始時点でhogeしてない人がある日においてもhogeしてない場合の数



## SQLのテクニック (1)
SUM, COUNTの中でCASEを使う

```sql
SELECT
  created_at_month AS month,
  SUM(
    CASE WHEN created_at_month = user_created_at_month
      THEN amount
    ELSE 0
    END
  ) AS new_employee_fee_amounts,
  COUNT(DISTINCT
    CASE WHEN created_at_or_work_time_month = user_created_at_month
      THEN user_id
    ELSE null
    END
  ) AS got_fee_new_employees,
FROM fees
```



## SQLのテクニック (2)
関数値を使ったGROUP BY

```sql
SELECT
  DATE_TRUNC('month', users.created_at) AS month,
  COUNT(users.id)
FROM users
GROUP BY DATE_TRUNC('month', users.created_at)
```



## SQLのテクニック (3)
ウインドウ関数

```sql
SELECT
  users.id,
  DATE_TRUNC('day', users.created_at) AS created_at_day,
  MIN(job_offers.created_at) OVER (PARTITION BY users.id) AS min_job_offer_created_at
FROM users
INNER JOIN job_offers ON job_offers.user_id = users.id
```



```sql
SELECT
  users.id,
  DATE_TRUNC('day', users.created_at) AS created_at_day,
  ROW_NUMBER() OVER (PARTITION BY users.id ORDER BY job_offers.created_at) AS min_job_offer_created_at
FROM users
INNER JOIN job_offers ON job_offers.user_id = users.id
```



## SQLのテクニック(4)
中間テーブルを作る

```sql
CREATE TABLE users_with_min_job_offer_created_at AS
SELECT
  users.id,
  DATE_TRUNC('day', users.created_at) AS created_at_day,
  MIN(job_offers.created_at) OVER (PARTITION BY users.id) AS min_job_offer_created_at
FROM users
INNER JOIN job_offers ON job_offers.user_id = users.id
```



## おすすめの本
- SQL実践入門──高速でわかりやすいクエリの書き方
- 10年戦えるデータ分析入門 SQLを武器にデータ活用時代を生き抜く



## もう集計バッチ怖くない
