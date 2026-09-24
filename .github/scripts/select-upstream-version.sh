#!/usr/bin/env bash
# 选出「上游最新的可打包 release」，供 auto-update workflow 使用。
#
# 前提：AUR 包就是上游 release 的镜像，不区分 stable / prerelease。
#
# 因此版本来源必须是 release 列表，而不是 tags：上游存在只有 tag、没有 release
# 的版本（例如 v1.2.2，/releases/tags/v1.2.2 返回 404），用 tags 会永远等不到资产。
#
# tag -> pkgver 的映射必须同时满足两件事：
#   1. pkgver 合法：按 Arch wiki，上游版本里的连字符要换成下划线
#   2. vercmp 排序与上游语义一致。实测（pacman vercmp）：
#        v1.3.0-1      -> 1.3.0_1      1.3.0_1 > 1.3.0, 且 < 1.3.1          ✅
#        v1.9.0-beta.1 -> 1.9.0beta.1  1.9.0beta.1 < 1.9.0                  ✅
#        v1.9.0-beta.1 -> 1.9.0_beta.1 1.9.0_beta.1 > 1.9.0（会把正式版永久挡住）❌
#   所以预发布后缀去连字符，其余连字符换下划线。
#
# 行为约定（宁可红，不要静默不动 —— 之前的 84 天零提交就是这么来的）：
#   * 上游最新 release 的必需资产缺失 -> 先等（可能正在上传），超时后报错退出
#   * 上游最新可打包版本比当前 pkgver 旧 -> 报错退出，绝不降级 AUR
#
# stdout: tag=... / pkgver=... / new_version=true|false（可直接 tee 到 $GITHUB_OUTPUT）
# stderr: 诊断信息与 ::error:: 注解
set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-AkaraChen/aghub}"
CURRENT_PKGVER="${CURRENT_PKGVER:-}"
# %s 会被替换成去掉前导 v 的 tag
REQUIRED_ASSETS="${REQUIRED_ASSETS:-aghub_%s_amd64.deb aghub-cli-x86_64-unknown-linux-gnu.tar.gz}"
ASSET_ATTEMPTS="${ASSET_ATTEMPTS:-11}"
ASSET_INTERVAL="${ASSET_INTERVAL:-60}"

log() { printf '%s\n' "$*" >&2; }

api() {
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl -fsSL -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H 'Accept: application/vnd.github+json' "$@"
  else
    curl -fsSL -H 'Accept: application/vnd.github+json' "$@"
  fi
}

# v1.3.0-1 -> 1.3.0_1 / v1.9.0-beta.1 -> 1.9.0beta.1 / v1.0.4-alpha1 -> 1.0.4alpha1
to_pkgver() {
  local v="${1#v}"
  v="$(sed -E 's/[-.](alpha|beta|rc|pre)([.-]?)/\1\2/Ig' <<<"$v")"
  printf '%s' "${v//-/_}"
}

# TSV: tag \t prerelease \t published_at \t asset,asset,...
fetch_releases() {
  local page=1 rows
  while [ "$page" -le 5 ]; do
    rows="$(api "https://api.github.com/repos/${UPSTREAM_REPO}/releases?per_page=100&page=${page}" |
      jq -r '.[] | [.tag_name, (.prerelease | tostring), (.published_at // ""), ([.assets[].name] | join(","))] | @tsv')"
    [ -n "$rows" ] || break
    printf '%s\n' "$rows"
    page=$((page + 1))
  done
}

# 结果放进全局变量
BEST_ANY_TAG=''; BEST_ANY_VER=''; BEST_ANY_PRE=''; BEST_ANY_PUB=''
BEST_PKG_TAG=''; BEST_PKG_VER=''
select_best() {
  local tag pre pub assets ver name tmpl ok
  BEST_ANY_TAG=''; BEST_ANY_VER=''; BEST_ANY_PRE=''; BEST_ANY_PUB=''
  BEST_PKG_TAG=''; BEST_PKG_VER=''
  while IFS=$'\t' read -r tag pre pub assets; do
    [ -n "$tag" ] || continue
    ver="$(to_pkgver "$tag")"
    case "$ver" in
      *-*) log "::error::tag $tag 映射出的 pkgver '$ver' 含连字符，不合法"; exit 1 ;;
    esac
    if [ -z "$BEST_ANY_VER" ] || [ "$(vercmp "$ver" "$BEST_ANY_VER")" -gt 0 ]; then
      BEST_ANY_TAG="$tag"; BEST_ANY_VER="$ver"
      BEST_ANY_PRE="$pre"; BEST_ANY_PUB="$pub"
    fi
    ok=1
    for tmpl in $REQUIRED_ASSETS; do
      # shellcheck disable=SC2059
      name="$(printf "$tmpl" "${tag#v}")"
      case ",$assets," in
        *",$name,"*) ;;
        *) ok=0 ;;
      esac
    done
    if [ "$ok" = 1 ] && { [ -z "$BEST_PKG_VER" ] || [ "$(vercmp "$ver" "$BEST_PKG_VER")" -gt 0 ]; }; then
      BEST_PKG_TAG="$tag"; BEST_PKG_VER="$ver"
    fi
  done < <(fetch_releases)
}

main() {
  : "${CURRENT_PKGVER:?必须提供 CURRENT_PKGVER（当前 PKGBUILD 的 pkgver）}"
  log "当前 pkgver: $CURRENT_PKGVER"

  local attempt=1 cmp_result new_version
  while :; do
    select_best
    [ -n "$BEST_PKG_TAG" ] && [ "$BEST_ANY_TAG" = "$BEST_PKG_TAG" ] && break
    [ "$attempt" -ge "$ASSET_ATTEMPTS" ] && break
    log "上游 $BEST_ANY_TAG 已是最新，但其必需资产（$REQUIRED_ASSETS）尚未就绪，等待 ${ASSET_INTERVAL}s（$attempt/$((ASSET_ATTEMPTS - 1))）"
    sleep "$ASSET_INTERVAL"
    attempt=$((attempt + 1))
  done

  if [ "$BEST_ANY_TAG" != "$BEST_PKG_TAG" ]; then
    log "::error::上游最新 release 是 ${BEST_ANY_TAG:-<无>}（prerelease=${BEST_ANY_PRE:-?}，发布于 ${BEST_ANY_PUB:-?}），但它的必需资产（${REQUIRED_ASSETS}）缺失或已改名，无法打包。"
    log "::error::这里故意报错而不是跳过：静默跳过会让 AUR 长期停在旧版本。请检查上游资产命名后调整 PKGBUILD/REQUIRED_ASSETS。"
    exit 1
  fi

  cmp_result="$(vercmp "$BEST_PKG_VER" "$CURRENT_PKGVER")"
  if [ "$cmp_result" -lt 0 ]; then
    log "::error::上游最新可打包版本 $BEST_PKG_TAG -> $BEST_PKG_VER 比当前 pkgver $CURRENT_PKGVER 旧。"
    log "::error::拒绝把 AUR 包降级（pacman 也不会给用户升级）。请人工确认上游是否回退/重发。"
    exit 1
  fi

  new_version=false
  [ "$cmp_result" -gt 0 ] && new_version=true
  log "上游最新可打包: $BEST_PKG_TAG -> pkgver $BEST_PKG_VER (new_version=$new_version)"

  printf 'tag=%s\n' "$BEST_PKG_TAG"
  printf 'pkgver=%s\n' "$BEST_PKG_VER"
  printf 'new_version=%s\n' "$new_version"
}

# 被 source 时只加载函数（便于单元测试）
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
