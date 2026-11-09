# 紹介動画の作り方

`docs/video/intro.mp4` は、このフォルダのファイルで作っています。

| ファイル | 内容 |
|---|---|
| `script.json` | 台本（場面ごとの見出し・字幕・読み上げる文）。読み間違いを防ぐため、読み上げる文は一部をひらがなにしている |
| `tts.py` | 台本を Kokoro（Apache 2.0）で読み上げ、場面ごとの音声と長さ（`durations.json`）を作る |
| `stage.html` | 左にアプリ、右に字幕を並べる 1280x720 の画面 |
| `record.js` | Playwright でアプリを操作しながら録画する。振る場面は、ブラウザに揺れのデータ（devicemotion）を送って再現する |
| `avatar.png` | アイコンを写真にする場面で使うイラスト |

おおまかな手順:

1. `flutter build web --release --no-web-resources-cdn` でアプリを作り、`stage.html` を `build/web/` にコピーして `http://localhost:8780` で配信する
2. Python 3.12 の環境で `pip install kokoro "misaki[ja]" soundfile` と `python -m unidic download` をしてから、`python tts.py jf_alpha`
3. `node record.js <出力フォルダ> durations.json` で録画する
4. ffmpeg で録画と場面ごとの音声を重ねて MP4 にする（各場面の開始時刻は録画フォルダの `timeline.json`）
