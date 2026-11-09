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
| cupertino_icons | アイコン | MIT |

`flutter build web` で作られる `assets/NOTICES` に、同梱される全ライブラリのライセンスが出力される。

## イラスト・画像

| 名前 | 出典 | ライセンス |
|---|---|---|
| シェイカーのイラスト | チームが作成（`lib/widgets/shaker.dart` でコードとして描画） | 本リポジトリのライセンスに従う |
| デモで使う写真・動画 | 【要記入：撮影者・写っている人の許可】 | 【要記入】 |

## データ

| 名前 | 用途 | 出典 |
|---|---|---|
| 仮データ（友達の名前・記録） | 画面確認用（架空） | チームが作成 |
| 課題の根拠となる統計 | 説明ドキュメント | 【要記入：例 厚生労働省「国民健康・栄養調査」】 |

## AI の利用

| 名前 | 用途 |
|---|---|
| Gemini（Vertex AI） | プロダクト内：袋の写真の読み取り・今週のふりかえり（予定） |
| Claude Code | 開発中のコーディング支援（プロダクトには含まれない） |
