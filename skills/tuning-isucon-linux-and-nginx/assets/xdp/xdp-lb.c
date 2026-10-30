// SPDX-License-Identifier: GPL-2.0
// front ホストの XDP L4 ロードバランサ: クライアント -> :443 の接続を送信元ポートのハッシュで
// 本ノード (XDP_PASS) / 他ノード (アドレス書き換え + XDP_TX) に振り分ける。
// iptables DNAT + MASQUERADE 相当をステートレスに行う (転送先は本ノード宛てに返信する)。
//   往路: bench:sport -> self:443   => self:sport -> tgt:443
//   復路: tgt:443 -> self:dport     => self:443 -> bench:dport   (bucket(dport) の転送先からのみ)
// 本ノード自身は転送先の :443 に接続しないので (self, port, tgt, 443) は衝突しない。
#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/tcp.h>
#include <linux/in.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

#define NBUCKET 64

struct cfg {
	__u32 self;   /* network order */
	__u32 client; /* network order */
	__u32 ifindex;
	__u8 self_mac[6];
	__u8 pad[2];
};

struct {
	__uint(type, BPF_MAP_TYPE_ARRAY);
	__uint(max_entries, 1);
	__type(key, __u32);
	__type(value, struct cfg);
} cfg_map SEC(".maps");

/* bucket -> 転送先 IP (network order)。0 は本ノード */
struct {
	__uint(type, BPF_MAP_TYPE_ARRAY);
	__uint(max_entries, NBUCKET);
	__type(key, __u32);
	__type(value, __u32);
} bucket_map SEC(".maps");

/* IP (network order) -> MAC (下位 6 byte) */
struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__uint(max_entries, 16);
	__type(key, __u32);
	__type(value, __u64);
} mac_map SEC(".maps");

/* 0: 往路 TX, 1: 復路 TX, 2: MAC 無しで DROP */
struct {
	__uint(type, BPF_MAP_TYPE_PERCPU_ARRAY);
	__uint(max_entries, 4);
	__type(key, __u32);
	__type(value, __u64);
} stats SEC(".maps");

static __always_inline void count(__u32 i)
{
	__u64 *v = bpf_map_lookup_elem(&stats, &i);
	if (v)
		*v += 1;
}

static __always_inline __u32 bucket_of(__u16 port_host)
{
	return ((__u32)port_host * 2654435761u >> 16) % NBUCKET;
}

static __always_inline __u16 csum_fold32(__u32 s)
{
	s = (s & 0xffff) + (s >> 16);
	s = (s & 0xffff) + (s >> 16);
	return (__u16)s;
}

/* RFC 1624: HC' = ~(~HC + ~m + m') を 32bit 値 2 つ分 (旧 2 アドレス -> 新 2 アドレス) */
static __always_inline __u16 csum_replace2x32(__u16 check, __u32 o1, __u32 n1, __u32 o2, __u32 n2)
{
	__u32 s = (__u16)~check;
	s += (__u16)~(o1 & 0xffff) + (__u16)~(o1 >> 16);
	s += (n1 & 0xffff) + (n1 >> 16);
	s += (__u16)~(o2 & 0xffff) + (__u16)~(o2 >> 16);
	s += (n2 & 0xffff) + (n2 >> 16);
	return ~csum_fold32(s);
}

static __always_inline int set_macs(struct ethhdr *eth, struct cfg *c, __u32 dst)
{
	__u64 *m = bpf_map_lookup_elem(&mac_map, &dst);
	if (!m) {
		count(2);
		return -1;
	}
	__u64 v = *m;
	#pragma unroll
	for (int i = 0; i < 6; i++)
		eth->h_dest[i] = (v >> (8 * (5 - i))) & 0xff;
	__builtin_memcpy(eth->h_source, c->self_mac, 6);
	return 0;
}

SEC("xdp")
int xdp_lb(struct xdp_md *ctx)
{
	void *data = (void *)(long)ctx->data;
	void *end = (void *)(long)ctx->data_end;
	struct ethhdr *eth = data;
	struct iphdr *ip;
	struct tcphdr *tcp;
	__u32 k0 = 0;
	struct cfg *c;

	if ((void *)(eth + 1) > end || eth->h_proto != bpf_htons(ETH_P_IP))
		return XDP_PASS;
	ip = (void *)(eth + 1);
	if ((void *)(ip + 1) > end || ip->ihl != 5 || ip->protocol != IPPROTO_TCP)
		return XDP_PASS;
	if (ip->frag_off & bpf_htons(0x3fff))
		return XDP_PASS;
	tcp = (void *)(ip + 1);
	if ((void *)(tcp + 1) > end)
		return XDP_PASS;
	c = bpf_map_lookup_elem(&cfg_map, &k0);
	if (!c || ip->daddr != c->self)
		return XDP_PASS;

	__u32 osrc = ip->saddr, odst = ip->daddr, nsrc, ndst;
	if (tcp->dest == bpf_htons(443) && osrc == c->client) {
		__u32 b = bucket_of(bpf_ntohs(tcp->source));
		__u32 *t = bpf_map_lookup_elem(&bucket_map, &b);
		if (!t || *t == 0)
			return XDP_PASS;
		nsrc = c->self;
		ndst = *t;
		if (set_macs(eth, c, ndst))
			return XDP_DROP;
		count(0);
	} else if (tcp->source == bpf_htons(443)) {
		__u32 b = bucket_of(bpf_ntohs(tcp->dest));
		__u32 *t = bpf_map_lookup_elem(&bucket_map, &b);
		if (!t || *t == 0 || *t != osrc)
			return XDP_PASS;
		nsrc = c->self;
		ndst = c->client;
		if (set_macs(eth, c, ndst))
			return XDP_DROP;
		count(1);
	} else {
		return XDP_PASS;
	}
	ip->check = csum_replace2x32(ip->check, osrc, nsrc, odst, ndst);
	tcp->check = csum_replace2x32(tcp->check, osrc, nsrc, odst, ndst);
	ip->saddr = nsrc;
	ip->daddr = ndst;
	return XDP_TX;
}

char LICENSE[] SEC("license") = "GPL";
