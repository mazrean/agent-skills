#!/usr/bin/env bash
# XDP L4 ロードバランサ (xdp-lb.o) を front ホストで on/off する。root で実行。実験用 — 既定では使わない。
#   SELF=<front の private IP> CLIENT=<ベンチの IP> TARGETS="<ip>:<buckets> ..." xdp-lb.sh on|off
#   TARGETS の buckets は 64 のうち何個をその転送先に回すか (残りは front 自身)。例: "10.0.0.3:29 10.0.0.2:14"
# 前提:
# - 転送先 (TARGETS の各ホスト) で: ip route replace <SELF>/32 dev <IF> mtu lock $MTU advmss $((MTU-40))
# - パッチ済み ENA (assets/kernel, xdp_shared_tx=Y) ならキュー数はそのまま。stock ENA では 1 キュー + RPS になる。
# - on にすると TLS-LB (iptables DNAT/flowtable) を外す。off で元に戻す。
# - xdp-lb.o: Release 同梱のもの、または clang -O2 -g -target bpf -c xdp-lb.c -o xdp-lb.o
set -u
IF=${NET_IF:-$(ip -o route show default | grep -o "dev [^ ]*" | head -1 | cut -d" " -f2)}
OBJ=${OBJ:-/usr/local/lib/isucon/xdp-lb.o}; PIN=/sys/fs/bpf/xdplb
MTU=${MTU:-3498}; MTU_OFF=${MTU_OFF:-9001}
BPFTOOL=$(ls /usr/lib/linux-tools/*/bpftool 2>/dev/null | head -1); BPFTOOL=${BPFTOOL:-bpftool}
iphex() { echo "$1" | awk -F. '{printf "%d %d %d %d", $1,$2,$3,$4}'; }
machex() { ip neigh show "$1" dev "$IF" | awk '{print $3}' | python3 -c "import sys;m=sys.stdin.read().split()[0];v=int(m.replace(':',''),16);print(' '.join(str(b) for b in v.to_bytes(8,'little')))"; }
case ${1:-} in
on)
  : "${SELF:?}" "${CLIENT:?}" "${TARGETS:?}"
  PEERS="$CLIENT"; for t in $TARGETS; do PEERS="$PEERS ${t%%:*}"; done
  nft delete table inet isucon_ft 2>/dev/null; iptables -t nat -F ISUCON_LB 2>/dev/null
  SHARED=$(cat /sys/module/ena/parameters/xdp_shared_tx 2>/dev/null || echo N)
  [ "$SHARED" = Y ] || { ethtool -L "$IF" combined 1 2>&1; sleep 2; }
  ip link set dev "$IF" mtu "$MTU"
  for ip in $PEERS; do ping -c1 -W1 "$ip" >/dev/null; m=$(ip neigh show "$ip" dev "$IF" | awk '{print $3}'); ip neigh replace "$ip" lladdr "$m" dev "$IF" nud permanent; done
  ip link set dev "$IF" xdpdrv off 2>/dev/null
  rm -rf $PIN; mkdir -p $PIN
  $BPFTOOL prog load "$OBJ" $PIN/prog type xdp pinmaps $PIN || exit 1
  selfmac=$(python3 -c "import sys;print(' '.join(str(int(x,16)) for x in open('/sys/class/net/$IF/address').read().strip().split(':')))")
  ifx=$(cat /sys/class/net/"$IF"/ifindex)
  $BPFTOOL map update pinned $PIN/cfg_map key 0 0 0 0 value $(iphex "$SELF") $(iphex "$CLIENT") $ifx 0 0 0 $selfmac 0 0
  b=0
  for t in $TARGETS; do ip=${t%%:*}; n=${t#*:}; for _ in $(seq 1 "$n"); do
    $BPFTOOL map update pinned $PIN/bucket_map key $b 0 0 0 value $(iphex "$ip"); b=$((b+1)); done; done
  for ip in $PEERS; do $BPFTOOL map update pinned $PIN/mac_map key $(iphex "$ip") value $(machex "$ip"); done
  ip link set dev "$IF" xdpdrv pinned $PIN/prog || exit 1
  if [ "$SHARED" = Y ]; then
    /usr/local/bin/isucon-net-tune.sh          # XDP を付けると ENA が再初期化されるので IRQ/XPS を再設定
  else
    echo 3 > /sys/class/net/"$IF"/queues/rx-0/rps_cpus; echo 3 > /sys/class/net/"$IF"/queues/tx-0/xps_cpus
  fi
  systemctl restart nginx ;;
off)
  ip link set dev "$IF" xdpdrv off 2>/dev/null; rm -rf $PIN
  for ip in ${CLIENT:-} ${TARGETS:-}; do ip neigh del "${ip%%:*}" dev "$IF" 2>/dev/null; done
  ip link set dev "$IF" mtu "$MTU_OFF"
  max=$(ethtool -l "$IF" | awk '/^Combined/{print $2}' | head -1)
  ethtool -L "$IF" combined "$max" 2>/dev/null; sleep 2
  echo 0 > /sys/class/net/"$IF"/queues/rx-0/rps_cpus 2>/dev/null
  /usr/local/bin/isucon-net-tune.sh; systemctl restart isucon-tls-lb nginx ;;
*) echo "usage: SELF=.. CLIENT=.. TARGETS=.. $0 on|off" >&2; exit 2 ;;
esac
