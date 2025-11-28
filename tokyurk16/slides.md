# DHHもすなるLinuxデスクトップといふものを、Rubyistもしてみむとてするなり

joker1007
TokyuRuby会議16

---

# 真のタイトル: Rubyistに5分で叩き込むLinux Tips 40

---

# 背景
OmarchyのおかげでLinuxちょっと使ってみようかという人が増えた気がする。
自分はずっとMacより全然使い易いと思っている。
Macを使っていた時期はあるが9割以上iPhoneとiTunesのためだった。
という訳でRubyistにLinuxで困ることは何もないということを伝えたい。

---

# Linuxの使い勝手について
Linuxは基本的にある目的を達成するソフトウェアをどれだけ知っているかで概ね使い勝手が決まる。
そして、調べる場所が分かればどうにかなる。
大事なのは名前と調べる場所を知っていること。

Linuxは自由な分選択肢が多いので、今回は自分のオススメも詰め込んである。
大体これ選んでおけばOKなやつ。

という訳で5分間で叩き込むから着いてきてくれ！

(多分着いてこれんので資料公開したやつを見てくれ)

---

# 1. man

Macでも余り変わらないが、困った時はとりあえずmanでマニュアルを見ること。
manにはセクションという概念があり、CLIのマニュアルだけでなく設定ファイルのフォーマットとかsystem callのマニュアルも書いてある。

```sh
man jq
man 5 systemd.unit
man 2 recv
```

---

# 2. 各種PATH
コマンド実行のためのPATHだけでなく色々なPATHが存在する。
あんまり直接弄ることはないが、ソースから何かをコンパイルする時には自分で設定しなければいけない時もある。

- LD_LIBRARY_PATH: 実行時のDLLを探す場所。/etc/ld.so.confに設定しておけば良いので直接弄ることは余りない
- PKG_CONFIG_PATH: pkg-config(コンパイル時に必要な情報を記録して参照可能にしてくれる)を探す場所。
- MANPATH: manを探す場所。システムのパッケージマネージャー以外でインストールすると他の場所にmanが入っててmanコマンドで見れない場合がある。
- C_INCLUDE_PATH, CPLUS_INCLUDE_PATH: C系のヘッダファイルを探す場所。

---

# 3. systemd

システム全体のプロセス起動・管理を行う。カーネルがPID1として起動する。
やたら多機能。(Unixっぽくないので嫌いな人が一定居てよく燃えてる)
現実として、こいつがシステムの基本的な動作の大半に絡むので覚えておく必要がある。

ここから少しの間systemdのよく使うものについて話をする

---

# 4. systemctlとunitファイル
めちゃくちゃざっくり言えば、デーモンプロセス、mount設定、socketサービス、timer、それらの依存関係を記述するのがunitファイルで、それの自動起動や状態の管理などを行うコマンドが`systemctl`。
例えばsshdの自動起動なんかを管理してるので、その辺りから見てみるのが良い。
なんらか自動起動したい時はこれを書けば良い。

```sh
systemctl --list-unit-files # 認識されているunitファイルのリスト
systemctl cat sshd.service # sshd起動のための設定
systemctl enable sshd.service # 自動起動を有効にする
```

---

# unitファイルの例

```
[Unit]
Description=OpenSSH server daemon
After=network.target auditd.service # network関係の依存関係をまとめるtarget処理が終わった後に起動する

[Service]
Type=notify-reload # systemdにプロセスの起動完了を伝える方法
ExecStartPre=/usr/bin/ssh-keygen -A # 起動前に行うコマンド
ExecStart=/usr/sbin/sshd -D -e # 起動に利用するコマンド
KillMode=process # プロセスの終了のさせ方
OOMPolicy=continue # OOMが起きた時どうするか
Restart=on-failure # どういう状況で再起動するか
RestartSec=42s

[Install]
WantedBy=multi-user.target # enableした時に規定で登録するtarget
```

---

# 詳細はここ

詳しく知りたくなったらArchWikiと公式docへ。

- https://wiki.archlinux.jp/index.php/Systemd
- https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html
- https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html

---

# 5. XとWayland

LinuxでGUIアプリ(ウインドウシステム)を提供する仕組みとして長く使われてきたのがXである。
そのための設定ファイルや起動スクリプトなどが諸々あったが、最近のLinuxではWaylandプロトコルに移行しつつある。
Waylandでは基本的にX時代の設定ファイルは無視される。設定は個別のウインドウマネージャーで行う。

詳しくはArchWikiへ。
https://wiki.archlinux.jp/index.php/Wayland

---

# 6. uwsm (Universal Wayland Session Manager)

waylandを利用するウインドウマネージャーで、systemdを利用していい感じにアプリの自動起動とか出来る様にしてくれる。
とても説明できないので、詳しくは俺のブログを読んでくれ。

- https://joker1007.hatenablog.com/entry/2025/10/02/222603

---

# 7. HyprlandのちょっとしたTips

windowruleは便利なのでちゃんと設定しておこう。動画見てたりMeeting中にdimがかからない様にするとか。

```
windowrule = nodim,class:^(google-chrome.*),title:^(.*YouTube.*)$
windowrule = nodim,class:^(google-chrome.*),title:^(.*Netflix.*)$
windowrule = nodim,class:^(google-chrome.*),title:^(.*Prime Video.*)$
windowrule = nodim,class:^(google-chrome.*),title:^(.*Twitch.*)$
windowrule = nodim,class:^(google-chrome.*),title:^(Meet.*)$
```

---

# 8. Terminal

この辺りがオススメ、他のターミナルは遅い

- [alacritty](https://alacritty.org/) (シンプル、有名)
- [foot](https://codeberg.org/dnkl/foot) (wayland専用、多機能)
- [ghostty](https://ghostty.org/) (必要十分)

---

# 9. タスクバー

[waybar](github.com/Alexays/Waybar)で良い。カスタマイズが簡単で必要なものは大体ある。

ドキュメント
https://github.com/Alexays/Waybar/wiki

---

# 10. ランチャー
以下は個人的なオススメ。

- [wofi](https://github.com/SimplyCEO/wofi) (シンプル)
- [walker & elephant](https://benz.gitbook.io/walker/) (elephantがバックエンドで検索と表示などを行う、walkerはフロントエンド)

シェルスクリプトと組み合わせるならwofiの方が楽。

---

# wofiでオーディオの出力先を変更する例

```sh
#!/bin/bash

id=$(pw-dump Node | jq -r 'map({id: .id, class: .info.props["media.class"], desc: .info.props["node.description"]} | select(.desc != null)) | sort_by(.class, .desc) | .[] | [.id, .class, .desc] | @tsv' | wofi -di | cut -f 1)

if [ -n "$id" ]; then
  echo "Setting default to $id"
  wpctl set-default $id
fi
```

---

# 11. Filer

Omarchyから来ているHyprlandユーザーならThunarが良いと思う。
Xfceデスクトップの基本ファイルマネージャーだが、依存で必要になるものが少ない。
次点でpcmanfm-qtかな。

CLIなら今は[yazi](https://yazi-rs.github.io/docs/installation)一択で良い。
シェルスクリプトメインで自分でカスタムしたい人は[nnn](https://github.com/jarun/nnn)がオススメ。

もっと試したい人はArchWikiで。
https://wiki.archlinux.jp/index.php/%E3%82%A2%E3%83%97%E3%83%AA%E3%82%B1%E3%83%BC%E3%82%B7%E3%83%A7%E3%83%B3%E4%B8%80%E8%A6%A7/%E3%83%A6%E3%83%BC%E3%83%86%E3%82%A3%E3%83%AA%E3%83%86%E3%82%A3#.E3.83.95.E3.82.A1.E3.82.A4.E3.83.AB.E3.83.9E.E3.83.8D.E3.83.BC.E3.82.B8.E3.83.A3


---

# 12. プレゼンツール

実は割と不毛。
pdf化して、[pdfpc](https://github.com/pdfpc/pdfpc)を使うか[pympress](https://github.com/Cimbali/pympress/)を使うのが良いかと思う。
デュアルモニタで発表者画面とプレゼン画面を分けて出せる。
ノートも書ける。

後はもうGoogleとかWebサービスに頼る。

---

# 13. ネットワーク

NetworkManagerかsystemd-networkdのどちらかで管理する。

デスクトップPCでシンプルに設定したいならsystemd-networkdがオススメ。余計なものが入らない。

Wifiをよく切り替えるノートPCならNetworkManagerがシステムトレイとかまとめて用意してくれるのでオススメ。

自分は大抵systemd-networkdを使っている。

---

# 14. Wifi

wpa_supplicantが必要。しばしばハマるので詳しくはArchWikiへ。
NetworkManagerなら大体勝手になんとかしてくれるはず。
https://wiki.archlinux.jp/index.php/Wpa_supplicant

---

# 15. 音声出力とpipewire

PulseAudioの時代は大体終わりを告げており、Pipewireが主流になってる。
`~/.config/pipewire`に基本設定を書いて、`~/.config/wireplumber`にデバイス特有の設定などを書く。
よく使うコマンドは以下。

```sh
pw-top # pipewireの動作モニタ
pw-dump # 現在の設定をJSONで出力してくれる
wpctl # wireplubmerの設定表示やメインの入出力デバイスの変更など

```

詳しくはArchWikiへ
https://wiki.archlinux.jp/index.php/PipeWire
https://wiki.archlinux.jp/index.php/WirePlumber

---

# Pipewire関連ツール

[qpwgraph](https://gitlab.freedesktop.org/rncbc/qpwgraph)をインストールしておくのが良い。

グラフィカルにどのアプリがどのデバイスと繋がっているかが分かるし、繋ぎ変えもできる。

---

# 16. bluetooth

bluezというソフトウェアがBluetoothを管理している。bluetoothdが起動している必要があるのでsystemdで有効にすること。
GUI管理ツールとしては[Blueman](https://github.com/blueman-project/blueman)がオススメ。
しかし、結構ハマるのでログとか確認しつつやるなら`bluetoothctl`コマンドに慣れた方がいいかも。
ヘッドセットを上手く動かすにはPipewireの設定が必要になる場合がある。

詳しくはArchWikiへ。
https://wiki.archlinux.jp/index.php/Bluetooth
https://wiki.archlinux.jp/index.php/Bluetooth_%E3%83%98%E3%83%83%E3%83%89%E3%82%BB%E3%83%83%E3%83%88

---

# 17. パスワード管理
gnome-keyringとかKDE Walletなどがあるが、1passwordにお金払ってるのが一番良いと思う。
スマホや他のPCで使う時に困らないし、普通にLinux版がある。
システム認証と連携する設定をすることで、OSのパスワードやYubikeyでロック解除が出来る。

---

# 18. polkit
polkitはGUI向けのsudoみたいなもので、1passwordの様なプロセスが認証を必要とする時や特権を一時的に一般ユーザーに与える時に利用する。設定ファイルは/usr/share/polkitにある。
認証を行うためにエージェントフロントエンドが必要。Hyprlandなら[hyprpolkitagent](https://github.com/hyprwm/hyprpolkitagent)が公式にメンテされている。
基本的にwheelグループに入っていれば管理者権限を引き受けられる。

詳しくはArchWikiへ。
https://wiki.archlinux.jp/index.php/Polkit

---

# 19. PAM (Pluggable Authentication Modules)
ログインのユーザー認証や、sudo, polkitのパスワード認証の裏側にあるものでLinuxの認証機能は大体これを理解すればなんとかなる。設定は/etc/pam.d以下にある。

```
auth		required	pam_env.so
auth		requisite	pam_faillock.so preauth
auth		[success=1 new_authtok_reqd=1 ignore=ignore default=bad]	pam_unix.so nullok  try_first_pass
auth		[default=die]	pam_faillock.so authfail
```

設定ファイルはシンプルで上から順に処理を実行する。個別の意味については`man pam.d`で。

詳しくはArchWikiへ。
https://wiki.archlinux.jp/index.php/PAM

---

# 20. Yubikey

Yubikeyを使ってLinuxの認証を行うことができる。[pam_u2f](https://developers.yubico.com/pam-u2f/)をインストールしてpam.dの設定を変更することでFIDO 2でLinuxの認証が行える様になる。
1passwordもロック解除できる様になる。

```
# /etc/pam.d/system-local-login
auth	sufficient	pam_u2f.so origin=pam://hostname appid=pam://hostname cue openasuser pinverification=1
auth	include	system-login
# 以下略
```

sufficientであればこれを満たした時点で成功になる。2要素認証にしたい場合はrequiredにする。
CLIであればPINの入力を要求するpromptが出る。GUIの場合はパスワードの代わりにPINを入力してからデバイスにタッチすれば認証できる。
詳しくは俺のブログ記事へ。
https://joker1007.hatenablog.com/entry/2025/11/25/023018

---

# 21. Screen Locker
昔はxscreensaverとかを利用していたが、今はWaylandのためのidle managementアプリとlockアプリを利用する。
以下のものを組み合わせれば何とかなる。

- swayidle or hypridle
- swaylock or hyprlock

Hyprlandユーザーならhypridleをuwsm + systemdで起動して、そこからhyprlockを起動する設定にするのが良いと思う。
ちなみにロック解除もPAMを経由するのでYubikey認証もできる。

---

# 22. ディスプレイ管理

Hyprlandなら設定ファイルで直接モニター設定を弄るのが基本になる。

```
monitor=HDMI-A-1, 1920x1080@60, auto, 1, bitdepth, 10
```

アプリケーションで上手く設定するなら[hyprdynamicmonitors](https://hyprdynamicmonitors.filipmikina.com/)がオススメ。
ディスプレイの接続状況などから動的に設定を自動更新したり、TUIで直感的に設定変更できるが多機能過ぎるかもしれない。

---

# 23. キーリマッピング

[kanata](https://github.com/jtroo/kanata)を利用するのがオススメ。Rust製でMacでもWindowsでも使える。

レイヤー作ってマップを切り替えたり、マウスを操作したりマクロを設定したりできる。
こんな感じでマッピングとかレイヤーを定義して、どこで切り替えるとかを設定する

```
(deflayer mouse
  _    _    _    _    _    _    _    _    _    _    _    _    _    _
  _    _    _    _    lrld _    _    @mal @mad @mau @mar _    _    _
  _    _    @slw _    @fst _    @msl @msd @msu @msr _    _    _
  _    _    _    _    _    _    mlft mrgt _    _    _    _
       _    _              _              _    @rat
)
```
https://github.com/jtroo/kanata/blob/main/docs/config.adoc

---

# 24. Font

システムレベルのフォントは`/usr/share/fonts`に、個別のユーザーレベルのフォントは`~/.local/share/fonts`に配置する。
フォントを追加した時は`fc-cache`を実行してキャッシュを更新すること。

個人的なおすすめフォントは[Cica](https://github.com/miiton/Cica)と[UDEVGothic](https://github.com/yuru7/udev-gothic)。

---

# 25. 日本語入力

wayland環境ならibusよりfcitxを利用する方が良いと思う。
日本語変換のエンジンは基本クオリティが微妙なので、個人的にはfcitx-skkをインストールしてskkに慣れるのを一番オススメする。

今なら[fcitx-haskey](https://github.com/7ka-Hiira/fcitx5-hazkey)をインストールしてニューラルかな漢字変換システムZenzaiを利用するのも良いかもしれない。日本語変換なのにGPUをバリバリ使うので楽しそう。
自分はskkに最適化されてしまったので利用していない。

---

# 26. Clipboard管理

[walker+elephent](https://benz.gitbook.io/walker/)に任せるか[wl-paste](https://github.com/bugaevc/wl-clipboard)と[cliphist](https://github.com/sentriz/cliphist)を使って管理する。

後者の場合はwofiなどを利用して保持されているものピックアップする設定も必要。

ちなみにLinuxのクリップボードは歴史的な理由によりPRIMARYとCLIPBOARDの二つがある。
それぞれが何と対応しているのかは正直かなり分かりにくい。
詳しくはArchWikiへ。
https://wiki.archlinux.jp/index.php/%E3%82%AF%E3%83%AA%E3%83%83%E3%83%97%E3%83%9C%E3%83%BC%E3%83%89

---

# 27. 音楽再生

[mpd](https://mpd.readthedocs.io/en/stable/)となんらかのフロントエンドを利用するのが良い。
管理用のサーバープロセスとフロントエンド分けるの面倒臭くない？と思うかもしれないが、結局これが一番潰しが効く。

フロントエンドのオススメはGUIなら[cantata](https://github.com/nullobsi/cantata)で、TUIなら[rmpc](https://github.com/mierak/rmpc)

## 一部のオーディオマニア向け
replaygainを算出してタグに付与したい場合は[rsgain](https://github.com/complexlogic/rsgain)を利用するのがオススメ。
またmpdでDSDのネイティブ再生も可能です。DACの対応がカーネルに無ければパッチを当てる必要があるかも。
気になる人は直接聞いてください。

---

# 28. 動画再生

[mpv](https://mpv.io/)を使っておけば良い。特に困ることは無い。
UIをリッチにしたいなら、[uosc](https://github.com/tomasklaen/uosc)を入れるのがオススメ。

---

# 29. HDR

最新のHyprlandを利用しているならHDRでディスプレイ出力ができる。
主な用途はゲームか動画再生。

詳しくは俺のブログへ。
https://joker1007.hatenablog.com/entry/2025/03/19/180603
https://joker1007.hatenablog.com/entry/2024/12/18/201907

---

# 30. 画像ビューワー

シンプルな用途なら[swayimg](https://github.com/artemsen/swayimg)が良い。十分なサポート形式、軽量、ギャラリーモードあり。
zipアーカイブでまとめてる場合などは[mcomix](https://sourceforge.net/projects/mcomix/)がオススメ。

---

# 31. 壁紙

Hyprlandユーザーなら[hyprpaper](https://wiki.hypr.land/Hypr-Ecosystem/hyprpaper/)を利用しておけば良いと思う。
GUIで設定を変えたいなら[waypaper](https://anufrievroman.gitbook.io/waypaper)がオススメ。

---

# 32. 動画配信

OBSが普通に使える。Linux向けのプラグインとしては以下の様なものがある。

- [obs-vkcapture](https://github.com/nowrep/obs-vkcapture): Vulkanを利用するゲーム画面キャプチャ。デスクトップ描画を経由しないので軽いし高画質。
- [obs-pipewire-audio-capture](https://github.com/dimtpap/obs-pipewire-audio-capture): pipewireを直接使ってオーディオのキャプチャを行う。
- [obs-vaapi](https://github.com/fzwoch/obs-vaapi): GPUエンコードのサポート。

---

# 33. 音声加工

GUIアプリとしては[Audacity](https://www.audacityteam.org/)が定番。エフェクトのためのプラグインが多く存在する。LADSPA(拡張形式のLV2)というプラグインシステムがLinux特有なので覚えておこう。
pipewireの設定を利用してマイク入力にLADSPAのプラグインを利用してエフェクトをかけたりできる。

よく利用される音声加工のエフェクトプラグインは以下。

- [easyeffects](https://github.com/wwmm/easyeffects) (pipewireに直接エフェクトをかける。大体これで良い)
- [calf](http://calf-studio-gear.org/)
- [lsp-plugins](https://github.com/lsp-plugins/lsp-plugins)
- [swh-lv2](https://github.com/swh/lv2)

---

# ノイズキャンセリングをかけるサンプル
[noise-suppression-for-voice](https://github.com/werman/noise-suppression-for-voice)を利用している

```sh
context.modules = [
  {   name = libpipewire-module-filter-chain
      args = {
          node.description =  "Noise Canceling source"
          media.name =  "Noise Canceling source"
          filter.graph = {
              nodes = [
                  {
                      type = ladspa
                      name = rnnoise
                      plugin = /home/joker/.ladspa/librnnoise_ladspa.so
                      label = noise_suppressor_mono
                      control = {
                          "VAD Threshold (%)" = 90.0
                          "VAD Grace Period (ms)" = 200
                      }
                  }
              ]
          }
          capture.props = {
              node.name =  "rnnoise_source.input"
              audio.position = [ MONO ]
              node.passive = true
              audio.rate = 48000
          }
          playback.props = {
              node.name =  "rnnoise_source.output"
              audio.position = [ MONO ]
              media.class = Audio/Source
              audio.rate = 48000
          }
      }
  }
]
```

---

# 34. 動画加工

シンプル用途なら[avidemux](https://avidemux.sourceforge.net/)が昔から使われている。
高機能なビデオエディタなら[kdenlive](https://invent.kde.org/multimedia/kdenlive)、[openshot](https://github.com/OpenShot/openshot-qt), [shotcut](https://github.com/mltframework/shotcut)辺りだと思う。
自分はkdenliveしか使ったことがない。

---

# 35. VPN

tailscaleを使っておくのが一番楽だと思う。Macでも多分同じ。
systemd-networkdならDNSの設定とかも良い感じに自動で調整してくれる。
NetworkManagerの場合はよく知らない。

---

# 36. Kernel Compile 

とりあえず基本的な注意点だけ。
GPUのドライバ、Framebuffer、ストレージのドライバだけはきっちり確認して有効化しておくこと。
こいつらが欠けてるとブートそのものに失敗したり画面に何も出なくて自分がフリーズすることになる。

後は8割ぐらいは必要なデバイスドライバを探して有効化していくのがメイン。
慣れれば1発か2発で起動に成功する。

---

# 37. ソースからのコンパイルとインストール

ソースから何かをコンパイルして入れる場合は、/usr/localに入れるより/opt以下にそのソフトウェア専用のディレクトリを用意してインストールのprefixをそこに設定して、必要なパスを個別に設定する方が個人的には好み。
最悪消したくなった時はそのディレクトリを削除すれば良いし、他のソフトウェアとごっちゃにならない。

---

# 38. ebuild

Gentooユーザーならebuildが書ける様になると、自分で好きなものをコンパイルしてインストールしつつパッケージマネージャーに管理を任せられる。
自分のローカルで利用するportageのoverlayを用意しておくと良い。
大抵の場合は他のebuildを参考にシェルスクリプトを多少書くだけで大丈夫。

- https://wiki.gentoo.org/wiki/Creating_an_ebuild_repository
- https://wiki.gentoo.org/wiki/Basic_guide_to_write_Gentoo_Ebuilds
- https://devmanual.gentoo.org/

---

# 39. Gaming

SteamがかなりLinux環境でのPCゲームに力を入れているので、大半のゲームは普通に動作する。
Arch Linux系なら普通にsteamパッケージを入れればいい。
Gentoo系なら`eselect repository enable steam-overlay`でOverlayを有効にしてsteam-launcherをインストールする。
基本的にProtonのおかげで大体のゲームは動作するが、コピーガードやアンチチートなどが邪魔することもある。
描画パフォーマンスなどを最適化するならいくつかのツールを活用した方がいい。
とりあえず[steamtinkerlaunch](https://github.com/sonic2kk/steamtinkerlaunch)と[gamescope](https://github.com/ValveSoftware/gamescope)を利用することをオススメする。

詳しくは俺のブログへ。
https://joker1007.hatenablog.com/entry/2022/11/28/014825


---

# 40. GPU

nvidia系のGPUを利用する場合はプロプライエタリのドライバが必要になる。
CUDAを使いたいならnvidiaにするしかないが、AMDのGPUはちゃんとカーネルにコントリビュートしていて本体にドライバが組込まれているので、CUDAが滅茶苦茶必要という訳でないならAMDをオススメする。
(AI需要でちょっとAMDの肩身が狭いが……)

---

# Linuxで困ることは特に何もないことが分かったと思う。

# Arch Wikiが凄いことも分かったと思う。

# Linux怖くない！

# Let's Linux Life
