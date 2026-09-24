#!/usr/bin/env python3
"""比较 AUR 上已有的 PKGBUILD 与本地 PKGBUILD，判断是否值得推送。

只比对决定用户实际拿到什么的字段（版本、依赖、校验和、上游 tag），
避免注释/空行这类无意义差异导致每天空推一次。

用法: aur-drift.py <aur-PKGBUILD> <local-PKGBUILD>
退出码: 0 = 一致（无需发布）, 1 = 有差异（需要发布）
"""
import re
import sys

FIELDS = [
    "_upstream_tag",
    "pkgver",
    "pkgrel",
    "depends",
    "optdepends",
    "provides",
    "conflicts",
    "sha256sums",
]


def parse(path):
    with open(path, encoding="utf-8") as fh:
        src = fh.read()
    out = {}
    for key in FIELDS:
        match = re.search(rf"^{re.escape(key)}=\(([^)]*)\)", src, re.M)
        if match is None:
            match = re.search(rf"^{re.escape(key)}=([^\n]*)", src, re.M)
        value = match.group(1) if match else ""
        out[key] = re.sub(r"\s+", " ", value).strip()
    return out


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    aur, local = parse(sys.argv[1]), parse(sys.argv[2])
    same = True
    for key in FIELDS:
        if aur[key] == local[key]:
            print(f"  {key}: {local[key]!r}")
        else:
            same = False
            print(f"* {key}: aur={aur[key]!r} local={local[key]!r}")
    return 0 if same else 1


if __name__ == "__main__":
    sys.exit(main())
