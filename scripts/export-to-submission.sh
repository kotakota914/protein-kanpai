#!/usr/bin/env bash
# 提出用リポジトリ（運営の df-2026-t071）に、このリポジトリの最新版をコピーしてコミットする。
#
# 使い方:
#   git clone https://github.com/Devfest-Hackathon-2026/df-2026-t071.git ../df-2026-t071
#   scripts/export-to-submission.sh ../df-2026-t071
#   （内容を確認してから）cd ../df-2026-t071 && git push
#
# - 履歴ごとではなく、最新のファイルだけをコピーする（過去のコミットに秘密情報が残っていても公開されない）
# - アプリは提出用リポジトリの app/ に置く（運営の README・LICENSE はそのまま残す）
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
cd "$dest"
git add app
if git diff --cached --quiet; then
  echo "変更はありません（すでに最新です）"
  exit 0
fi
git commit -q -m "Add app source from protein-kanpai ($rev)"
echo "コミットしました: $(git log --oneline -1)"
echo "内容を確認してから、$dest で git push してください"
