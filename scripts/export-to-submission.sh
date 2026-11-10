#!/usr/bin/env bash
# 提出用リポジトリ（運営の df-2026-t071）に、このリポジトリの最新版をコピーしてコミットする。
#
# 使い方:
#   git clone https://github.com/Devfest-Hackathon-2026/df-2026-t071.git ../df-2026-t071
#   scripts/export-to-submission.sh ../df-2026-t071
#   （内容を確認してから）cd ../df-2026-t071 && git push
#
# - 履歴ごとではなく、最新のファイルだけをコピーする（過去のコミットに秘密情報が残っていても公開されない）
# - アプリは提出用リポジトリの app/ に置く（運営の LICENSE などはそのまま残す）
# - 提出用リポジトリの README.md の先頭に、アプリの案内（app/ へのリンク）を入れる。
#   運営が書いた部分は消さない。2 回目以降は案内の部分だけを書き換える
set -euo pipefail

dest="${1:?提出用リポジトリを clone したフォルダを指定してください}"
if [ ! -d "$dest/.git" ]; then
  echo "エラー: $dest は git リポジトリではありません" >&2
  exit 1
fi
dest="$(cd "$dest" && pwd)"

src="$(git rev-parse --show-toplevel)"
cd "$src"

if [ -n "$(git status --porcelain)" ]; then
  echo "エラー: コミットしていない変更があります。先にコミットしてください" >&2
  exit 1
fi

# 秘密情報らしきファイルが入っていないか確認する
if git ls-files | grep -Ei '(^|/)(\.env(\..*)?|.*service-account.*\.json|credentials.*\.json|.*\.pem|.*\.key|google-services\.json|GoogleService-Info\.plist)$'; then
  echo "エラー: 秘密情報らしきファイルがあります（上の一覧）。中止します" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git archive HEAD | tar -x -C "$tmp"

rm -rf "$dest/app"
mkdir -p "$dest/app"
cp -R "$tmp"/. "$dest/app"/

rev="$(git rev-parse --short HEAD)"

# 提出用リポジトリの README.md の先頭に、審査員向けの案内を入れる
python3 - "$dest/README.md" "$rev" <<'PY'
import os, re, sys
path, rev = sys.argv[1], sys.argv[2]
start, end = "<!-- protein-kanpai:start -->", "<!-- protein-kanpai:end -->"
block = f"""{start}
# プロテインで乾杯

シェイカーを振ったら、今日の筋トレ完了。友達と同時に振れば「乾杯」になる。運動を一人で続けられない人のためのアプリです。

- **公開版（スマホのブラウザで開く。iPhone は Safari）**：https://protein-kanpai-t071.web.app
  - 仮のデータで動く版。振る検知は本物で、iPhone の実機で確認済み。サーバーは実装とローカルでの接続確認まで済み、公開版にはまだつないでいない
- **アプリのソースと詳しい説明**：[app/README.md](app/README.md)
- **サーバー（FastAPI / Cloud Run 用）**：[app/backend/](app/backend/)、API の約束は [app/docs/api-contract.md](app/docs/api-contract.md)
- **実機デモ動画（30 秒。iPhone で実際に振っている手元と画面）**：[app/docs/video/demo.mp4](app/docs/video/demo.mp4)
- **紹介動画**：[app/docs/video/intro.mp4](app/docs/video/intro.mp4)
- **プロダクト説明**：[app/docs/product.md](app/docs/product.md)
- **アーキテクチャ図**：[app/docs/images/architecture.png](app/docs/images/architecture.png)
- **著作物利用シート**：[app/docs/copyright-sheet.md](app/docs/copyright-sheet.md)
- 開発用リポジトリ：https://github.com/kotakota914/protein-kanpai （`{rev}` 時点の内容をコピー。サーバーと接続のコードはプルリクエスト #1・#2 として提出中）

![アプリの画面](app/docs/images/02-home.png)
{end}
"""
old = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
if start in old and end in old:
    new = re.sub(re.escape(start) + ".*?" + re.escape(end) + "\n?", lambda m: block, old, flags=re.S)
else:
    new = block + ("\n---\n\n" + old if old.strip() else "")
open(path, "w", encoding="utf-8").write(new)
PY

cd "$dest"
git add app README.md
if git diff --cached --quiet; then
  echo "変更はありません（すでに最新です）"
  exit 0
fi
git commit -q -m "Add app source from protein-kanpai ($rev)"
echo "コミットしました: $(git log --oneline -1)"
echo "内容を確認してから、$dest で git push してください"
