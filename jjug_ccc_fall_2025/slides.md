---
title: Quarkusで作るInteractive Stream Application
theme: default
paginate: true
style: |
    /* @theme rose-pine */
    /*
    Rosé Pine theme create by RAINBOWFLESH
    > www.rosepinetheme.com

    palette in :root
    */

    @import "default";
    @import "schema";
    @import "structure";

    :root {
        --base: #191724;
        --surface: #1f1d2e;
        --overlay: #26233a;
        --muted: #6e6a86;
        --subtle: #e0def4;
        --text: #e0def4;
        --love: #eb6f92;
        --gold: #f6c177;
        --rose: #ebbcba;
        --pine: #31748f;
        --foam: #9ccfd8;
        --iris: #c4a7e7;
        --highlight-low: #21202e;
        --highlight-muted: #403d52;
        --highlight-high: #524f67;

        font-family: Pier Sans, ui-sans-serif, system-ui, -apple-system,
            BlinkMacSystemFont, Segoe UI, Roboto, Helvetica Neue, Arial, Noto Sans,
            sans-serif, "Apple Color Emoji", "Segoe UI Emoji", Segoe UI Symbol,
            "Noto Color Emoji";
        font-weight: initial;

        background-color: var(--base);
    }
    /* Common style */
    h1 {
        color: var(--rose);
        padding-bottom: 2mm;
        margin-bottom: 12mm;
    }
    h2 {
        color: var(--rose);
    }
    h3 {
        color: var(--rose);
    }
    h4 {
        color: var(--rose);
    }
    h5 {
        color: var(--rose);
    }
    h6 {
        color: var(--rose);
    }
    a {
        color: var(--iris);
    }
    p {
        font-size: 20pt;
        font-weight: 600;
        color: var(--text);
    }
    code {
        color: var(--text);
        background-color: var(--highlight-muted);
    }
    text {
        color: var(--text);
    }
    ul {
        color: var(--subtle);
    }
    li {
        color: var(--subtle);
    }
    img {
        background-color: var(--highlight-low);
    }
    strong {
        color: var(--text);
        font-weight: inherit;
        font-weight: 800;
    }
    mjx-container {
        color: var(--text);
    }
    marp-pre {
        background-color: var(--overlay);
        border-color: var(--highlight-high);
    }

    /* Code blok */
    .hljs-comment {
        color: var(--muted);
    }
    .hljs-attr {
        color: var(--foam);
    }
    .hljs-punctuation {
        color: var(--subtle);
    }
    .hljs-string {
        color: var(--gold);
    }
    .hljs-title {
        color: var(--foam);
    }
    .hljs-keyword {
        color: var(--pine);
    }
    .hljs-variable {
        color: var(--text);
    }
    .hljs-literal {
        color: var(--rose);
    }
    .hljs-type {
        color: var(--love);
    }
    .hljs-number {
        color: var(--gold);
    }
    .hljs-built_in {
        color: var(--love);
    }
    .hljs-params {
        color: var(--iris);
    }
    .hljs-symbol {
        color: var(--foam);
    }
    .hljs-meta {
        color: var(--subtle);
    }


---

<style scoped>
h1, h2, h3 {
  color: white;
}
</style>

# Quarkusで作るInteractive Stream Application

### joker1007 (Repro株式会社)
### JJUG CCC Fall 2025

---

<!--
footer: ![w:100 h:32](logo_white.png)
-->

# 自己紹介

- 橋立友宏 (@joker1007)
- Repro株式会社 チーフアーキテクト
- 元々はRailsエンジニアだったが、最近はJavaばかり書いている
- 日本酒とクラフトビールが好き

![bg right height:160px](./icon.jpg)

---

# Asakusaから来ました
活動中のRubyコミュニティで日本最古
(自分は本当に浅草に住んでます)

![bg right height:640px](asakusarb.png)

---

# 最近の仕事
![repro height:200px](logo_white.png)
チーフアーキテクトとして、サービス全体の中長期的な技術選定、設計アドバイス、全体アーキテクチャのデザインなどをしている。

---

# Reproの事業
マーケティングオートメーションサービスを提供している。
マーケティングオートメーションとは、

- ユーザーの行動を分析・分類し
- 複数のチャネルで適切なキャンペーンを配信することで
- 顧客とエンドユーザーのコミュニケーションを支援する

SaaS事業だけでなく、サービスグロースの総合的な支援も提供しています。

(この辺まで前回のJJUG CCCの資料の流用)

---

# ReproではKafkaを積極的に活用しています

---

# 前回のJJUG CCCではKafka Streamsの実践的な開発テクニックについて話しました

---

# Streaming Applicationの基本

## Fire and Forget

出来る限り後続の処理にはタッチしない

## CQRS

結果が欲しい場合は読み取り用のDBを経由して疎結合に保つ。
しかし、書き込み完了までのインターバルやpollingのオーバーヘッドなどが発生する。

---

# RDBやKVSだけでは扱いにくいデータやサービスも存在する

- Sketch
- CRDT (Conflict-free Replicated Data Type)
- Apache Arrow

Database側で独自の拡張を持っているケースはあるが用途に合うかはケースバイケース。

---

# 大量のデータを処理しつつ、そういったデータ構造を活用したマイクロサービスを実装したい、そういう時がありますよね？(あんま無いかも……？)

---

# Stream Application + Interactive

クエリ可能なStream Applicationという選択肢

---

# Kafka StreamsのInteractive Queries

---

# Quarkusを利用してKafka StreamsにWeb I/Fを追加する

---

# Quarkusを利用するメリット

---

# Kafka Streams Extension

---

# その他の相性の良いExtension

---

# サンプル

---

# 活用事例

---

# Theta Sketchを利用したユニークユーザーカウント

---

# リードタイム短縮を諦めないTemplate Rendering Server

---

# デバッグ用途

---

# 動的な設定変更

---

# まとめ
