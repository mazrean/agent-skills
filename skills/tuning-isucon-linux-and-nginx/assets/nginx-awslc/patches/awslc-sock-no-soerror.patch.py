# AWS-LC: ソケット BIO の read/write のたびに getsockopt(SO_ERROR) で保留エラーを消す処理を外す。
# 上流 BoringSSL / OpenSSL は POSIX ではやらない (read/write 自体が保留エラーを返して消す)。
# nginx では SSL レコード 1 つの読み書きごとに 1 syscall 余計に掛かっていた (worker の syscall の ~4 割)。
import sys
p = sys.argv[1] + '/crypto/bio/socket_helper.c'
s = open(p).read()
old = '''void bio_clear_socket_error(int sock) {
  bio_sock_error_get_and_clear(sock);
}'''
new = '''void bio_clear_socket_error(int sock) {
#if defined(OPENSSL_WINDOWS)
  bio_sock_error_get_and_clear(sock);
#else
  (void)sock;
#endif
}'''
if new in s:
    sys.exit(0)
assert old in s
open(p, 'w').write(s.replace(old, new, 1))
