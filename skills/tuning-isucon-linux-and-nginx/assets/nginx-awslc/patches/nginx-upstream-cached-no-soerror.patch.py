# nginx: keepalive で再利用した upstream 接続 (u->peer.cached) では、接続完了確認の
# getsockopt(SO_ERROR) を省く。確立済みの接続なので connect() のエラーは起こり得ず、
# 切断はキャッシュ中の close ハンドラか writev/recv のエラーで従来どおり検出される。
import sys
p = sys.argv[1] + '/src/http/ngx_http_upstream.c'
s = open(p).read()
old = 'if (!u->request_sent && ngx_http_upstream_test_connect(c) != NGX_OK) {'
new = 'if (!u->request_sent && !u->peer.cached\n        && ngx_http_upstream_test_connect(c) != NGX_OK)\n    {'
if new in s:
    sys.exit(0)
assert s.count(old) == 2
open(p, 'w').write(s.replace(old, new))
