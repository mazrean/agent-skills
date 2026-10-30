# nginx: reuseport の listen ソケットに、ワーカーが固定されている CPU を SO_INCOMING_CPU として設定する。
# Linux 6.x の reuseport_select_sock_by_hash() は SYN を処理している CPU と sk_incoming_cpu が一致する
# ソケットを選ぶので、NIC キュー N の割り込み = CPU N = ワーカー N で 1 本の接続が 1 コアに収まる。
import sys
p = sys.argv[1] + '/src/event/ngx_event.c'
s = open(p).read()
if 'SO_INCOMING_CPU' in s:
    sys.exit(0)
old = '''        if (ls[i].reuseport && ls[i].worker != ngx_worker) {
            continue;
        }
#endif
'''
new = old + '''
#if (NGX_HAVE_REUSEPORT && defined SO_INCOMING_CPU)
        if (ls[i].reuseport) {
            cpu_set_t  cpus;
            int        cpu, n = 0, found = -1;

            if (sched_getaffinity(0, sizeof(cpus), &cpus) == 0) {
                for (cpu = 0; cpu < CPU_SETSIZE; cpu++) {
                    if (CPU_ISSET(cpu, &cpus)) {
                        found = cpu;
                        n++;
                    }
                }
            }

            if (n == 1
                && setsockopt(ls[i].fd, SOL_SOCKET, SO_INCOMING_CPU,
                              &found, sizeof(int)) == -1)
            {
                ngx_log_error(NGX_LOG_ALERT, cycle->log, ngx_socket_errno,
                              "setsockopt(SO_INCOMING_CPU) failed, ignored");
            }
        }
#endif
'''
assert old in s
s = s.replace(old, new, 1)
open(p, 'w').write(s)
