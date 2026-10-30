#!/usr/bin/env bash
# NIC 割り込みとキューを CPU と 1 対 1 に揃える (マルチキュー NIC: ENA / virtio-net など)。
#   NET_IF で NIC を指定可 (既定: デフォルトルートの NIC)。冪等。systemd の oneshot から毎起動実行する。
# - irqbalance は複数キューの割り込みを同じ CPU に寄せることがある (観測例: 2 キューとも CPU0) ので止めて、
#   キュー N の割り込みを CPU N に固定する (softirq を全コアに分散)
# - XPS で送信キューも CPU と 1 対 1 に揃える (送信キューのロック競合を避ける)
# - qdisc を fq_codel から軽い pfifo_fast に替える (サーバー用途で AQM は不要)
# nginx の worker_cpu_affinity auto + reuseport + SO_INCOMING_CPU (nginx-awslc のパッチ) と組み合わせると、
# 1 本の接続の割り込み・TCP 処理・nginx ワーカーが同じ CPU に収まる。
set -euo pipefail
IF=${NET_IF:-$(ip -o route show default | grep -o "dev [^ ]*" | head -1 | cut -d" " -f2)}
ncpu=$(nproc)
systemctl stop irqbalance 2>/dev/null || true

# 割り込み名の末尾の数字をキュー番号とみなす (ENA: ens5-Tx-Rx-0, virtio: virtio0-input.0 など)
i=0
grep -E "$IF|virtio[0-9]+-(input|output)" /proc/interrupts | while read -r line; do
  irq=${line%%:*}; irq=${irq// /}
  name=${line##* }
  q=$(grep -oE '[0-9]+$' <<<"$name" || echo $i)
  echo $((q % ncpu)) > "/proc/irq/$irq/smp_affinity_list" 2>/dev/null || true
  i=$((i + 1))
done

for q in /sys/class/net/"$IF"/queues/tx-*; do
  n=${q##*tx-}
  printf '%x' $((1 << (n % ncpu))) > "$q/xps_cpus" 2>/dev/null || true
done

sysctl -q -w net.core.default_qdisc=pfifo_fast
tc qdisc replace dev "$IF" root mq 2>/dev/null || true
