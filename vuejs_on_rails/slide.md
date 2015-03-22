# Vue.js on Ruby on Rails

Tomohiro Hashidate
@joker1007


## 自己紹介
- @joker1007
- (株)ウサギィ (退職予定)
- Ruby/Railsを中心にした何でも屋みたいな
- パーフェクトRuby, パーフェクトRuby on Rails著者
- vimmer



## 今日は大体JSの話をします。



## RailsとVue.jsでSPAを作る
- 1.5人月でバックエンドRails + 複数DBのSPAを作る
- とにかく時間が無い
- ある程度のメンテナンス性
- パフォーマンスはそれなりでいい
- Vue.jsを使う



## Vue.jsのおさらい



## MVVMパターンの
## VM部分を提供するライブラリ



## ViewModel



## Mustacheっぽいテンプレート



## コンポーネント指向



## Vue.jsとRailsの相性がいい点
- 単体のJSで動作する (rails-assets)
- 覚える事が少ない
- 事前コンパイル不要
- デザイナーと協業しやすい



## HTMLをほぼそのまま
## テンプレート化できる
### v-cloak



## Vue.jsのコツ



## Reactっぽいデータの流れを意識する
- コンポーネントツリーのルートとなる箇所が必要なデータを全て持つ
- 同じdataオブジェクトを引き回す
- 自分の管轄の箇所のデータを更新する
- 全体が勝手に再構築される



## 重要なのはデータを共有すること



## シンプルなReactとして使う



## Routerライブラリを用意する
- 不要なViewModelオブジェクトをちゃんと破棄する



## 似非SPA
Turbolinksでテンプレと初期データを差し替え
Routerでディスパッチ



## 小規模アプリにはVue.jsも良い
