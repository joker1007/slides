JJUG CCC Fall 2026で発表するスライドをMarkdownで作成する。

タイトルは「Semi-Realtime Data Warehouse with Trino, Apache Arrow, and Iceberg」。

以下の技術要素についてと、~/repro/streamhouse, ~/repro/trino-flight-sql-connectorの開発についてJavaユーザーコミュニティに解説する。

- Kafka
- Kafka Streams
- Trino
- Arrow
- Iceberg
- DuckDB

冒頭でKafkaとKafka Streamsの解説を軽くした後で、Icebergの解説、Icebergのメリットとしての透過的パーティショニングやMerge on Readについて紹介、IcebergへのSparkを使った書き込みの解説、Arrowの紹介、Arrowのゼロコピーによる性能向上の解説、KafkaからストリームでApache Arrowにデータを蓄積しつつ耐障害性を確保するためにKafka StreamsのカスタムStateStoreを使ったことについて紹介(実装面も含むが詳細には踏み込まない)、内部でクエリ可能にするためのDuckDBの導入について紹介、外部からのクエリ受け付けのためのFlightSQLの紹介、その導入について実装面を軽く紹介、TrinoからクエリするためのFlightSQLコネクタの開発について紹介、Trinoコネクタプラグインの構成要素と作るものの多さを紹介。

こういった流れでスライドを展開し、全体で40分程度の発表を想定する。
聴衆はJavaユーザーコミュニティで、データエンジニアリングや分散システムに興味があり、KafkaやSparkなどメジャーなミドルウェアの基本的な知識はある人間を対象とする。

資料の体裁は、このリポジトリの../jjug_ccc_fall_2025を参考にする。
発表には~/malchutというツールを利用する想定なので、Marpとの記法の差があれば注意。
mermaid記法やコードハイライトが利用できるので、必要に応じて利用する。

yomiyasu SKILLを利用して平易な日本語で書くこと。
