# 著作物利用シート（下書き）

運営の著作物利用シートに転記する。アプリに同梱・利用している素材、ライブラリ、データの出典とライセンス。

## フォント（アプリに同梱）

| 名前 | 出典 | ライセンス | 同梱ファイル |
|---|---|---|---|
| Noto Sans JP | Google Fonts（https://fonts.google.com/noto/specimen/Noto+Sans+JP） | SIL Open Font License 1.1 | `assets/fonts/NotoSansJP-*.ttf`、ライセンス文 `assets/fonts/OFL-NotoSansJP.txt` |
| Zen Maru Gothic | Google Fonts（https://fonts.google.com/specimen/Zen+Maru+Gothic） | SIL Open Font License 1.1 | `assets/fonts/ZenMaruGothic-Black.ttf`、ライセンス文 `assets/fonts/OFL-ZenMaruGothic.txt` |
| Material Icons | Flutter に同梱 | Apache License 2.0 | （ビルド時に同梱） |

## ライブラリ

| 名前 | 用途 | ライセンス |
|---|---|---|
| Flutter SDK | 画面全体 | BSD 3-Clause |
| go_router | 画面の移動 | BSD 3-Clause |
| web（package:web） | ブラウザの加速度センサー・写真選択 | BSD 3-Clause |
| sensors_plus | iPhone アプリの加速度センサー | BSD 3-Clause |
| image_picker | iPhone アプリの写真選択 | BSD 3-Clause |
| cupertino_icons | アイコン | MIT |

`flutter build web` で作られる `assets/NOTICES` に、同梱される全ライブラリのライセンスが出力される。

## イラスト・画像

| 名前 | 出典 | ライセンス |
|---|---|---|
| シェイカーのイラスト | チームが作成（`lib/widgets/shaker.dart` でコードとして描画） | 本リポジトリのライセンスに従う |
| アーキテクチャ図・スクリーンショット | チームが作成（`docs/images/`） | 本リポジトリのライセンスに従う |
| デモ動画の映像・写真 | 【要記入：撮影者の名前。写っている人がいれば許可を取ったこと】 | チームが撮影 |
| デモ動画の音楽 | 【要記入：使った場合だけ。曲名・出典・ライセンス。使わなければ行ごと消す】 | |

## データ

| 名前 | 用途 | 出典 |
|---|---|---|
| 仮データ（友達の名前・記録） | 画面確認用（架空） | チームが作成 |
| 課題の根拠となる統計 | 説明ドキュメント・デモ動画 | スポーツ庁「令和6年度 スポーツの実施状況等に関する世論調査」（https://www.mext.go.jp/sports/b_menu/houdou/jsa_00202.html）。出典を明記して数値を引用 |

## 紹介動画

| 名前 | 出典 | ライセンス |
|---|---|---|
| ナレーション音声 | Kokoro-82M（https://huggingface.co/hexgrad/Kokoro-82M）、音声 `jf_alpha` で生成 | Apache License 2.0 |
| 読み上げ用の日本語辞書 | UniDic（misaki・fugashi 経由で使用。動画の作成時のみ） | GPL・LGPL・BSD のいずれかを選べる（UniDic Consortium）。BSD を選択 |
| アイコン用のイラスト | チームが作成（`scripts/video/avatar.png`。実在の人物ではない） | 本リポジトリのライセンスに従う |

## AI の利用

| 名前 | 用途 |
|---|---|
| Gemini（Vertex AI） | プロダクト内：袋の写真の読み取り・今週のふりかえり（予定） |
| Claude Code | 開発中のコーディング支援（プロダクトには含まれない） |
| Kokoro-82M | 紹介動画のナレーション（プロダクトには含まれない） |
