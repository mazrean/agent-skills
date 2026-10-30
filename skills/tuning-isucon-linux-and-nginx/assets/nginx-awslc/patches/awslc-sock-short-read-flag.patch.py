# AWS-LC: ソケット BIO の read() が要求より短く返った (= その時点でカーネルの受信キューが空) ことを
# BIO フラグ 0x10000 (BIO_FLAGS_NGX_SHORT_READ) で nginx に伝える。nginx 側
# (nginx-ssl-recv-short-read.patch.py) はこれを見て、EAGAIN になるだけの read() を省く。
import sys
p = sys.argv[1] + '/crypto/bio/socket.c'
s = open(p).read()
if 'BIO_FLAGS_NGX_SHORT_READ' in s:
    sys.exit(0)
old = '''  int ret = (int)read(b->num, out, outl);
#endif
  BIO_clear_retry_flags(b);
'''
new = '''  int ret = (int)read(b->num, out, outl);
#endif
  BIO_clear_retry_flags(b);
#define BIO_FLAGS_NGX_SHORT_READ 0x10000
  if (ret > 0 && ret < outl) {
    BIO_set_flags(b, BIO_FLAGS_NGX_SHORT_READ);
  } else {
    BIO_clear_flags(b, BIO_FLAGS_NGX_SHORT_READ);
  }
'''
assert s.count(old) == 1
open(p, 'w').write(s.replace(old, new, 1))
