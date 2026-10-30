#!/usr/bin/env bash
# 負荷 (ベンチ 1 回 / 合成負荷) の前後で各ホストのカウンタを取り、差分を 1 行ずつ出す。
# スコアよりぶれが小さく、ベンチのキューを待たずに「どのホストの何が減ったか」を比べられる。
#   usage: node-metrics.sh start            # 全ホストのカウンタを保存
#          node-metrics.sh stop             # 差分を表示
#   HOSTS="isu1 isu2 isu3"  (ssh エイリアス)   STATE_DIR=/tmp/node-metrics
set -euo pipefail
HOSTS=${HOSTS:?set HOSTS="isu1 isu2 isu3"}
STATE_DIR=${STATE_DIR:-/tmp/node-metrics}
mkdir -p "$STATE_DIR"

snap() { # 1 行: user nice system idle iowait irq softirq steal | tx_bytes rx_bytes | allowance... | tcp...
  timeout 15 ssh -o BatchMode=yes -o ConnectTimeout=5 "$1" 'bash -s' </dev/null <<'R'
IF=$(ip -o route show default | grep -o "dev [^ ]*" | head -1 | cut -d" " -f2)
read -r _ u n s i w q sq st _ < /proc/stat
tx=$(cat /sys/class/net/$IF/statistics/tx_bytes); rx=$(cat /sys/class/net/$IF/statistics/rx_bytes)
al=$(sudo ethtool -S "$IF" 2>/dev/null | awk '{sub(":","",$1); v[$1]=$2} END{printf "%d %d %d %d", v["bw_in_allowance_exceeded"], v["bw_out_allowance_exceeded"], v["pps_allowance_exceeded"], v["conntrack_allowance_exceeded"]}')
tcp=$(nstat -az TcpPassiveOpens TcpActiveOpens TcpRetransSegs TcpExtListenDrops 2>/dev/null | awk 'NR>1{v[$1]=$2} END{printf "%d %d %d %d", v["TcpPassiveOpens"], v["TcpActiveOpens"], v["TcpRetransSegs"], v["TcpExtListenDrops"]}')
echo "$u $n $s $i $w $q $sq $st $tx $rx ${al:-0 0 0 0} ${tcp:-0 0 0 0} $(date +%s.%N)"
R
}

case ${1:-} in
start) for h in $HOSTS; do snap "$h" >| "$STATE_DIR/$h"; done ;;
stop)
  printf '%-10s %6s %6s %6s %6s %8s %8s %9s %9s %8s %8s\n' host usr% sys% soft% idle% txMB/s rxMB/s bwOutDrop ppsDrop accept/s retrans/s
  for h in $HOSTS; do
    a=$(cat "$STATE_DIR/$h"); b=$(snap "$h")
    python3 - "$h" "$a" "$b" <<'P'
import sys
h,a,b=sys.argv[1],list(map(float,sys.argv[2].split())),list(map(float,sys.argv[3].split()))
d=[y-x for x,y in zip(a,b)]
cpu=sum(d[0:8]) or 1; sec=d[-1] or 1
# 列: 0 user 1 nice 2 sys 3 idle 4 iowait 5 irq 6 softirq 7 steal | 8 tx 9 rx | 10 bw_in 11 bw_out 12 pps 13 conntrack | 14 passive 15 active 16 retrans 17 listendrop
print(f"{h:<10} {100*(d[0]+d[1])/cpu:6.1f} {100*d[2]/cpu:6.1f} {100*(d[5]+d[6])/cpu:6.1f} {100*(d[3]+d[4])/cpu:6.1f} "
      f"{d[8]/sec/1e6:8.1f} {d[9]/sec/1e6:8.1f} {d[11]:9.0f} {d[12]:9.0f} {d[14]/sec:8.0f} {d[16]/sec:8.0f}")
P
  done ;;
*) echo "usage: $0 start|stop" >&2; exit 2 ;;
esac
