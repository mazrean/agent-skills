#!/usr/bin/env bash
# 実験用カーネルの .deb を 1 台に入れて、1 回だけそのカーネルで起動する (既定は stock のまま)。
#   HOST=isu1 ./install.sh <dir-with-debs>   install + grub-reboot + reboot + 確認
#   HOST=isu1 ./install.sh --default         起動確認・再起動試験の後で、実験用カーネルを既定にする
#   HOST=isu1 ./install.sh --stock           既定を stock に戻して再起動
# 起動に失敗しても、grub-reboot は 1 回限りなので次の再起動で stock に戻る。
# ssh が戻らないときは、クラウドの API で再起動する (例: aws ec2 reboot-instances)。
set -euo pipefail
H=${HOST:?ssh alias of the target host}
KVER=${KVER:-6.17.13-isucon}
r() { ssh -o BatchMode=yes -o ConnectTimeout=10 "$H" "$@" </dev/null; }
STOCK=${STOCK:-$(r "ls /boot/vmlinuz-* | sed 's|/boot/vmlinuz-||' | grep -v -- '-isucon' | sort -V | tail -1")}
ids() { # $1 = kernel version -> "submenu>entry" id for grub
  r "sudo cat /boot/grub/grub.cfg" | awk -v k="$1" -F"'" '/^submenu/{s=$4} /^\tmenuentry /{ if ($2 == "Ubuntu, with Linux " k) print s">"$4 }' | head -1
}
boot_id() { r "cat /proc/sys/kernel/random/boot_id" 2>/dev/null || true; }
wait_up() { # $1 = boot_id before the reboot; "ssh works" is not enough, the boot_id must change
  sleep 15
  for _ in $(seq 1 80); do
    b=$(boot_id); [ -n "$b" ] && [ "$b" != "$1" ] && { sleep 10; return 0; }
    sleep 5
  done
  echo "host did not come back: reboot it via the cloud API and check the console output" >&2; return 1
}
pin_default() { r "echo 'GRUB_DEFAULT=\"$(ids "$1")\"' | sudo tee /etc/default/grub.d/99-isucon-kernel.cfg >/dev/null && sudo update-grub 2>/dev/null"; }
case "${1:-}" in
--default) pin_default "$KVER"; r "cat /etc/default/grub.d/99-isucon-kernel.cfg" ;;
--stock)
  b0=$(boot_id); pin_default "$STOCK"
  r "sudo systemd-run --on-active=2 systemctl reboot" || true
  wait_up "$b0"; r "uname -r" ;;
*)
  D=${1:?dir with linux-image-${KVER}_*.deb}
  r "mkdir -p /tmp/kdeb"
  rsync -a "$D"/linux-image-${KVER}_*.deb "$H:/tmp/kdeb/"
  pin_default "$STOCK"   # 新しい版が grub の先頭に来るので、先に既定を stock に固定
  r "sudo dpkg -i /tmp/kdeb/linux-image-${KVER}_*.deb >/tmp/kdeb/dpkg.log 2>&1; tail -2 /tmp/kdeb/dpkg.log; sudo update-grub 2>/dev/null"
  id=$(ids "$KVER"); echo "one-shot boot: $id"; [ -n "$id" ]
  b0=$(boot_id)
  r "sudo grub-reboot '$id' && sudo systemd-run --on-active=2 systemctl reboot" || true
  wait_up "$b0"
  r 'uname -r; cat /sys/module/ena/parameters/xdp_shared_tx 2>/dev/null; IF=$(ip -o route show default | awk "{print \$5}"); sudo ethtool -l $IF | tail -1; systemctl --failed --no-legend | head' ;;
esac
