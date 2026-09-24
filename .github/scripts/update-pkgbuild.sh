#!/usr/bin/env bash
# 按选定好的上游 release 重写 PKGBUILD（pkgver / pkgrel / _upstream_tag / 校验和）
# 并重新生成 .SRCINFO。只改工作区，不 commit（提交与推送由 workflow 负责）。
#
# 环境变量：
#   UPSTREAM_TAG  上游 release tag，例如 v1.9.1 或 v1.9.0-beta.1
#   NEW_PKGVER    映射后的合法 pkgver，例如 1.9.1 或 1.9.0beta.1
#
# 同版本重传资产的场景（上游重建 release、sha256 变化）会在这里体现为 pkgrel+1，
# 这是之前 workflow 只比版本号时永远发现不了的漏洞。
set -euo pipefail

UPSTREAM_TAG="${UPSTREAM_TAG:?必须提供 UPSTREAM_TAG}"
NEW_PKGVER="${NEW_PKGVER:?必须提供 NEW_PKGVER}"

[ -f PKGBUILD ] || { echo "::error::当前目录没有 PKGBUILD" >&2; exit 1; }

get_field() { sed -n "s/^$1=//p" PKGBUILD | head -n1; }
sums_block() { awk '/^sha256sums=\(/{inside=1} inside{print} inside&&/\)[[:space:]]*$/{exit}' PKGBUILD; }

OLD_PKGVER="$(get_field pkgver)"
OLD_PKGREL="$(get_field pkgrel)"
OLD_TAG="$(get_field _upstream_tag)"
SUMS_BEFORE="$(sums_block)"

case "$NEW_PKGVER" in
  *[!A-Za-z0-9._]*|'') echo "::error::非法 pkgver: '$NEW_PKGVER'（只允许字母、数字、点、下划线）" >&2; exit 1 ;;
esac
[ -n "$OLD_TAG" ] || { echo "::error::PKGBUILD 缺少 _upstream_tag，无法安全改写 source URL" >&2; exit 1; }
[ -n "$OLD_PKGREL" ] || { echo "::error::PKGBUILD 缺少 pkgrel" >&2; exit 1; }

# 1) 版本与上游 tag
sed -i "s|^_upstream_tag=.*|_upstream_tag=${UPSTREAM_TAG}|" PKGBUILD
if [ "$OLD_PKGVER" != "$NEW_PKGVER" ]; then
  sed -i "s|^pkgver=.*|pkgver=${NEW_PKGVER}|" PKGBUILD
  sed -i "s|^pkgrel=.*|pkgrel=1|" PKGBUILD
fi

# 2) 校验和。资产缺失/改名会在这里直接失败（不会静默产出旧包）
updpkgsums

# 3) 版本没变、但包内容变了（上游重传资产或换了 tag）-> pkgrel+1
SUMS_AFTER="$(sums_block)"
if [ "$OLD_PKGVER" = "$NEW_PKGVER" ] &&
  { [ "$SUMS_BEFORE" != "$SUMS_AFTER" ] || [ "$OLD_TAG" != "$UPSTREAM_TAG" ]; }; then
  sed -i "s|^pkgrel=.*|pkgrel=$((OLD_PKGREL + 1))|" PKGBUILD
fi

# 4) 重新生成 .SRCINFO
makepkg --printsrcinfo >.SRCINFO

FINAL_PKGVER="$(get_field pkgver)"
FINAL_PKGREL="$(get_field pkgrel)"
FINAL_TAG="$(get_field _upstream_tag)"

if [ "$OLD_PKGVER" != "$FINAL_PKGVER" ]; then
  reason=upstream-version
elif [ "$SUMS_BEFORE" != "$SUMS_AFTER" ]; then
  reason=upstream-rebuilt-assets
elif [ "$OLD_TAG" != "$FINAL_TAG" ]; then
  reason=upstream-retag
else
  reason=same-as-upstream
fi

printf 'pkgver=%s\n' "$FINAL_PKGVER"
printf 'pkgrel=%s\n' "$FINAL_PKGREL"
printf '_upstream_tag=%s\n' "$FINAL_TAG"
printf 'reason=%s\n' "$reason"
