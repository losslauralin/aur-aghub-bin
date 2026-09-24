#!/usr/bin/env bash
# 断言 tag -> pkgver 映射在 pacman 的 vercmp 下排序语义正确。
# 这些不变量都是实测出来的（见 select-upstream-version.sh 顶部注释）：一旦映射被改坏，
# AUR 用户要么被永久挡住升级（预发布排在正式版之上），要么拿到降级包。
# 只需要 vercmp（pacman/pacman-contrib），不需要网络。
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=select-upstream-version.sh
source "$here/select-upstream-version.sh"

fail=0
eq() { [ "$2" = "$3" ] || { echo "FAIL $1: 期望 '$3'，实际 '$2'" >&2; fail=1; }; }
lt() { [ "$(vercmp "$2" "$3")" -lt 0 ] || { echo "FAIL $1: vercmp '$2' '$3' 应 < 0" >&2; fail=1; }; }
gt() { [ "$(vercmp "$2" "$3")" -gt 0 ] || { echo "FAIL $1: vercmp '$2' '$3' 应 > 0" >&2; fail=1; }; }

# 映射本身
eq "普通版本" "$(to_pkgver v1.9.1)" "1.9.1"
eq "连字符->下划线" "$(to_pkgver v1.3.0-1)" "1.3.0_1"
eq "预发布去连字符" "$(to_pkgver v1.9.0-beta.1)" "1.9.0beta.1"
eq "alpha 后缀" "$(to_pkgver v1.0.4-alpha1)" "1.0.4alpha1"
eq "无前导 v" "$(to_pkgver 1.2.2)" "1.2.2"

# 关键排序不变量
gt "构建号高于基版本" "$(to_pkgver v1.3.0-1)" "1.3.0"
lt "构建号低于下一版本" "$(to_pkgver v1.3.0-1)" "1.3.1"
lt "beta 低于正式版" "$(to_pkgver v1.9.0-beta.1)" "1.9.0"
lt "alpha 低于正式版" "$(to_pkgver v1.0.4-alpha1)" "1.0.4"
gt "rc 高于 beta" "$(to_pkgver v1.9.0-rc.1)" "$(to_pkgver v1.9.0-beta.1)"
gt "beta.2 高于 beta.1" "$(to_pkgver v1.9.0-beta.2)" "$(to_pkgver v1.9.0-beta.1)"
gt "跨小版本预发布" "$(to_pkgver v1.10.0-beta.1)" "1.9.1"
gt "beta 高于上一正式版" "$(to_pkgver v1.9.0-beta.1)" "1.8.0"

if [ "$fail" = 0 ]; then
  echo "映射不变量全部通过"
else
  echo "::error::tag -> pkgver 映射不变量被破坏，见上面的 FAIL 行" >&2
fi
exit "$fail"
