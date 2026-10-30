# nginx: ngx_ssl_recv() は SSL_read() を EAGAIN が返るまで繰り返すので、受信 1 回ごとに
# EAGAIN になるだけの read() が 1 回余計に走る。この ngx_ssl_recv() 呼び出しの中で
# ソケットの read() が短く返り (AWS-LC パッチ awslc-sock-short-read-flag.patch.py のフラグ)、
# SSL 層にも未処理データが無ければ、ngx_unix_recv() と同じ条件 (epoll + EPOLLRDHUP 対応、
# FIN 未受信) で ready を落として返る。以降に届いたデータは edge-triggered epoll が新たに通知する。
import sys
p = sys.argv[1] + '/src/event/ngx_event_openssl.c'
s = open(p).read()
if 'NGX_SSL_SHORT_READ' in s:
    sys.exit(0)
old1 = '''    bytes = 0;

    ngx_ssl_clear_error(c->log);

    /*
     * SSL_read() may return data in parts, so try to read
     * until SSL_read() would return no data
     */

    for ( ;; ) {
'''
new1 = '''    bytes = 0;

    ngx_ssl_clear_error(c->log);

#define NGX_SSL_SHORT_READ  0x10000
    BIO_clear_flags(SSL_get_rbio(c->ssl->connection), NGX_SSL_SHORT_READ);

    /*
     * SSL_read() may return data in parts, so try to read
     * until SSL_read() would return no data
     */

    for ( ;; ) {
'''
old2 = '''            buf += n;

            continue;
        }

        if (bytes) {
            if (c->ssl->last != NGX_AGAIN) {
'''
new2 = '''            buf += n;

#if (NGX_HAVE_EPOLLRDHUP)
            if ((ngx_event_flags & NGX_USE_EPOLL_EVENT)
                && ngx_use_epoll_rdhup
                && !c->read->pending_eof
                && BIO_test_flags(SSL_get_rbio(c->ssl->connection),
                                  NGX_SSL_SHORT_READ)
                && !SSL_has_pending(c->ssl->connection))
            {
                c->read->ready = 0;
                c->read->available = 0;
                return bytes;
            }
#endif

            continue;
        }

        if (bytes) {
            if (c->ssl->last != NGX_AGAIN) {
'''
assert s.count(old1) == 1 and s.count(old2) == 1
s = s.replace(old1, new1, 1).replace(old2, new2, 1)
open(p, 'w').write(s)
