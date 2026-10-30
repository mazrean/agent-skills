#!/usr/bin/env bash
# 実験用カーネル (upstream 6.17.13 + ENA XDP_TX 共有 Tx リング/doorbell まとめ + PREEMPT_NONE) を .deb にする。
#   W=<作業ディレクトリ> ./build.sh            → $W/linux-image-6.17.13-isucon_*.deb
# - config-6.17.13-isucon: Ubuntu 24.04 の 6.17 AWS カーネル (6.17.0-1019-aws) の config を、
#   EC2 c5 系で lsmod を取って localmodconfig し、PREEMPT_NONE / LOCALVERSION=-isucon / 署名鍵を空にしたもの。
#   ENA / NVMe / virtio-net / Xen blkfront は組み込み (=y)。mitigations / LSM / audit は stock のまま。
#   別の環境向けには、その環境の /boot/config-* と lsmod から作り直す (make localmodconfig)。
# - ビルド依存: build-essential flex bison libelf-dev libssl-dev bc dwarves cpio rsync (debhelper は不要: DPKG_FLAGS=-d)
# ビルド者・ホスト・時刻は固定値にする (公開用バイナリに手元の情報を入れない)。
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
W=${W:?work dir}
V=${V:-6.17.13}
mkdir -p "$W"; cd "$W"
[ -d linux-$V ] || { [ -f linux-$V.tar.xz ] || curl -fsSO https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$V.tar.xz; tar xf linux-$V.tar.xz; }
cd linux-$V
if patch -p1 -N --dry-run < "$here/0001-ena-xdp-shared-tx-batched-doorbell.patch" >/dev/null 2>&1; then
  patch -p1 -N < "$here/0001-ena-xdp-shared-tx-batched-doorbell.patch"
fi
command cp -f "$here/config-$V-isucon" .config
[ -n "${ENV:-}" ] && . "$ENV"          # ツールを sudo 無しで展開した場合の PATH 等
export KBUILD_BUILD_USER=${KBUILD_BUILD_USER:-isucon} KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST:-build}
export KBUILD_BUILD_TIMESTAMP=${KBUILD_BUILD_TIMESTAMP:-"2026-10-30 00:00:00 UTC"}
export KDEB_PKGVERSION=${KDEB_PKGVERSION:-$V-1} DEBEMAIL=${DEBEMAIL:-isucon@localhost} DEBFULLNAME=${DEBFULLNAME:-isucon}
make olddefconfig >/dev/null
make -j"$(nproc)" KCFLAGS="-ffile-prefix-map=$W/=" bindeb-pkg DPKG_FLAGS=-d >| "$W/build.log" 2>&1 || { tail -30 "$W/build.log"; exit 1; }
ls -la "$W"/linux-image-$V-isucon_*.deb
