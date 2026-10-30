#!/usr/bin/env bash
# ベンチからの :443 の新規接続を、カーネル (netfilter) で複数の nginx に振り分ける。
# TLS 終端の CPU を複数ノードに分散するため。戻りは MASQUERADE で本ノード経由にする。
#   LB_TARGETS: 転送先の private IP (空白区切り)。本ノード自身の nginx も 1 台分として扱う。
set -euo pipefail
LB_TARGETS=${LB_TARGETS:-}
sysctl -q -w net.ipv4.ip_forward=1
iptables -t nat -N ISUCON_LB 2>/dev/null || iptables -t nat -F ISUCON_LB
iptables -t nat -C PREROUTING -p tcp --dport 443 -j ISUCON_LB 2>/dev/null || iptables -t nat -A PREROUTING -p tcp --dport 443 -j ISUCON_LB
iptables -t nat -N ISUCON_LB_POST 2>/dev/null || iptables -t nat -F ISUCON_LB_POST
iptables -t nat -C POSTROUTING -j ISUCON_LB_POST 2>/dev/null || iptables -t nat -A POSTROUTING -j ISUCON_LB_POST
# LB_TARGETS の各要素は "ip" (均等) か "ip:重み"。本ノード自身の重みは LB_SELF_WEIGHT (既定 1)。
# 重み付きは statistic random で、残りの接続に対する条件付き確率を順に設定する。
SELF_W=${LB_SELF_WEIGHT:-1}
total=$SELF_W
for t in $LB_TARGETS; do w=${t#*:}; [ "$w" = "$t" ] && w=1; total=$(python3 -c "print($total+$w)"); done
rest=$total
for t in $LB_TARGETS; do
  ip=${t%%:*}; w=${t#*:}; [ "$w" = "$t" ] && w=1
  p=$(python3 -c "print(f'{$w/$rest:.6f}')")
  iptables -t nat -A ISUCON_LB -p tcp --dport 443 -m conntrack --ctstate NEW -m statistic --mode random --probability "$p" -j DNAT --to-destination "$ip:443"
  iptables -t nat -A ISUCON_LB_POST -p tcp -d "$ip" --dport 443 -j MASQUERADE
  rest=$(python3 -c "print($rest-$w)")
done

# 確立済みの転送フローを nftables の flowtable (ソフトウェア fast path) に載せ、
# 転送パケットごとの netfilter 処理 (softirq) を減らす。NAT も flowtable 内で適用される。
IF=${NET_IF:-$(ip -o route show default | grep -o "dev [^ ]*" | head -1 | cut -d" " -f2)}
nft delete table inet isucon_ft 2>/dev/null || true
if [ -n "$LB_TARGETS" ]; then
  nft -f - <<NFT
table inet isucon_ft {
  flowtable ft {
    hook ingress priority 0
    devices = { $IF }
  }
  chain forward {
    type filter hook forward priority 0; policy accept;
    meta l4proto tcp flow add @ft
  }
}
NFT
fi
