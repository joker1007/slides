# Vue.js on Ruby on Rails
![vue.png](vue.png)
![rails.png](rails.png)

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

```js
var vm = new Vue({
  "el": "#hello"
  "data": {
    "message": "hello World"
  }
})
```



## Mustacheっぽいテンプレート

```html
<div>{{message}}</div>
```



## コンポーネント指向

```js
Vue.component("tweet", {
  "template": '<span class="name">{{username}}</span><span class="body">{{body}}</span>'
})
```

```js
new Vue({
  "el": "#tweets",
  "data": {
    "tweets": [
      {"username": "joker1007", "body": "Hello"},
      {"username": "joker1007", "body": "I love Ruby"}
    ]
  }
})
```

```html
<div id="tweets">
  <tweet v-repeat="tweets">
</div>
```



## Vue.jsとRailsの相性がいい点
- 単体のJSで動作する (rails-assets)
- 覚える事が少ない
- 事前コンパイル不要
- デザイナーと協業しやすい



## HTMLをほぼそのまま
## テンプレート化できる
### ex. v-cloak

```html
<div id="commits">
  <ul v-repeat="commits" v-cloak>
    <li>{{sha1}} {{comment}}</li>
  </ul>
</div>
```

```css
[v-cloak] { display: none }
```



## Vue.jsのコツ

### 重要なのはVM同士でデータを共有すること
- コンポーネントツリーのルートとなる箇所が必要なデータを全て持つ
- 同じdataオブジェクトを引き回す
- 自分の管轄の箇所のデータを更新する
- 全体が勝手に再構築される



## シンプルなReactっぽい何かとして
![http://facebook.github.io/flux/img/flux-simple-f8-diagram-with-client-action-1300w.png](http://facebook.github.io/flux/img/flux-simple-f8-diagram-with-client-action-1300w.png)



## Routerライブラリを用意する
- page.js, director.js, etc
- Contextの切り替えを意識する
  - 状態を保存して復元できるように
  - 不要なViewModelオブジェクトをちゃんと破棄する
  - シンプルなものならpushState/popStateでも

cf. [Arda - MetaFluxなフレームワークを作った - Qiita](http://qiita.com/mizchi/items/ef3ee47957e431c8be7b "Arda - MetaFluxなフレームワークを作った - Qiita")



## 似非SPAで手抜き
- turbolinksでテンプレと初期データを差し替え
- Routerでディスパッチ
- 割と行ける気がする
- turbolinks-3.0(not yet)のpartial replacementで……



## 小規模アプリにはVue.jsも良い
react.jsはこれから本気出す……
